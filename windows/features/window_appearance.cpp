#include "window_appearance.h"
#include "session.h"
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Content.h>
#include <winrt/Microsoft.UI.Windowing.h>
#include <winrt/Windows.UI.h>
#include <set>
namespace dt {
using namespace winrt;
using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Windowing;
using ColorRef = winrt::Windows::Foundation::IReference<winrt::Windows::UI::Color>;
static bool same(const ColorRef& a, const ColorRef& b) { return (!a && !b) || (a && b && a.Value() == b.Value()); }
struct CaptionColors {
    AppWindowTitleBar bar{nullptr};
    ColorRef before[4]{nullptr, nullptr, nullptr, nullptr};
    ColorRef applied[4]{nullptr, nullptr, nullptr, nullptr};
    bool changed[4]{};
    ColorRef get(unsigned i) const {
        if (i == 0) return bar.InactiveBackgroundColor();
        if (i == 1) return bar.InactiveForegroundColor();
        if (i == 2) return bar.ButtonInactiveBackgroundColor();
        return bar.ButtonInactiveForegroundColor();
    }
    void set(unsigned i, const ColorRef& color) {
        if (i == 0) bar.InactiveBackgroundColor(color);
        else if (i == 1) bar.InactiveForegroundColor(color);
        else if (i == 2) bar.ButtonInactiveBackgroundColor(color);
        else bar.ButtonInactiveForegroundColor(color);
    }
    CaptionColors(const AppWindowTitleBar& titlebar, ElementTheme theme) : bar(titlebar) {
        const auto text = theme == ElementTheme::Dark ? winrt::Windows::UI::Color{255, 255, 255, 255} : winrt::Windows::UI::Color{255, 0, 0, 0};
        const auto transparent = winrt::Windows::UI::Color{0, 0, 0, 0};
        const ColorRef fallbackText = box_value(text).as<ColorRef>(), fallbackClear = box_value(transparent).as<ColorRef>();
        applied[0] = bar.BackgroundColor() ? bar.BackgroundColor() : fallbackClear;
        applied[1] = bar.ForegroundColor() ? bar.ForegroundColor() : fallbackText;
        applied[2] = bar.ButtonBackgroundColor() ? bar.ButtonBackgroundColor() : fallbackClear;
        applied[3] = bar.ButtonForegroundColor() ? bar.ButtonForegroundColor() : applied[1];
        for (unsigned i = 0; i < 4; ++i) before[i] = get(i);
        try { for (unsigned i = 0; i < 4; ++i) {
            changed[i] = true; set(i, applied[i]); if (!same(get(i), applied[i])) throw E_FAIL;
        } }
        catch (...) { restore(); throw; }
    }
    void restore() noexcept {
        for (unsigned i = 0; i < 4; ++i) if (changed[i]) {
            try { if (same(get(i), applied[i])) set(i, before[i]); changed[i] = false; } catch (...) {}
        }
    }
    ~CaptionColors() { restore(); }
};
struct WindowAppearance::Impl {
    ComPtr<IXamlDiagnostics> diagnostics;
    std::map<uint64_t, std::unique_ptr<CaptionColors>> windows;
    explicit Impl(IXamlDiagnostics* d) : diagnostics(d) {}
};
WindowAppearance::WindowAppearance(IXamlDiagnostics* d) : impl_(std::make_unique<Impl>(d)) {}
WindowAppearance::~WindowAppearance() = default;
void WindowAppearance::restore() { impl_->windows.clear(); }
bool WindowAppearance::active() const { return !impl_->windows.empty(); }
void WindowAppearance::tick(const std::vector<Node>& nodes, bool on, FeatureState& state) {
    state.detail = L"Caption colors are not exposed by this Windows window";
    if (!on) restore();
    try { if (!AppWindowTitleBar::IsCustomizationSupported()) return; }
    catch (...) { state.detail = L"Windows caption color customization is unavailable"; return; }
    std::set<uint64_t> present;
    for (const auto& n : nodes) {
        if (n.name != L"SidebarBorder" || n.type != L"Microsoft.UI.Xaml.Controls.Border") continue;
        try {
            ComPtr<::IInspectable> raw; check(impl_->diagnostics->GetIInspectableFromHandle(n.handle, &raw));
            winrt::Windows::Foundation::IInspectable object{nullptr}; copy_from_abi(object, raw.Get());
            auto e = object.as<FrameworkElement>();
            if (!e.IsLoaded() || !e.XamlRoot()) continue;
            const auto id = e.XamlRoot().ContentIslandEnvironment().AppWindowId();
            if (!id.Value) continue;
            const auto bar = AppWindow::GetFromWindowId(id).TitleBar();
            if (!bar) continue;
            present.insert(id.Value); state.available = true;
            state.detail = L"Windows caption colors only; shadow and backdrop remain system-managed";
            if (on && !impl_->windows.contains(id.Value)) impl_->windows[id.Value] = std::make_unique<CaptionColors>(bar, e.ActualTheme());
        } catch (const hresult_error&) { state.detail = L"This Dia window does not support caption color overrides"; }
          catch (HRESULT) { state.detail = L"Could not access this window's caption colors"; }
    }
    for (auto it = impl_->windows.begin(); it != impl_->windows.end();) if (!present.contains(it->first)) it = impl_->windows.erase(it); else ++it;
    state.applied = !impl_->windows.empty();
}
}
