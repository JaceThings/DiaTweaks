#include "page.h"
#include "feature_catalog.h"
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.UI.Text.h>
#include <cwctype>

namespace dt {
using namespace winrt;
using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Xaml::Controls;
static TextBlock text(hstring value, double size = 14) {
    TextBlock result;
    result.Text(value); result.FontSize(size); result.TextWrapping(TextWrapping::Wrap);
    return result;
}
static std::wstring lower(std::wstring value) {
    for (auto& c : value) c = static_cast<wchar_t>(std::towlower(c));
    return value;
}
PatchesPage::PatchesPage(const FeatureStates& states, FeatureChanged changed, std::function<void()> back) {
    root.Name(L"DiaTweaksPatchesPage");
    StackPanel content;
    content.Spacing(16); content.Margin(Thickness{28, 24, 28, 24});
    Button backButton;
    backButton.Content(box_value(L"Back to Dia Settings"));
    backButton.Click([back](auto&&, auto&&) noexcept { try { back(); } catch (...) {} });
    content.Children().Append(backButton);
    content.Children().Append(text(L"Patches", 26));
    content.Children().Append(text(L"DiaTweaks · Windows prototype", 13));
    content.Children().Append(text(L"Changes apply while DiaTweaks is running. Switch availability depends on this Windows Dia layout.", 12));
    search.PlaceholderText(L"Search patches");
    search.Name(L"DiaTweaksPatchSearch");
    content.Children().Append(search);
    std::wstring section;
    for (const auto& feature : Features) {
        if (section != feature.section) {
            section = feature.section;
            auto header = text(feature.section, 17);
            header.FontWeight(winrt::Windows::UI::Text::FontWeight{600});
            headers.push_back(header); content.Children().Append(header);
        }
        Grid row;
        row.Name(hstring(L"DiaTweaks_" + std::wstring(feature.key)));
        row.Padding(Thickness{12, 12, 12, 12}); row.ColumnSpacing(16);
        ColumnDefinition left, right;
        left.Width(GridLength{1, GridUnitType::Star}); right.Width(GridLength{1, GridUnitType::Auto});
        row.ColumnDefinitions().Append(left); row.ColumnDefinitions().Append(right);
        StackPanel labels;
        labels.Spacing(4);
        labels.Children().Append(text(feature.title));
        const auto description = std::wstring(feature.key) == L"keepWindowsActive"
            ? L"Keep the title-bar and window-button colors from dimming when Dia loses focus."
            : std::wstring(feature.key) == L"passkeys" ? L"Windows uses the installed Dia's normal passkey support. This macOS workaround is not needed." : feature.detail;
        auto detail = text(description, 12); detail.Opacity(0.75); labels.Children().Append(detail);
        const auto id = feature_id(feature.key);
        auto note = text(std::wstring(feature.key) == L"passkeys" ? L"macOS-only workaround"
            : id == FeatureId::Count ? L"Windows adapter not installed" : L"Detecting Windows controls…", 12);
        note.Opacity(0.7); labels.Children().Append(note);
        if (id != FeatureId::Count) notes.emplace(id, note);
        if (*feature.requiresKey) for (const auto& parent : Features) if (std::wstring(parent.key) == feature.requiresKey)
            labels.Children().Append(text(hstring(L"Requires: " + std::wstring(parent.title)), 11));
        row.Children().Append(labels);
        if (std::wstring(feature.kind) == L"toggle") {
            ToggleSwitch toggle;
            toggle.Name(hstring(L"DiaTweaksToggle_" + std::wstring(feature.key)));
            toggle.IsOn(false); toggle.IsEnabled(false);
            toggle.VerticalAlignment(VerticalAlignment::Center);
            toggle.OnContent(box_value(L"On")); toggle.OffContent(box_value(L"Off"));
            Grid::SetColumn(toggle, 1);
            toggles.emplace(id, toggle);
            toggle.Toggled([this, changed, id](const winrt::Windows::Foundation::IInspectable& sender, auto&&) noexcept {
                try { if (!synchronizing && id != FeatureId::Count) changed(id, sender.as<ToggleSwitch>().IsOn()); } catch (...) {}
            });
            row.Children().Append(toggle);
        } else {
            auto state = text(L"Not ported", 12); Grid::SetColumn(state, 1); row.Children().Append(state);
        }
        rows.push_back({row, lower(std::wstring(feature.title) + L" " + feature.detail + L" " + feature.key), headers.size() - 1});
        content.Children().Append(row);
    }
    empty = text(L"No patches match your search."); empty.Visibility(Visibility::Collapsed);
    content.Children().Append(empty);
    content.Children().Append(text(L"Updates", 17));
    content.Children().Append(text(L"Dia keeps using its normal Windows updater. DiaTweaks updates are not available in this prototype.", 12));
    content.Children().Append(text(L"Unofficial. Not affiliated with The Browser Company.", 11));
    ScrollViewer scroll;
    scroll.VerticalScrollBarVisibility(ScrollBarVisibility::Auto);
    scroll.HorizontalScrollBarVisibility(ScrollBarVisibility::Disabled);
    scroll.Content(content); root.Children().Append(scroll);
    searchToken = search.TextChanged([this](auto&&, auto&&) noexcept { try { filter(); } catch (...) {} });
    loadedToken = root.Loaded([this](auto&&, auto&&) noexcept { if (entrancePending) play_entrance(); });
    sync(states);
}
PatchesPage::~PatchesPage() {
    stop_entrance();
    if (search) search.TextChanged(searchToken);
    if (root) root.Loaded(loadedToken);
}
void PatchesPage::sync(const FeatureStates& states) {
    synchronizing = true;
    try {
        uint32_t mask = 0;
        for (const auto& state : states) if (state.applied) mask |= feature_bit(state.id);
        for (const auto& state : states) {
            if (!toggles.contains(state.id)) continue;
            auto toggle = toggles.at(state.id);
            if (toggle.IsOn() != state.on) toggle.IsOn(state.on);
            bool enabled = state.available || state.on;
            std::wstring detail = state.detail;
            if (state.id == FeatureId::Square && !requested(mask, FeatureId::Edge)) { enabled = false; detail = L"Turn on Edge-to-edge web content first"; }
            if (state.id == FeatureId::Hover && !requested(mask, FeatureId::Toolbar)) { enabled = false; detail = L"Turn on Hide toolbar first"; }
            if ((state.id == FeatureId::Sidebar || state.id == FeatureId::Chat) && requested(mask, FeatureId::Toolbar)) { enabled = false; detail = L"Toolbar is already hidden"; }
            if (toggle.IsEnabled() != enabled) toggle.IsEnabled(enabled);
            if (notes.contains(state.id) && notes.at(state.id).Text() != detail) notes.at(state.id).Text(detail);
        }
    } catch (...) { synchronizing = false; throw; }
    synchronizing = false;
}
void PatchesPage::filter() {
    const auto query = lower(std::wstring(search.Text()));
    std::vector<bool> visible(headers.size(), false);
    bool any = false;
    for (auto& row : rows) {
        const bool match = row.text.find(query) != std::wstring::npos;
        row.view.Visibility(match ? Visibility::Visible : Visibility::Collapsed);
        visible[row.section] = visible[row.section] || match; any = any || match;
    }
    for (size_t i = 0; i < headers.size(); ++i) headers[i].Visibility(visible[i] ? Visibility::Visible : Visibility::Collapsed);
    empty.Visibility(any ? Visibility::Collapsed : Visibility::Visible);
}
}
