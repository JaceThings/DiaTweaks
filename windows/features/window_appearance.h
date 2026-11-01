#pragma once
#include "native_features.h"
namespace dt {
// Windows adaptation: retain caption colors without changing actual activation,
// keyboard focus, DWM shadow policy, or the application's backdrop controller.
class WindowAppearance {
    struct Impl;
    std::unique_ptr<Impl> impl_;
public:
    explicit WindowAppearance(IXamlDiagnostics*);
    ~WindowAppearance();
    void tick(const std::vector<Node>&, bool on, FeatureState&);
    void restore();
    bool active() const;
};
}
