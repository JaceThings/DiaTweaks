#pragma once
#include "visibility.h"
#include "feature_state.h"
#include <functional>
#include <memory>
namespace dt {
struct SettingsError { HRESULT code; std::wstring detail; };
class NativeSettings {
    struct Impl;
    std::unique_ptr<Impl> impl_;
public:
    NativeSettings(IXamlDiagnostics*, IVisualTreeService*, InstanceHandle,
                   const FeatureStates&, FeatureChanged changed);
    ~NativeSettings();
    void remove();
    void sync(const FeatureStates&);
    std::wstring status() const;
    bool alive() const noexcept;
};
}
