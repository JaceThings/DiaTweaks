#pragma once
#ifdef GetCurrentTime
#undef GetCurrentTime
#endif
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Controls.Primitives.h>
#include <winrt/Microsoft.UI.Xaml.Media.Animation.h>
#include <functional>
#include <vector>
namespace dt {
struct PatchesPage {
    winrt::Microsoft::UI::Xaml::Controls::Grid root;
    winrt::Microsoft::UI::Xaml::Controls::TextBox search;
    winrt::Microsoft::UI::Xaml::Controls::TextBlock empty;
    winrt::Microsoft::UI::Xaml::Controls::ToggleSwitch sidebarToggle{nullptr};
    struct Row { winrt::Microsoft::UI::Xaml::FrameworkElement view; std::wstring text; size_t section; };
    std::vector<Row> rows;
    std::vector<winrt::Microsoft::UI::Xaml::Controls::TextBlock> headers;
    winrt::event_token searchToken{};
    winrt::event_token loadedToken{};
    winrt::Microsoft::UI::Xaml::Media::Animation::Storyboard entrance{nullptr};
    winrt::Microsoft::UI::Xaml::Media::TranslateTransform motion{nullptr};
    bool entrancePending = false;
    PatchesPage(bool available, bool on, std::function<void(bool)> changed, std::function<void()> back);
    ~PatchesPage();
    void filter();
    void enter() noexcept;
    void play_entrance() noexcept;
    void stop_entrance() noexcept;
};
}
