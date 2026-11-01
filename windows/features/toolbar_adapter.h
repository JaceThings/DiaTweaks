#pragma once
#include "literal_override.h"
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Input.h>
#include <winrt/Microsoft.UI.Xaml.Media.Animation.h>
namespace dt {
struct ToolbarAdapter {
    using Grid = winrt::Microsoft::UI::Xaml::Controls::Grid;
    Grid chrome{nullptr}, parent{nullptr};
    winrt::Microsoft::UI::Xaml::Controls::Border hotzone{nullptr};
    OverrideSet changes;
    std::vector<LiteralOverride<double>*> opacity;
    std::vector<LiteralOverride<bool>*> hitTest;
    winrt::event_token hotEntered{}, barEntered{}, barExited{};
    bool hotHooked = false, enteredHooked = false, exitedHooked = false;
    bool hidden = false, revealed = false, hover = false;
    ULONGLONG hideAfter = 0;
    ToolbarAdapter(IXamlDiagnostics*, IVisualTreeService*, const Grid&);
    ~ToolbarAdapter();
    void tick(bool hide, bool revealOnHover);
    void set_revealed(bool);
    void restore();
};
}
