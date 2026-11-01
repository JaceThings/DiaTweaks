#include "session.h"
#include <winrt/Microsoft.UI.Xaml.Controls.h>
namespace dt {
void Context::auto_settings() {
    if (settings && (!session->node(settingsId) || !settings->alive())) { settings->remove(); settings.reset(); settingsId = 0; }
    if (settings || GetTickCount64() < nextSettingsAttempt) return;
    nextSettingsAttempt = GetTickCount64() + 1000;
    for (const auto& n : session->nodes_on_thread(thread)) {
        if (n.type != L"Microsoft.UI.Xaml.Controls.NavigationView" || !session->is_settings_navigation(n.id)) continue;
        try {
            ComPtr<::IInspectable> raw; check(session->diagnostics->GetIInspectableFromHandle(n.handle, &raw));
            winrt::Windows::Foundation::IInspectable object{nullptr}; winrt::copy_from_abi(object, raw.Get());
            auto nav = object.as<winrt::Microsoft::UI::Xaml::Controls::NavigationView>();
            if (!nav.IsLoaded() || nav.ActualWidth() <= 0 || !nav.XamlRoot() || !nav.XamlRoot().IsHostVisible()) continue;
            settings = std::make_unique<NativeSettings>(session->diagnostics.Get(), session->service.Get(), n.handle,
                featureStates, [s = session](FeatureId id, bool on) {
                    s->set_feature(id, on);
                });
            settingsId = n.id; settingsError.clear(); return;
        } catch (const SettingsError& e) { settingsError = e.detail; }
          catch (...) { settingsError = L"Settings is not ready for Patches yet"; }
    }
}
}
