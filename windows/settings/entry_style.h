#pragma once
#include "page.h"
namespace dt {
// Owns the small, reversible template change that puts the extra row directly
// after the menu, without inserting an unknown route into Dia's menu model.
class EntryStyle {
    winrt::Microsoft::UI::Xaml::Controls::NavigationView navigation_{nullptr};
    winrt::Microsoft::UI::Xaml::Controls::NavigationViewItem advanced_{nullptr};
    winrt::Microsoft::UI::Xaml::Controls::Button entry_{nullptr};
    winrt::Microsoft::UI::Xaml::Controls::RowDefinition menuRow_{nullptr};
    winrt::Windows::Foundation::IInspectable originalHeight_{nullptr};
    bool positioned_ = false;
    bool nativePalette_ = false;
public:
    EntryStyle(const winrt::Microsoft::UI::Xaml::Controls::NavigationView&,
               const winrt::Microsoft::UI::Xaml::Controls::Button&);
    void place_inline();
    void restore();
    std::wstring placement() const;
};
}
