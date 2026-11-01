#pragma once
#include "page.h"
#include <memory>
namespace dt {
// Visual-only selection bridge; Dia retains its selected item and routing model.
class SelectionVisual {
    struct Impl;
    std::unique_ptr<Impl> impl_;
public:
    SelectionVisual(const winrt::Microsoft::UI::Xaml::Controls::NavigationView&,
                    const winrt::Microsoft::UI::Xaml::Controls::Button&);
    ~SelectionVisual();
    void set(bool active) noexcept;
    void remove() noexcept;
    std::wstring status() const;
};
}
