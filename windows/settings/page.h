#pragma once
#ifdef GetCurrentTime
#undef GetCurrentTime
#endif
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Controls.Primitives.h>
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
    PatchesPage(bool available, bool on, std::function<void(bool)> changed, std::function<void()> back);
    ~PatchesPage();
    void filter();
};
}
