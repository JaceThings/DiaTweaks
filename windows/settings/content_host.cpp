#include "content_host.h"
#include "visual_tree.h"
#include <winrt/Windows.Foundation.Collections.h>

namespace dt {
using namespace winrt;
using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Xaml::Controls;
using namespace winrt::Microsoft::UI::Xaml::Media;
SettingsContentHost::SettingsContentHost(const NavigationView& navigation) {
    const auto content = navigation.Content();
    presenter_ = find_visual(navigation, [&](const FrameworkElement& e) {
        auto presenter = e.try_as<ContentPresenter>();
        if (!presenter || e.Name() != L"ContentPresenter" || presenter.Content() != content) return false;
        auto parent = VisualTreeHelper::GetParent(e).try_as<Grid>();
        return parent && parent.Name() == L"ContentGrid" && Grid::GetRow(e) == 2;
    }).try_as<ContentPresenter>();
    if (!presenter_) throw hresult_not_implemented();
    parent_ = VisualTreeHelper::GetParent(presenter_).as<Grid>();
}
void SettingsContentHost::show(const FrameworkElement& page) {
    if (active_) return;
    originalVisibility_ = presenter_.ReadLocalValue(UIElement::VisibilityProperty());
    if (originalVisibility_ != DependencyProperty::UnsetValue())
        (void)unbox_value<Visibility>(originalVisibility_); // Refuse expressions.
    if (!overlay_) {
        overlay_ = page;
        overlay_.Visibility(Visibility::Collapsed);
        Grid::SetRow(overlay_, Grid::GetRow(presenter_));
        Grid::SetColumn(overlay_, Grid::GetColumn(presenter_));
        Grid::SetRowSpan(overlay_, Grid::GetRowSpan(presenter_));
        Grid::SetColumnSpan(overlay_, Grid::GetColumnSpan(presenter_));
        Canvas::SetZIndex(overlay_, Canvas::GetZIndex(presenter_) + 1);
        parent_.Children().Append(overlay_);
    }
    try {
        presenter_.Visibility(Visibility::Collapsed);
        overlay_.Visibility(Visibility::Visible);
        active_ = true;
    } catch (...) { restore_visibility(); throw; }
}
void SettingsContentHost::restore_visibility() {
    if (presenter_.Visibility() != Visibility::Collapsed) return;
    if (originalVisibility_ == DependencyProperty::UnsetValue()) presenter_.ClearValue(UIElement::VisibilityProperty());
    else presenter_.SetValue(UIElement::VisibilityProperty(), originalVisibility_);
}
void SettingsContentHost::hide() {
    if (!active_) return;
    overlay_.Visibility(Visibility::Collapsed);
    restore_visibility();
    active_ = false;
}
void SettingsContentHost::remove() {
    hide();
    uint32_t index = 0;
    if (overlay_ && parent_.Children().IndexOf(overlay_, index)) parent_.Children().RemoveAt(index);
    overlay_ = nullptr;
}
}
