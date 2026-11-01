#include "native_settings.h"
#include "page.h"
#include "entry_style.h"
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <sstream>

namespace dt {
using namespace winrt;
using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Xaml::Controls;
struct Source { unsigned index; bool local; };
static Source source(IVisualTreeService* service, InstanceHandle handle, const wchar_t* name) {
    PropertyValues properties;
    check(properties.read(service, handle));
    std::optional<Source> result;
    for (unsigned i = 0; i < properties.valuesCount; ++i) {
        const auto& v = properties.values[i];
        if (str(v.PropertyName) != name) continue;
        if (v.MetadataBits & IsValueBindingExpression) throw E_NOTIMPL;
        if (v.PropertyChainIndex >= properties.sourcesCount) throw E_UNEXPECTED;
        const auto origin = properties.sources[v.PropertyChainIndex].Source;
        if (origin != BaseValueSourceDefault && origin != BaseValueSourceBuiltInStyle &&
            origin != BaseValueSourceStyle && origin != BaseValueSourceLocal) throw E_NOTIMPL;
        if (!v.Overridden) {
            if (result) throw E_UNEXPECTED;
            result = Source{v.Index, origin == BaseValueSourceLocal};
        }
    }
    if (!result) throw HRESULT_FROM_WIN32(ERROR_NOT_FOUND);
    return *result;
}
struct NativeSettings::Impl {
    ComPtr<IVisualTreeService> service;
    InstanceHandle handle;
    NavigationView navigation{nullptr};
    Button entry{nullptr};
    StackPanel footer{nullptr};
    UIElement previousFooter{nullptr};
    std::unique_ptr<PatchesPage> page;
    std::unique_ptr<EntryStyle> entryStyle;
    winrt::Windows::Foundation::IInspectable previousContent{nullptr};
    Source footerSource{}, contentSource{};
    event_token clickToken{};
    bool installed = false, available, on;
    std::function<void(bool)> changed;
    std::wstring stage, lastError;
    Impl(IXamlDiagnostics* diagnostics, IVisualTreeService* s, InstanceHandle h, bool a, bool o, std::function<void(bool)> c, std::wstring& stage)
        : service(s), handle(h), available(a), on(o), changed(std::move(c)) {
        stage = L"resolve Settings NavigationView";
        ComPtr<::IInspectable> raw;
        check(diagnostics->GetIInspectableFromHandle(handle, &raw));
        winrt::Windows::Foundation::IInspectable object{nullptr};
        copy_from_abi(object, raw.Get());
        navigation = object.as<NavigationView>();
        previousFooter = navigation.PaneFooter();
        stage = L"inspect Settings footer property source";
        footerSource = source(service.Get(), handle, L"PaneFooter");
        stage = L"create native Patches button";
        entry = Button{};
        entry.Name(L"DiaTweaksPatchesEntry"); entry.Content(box_value(L"Patches"));
        entry.HorizontalAlignment(HorizontalAlignment::Stretch); entry.Margin(Thickness{8, 8, 8, 8});
        stage = L"match Advanced row layout and style";
        entryStyle = std::make_unique<EntryStyle>(navigation, entry);
        clickToken = entry.Click([this](auto&&, auto&&) noexcept {
            try { show(); }
            catch (const hresult_error& error) { fail(static_cast<HRESULT>(error.code().value), error.message().c_str()); }
            catch (HRESULT hr) { fail(hr, L"Settings property source is unsupported"); }
            catch (...) { try { entry.Content(box_value(L"Patches unavailable")); entry.IsEnabled(false); } catch (...) {} }
        });
        stage = L"wrap existing Settings footer";
        footer = StackPanel{};
        footer.Name(L"DiaTweaksFooter");
        try {
            // A UIElement can have one parent. Release Dia's footer from the
            // presenter before placing that same object inside our wrapper.
            navigation.PaneFooter(nullptr);
            navigation.UpdateLayout();
            footer.Children().Append(entry);
            if (previousFooter) footer.Children().Append(previousFooter);
            stage = L"insert native Patches footer";
            navigation.PaneFooter(footer);
            stage = L"place Patches below Advanced";
            entryStyle->place_inline();
            installed = true;
        } catch (...) {
            try { entryStyle->restore(); } catch (...) {}
            try {
                footer.Children().Clear();
                if (!navigation.PaneFooter() || navigation.PaneFooter() == footer) {
                    if (footerSource.local) navigation.PaneFooter(previousFooter);
                    else check(service->ClearProperty(handle, footerSource.index));
                }
                entry.Click(clickToken);
            } catch (...) {}
            throw;
        }
    }
    void show() {
        if (!installed) return;
        if (page && navigation.Content() == page->root) return;
        stage = L"inspect Settings content source";
        contentSource = source(service.Get(), handle, L"Content");
        previousContent = navigation.Content();
        stage = L"create native Patches page";
        if (!page) page = std::make_unique<PatchesPage>(available, on, [this](bool value) {
            on = value; changed(value);
        }, [this] { back(); });
        stage = L"display native Patches page";
        navigation.Content(page->root);
    }
    void fail(HRESULT hr, const wchar_t* message) noexcept {
        try {
            std::wostringstream out;
            out << stage << L": 0x" << std::hex << static_cast<unsigned long>(hr) << L" " << message;
            lastError = out.str();
            entry.Content(box_value(L"Patches unavailable")); entry.IsEnabled(false);
        } catch (...) {}
    }
    void back() {
        if (!page || navigation.Content() != page->root) return;
        if (contentSource.local) navigation.Content(previousContent);
        else check(service->ClearProperty(handle, contentSource.index));
        previousContent = nullptr;
    }
    void remove() {
        if (!installed) return;
        back();
        entryStyle->restore();
        if (navigation.PaneFooter() == footer) {
            footer.Children().Clear();
            if (footerSource.local) navigation.PaneFooter(previousFooter);
            else check(service->ClearProperty(handle, footerSource.index));
        } else footer.Children().Clear();
        entry.Click(clickToken); installed = false;
    }
};
NativeSettings::NativeSettings(IXamlDiagnostics* d, IVisualTreeService* s, InstanceHandle h, bool a, bool on, std::function<void(bool)> c) {
    std::wstring stage = L"prepare native Settings integration";
    try { impl_ = std::make_unique<Impl>(d, s, h, a, on, std::move(c), stage); }
    catch (const hresult_error& error) { throw SettingsError{static_cast<HRESULT>(error.code().value), stage + L": " + error.message().c_str()}; }
    catch (HRESULT hr) { throw SettingsError{hr, stage}; }
}
NativeSettings::~NativeSettings() = default;
void NativeSettings::remove() {
    try { impl_->remove(); } catch (const hresult_error& error) { throw static_cast<HRESULT>(error.code().value); }
}
void NativeSettings::sync(bool on) {
    impl_->on = on;
    if (impl_->page && impl_->page->sidebarToggle && impl_->page->sidebarToggle.IsOn() != on)
        impl_->page->sidebarToggle.IsOn(on);
}
std::wstring NativeSettings::status() const {
    return impl_->lastError.empty() ? L"Patches entry is installed. Click it in Dia Settings.\n" + impl_->entryStyle->placement() : impl_->lastError + L"\n";
}
}
