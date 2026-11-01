#pragma once
#include "native_features.h"
namespace dt {
class LayoutFeatures {
    struct Impl;
    std::unique_ptr<Impl> impl_;
public:
    LayoutFeatures(IXamlDiagnostics*, IVisualTreeService*);
    ~LayoutFeatures();
    void tick(const std::vector<Node>&, uint32_t, FeatureStates&);
    void restore();
    bool active() const;
};
}
