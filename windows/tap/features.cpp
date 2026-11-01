#include "session.h"
#include <set>
namespace dt {
std::vector<Node> Session::sidebar_nodes(DWORD thread) {
    std::lock_guard lock(mutex_);
    std::vector<Node> result;
    for (const auto& [_, n] : nodes_) if (n.thread == thread &&
        n.type == L"Microsoft.UI.Xaml.Controls.Button" && n.name == L"SidebarToggleButton") result.push_back(n);
    return result;
}
bool Session::is_settings_navigation(uint64_t id) {
    std::lock_guard lock(mutex_);
    const Node* nav = nullptr;
    for (const auto& [_, n] : nodes_) if (n.id == id) nav = &n;
    if (!nav || nav->type != L"Microsoft.UI.Xaml.Controls.NavigationView") return false;
    std::set<std::wstring> names;
    for (const auto& [_, n] : nodes_) {
        if (n.thread != nav->thread || n.type != L"Microsoft.UI.Xaml.Controls.NavigationViewItem") continue;
        auto parent = n.parent;
        for (size_t depth = 0; parent && depth < 64; ++depth) {
            if (parent == nav->handle) { names.insert(n.name); break; }
            auto it = nodes_.find({nav->thread, parent});
            if (it == nodes_.end()) break;
            parent = it->second.parent;
        }
    }
    return names.contains(L"account") && names.contains(L"tabs") && names.contains(L"advanced");
}
void Context::sync_feature() {
    const auto nodes = session->sidebar_nodes(thread);
    const bool enabled = session->hideSidebar && !session->stopping;
    std::set<uint64_t> current;
    for (const auto& n : nodes) current.insert(n.id);
    for (auto it = featureOverrides.begin(); it != featureOverrides.end();) {
        if (!current.contains(it->first)) { it = featureOverrides.erase(it); continue; }
        if (!enabled) {
            if (SUCCEEDED(it->second.restore(session->service.Get()))) it = featureOverrides.erase(it);
            else ++it;
        } else ++it;
    }
    if (enabled) for (const auto& n : nodes) if (!featureOverrides.contains(n.id)) {
        VisibilityLease value;
        if (value.enable(session->service.Get(), n.handle) == S_OK) featureOverrides.emplace(n.id, std::move(value));
    }
}
}
