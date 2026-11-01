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
PatchesPage::PatchesPage(bool available, bool on, std::function<void(bool)> changed, std::function<void()> back) {
    root.Name(L"DiaTweaksPatchesPage");
    StackPanel content;
    content.Spacing(16); content.Margin(Thickness{28, 24, 28, 24});
    Button backButton;
    backButton.Content(box_value(L"Back to Dia Settings"));
    backButton.Click([back](auto&&, auto&&) noexcept { try { back(); } catch (...) {} });
    content.Children().Append(backButton);
    content.Children().Append(text(L"Patches", 26));
    content.Children().Append(text(L"DiaTweaks · Windows prototype", 13));
    content.Children().Append(text(L"Changes apply while the controller is connected. Features awaiting a Windows implementation are unavailable.", 12));
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
        auto detail = text(feature.detail, 12); detail.Opacity(0.75); labels.Children().Append(detail);
        const bool supported = std::wstring(feature.key) == L"hideSidebarButton" && available;
        if (!supported) {
            auto note = text(L"Unavailable · Windows implementation pending", 12);
            note.Opacity(0.6); labels.Children().Append(note);
        } else labels.Children().Append(text(L"Live-tested adapter · this session only", 12));
        if (*feature.requiresKey) for (const auto& parent : Features) if (std::wstring(parent.key) == feature.requiresKey)
            labels.Children().Append(text(hstring(L"Requires: " + std::wstring(parent.title)), 11));
        row.Children().Append(labels);
        if (std::wstring(feature.kind) == L"toggle") {
            ToggleSwitch toggle;
            toggle.Name(hstring(L"DiaTweaksToggle_" + std::wstring(feature.key)));
            toggle.IsOn(supported && on); toggle.IsEnabled(supported);
            toggle.VerticalAlignment(VerticalAlignment::Center);
            toggle.OnContent(box_value(L"On")); toggle.OffContent(box_value(L"Off"));
            Grid::SetColumn(toggle, 1);
            if (supported) sidebarToggle = toggle;
            if (supported) toggle.Toggled([changed](const winrt::Windows::Foundation::IInspectable& sender, auto&&) noexcept {
                try { changed(sender.as<ToggleSwitch>().IsOn()); } catch (...) {}
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
}
PatchesPage::~PatchesPage() {
    stop_entrance();
    if (search) search.TextChanged(searchToken);
    if (root) root.Loaded(loadedToken);
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
