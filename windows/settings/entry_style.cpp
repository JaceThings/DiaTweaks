#include "entry_style.h"
#include "wand_icon.h"
#include "visual_tree.h"
#include <winrt/Microsoft.UI.Xaml.Markup.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <algorithm>
#include <functional>
#include <sstream>

namespace dt {
using namespace winrt;
using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Xaml::Controls;
using namespace winrt::Microsoft::UI::Xaml::Media;
EntryStyle::EntryStyle(const NavigationView& navigation, const Button& entry) {
    const auto advanced = find_visual(navigation, [](const FrameworkElement& e) {
        return e.Name() == L"advanced" && e.try_as<NavigationViewItem>();
    }).try_as<NavigationViewItem>();
    const auto items = find_visual(navigation, [](const FrameworkElement& e) {
        return e.Name() == L"ItemsContainerGrid" && e.try_as<Grid>();
    }).try_as<Grid>();
    if (!advanced || !items || items.RowDefinitions().Size() < 3) throw hresult_not_implemented();
    navigation_ = navigation; advanced_ = advanced; entry_ = entry;
    // Validate the template's menu/footer arrangement before changing a row.
    const auto menu = find_visual(items, [](const FrameworkElement& e) { return e.Name() == L"MenuItemsScrollViewer"; });
    const auto footer = find_visual(items, [](const FrameworkElement& e) { return e.Name() == L"FooterContentBorder"; });
    if (!menu || !footer) throw hresult_not_implemented();
    auto host = menu;
    while (host && VisualTreeHelper::GetParent(host) != items) host = VisualTreeHelper::GetParent(host);
    if (!host || Grid::GetRow(host.as<FrameworkElement>()) != 0 || Grid::GetRow(footer.as<FrameworkElement>()) != 2) throw hresult_not_implemented();
    menuRow_ = items.RowDefinitions().GetAt(0);
    originalHeight_ = menuRow_.ReadLocalValue(RowDefinition::HeightProperty());
    // A literal or unset value can be restored exactly; bindings are refused.
    if (originalHeight_ != DependencyProperty::UnsetValue()) (void)unbox_value<GridLength>(originalHeight_);

    try { entry.Resources(Markup::XamlReader::Load(LR"(
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <ResourceDictionary.ThemeDictionaries><ResourceDictionary x:Key="Default">
    <StaticResource x:Key="ButtonBackgroundPointerOver" ResourceKey="NavigationViewItemBackgroundPointerOver"/>
    <StaticResource x:Key="ButtonBackgroundPressed" ResourceKey="NavigationViewItemBackgroundPressed"/>
    <StaticResource x:Key="ButtonForegroundPointerOver" ResourceKey="NavigationViewItemForegroundPointerOver"/>
    <StaticResource x:Key="ButtonForegroundPressed" ResourceKey="NavigationViewItemForegroundPressed"/>
  </ResourceDictionary></ResourceDictionary.ThemeDictionaries>
</ResourceDictionary>)").as<ResourceDictionary>()); nativePalette_ = true; }
    catch (const hresult_error&) { /* Retain native Button theme if a palette key is unavailable. */ }
    entry.FontFamily(advanced.FontFamily()); entry.FontSize(advanced.FontSize());
    entry.FontWeight(advanced.FontWeight()); entry.Foreground(advanced.Foreground());
    entry.Background(advanced.Background() ? advanced.Background() : SolidColorBrush(winrt::Windows::UI::Color{0, 0, 0, 0}));
    entry.CornerRadius(advanced.CornerRadius());
    entry.BorderThickness(Thickness{0}); entry.Margin(advanced.Margin());
    entry.HorizontalAlignment(HorizontalAlignment::Stretch);
    entry.HorizontalContentAlignment(HorizontalAlignment::Left);
    entry.VerticalContentAlignment(VerticalAlignment::Center);
    entry.Height(std::max(32.0, advanced.ActualHeight()));
    double inset = 12, gap = 16;
    auto icon = Markup::XamlReader::Load(hstring(L"<PathIcon xmlns=\"http://schemas.microsoft.com/winfx/2006/xaml/presentation\" Data=\"" + std::wstring(WandPath) + L"\"/>")).as<PathIcon>();
    Border iconSlot;
    iconSlot.Width(20); iconSlot.Height(20);
    if (auto original = advanced.Icon()) {
        const auto point = original.TransformToVisual(advanced).TransformPoint({0, 0});
        inset = std::clamp(static_cast<double>(point.X), 0.0, 40.0);
        const auto title = unbox_value_or<hstring>(advanced.Content(), L"Advanced");
        auto label = find_visual(advanced, [&](const FrameworkElement& e) {
            auto block = e.try_as<TextBlock>(); return block && block.Text() == title;
        }).try_as<TextBlock>();
        if (label) {
            const auto labelPoint = label.TransformToVisual(advanced).TransformPoint({0, 0});
            gap = std::clamp(labelPoint.X - point.X - original.ActualWidth(), 0.0, 40.0);
        }
        if (original.ActualWidth() > 0) iconSlot.Width(original.ActualWidth());
        if (original.ActualHeight() > 0) iconSlot.Height(original.ActualHeight());
    }
    // Keep the complete SVG viewport, then scale it into the native icon cell.
    // Reducing PathIcon's bounds directly clips its geometry.
    icon.Width(20); icon.Height(20); icon.Name(L"DiaTweaksWandIcon");
    ScaleTransform mirror; mirror.ScaleX(-1);
    icon.RenderTransformOrigin({0.5f, 0.5f}); icon.RenderTransform(mirror);
    Viewbox view; view.Stretch(Stretch::Uniform); view.Child(icon);
    iconSlot.Child(view); iconSlot.VerticalAlignment(VerticalAlignment::Center);
    entry.Padding(Thickness{inset, 0, 12, 0});
    StackPanel content; content.Orientation(Orientation::Horizontal); content.Spacing(gap);
    content.Children().Append(iconSlot);
    TextBlock label; label.Text(L"Patches"); label.VerticalAlignment(VerticalAlignment::Center);
    content.Children().Append(label); entry.Content(content);
}
void EntryStyle::place_inline() {
    positioned_ = true;
    menuRow_.Height(GridLength{1, GridUnitType::Auto});
}
void EntryStyle::restore() {
    if (selection_) selection_->remove();
    if (!positioned_) return;
    if (menuRow_.Height().GridUnitType == GridUnitType::Auto) {
        if (originalHeight_ == DependencyProperty::UnsetValue()) menuRow_.ClearValue(RowDefinition::HeightProperty());
        else menuRow_.SetValue(RowDefinition::HeightProperty(), originalHeight_);
    }
    positioned_ = false;
}
void EntryStyle::selected(bool active) {
    try {
        if (active && !selection_) selection_ = std::make_unique<SelectionVisual>(navigation_, entry_);
        if (selection_) selection_->set(active);
    } catch (const hresult_error& error) { selectionError_ = error.message().c_str(); }
}
std::wstring EntryStyle::placement() const {
    try {
        const auto a = advanced_.TransformToVisual(navigation_).TransformPoint({0, 0});
        const auto p = entry_.TransformToVisual(navigation_).TransformPoint({0, 0});
        std::wostringstream out;
        out << L"Layout: Patches top=" << p.Y << L"; Advanced bottom=" << a.Y + advanced_.ActualHeight()
            << L"; Patches/Advanced font=" << entry_.FontSize() << L"/" << advanced_.FontSize()
            << L"; palette=" << (nativePalette_ ? L"navigation" : L"native button fallback") << L"\n";
        if (selection_) out << selection_->status();
        if (!selectionError_.empty()) out << L"Selection unavailable: " << selectionError_ << L"\n";
        return out.str();
    } catch (const hresult_error&) { return L"Layout metrics unavailable while the Settings pane is detached.\n"; }
}
}
