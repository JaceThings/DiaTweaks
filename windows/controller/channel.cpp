#include "channel.h"
#include <sddl.h>
#include <vector>

namespace dt {
Channel::Channel(DWORD target) {
    auto lockName = L"Local\\DiaTweaks.Controller." + std::to_wstring(target);
    controllerLock_.value = CreateMutexW(nullptr, FALSE, lockName.c_str());
    if (!controllerLock_) throw last_error();
    if (GetLastError() == ERROR_ALREADY_EXISTS) throw HRESULT_FROM_WIN32(ERROR_ALREADY_EXISTS);
    GUID id{};
    check(CoCreateGuid(&id));
    wchar_t guid[40]{};
    StringFromGUID2(id, guid, 40);
    name = L"Local\\DiaTweaks.Prototype." + std::wstring(guid);
    Handle token;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token.value)) throw last_error();
    DWORD length = 0;
    GetTokenInformation(token.value, TokenUser, nullptr, 0, &length);
    std::vector<BYTE> user(length);
    if (!GetTokenInformation(token.value, TokenUser, user.data(), length, &length)) throw last_error();
    LPWSTR sid = nullptr;
    if (!ConvertSidToStringSidW(reinterpret_cast<TOKEN_USER*>(user.data())->User.Sid, &sid)) throw last_error();
    auto sddl = L"D:P(A;;GA;;;" + std::wstring(sid) + L")";
    LocalFree(sid);
    PSECURITY_DESCRIPTOR descriptor = nullptr;
    if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl.c_str(), SDDL_REVISION_1, &descriptor, nullptr)) throw last_error();
    SECURITY_ATTRIBUTES security{sizeof(security), descriptor, FALSE};
    mapping_.value = CreateFileMappingW(INVALID_HANDLE_VALUE, &security, PAGE_READWRITE, 0, sizeof(Shared), name.c_str());
    const auto error = GetLastError();
    LocalFree(descriptor);
    if (!mapping_) throw HRESULT_FROM_WIN32(error);
    if (error == ERROR_ALREADY_EXISTS) throw HRESULT_FROM_WIN32(ERROR_ALREADY_EXISTS);
    shared = static_cast<Shared*>(MapViewOfFile(mapping_.value, FILE_MAP_ALL_ACCESS, 0, 0, sizeof(Shared)));
    if (!shared) throw last_error();
    shared->version = ProtocolVersion;
    shared->controller = GetCurrentProcessId();
    shared->target = target;
}
Channel::~Channel() {
    if (shared) {
        InterlockedExchange(&shared->stop, 1);
        // The TAP restores on its UI threads; it stays pinned until Dia exits.
        const auto deadline = GetTickCount64() + 3000;
        while (read_flag(shared->ready) == 1 && GetTickCount64() < deadline) Sleep(25);
        UnmapViewOfFile(shared);
    }
}
HRESULT Channel::call(Request request, std::wstring& response) {
    if (read_flag(shared->phase) != Idle) return HRESULT_FROM_WIN32(ERROR_BUSY);
    shared->request = request;
    InterlockedExchange(&shared->phase, Pending);
    const auto deadline = GetTickCount64() + 12000;
    while (read_flag(shared->phase) != Complete) {
        if (GetTickCount64() >= deadline || read_flag(shared->ready) != 1) return HRESULT_FROM_WIN32(ERROR_TIMEOUT);
        Sleep(25);
    }
    response.assign(shared->response, wcsnlen_s(shared->response, ResponseCapacity));
    const HRESULT hr = shared->result;
    InterlockedExchange(&shared->phase, Idle);
    return hr;
}
}
