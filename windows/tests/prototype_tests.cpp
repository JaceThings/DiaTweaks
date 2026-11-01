#include "fake_service.h"
#include "channel.h"
#include <future>
#include <iostream>
#include <filesystem>

using namespace dt;
using namespace dt::test;
static void require(bool ok, const char* message) { if (!ok) throw std::runtime_error(message); }
static void property_tests() {
    auto service = Microsoft::WRL::Make<FakeService>();
    VisibilityLease lease;
    require(lease.pulse(service.Get(), 42, 0) == E_INVALIDARG, "reject zero duration");
    require(lease.pulse(service.Get(), 42, 31) == E_INVALIDARG, "bound duration");
    require(lease.pulse(service.Get(), 42, 1) == S_OK && service->collapsed, "collapse default");
    require(FAILED(lease.pulse(service.Get(), 42, 1)), "refuse overlapping override");
    require(lease.restore(service.Get()) == S_OK && !service->local && service->clears == 1, "restore by clearing default override");
    service->local = true;
    require(lease.pulse(service.Get(), 42, 1) == S_OK, "collapse local literal");
    require(lease.restore(service.Get()) == S_OK && service->local && !service->collapsed, "restore local literal");
    service->local = false; service->metadata = IsValueBindingExpression;
    require(lease.pulse(service.Get(), 42, 1) == E_NOTIMPL, "preserve binding");
    service->metadata = 0; service->source = Animation;
    require(lease.pulse(service.Get(), 42, 1) == E_NOTIMPL, "preserve animation");
    service->source = BaseValueSourceDefault; service->type = L"UnexpectedEnum";
    require(lease.pulse(service.Get(), 42, 1) == E_NOTIMPL, "refuse unknown property type");
    service->type = L"Microsoft.UI.Xaml.Visibility"; service->collapsed = true;
    require(lease.pulse(service.Get(), 42, 1) == S_FALSE && !lease.active(), "leave existing collapsed state alone");
    service->collapsed = false; service->ignoreWrites = true;
    require(FAILED(lease.pulse(service.Get(), 42, 1)) && !lease.active(), "verify readback");
    service->ignoreWrites = false; service->failWriteOnce = true;
    require(FAILED(lease.pulse(service.Get(), 42, 1)) && !service->local, "rollback partially failed write");
    require(lease.pulse(service.Get(), 42, 1) == S_OK, "set before app update");
    service->collapsed = false;
    require(lease.restore(service.Get()) == S_FALSE && service->local, "preserve app's newer value");
    service->local = false;
    require(lease.pulse(service.Get(), 42, 1) == S_OK, "set before element removal");
    const int writes = service->sets;
    lease.removed(42);
    require(!lease.active() && lease.restore(service.Get()) == S_FALSE && writes == service->sets, "never write a removed handle");
}
static LRESULT CALLBACK fixture_proc(HWND window, UINT message, WPARAM wp, LPARAM lp) {
    if (message == WM_APP + 1) {
        auto* callback = reinterpret_cast<IVisualTreeServiceCallback*>(lp);
        Bstr type(L"Microsoft.UI.Xaml.Controls.Button"), name(L"FixtureChatButton");
        VisualElement element{};
        element.Handle = 42; element.Type = type.value; element.Name = name.value;
        callback->OnVisualTreeChange({0, 42, 0}, element, Add);
        return 0;
    }
    return DefWindowProcW(window, message, wp, lp);
}
static void session_tests() {
    auto service = Microsoft::WRL::Make<FakeService>();
    WNDCLASSW wc{};
    wc.lpfnWndProc = fixture_proc; wc.hInstance = GetModuleHandleW(nullptr); wc.lpszClassName = L"DiaTweaks.TestFixture";
    require(RegisterClassW(&wc) != 0, "register fixture");
    service->ui = CreateWindowExW(0, wc.lpszClassName, L"", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr, wc.hInstance, nullptr);
    require(service->ui != nullptr, "create fixture message window");
    wchar_t executable[32768]{};
    GetModuleFileNameW(nullptr, executable, 32768);
    auto dll = std::filesystem::path(executable).parent_path() / L"DiaTweaksTap.dll";
    HMODULE module = LoadLibraryW(dll.c_str());
    require(module != nullptr, "load real TAP DLL");
    using GetClass = HRESULT(WINAPI*)(REFCLSID, REFIID, void**);
    auto getClass = reinterpret_cast<GetClass>(GetProcAddress(module, "DllGetClassObject"));
    require(getClass != nullptr, "exported COM factory");
    ComPtr<IClassFactory> factory;
    check(getClass(TapClsid, IID_PPV_ARGS(&factory)));
    ComPtr<IObjectWithSite> tap;
    check(factory->CreateInstance(nullptr, IID_PPV_ARGS(&tap)));
    auto future = std::async(std::launch::async, [&] {
        check(CoInitializeEx(nullptr, COINIT_MULTITHREADED));
        {
            Channel channel(GetCurrentProcessId());
            service->initialization = channel.name;
            check(tap->SetSite(static_cast<IVisualTreeService*>(service.Get())));
            const auto deadline = GetTickCount64() + 5000;
            while (!read_flag(channel.shared->ready) && GetTickCount64() < deadline) Sleep(10);
            require(read_flag(channel.shared->ready) == 1, "session handshake");
            bool duplicateRejected = false;
            try { Channel duplicate(GetCurrentProcessId()); }
            catch (HRESULT hr) { duplicateRejected = hr == HRESULT_FROM_WIN32(ERROR_ALREADY_EXISTS); }
            require(duplicateRejected, "one controller per target");
            std::wstring response;
            require(SUCCEEDED(channel.call({Command::Tree, 0, 0}, response)) && response.find(L"FixtureChatButton") != std::wstring::npos, "tree roundtrip");
            require(channel.call({Command::Inspect, 1, 0}, response) == S_OK && response.find(L"Visible") != std::wstring::npos, "inspect on owner thread");
            require(FAILED(channel.call({Command::Pulse, 999, 1}, response)), "reject stale ID");
            require(channel.call({Command::Pulse, 1, 1}, response) == S_OK && service->collapsed, "pulse roundtrip");
            const auto restoredBy = GetTickCount64() + 2500;
            while (service->collapsed && GetTickCount64() < restoredBy) Sleep(25);
            require(!service->collapsed && !service->local, "timer restores original source");
            require(channel.call({Command::Pulse, 1, 30}, response) == S_OK && service->collapsed, "long lease before disconnect");
        }
        require(!service->collapsed && !service->local, "controller disconnect restores");
        require(!service->wrongThread, "all property calls stay on UI thread");
        CoUninitialize();
    });
    while (future.wait_for(std::chrono::milliseconds(0)) != std::future_status::ready) {
        MSG msg{};
        while (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) { TranslateMessage(&msg); DispatchMessageW(&msg); }
        MsgWaitForMultipleObjectsEx(0, nullptr, 10, QS_ALLINPUT, MWMO_INPUTAVAILABLE);
    }
    DestroyWindow(service->ui);
    future.get();
    check(tap->SetSite(nullptr));
    // Like diagnostics, retain the module until process exit, even after stop.
}
int main() {
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    try {
        property_tests(); session_tests();
        std::cout << "PASS: restore policy, failure rollback, IPC, UI-thread dispatch, timer and disconnect\n";
    } catch (HRESULT hr) { std::cerr << "HRESULT failure: " << std::hex << hr << '\n'; return 1; }
      catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
    CoUninitialize();
    return 0;
}
