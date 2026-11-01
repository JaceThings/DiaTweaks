#include "target.h"
#include "runtime.h"
#include <tlhelp32.h>
#include <appmodel.h>
#include <vector>
#include <iostream>

namespace dt {
static bool has_ui_window(DWORD pid) {
    struct Search { DWORD pid; bool found; } search{pid, false};
    EnumWindows([](HWND window, LPARAM data) -> BOOL {
        auto& search = *reinterpret_cast<Search*>(data);
        DWORD owner = 0;
        GetWindowThreadProcessId(window, &owner);
        if (owner == search.pid && IsWindowVisible(window)) { search.found = true; return FALSE; }
        return TRUE;
    }, reinterpret_cast<LPARAM>(&search));
    return search.found;
}
static Target inspect(DWORD pid) {
    if (!has_ui_window(pid)) throw HRESULT_FROM_WIN32(ERROR_NOT_FOUND);
    Handle process(OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION | SYNCHRONIZE, FALSE, pid));
    if (!process) throw last_error();
    USHORT machine = 0, native = 0;
    if (!IsWow64Process2(process.value, &machine, &native)) throw last_error();
    if (machine != IMAGE_FILE_MACHINE_UNKNOWN || native != IMAGE_FILE_MACHINE_AMD64) throw E_NOTIMPL;
    UINT32 count = 0;
    if (GetPackageFamilyName(process.value, &count, nullptr) != ERROR_INSUFFICIENT_BUFFER) throw E_ACCESSDENIED;
    std::wstring family(count, L'\0');
    if (GetPackageFamilyName(process.value, &count, family.data()) != ERROR_SUCCESS) throw E_ACCESSDENIED;
    family.resize(count - 1);
    if (family != L"TheBrowserCompany.Dia_ttt1ap7aakyb4") throw E_ACCESSDENIED;
    Handle modules(CreateToolhelp32Snapshot(TH32CS_SNAPMODULE, pid));
    if (!modules) throw last_error();
    MODULEENTRY32W module{sizeof(module)};
    std::filesystem::path framework;
    if (Module32FirstW(modules.value, &module)) do {
        if (!_wcsicmp(module.szModule, L"DiaTweaksTap.dll")) throw HRESULT_FROM_WIN32(ERROR_ALREADY_EXISTS);
        if (!_wcsicmp(module.szModule, L"Microsoft.Internal.FrameworkUdk.dll")) framework = module.szExePath;
    } while (Module32NextW(modules.value, &module));
    if (framework.empty()) throw HRESULT_FROM_WIN32(ERROR_MOD_NOT_FOUND);
    return {pid, framework, family};
}

Target find_target(DWORD requestedPid) {
    Handle snapshot(CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0));
    if (!snapshot) throw last_error();
    PROCESSENTRY32W p{sizeof(p)};
    std::vector<Target> matches;
    HRESULT rejection = HRESULT_FROM_WIN32(ERROR_NOT_FOUND);
    if (Process32FirstW(snapshot.value, &p)) do {
        if (_wcsicmp(p.szExeFile, L"Dia.exe") || (requestedPid && p.th32ProcessID != requestedPid)) continue;
        try { matches.push_back(inspect(p.th32ProcessID)); }
        catch (HRESULT hr) { if (requestedPid || hr == HRESULT_FROM_WIN32(ERROR_ALREADY_EXISTS)) rejection = hr; }
    } while (Process32NextW(snapshot.value, &p));
    if (matches.empty()) throw rejection;
    if (matches.size() != 1) throw HRESULT_FROM_WIN32(ERROR_MORE_DATA);
    return matches.front();
}

HRESULT attach(const Target& target, const std::filesystem::path& dll, const std::wstring& initialization) {
    // Load the exact diagnostics runtime already loaded by this Dia process.
    RuntimeLibrary framework(target.framework);
    if (framework.staged()) std::wcout << L"Loaded an exact temporary copy of the installed diagnostics runtime.\n";
    using Initialize = HRESULT(WINAPI*)(LPCWSTR, DWORD, LPCWSTR, LPCWSTR, CLSID, LPCWSTR);
    auto initialize = reinterpret_cast<Initialize>(framework.symbol("InitializeXamlDiagnosticsEx"));
    HRESULT hr = HRESULT_FROM_WIN32(ERROR_PROC_NOT_FOUND);
    if (initialize) {
        const auto deadline = GetTickCount64() + 10000;
        for (int i = 1; i <= 10000 && GetTickCount64() < deadline; ++i) {
            auto endpoint = L"WinUIVisualDiagConnection" + std::to_wstring(i);
            hr = initialize(endpoint.c_str(), target.pid, L"", dll.c_str(), TapClsid, initialization.c_str());
            if (hr != HRESULT_FROM_WIN32(ERROR_NOT_FOUND)) std::wcerr << L"Diagnostics endpoint " << endpoint << L" returned 0x" << std::hex << static_cast<unsigned long>(hr) << std::dec << L'\n';
            if (hr != HRESULT_FROM_WIN32(ERROR_NOT_FOUND)) break;
        }
    }
    return hr;
}
}
