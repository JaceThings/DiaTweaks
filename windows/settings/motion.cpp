#include "page.h"
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.UI.ViewManagement.h>

namespace dt {
using namespace winrt;
using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Xaml::Media;
using namespace winrt::Microsoft::UI::Xaml::Media::Animation;
void PatchesPage::enter() noexcept {
    entrancePending = true;
    try { if (root.IsLoaded()) play_entrance(); } catch (...) { stop_entrance(); }
}
void PatchesPage::play_entrance() noexcept {
    stop_entrance();
    try {
        if (!winrt::Windows::UI::ViewManagement::UISettings{}.AnimationsEnabled()) return;
        if (!motion) { motion = TranslateTransform{}; root.RenderTransform(motion); }
        root.Opacity(0); motion.Y(12);
        entrance = Storyboard{};
        Duration duration{};
        duration.Type = DurationType::TimeSpan;
        duration.TimeSpan = std::chrono::milliseconds(180);
        CubicEase ease; ease.EasingMode(EasingMode::EaseOut);
        DoubleAnimation opacity;
        opacity.From(0.0); opacity.To(1.0); opacity.Duration(duration); opacity.EasingFunction(ease);
        Storyboard::SetTarget(opacity, root); Storyboard::SetTargetProperty(opacity, L"Opacity");
        DoubleAnimation offset;
        offset.From(12.0); offset.To(0.0); offset.Duration(duration); offset.EasingFunction(ease);
        Storyboard::SetTarget(offset, motion); Storyboard::SetTargetProperty(offset, L"Y");
        entrance.Children().Append(opacity); entrance.Children().Append(offset);
        entrance.Begin();
    } catch (...) { stop_entrance(); }
}
void PatchesPage::stop_entrance() noexcept {
    entrancePending = false;
    try {
        if (entrance) { entrance.Stop(); entrance = nullptr; }
        root.Opacity(1);
        if (motion) motion.Y(0);
    } catch (...) {}
}
}
