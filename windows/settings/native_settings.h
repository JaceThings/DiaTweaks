#pragma once
#include "visibility.h"
#include <functional>
#include <memory>
namespace dt {
struct SettingsError { HRESULT code; std::wstring detail; };
class NativeSettings {
    struct Impl;
    std::unique_ptr<Impl> impl_;
public:
    NativeSettings(IXamlDiagnostics*, IVisualTreeService*, InstanceHandle,
                   bool available, bool on, std::function<void(bool)> changed);
    ~NativeSettings();
    void remove();
    void sync(bool on);
    std::wstring status() const;
};
}
