#pragma once
#include "common.h"
#include <filesystem>
namespace dt {
// WindowsApps may permit reading a DLL while denying execution by an unpackaged
// process. Stage the exact installed bytes for this controller only. Never ship
// the staged DLL or alter the installed package's ACLs.
class RuntimeLibrary {
    HMODULE module_ = nullptr;
    std::filesystem::path directory_;
public:
    explicit RuntimeLibrary(const std::filesystem::path& installed) {
        module_ = LoadLibraryExW(installed.c_str(), nullptr,
            LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
        if (module_) return;
        auto error = GetLastError();
        if (error != ERROR_ACCESS_DENIED) throw HRESULT_FROM_WIN32(error);
        GUID id{}; check(CoCreateGuid(&id));
        wchar_t name[40]{}; StringFromGUID2(id, name, 40);
        directory_ = std::filesystem::temp_directory_path() / (L"DiaTweaksRuntime-" + std::wstring(name));
        std::filesystem::create_directory(directory_);
        try {
            const auto local = directory_ / installed.filename();
            std::filesystem::copy_file(installed, local);
            module_ = LoadLibraryExW(local.c_str(), nullptr,
                LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
            if (!module_) throw last_error();
        } catch (...) { cleanup(); throw; }
    }
    ~RuntimeLibrary() { if (module_) FreeLibrary(module_); cleanup(); }
    RuntimeLibrary(const RuntimeLibrary&) = delete;
    RuntimeLibrary& operator=(const RuntimeLibrary&) = delete;
    FARPROC symbol(const char* name) const { return GetProcAddress(module_, name); }
    bool staged() const { return !directory_.empty(); }
private:
    void cleanup() noexcept {
        if (directory_.empty()) return;
        std::error_code ignored;
        std::filesystem::remove(directory_ / L"Microsoft.Internal.FrameworkUdk.dll", ignored);
        std::filesystem::remove(directory_, ignored);
    }
};
}
