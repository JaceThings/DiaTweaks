#include "toolbar_adapter.h"
#include "visual_tree.h"
#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <winrt/Microsoft.UI.Xaml.Automation.h>
#include <winrt/Windows.Foundation.Collections.h>
namespace dt {
using namespace winrt;
using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Xaml::Controls;
using XamlVisibility = winrt::Microsoft::UI::Xaml::Visibility;
ToolbarAdapter::ToolbarAdapter(IXamlDiagnostics* d, IVisualTreeService* s, const Grid& host) : chrome(host), changes(d, s) {
    parent = Media::VisualTreeHelper::GetParent(chrome).try_as<Grid>();
    if (!parent || Grid::GetRow(chrome) != 0 || parent.RowDefinitions().Size() != 2 || chrome.RowDefinitions().Size() != 3) throw E_NOTIMPL;
    auto bar = find_visual(chrome, [](const FrameworkElement& e) { return e.Name() == L"NavigationBarHost"; }).try_as<FrameworkElement>();
    auto bookmarks = find_visual(chrome, [](const FrameworkElement& e) { return e.Name() == L"BookmarksBarHost"; }).try_as<FrameworkElement>();
    auto variant = find_visual(parent, [](const FrameworkElement& e) { return e.Name() == L"VariantHost"; }).try_as<FrameworkElement>();
    if (!bar || !bookmarks || !variant || Grid::GetRow(variant) != 1) throw E_NOTIMPL;
    // Keep Dia's toolbar in its original layout. Let the page span both rows;
    // revealing the toolbar then floats it over the page without resizing it.
    for (const auto& child : parent.Children()) if (auto e = child.try_as<FrameworkElement>(); e && Grid::GetRow(e) == 1) {
        changes.add(e, Grid::RowProperty(), L"Row", int32_t{0});
        changes.add(e, Grid::RowSpanProperty(), L"RowSpan", int32_t{2});
    }
    changes.add(chrome, Canvas::ZIndexProperty(), L"ZIndex", int32_t{10});
    for (const auto& element : {bar, bookmarks}) {
        opacity.push_back(&changes.add(element, UIElement::OpacityProperty(), L"Opacity", 0.0));
        hitTest.push_back(&changes.add(element, UIElement::IsHitTestVisibleProperty(), L"IsHitTestVisible", false));
    }
    hotzone = Border{}; hotzone.Name(L"DiaTweaksToolbarHotzone"); hotzone.Height(8);
    hotzone.VerticalAlignment(VerticalAlignment::Top);
    hotzone.Background(Media::SolidColorBrush(winrt::Windows::UI::Color{0, 0, 0, 0}));
    hotzone.Visibility(XamlVisibility::Collapsed);
    Grid::SetRowSpan(hotzone, 2); Canvas::SetZIndex(hotzone, 11);
    try {
        hotEntered = hotzone.PointerEntered([this](auto&&, auto&&) noexcept { try { if (hover) set_revealed(true); } catch (...) {} }); hotHooked = true;
        barEntered = chrome.PointerEntered([this](auto&&, auto&&) noexcept { hideAfter = 0; }); enteredHooked = true;
        barExited = chrome.PointerExited([this](auto&&, auto&&) noexcept { hideAfter = GetTickCount64() + 200; }); exitedHooked = true;
        parent.Children().Append(hotzone); hidden = true;
    } catch (...) { restore(); throw; }
}
ToolbarAdapter::~ToolbarAdapter() { try { restore(); } catch (...) {} }
void ToolbarAdapter::set_revealed(bool value) {
    if (revealed == value) return;
    for (auto* property : opacity) property->apply(value ? 1.0 : 0.0);
    for (auto* property : hitTest) property->apply(value);
    revealed = value; hideAfter = value ? GetTickCount64() + 250 : 0;
    hotzone.Visibility(hover && !revealed ? XamlVisibility::Visible : XamlVisibility::Collapsed);
}
void ToolbarAdapter::tick(bool hide, bool revealOnHover) {
    if (!hide) { restore(); return; }
    hover = revealOnHover;
    auto focused = Input::FocusManager::GetFocusedElement(chrome.XamlRoot()).try_as<DependencyObject>();
    bool toolbarFocused = false;
    for (auto p = focused; p; p = Media::VisualTreeHelper::GetParent(p)) if (p == chrome) { toolbarFocused = true; break; }
    if (toolbarFocused) set_revealed(true);
    else if (!hover || (hideAfter && GetTickCount64() >= hideAfter && !(GetKeyState(VK_LBUTTON) & 0x8000))) set_revealed(false);
    hotzone.Visibility(hover && !revealed ? XamlVisibility::Visible : XamlVisibility::Collapsed);
}
void ToolbarAdapter::restore() {
    if (hotHooked) { hotzone.PointerEntered(hotEntered); hotHooked = false; }
    if (enteredHooked) { chrome.PointerEntered(barEntered); enteredHooked = false; }
    if (exitedHooked) { chrome.PointerExited(barExited); exitedHooked = false; }
    uint32_t index = 0;
    if (hotzone && parent.Children().IndexOf(hotzone, index)) parent.Children().RemoveAt(index);
    changes.restore(); hidden = false;
}
}
