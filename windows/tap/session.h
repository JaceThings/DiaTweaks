#pragma once
#include "protocol.h"
#include "visibility.h"
#include <ocidl.h>
#include <atomic>
#include <map>
#include <memory>
#include <mutex>

namespace dt {
struct Node { uint64_t id; InstanceHandle handle, parent; DWORD thread; std::wstring type, name; };
struct Job {
    Request request{};
    Handle done{CreateEventW(nullptr, TRUE, FALSE, nullptr)};
    std::atomic<bool> cancelled{false};
    ULONGLONG deadline = GetTickCount64() + 5000;
    HRESULT result = E_PENDING;
    std::wstring response;
};
class Session;
struct Context {
    Session* session;
    DWORD thread;
    std::atomic<HWND> window{nullptr};
    VisibilityLease lease;
    static LRESULT CALLBACK window_proc(HWND, UINT, WPARAM, LPARAM);
    void execute(Job&);
};
class Session final : public Microsoft::WRL::RuntimeClass<
    Microsoft::WRL::RuntimeClassFlags<Microsoft::WRL::ClassicCom>,
    IVisualTreeServiceCallback2, Microsoft::WRL::FtmBase> {
    Handle mapping_, controller_;
    Shared* shared_ = nullptr;
    std::mutex mutex_;
    std::map<std::pair<DWORD, InstanceHandle>, Node> nodes_;
    std::map<DWORD, std::unique_ptr<Context>> contexts_;
    uint64_t nextId_ = 1;
    bool overflow_ = false;
    void run() noexcept;
    HRESULT dispatch(Context*, Request, std::wstring&);
public:
    ~Session() { if (shared_) UnmapViewOfFile(shared_); }
    ComPtr<IVisualTreeService> service;
    std::atomic<bool> stopping{false};
    HRESULT start(IUnknown*);
    HRESULT STDMETHODCALLTYPE OnVisualTreeChange(ParentChildRelation, VisualElement, VisualMutationType) noexcept override;
    HRESULT STDMETHODCALLTYPE OnElementStateChanged(InstanceHandle, VisualElementState, LPCWSTR) noexcept override { return S_OK; }
    std::optional<Node> node(uint64_t);
    std::wstring tree();
};
}
