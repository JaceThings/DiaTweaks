#include "selection_visual.h"
#include "visual_tree.h"
#include <winrt/Microsoft.UI.Xaml.Input.h>
#include <winrt/Microsoft.UI.Xaml.Shapes.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.UI.ViewManagement.h>
#include <algorithm>
#include <sstream>

namespace dt {
using namespace winrt;
using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Xaml::Controls;
using namespace winrt::Microsoft::UI::Xaml::Media;
using namespace winrt::Microsoft::UI::Xaml::Media::Animation;
using namespace winrt::Microsoft::UI::Xaml::Shapes;
struct SelectionVisual::Impl {
    NavigationView navigation;
    Button entry;
    Grid pane{nullptr};
    Canvas layer;
    Rectangle pill;
    TranslateTransform offset;
    Storyboard motion{nullptr};
    event_token completed{}, entered{}, exited{};
    bool completedHooked = false, enteredHooked = false, exitedHooked = false;
    bool active = false, attached = false;
    NavigationViewItem originalItem{nullptr};
    Control originalPresenter{nullptr};
    Brush originalBackground{nullptr};
    struct Mask { UIElement element; winrt::Windows::Foundation::IInspectable value; };
    std::vector<Mask> masks;
    std::wstring error;
    double destinationY = 0;
    Impl(const NavigationView& nav, const Button& button) : navigation(nav), entry(button) {
        pane = find_visual(nav, [](const FrameworkElement& e) {
            return e.Name() == L"PaneContentGrid" && e.try_as<Grid>();
        }).try_as<Grid>();
        if (!pane) throw hresult_not_implemented();
        layer.Name(L"DiaTweaksSelectionLayer"); pill.Name(L"DiaTweaksSelectionIndicator");
        layer.IsHitTestVisible(false); layer.Visibility(Visibility::Collapsed);
        Grid::SetRowSpan(layer, std::max(1u, pane.RowDefinitions().Size()));
        Grid::SetColumnSpan(layer, std::max(1u, pane.ColumnDefinitions().Size()));
        Canvas::SetZIndex(layer, 20); pill.RenderTransform(offset);
        layer.Children().Append(pill);
        originalBackground = entry.Background();
    }
    NavigationViewItem selected_item() {
        return find_visual(navigation, [](const FrameworkElement& e) {
            auto item = e.try_as<NavigationViewItem>(); return item && item.IsSelected();
        }).try_as<NavigationViewItem>();
    }
    Rectangle indicator(const NavigationViewItem& item) {
        return find_visual(item, [](const FrameworkElement& e) {
            return e.Name() == L"SelectionIndicator" && e.try_as<Rectangle>();
        }).try_as<Rectangle>();
    }
    void mask_indicators(const DependencyObject& node, unsigned depth = 0) {
        if (!node || depth > 64) return;
        if (auto item = node.try_as<NavigationViewItem>()) {
            if (auto source = indicator(item)) {
                auto value = source.ReadLocalValue(UIElement::VisibilityProperty());
                // Refuse a binding/expression rather than replacing it.
                if (value != DependencyProperty::UnsetValue()) (void)unbox_value<Visibility>(value);
                // Native NavigationView animates the indicator's composition
                // visual. Hide the XAML element itself, rather than relying on
                // an empty geometry clip surviving that composition animation.
                masks.push_back({source, value}); source.Visibility(Visibility::Collapsed);
            }
            return;
        }
        for (int i = 0, count = VisualTreeHelper::GetChildrenCount(node); i < count; ++i)
            mask_indicators(VisualTreeHelper::GetChild(node, i), depth + 1);
    }
    void stop_motion() {
        if (!motion) return;
        const auto current = offset.Y();
        if (completedHooked) { motion.Completed(completed); completedHooked = false; }
        motion.Stop(); motion = nullptr; offset.Y(current);
    }
    void restore_masks() {
        for (const auto& mask : masks) {
            if (mask.element.Visibility() != Visibility::Collapsed) continue;
            if (mask.value == DependencyProperty::UnsetValue()) mask.element.ClearValue(UIElement::VisibilityProperty());
            else mask.element.SetValue(UIElement::VisibilityProperty(), mask.value);
        }
        masks.clear(); layer.Visibility(Visibility::Collapsed);
    }
    void restore_row() {
        if (enteredHooked) { originalItem.PointerEntered(entered); enteredHooked = false; }
        if (exitedHooked) { originalItem.PointerExited(exited); exitedHooked = false; }
        if (originalPresenter && originalItem.IsSelected()) VisualStateManager::GoToState(originalPresenter, L"Selected", false);
        originalPresenter = nullptr; originalItem = nullptr;
        entry.Background(originalBackground);
    }
    void animate(double target) {
        stop_motion();
        destinationY = target;
        if (!winrt::Windows::UI::ViewManagement::UISettings{}.AnimationsEnabled()) {
            offset.Y(target); if (!active) restore_masks(); return;
        }
        motion = Storyboard{};
        DoubleAnimation move; move.From(offset.Y()); move.To(target);
        Duration duration{}; duration.Type = DurationType::TimeSpan;
        duration.TimeSpan = std::chrono::milliseconds(200); move.Duration(duration);
        CubicEase ease; ease.EasingMode(EasingMode::EaseOut); move.EasingFunction(ease);
        Storyboard::SetTarget(move, offset); Storyboard::SetTargetProperty(move, L"Y");
        motion.Children().Append(move);
        completed = motion.Completed([this](auto&&, auto&&) noexcept {
            try { if (!active) restore_masks(); } catch (...) {}
        }); completedHooked = true;
        motion.Begin();
    }
    void show() {
        if (active) return;
        stop_motion(); restore_masks();
        auto item = selected_item(); auto source = indicator(item);
        if (!item || !source || source.ActualHeight() <= 0 || source.ActualWidth() <= 0)
            throw hresult_not_implemented();
        originalItem = item;
        originalPresenter = find_visual(item, [](const FrameworkElement& e) {
            return e.try_as<Controls::Primitives::NavigationViewItemPresenter>() != nullptr;
        }).try_as<Control>();
        auto layout = find_visual(originalPresenter, [](const FrameworkElement& e) {
            return e.Name() == L"LayoutRoot" && e.try_as<Grid>();
        }).try_as<Grid>();
        if (!originalPresenter || !layout) throw hresult_not_implemented();
        auto origin = source.TransformToVisual(pane).TransformPoint({0, 0});
        auto destination = entry.TransformToVisual(pane).TransformPoint({0, 0});
        pill.Width(source.ActualWidth()); pill.Height(source.ActualHeight());
        pill.RadiusX(source.RadiusX()); pill.RadiusY(source.RadiusY()); pill.Fill(source.Fill());
        Canvas::SetLeft(pill, origin.X); offset.Y(origin.Y);
        if (!attached) { pane.Children().Append(layer); attached = true; }
        mask_indicators(navigation);
        entry.Background(layout.Background());
        active = true;
        if (!VisualStateManager::GoToState(originalPresenter, L"Normal", false)) throw hresult_not_implemented();
        entered = item.PointerEntered([this](auto&&, auto&&) noexcept {
            try { if (active) VisualStateManager::GoToState(originalPresenter, L"PointerOver", false); } catch (...) {}
        }); enteredHooked = true;
        exited = item.PointerExited([this](auto&&, auto&&) noexcept {
            try { if (active) VisualStateManager::GoToState(originalPresenter, L"Normal", false); } catch (...) {}
        }); exitedHooked = true;
        layer.Visibility(Visibility::Visible);
        animate(destination.Y + (entry.ActualHeight() - pill.Height()) / 2);
    }
    void hide() {
        if (!active && masks.empty()) return;
        active = false; restore_row();
        auto item = selected_item(); auto target = indicator(item);
        if (!target) { stop_motion(); restore_masks(); return; }
        animate(target.TransformToVisual(pane).TransformPoint({0, 0}).Y);
    }
    void reset() noexcept {
        active = false;
        try { stop_motion(); } catch (...) {}
        try { restore_row(); } catch (...) {}
        try { restore_masks(); } catch (...) {}
    }
    void remove() noexcept {
        reset();
        try {
            uint32_t index = 0;
            if (attached && pane.Children().IndexOf(layer, index)) pane.Children().RemoveAt(index);
            attached = false;
        } catch (...) {}
    }
};
SelectionVisual::SelectionVisual(const NavigationView& nav, const Button& entry) : impl_(std::make_unique<Impl>(nav, entry)) {}
SelectionVisual::~SelectionVisual() { remove(); }
void SelectionVisual::set(bool active) noexcept {
    try { if (active) impl_->show(); else impl_->hide(); impl_->error.clear(); }
    catch (const hresult_error& error) { impl_->reset(); impl_->error = error.message().c_str(); }
    catch (...) { impl_->reset(); impl_->error = L"unsupported selection visuals"; }
}
void SelectionVisual::remove() noexcept { impl_->remove(); }
std::wstring SelectionVisual::status() const {
    if (!impl_->error.empty()) return L"Selection animation unavailable: " + impl_->error + L"\n";
    std::wostringstream out;
    out << L"Selection: " << (impl_->active ? L"Patches active" : L"native category")
        << L"; marker Y=" << impl_->offset.Y() << L"; target=" << impl_->destinationY
        << L"; hidden native markers=" << impl_->masks.size() << L"\n";
    return out.str();
}
}
