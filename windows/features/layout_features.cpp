#include "layout_features.h"
#include "toolbar_adapter.h"
#include "session.h"
#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <set>
#include <sstream>
namespace dt {
using namespace winrt;
using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Xaml::Controls;
struct LayoutFeatures::Impl {
    ComPtr<IXamlDiagnostics> diagnostics;
    ComPtr<IVisualTreeService> service;
    struct Edge { std::unique_ptr<OverrideSet> margin, corners; uint64_t frames = 0; bool adjacent = false; };
    std::map<uint64_t, Edge> edges;
    std::map<uint64_t, std::unique_ptr<ToolbarAdapter>> toolbars;
    std::map<uint64_t, HRESULT> toolbarErrors, edgeErrors, cornerErrors;
    Impl(IXamlDiagnostics* d, IVisualTreeService* s) : diagnostics(d), service(s) {}
    FrameworkElement element(InstanceHandle h) {
        ComPtr<::IInspectable> raw; check(diagnostics->GetIInspectableFromHandle(h, &raw));
        winrt::Windows::Foundation::IInspectable object{nullptr}; copy_from_abi(object, raw.Get()); return object.try_as<FrameworkElement>();
    }
    std::unique_ptr<OverrideSet> transaction() { return std::make_unique<OverrideSet>(diagnostics.Get(), service.Get()); }
    void square(const Grid& content, OverrideSet& set, const std::vector<Node>& nodes) {
        auto root = Media::VisualTreeHelper::GetParent(content).try_as<Grid>();
        if (!root || Grid::GetColumn(content) == 0 || root.ColumnDefinitions().Size() < 2 || root.ColumnDefinitions().GetAt(0).ActualWidth() < 10) return;
        // Only the SharedSurface and the sibling frame borders immediately
        // enclosing browser panes qualify. Never round arbitrary page controls.
        for (const auto& n : nodes) {
            if (n.name != L"NavigationChromeHost" && n.name != L"SharedSurface") continue;
            auto e = element(n.handle);
            if (!e || e.XamlRoot() != content.XamlRoot()) continue;
            Border shell = e.try_as<Border>();
            if (!shell) for (auto p = Media::VisualTreeHelper::GetParent(e); p; p = Media::VisualTreeHelper::GetParent(p)) {
                if (auto b = p.try_as<Border>()) { shell = b; break; }
            }
            if (!shell) continue;
            auto parent = Media::VisualTreeHelper::GetParent(shell).try_as<Grid>();
            if (!parent) continue;
            if (n.name == L"SharedSurface") {
                auto c = shell.CornerRadius(); c.TopLeft = c.BottomLeft = 0;
                set.add(shell, Border::CornerRadiusProperty(), L"CornerRadius", c);
            } else for (const auto& child : parent.Children()) if (auto border = child.try_as<Border>()) {
                auto c = border.CornerRadius();
                if (c.TopLeft > 16 || c.BottomLeft > 16) throw E_NOTIMPL;
                c.TopLeft = c.BottomLeft = 0;
                set.add(border, Border::CornerRadiusProperty(), L"CornerRadius", c);
            }
        }
    }
};
LayoutFeatures::LayoutFeatures(IXamlDiagnostics* d, IVisualTreeService* s) : impl_(std::make_unique<Impl>(d, s)) {}
LayoutFeatures::~LayoutFeatures() = default;
bool LayoutFeatures::active() const { return !impl_->edges.empty() || !impl_->toolbars.empty(); }
void LayoutFeatures::restore() { impl_->toolbars.clear(); impl_->edges.clear(); }
static void failure(FeatureState& state, HRESULT hr) {
    std::wostringstream out; out << L"Unsupported property source/layout (0x" << std::hex << static_cast<unsigned long>(hr) << L")";
    state.detail = out.str(); state.applied = false;
}
void LayoutFeatures::tick(const std::vector<Node>& nodes, uint32_t mask, FeatureStates& states) {
    std::set<uint64_t> surviving;
    for (const auto& n : nodes) surviving.insert(n.id);
    for (auto it = impl_->edges.begin(); it != impl_->edges.end();) if (!surviving.contains(it->first)) it = impl_->edges.erase(it); else ++it;
    for (auto it = impl_->toolbars.begin(); it != impl_->toolbars.end();) if (!surviving.contains(it->first)) it = impl_->toolbars.erase(it); else ++it;
    for (const auto& n : nodes) {
        if (n.name == L"ContentGroup" && n.type == L"Microsoft.UI.Xaml.Controls.Grid") {
            auto& edge = states[static_cast<size_t>(FeatureId::Edge)]; auto& corners = states[static_cast<size_t>(FeatureId::Square)];
            try {
                auto group = impl_->element(n.handle).as<Grid>();
                auto parent = Media::VisualTreeHelper::GetParent(group).try_as<Grid>();
                if (!parent) continue;
                bool surface = false, tabInset = false;
                for (const auto& e : parent.Children()) if (auto f = e.try_as<FrameworkElement>()) {
                    surface |= f.Name() == L"SharedSurface"; tabInset |= f.Name() == L"TabStripContentInset";
                }
                if (!surface || !tabInset) continue;
                edge.available = corners.available = true;
                edge.detail = corners.detail = L"Experimental Windows layout adapter · this session only";
                if (!effective(mask, FeatureId::Edge)) { impl_->edges.erase(n.id); impl_->edgeErrors.erase(n.id); impl_->cornerErrors.erase(n.id); continue; }
                if (impl_->edgeErrors.contains(n.id)) { failure(edge, impl_->edgeErrors.at(n.id)); continue; }
                auto& record = impl_->edges[n.id];
                if (!record.margin) {
                    auto m = parent.Margin();
                    for (const auto v : {m.Left, m.Top, m.Right, m.Bottom}) if (v < 0 || v > 12) throw E_NOTIMPL;
                    auto change = impl_->transaction();
                    change->add(parent, FrameworkElement::MarginProperty(), L"Margin", Thickness{0}); record.margin = std::move(change);
                }
                edge.applied = true;
                if (effective(mask, FeatureId::Square)) {
                    auto window = Media::VisualTreeHelper::GetParent(parent).try_as<Grid>();
                    bool adjacent = window && Grid::GetColumn(parent) != 0 && window.ColumnDefinitions().Size() > 1 && window.ColumnDefinitions().GetAt(0).ActualWidth() > 10;
                    uint64_t frames = 0; for (const auto& frame : nodes) if (frame.name == L"NavigationChromeHost") frames += frame.id;
                    if (record.adjacent != adjacent || record.frames != frames) { record.corners.reset(); impl_->cornerErrors.erase(n.id); }
                    record.adjacent = adjacent; record.frames = frames;
                    try {
                        if (impl_->cornerErrors.contains(n.id)) throw impl_->cornerErrors.at(n.id);
                        if (!record.corners) { auto change = impl_->transaction(); impl_->square(parent, *change, nodes); record.corners = std::move(change); }
                        corners.applied = !record.corners->empty();
                    } catch (const hresult_error& e) { impl_->cornerErrors[n.id] = e.code(); failure(corners, e.code()); }
                      catch (HRESULT hr) { impl_->cornerErrors[n.id] = hr; failure(corners, hr); }
                } else { record.corners.reset(); impl_->cornerErrors.erase(n.id); }
            } catch (const hresult_error& e) { impl_->edgeErrors[n.id] = e.code(); failure(edge, e.code()); }
              catch (HRESULT hr) { impl_->edgeErrors[n.id] = hr; failure(edge, hr); }
        } else if (n.name == L"NavigationChromeHost" && n.type == L"Microsoft.UI.Xaml.Controls.Grid") {
            auto& toolbar = states[static_cast<size_t>(FeatureId::Toolbar)]; auto& hover = states[static_cast<size_t>(FeatureId::Hover)];
            try {
                auto chrome = impl_->element(n.handle).as<Grid>();
                if (!chrome.IsLoaded()) continue;
                toolbar.available = hover.available = true;
                toolbar.detail = hover.detail = L"Experimental Windows toolbar adapter · this session only";
                if (!effective(mask, FeatureId::Toolbar)) { impl_->toolbars.erase(n.id); impl_->toolbarErrors.erase(n.id); continue; }
                if (impl_->toolbarErrors.contains(n.id)) { failure(toolbar, impl_->toolbarErrors.at(n.id)); continue; }
                auto& adapter = impl_->toolbars[n.id];
                if (!adapter) adapter = std::make_unique<ToolbarAdapter>(impl_->diagnostics.Get(), impl_->service.Get(), chrome);
                adapter->tick(true, effective(mask, FeatureId::Hover)); toolbar.applied = true; hover.applied = effective(mask, FeatureId::Hover);
            } catch (const hresult_error& e) { impl_->toolbars.erase(n.id); impl_->toolbarErrors[n.id] = e.code(); failure(toolbar, e.code()); }
              catch (HRESULT hr) { impl_->toolbars.erase(n.id); impl_->toolbarErrors[n.id] = hr; failure(toolbar, hr); }
        }
    }
}
}
