#pragma once
#include "common.h"
#include <xamlom.h>
#include <optional>

namespace dt {
struct PropertyValues {
    unsigned sourcesCount = 0, valuesCount = 0;
    PropertyChainSource* sources = nullptr;
    PropertyChainValue* values = nullptr;
    ~PropertyValues();
    HRESULT read(IVisualTreeService* service, InstanceHandle handle);
};
struct Visibility {
    unsigned index;
    std::wstring type, value;
    bool local;
};
HRESULT read_visibility(IVisualTreeService*, InstanceHandle, Visibility&);
class VisibilityLease {
    struct Saved { InstanceHandle handle; Visibility original; ULONGLONG deadline; };
    std::optional<Saved> saved_;
public:
    bool active() const { return saved_.has_value(); }
    bool expired() const { return saved_ && GetTickCount64() >= saved_->deadline; }
    HRESULT pulse(IVisualTreeService*, InstanceHandle, DWORD seconds);
    HRESULT restore(IVisualTreeService*);
    void removed(InstanceHandle h) { if (saved_ && saved_->handle == h) saved_.reset(); }
};
}
