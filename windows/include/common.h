#pragma once
#include <windows.h>
#include <wrl.h>
#include <string>
#include <stdexcept>
#include <utility>
#if !defined(_M_X64)
#error The prototype currently supports x64 only.
#endif

namespace dt {
using Microsoft::WRL::ComPtr;
inline constexpr CLSID TapClsid = {0x82317f6e, 0x3789, 0x47ad, {0xb3, 0xc8, 0x2b, 0x99, 0x04, 0x4c, 0xa8, 0xc1}};
inline void check(HRESULT hr) { if (FAILED(hr)) throw hr; }
inline HRESULT last_error() { return HRESULT_FROM_WIN32(GetLastError()); }
struct Handle {
    HANDLE value = nullptr;
    Handle() = default;
    explicit Handle(HANDLE h) : value(h) {}
    ~Handle() { if (value && value != INVALID_HANDLE_VALUE) CloseHandle(value); }
    Handle(const Handle&) = delete;
    Handle& operator=(const Handle&) = delete;
    Handle(Handle&& other) noexcept : value(std::exchange(other.value, nullptr)) {}
    explicit operator bool() const { return value && value != INVALID_HANDLE_VALUE; }
};
struct Bstr {
    BSTR value = nullptr;
    Bstr() = default;
    explicit Bstr(const wchar_t* s) : value(SysAllocString(s)) { if (!value) throw E_OUTOFMEMORY; }
    ~Bstr() { SysFreeString(value); }
    Bstr(const Bstr&) = delete;
    Bstr& operator=(const Bstr&) = delete;
};
inline std::wstring str(BSTR s) { return s ? std::wstring(s, SysStringLen(s)) : L""; }
}
