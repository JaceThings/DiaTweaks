#include "session.h"
#include <sstream>

namespace dt {
static constexpr UINT WorkMessage = WM_APP + 73;
static constexpr wchar_t WindowClass[] = L"DiaTweaks.Prototype.UIThread";
static std::wstring field(std::wstring s) {
    for (auto& c : s) if (c == L'\t' || c == L'\r' || c == L'\n') c = L' ';
    return s.substr(0, 256);
}
HRESULT Session::OnVisualTreeChange(ParentChildRelation relation, VisualElement element, VisualMutationType mutation) noexcept {
    try {
        const auto thread = GetCurrentThreadId();
        Context* context = nullptr;
        {
            std::lock_guard lock(mutex_);
            const auto key = std::make_pair(thread, element.Handle);
            if (mutation == Remove) {
                nodes_.erase(key);
                if (auto it = contexts_.find(thread); it != contexts_.end()) it->second->lease.removed(element.Handle);
                return S_OK;
            }
            if (stopping) return S_OK;
            if (nodes_.size() >= 8192) { overflow_ = true; return S_OK; }
            auto existing = nodes_.find(key);
            auto id = existing != nodes_.end() ? existing->second.id : nextId_++;
            nodes_[key] = {id, element.Handle, relation.Parent, thread, field(str(element.Type)), field(str(element.Name))};
            if (!contexts_.contains(thread)) {
                auto ctx = std::make_unique<Context>();
                ctx->session = this; ctx->thread = thread;
                contexts_[thread] = std::move(ctx);
            }
            context = contexts_[thread].get();
        }
        if (!context->window) {
            WNDCLASSW wc{};
            wc.lpfnWndProc = Context::window_proc;
            wc.hInstance = GetModuleHandleW(nullptr);
            wc.lpszClassName = WindowClass;
            if (!RegisterClassW(&wc) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) return S_OK;
            context->window = CreateWindowExW(0, WindowClass, L"", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr, wc.hInstance, context);
            if (context->window && !SetTimer(context->window, 1, 100, nullptr)) {
                DestroyWindow(context->window); context->window = nullptr;
            }
        }
    } catch (...) { /* Never unwind into Dia or stop its diagnostics callbacks. */ }
    return S_OK;
}
std::optional<Node> Session::node(uint64_t id) {
    std::lock_guard lock(mutex_);
    for (const auto& [_, n] : nodes_) if (n.id == id) return n;
    return {};
}
std::wstring Session::tree() {
    std::lock_guard lock(mutex_);
    std::wostringstream out;
    out << L"id\tthread\thandle\tparent-handle\ttype\tx:Name\n";
    for (const auto& [_, n] : nodes_) out << n.id << L'\t' << n.thread << L'\t' << n.handle << L'\t'
        << n.parent << L'\t' << n.type << L'\t' << n.name << L'\n';
    if (overflow_) out << L"TRUNCATED: more than 8192 nodes; restart Dia to reset this probe.\n";
    return out.str();
}
void Context::execute(Job& job) {
    if (job.cancelled || GetTickCount64() > job.deadline) { job.result = HRESULT_FROM_WIN32(ERROR_TIMEOUT); return; }
    if (job.request.command == Command::Restore) {
        job.result = lease.restore(session->service.Get());
        job.response = lease.active() ? L"Restore failed; retrying on the UI thread.\n" : L"Restored (or no active override).\n";
        return;
    }
    if (session->stopping) { job.result = E_ABORT; return; }
    auto node = session->node(job.request.handle);
    if (!node || node->thread != GetCurrentThreadId()) { job.result = HRESULT_FROM_WIN32(ERROR_NOT_FOUND); return; }
    if (job.request.command == Command::Inspect) {
        Visibility v;
        job.result = read_visibility(session->service.Get(), node->handle, v);
        if (SUCCEEDED(job.result)) job.response = L"Visibility=" + v.value + L"; type=" + v.type +
            (v.local ? L"; source=local\n" : L"; source=style/default\n");
    } else if (job.request.command == Command::Pulse) {
        job.result = lease.pulse(session->service.Get(), node->handle, job.request.seconds);
        job.response = job.result == S_OK ? L"Collapsed; automatic restore is armed.\n" : L"No new override applied.\n";
    } else job.result = E_INVALIDARG;
}
LRESULT CALLBACK Context::window_proc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    auto* context = reinterpret_cast<Context*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (msg == WM_NCCREATE) {
        context = static_cast<Context*>(reinterpret_cast<CREATESTRUCTW*>(lp)->lpCreateParams);
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(context));
    }
    try {
        if (context && msg == WorkMessage) {
            std::unique_ptr<std::shared_ptr<Job>> holder(reinterpret_cast<std::shared_ptr<Job>*>(lp));
            auto job = *holder;
            try { context->execute(*job); } catch (...) { job->result = E_FAIL; }
            SetEvent(job->done.value);
            return 0;
        }
        if (context && msg == WM_TIMER) {
            if (context->lease.expired() || context->session->stopping) context->lease.restore(context->session->service.Get());
            if (context->session->stopping && !context->lease.active()) KillTimer(hwnd, 1);
            return 0;
        }
    } catch (...) { /* The next timer can retry restoration. */ }
    return DefWindowProcW(hwnd, msg, wp, lp);
}
HRESULT Session::dispatch(Context* context, Request request, std::wstring& response) {
    const HWND window = context->window.load();
    if (!window) return HRESULT_FROM_WIN32(ERROR_INVALID_WINDOW_HANDLE);
    auto job = std::make_shared<Job>();
    job->request = request;
    if (!job->done) return last_error();
    auto* holder = new std::shared_ptr<Job>(job);
    if (!PostMessageW(window, WorkMessage, 0, reinterpret_cast<LPARAM>(holder))) { delete holder; return last_error(); }
    if (WaitForSingleObject(job->done.value, 6000) != WAIT_OBJECT_0) {
        job->cancelled = true;
        return HRESULT_FROM_WIN32(ERROR_TIMEOUT);
    }
    response += job->response;
    return job->result;
}
}
