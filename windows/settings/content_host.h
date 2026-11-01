#pragma once
#include "page.h"
namespace dt {
// Patches is an overlay in the template's content cell. Dia's own content
// object stays parented, so its navigation model and transitions keep working.
class SettingsContentHost {
    winrt::Microsoft::UI::Xaml::Controls::ContentPresenter presenter_{nullptr};
    winrt::Microsoft::UI::Xaml::Controls::Grid parent_{nullptr};
    winrt::Microsoft::UI::Xaml::FrameworkElement overlay_{nullptr};
    winrt::Windows::Foundation::IInspectable originalVisibility_{nullptr};
    bool active_ = false;
    void restore_visibility();
public:
    explicit SettingsContentHost(const winrt::Microsoft::UI::Xaml::Controls::NavigationView&);
    bool active() const { return active_; }
    void show(const winrt::Microsoft::UI::Xaml::FrameworkElement&);
    void hide();
    void remove();
};
}
