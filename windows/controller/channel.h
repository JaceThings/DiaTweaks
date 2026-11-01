#pragma once
#include "protocol.h"
namespace dt {
class Channel {
    Handle mapping_;
    Handle controllerLock_;
public:
    Shared* shared = nullptr;
    std::wstring name;
    explicit Channel(DWORD target);
    ~Channel();
    HRESULT call(Request request, std::wstring& response);
};
}
