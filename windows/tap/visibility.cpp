#include "visibility.h"

namespace dt {
PropertyValues::~PropertyValues() {
    for (unsigned i = 0; i < sourcesCount; ++i) {
        auto& s = sources[i];
        SysFreeString(s.TargetType); SysFreeString(s.Name);
        SysFreeString(s.SrcInfo.FileName); SysFreeString(s.SrcInfo.Hash);
    }
    for (unsigned i = 0; i < valuesCount; ++i) {
        auto& v = values[i];
        SysFreeString(v.Type); SysFreeString(v.DeclaringType); SysFreeString(v.ValueType);
        SysFreeString(v.ItemType); SysFreeString(v.Value); SysFreeString(v.PropertyName);
    }
    CoTaskMemFree(sources); CoTaskMemFree(values);
}
HRESULT PropertyValues::read(IVisualTreeService* service, InstanceHandle handle) {
    return service->GetPropertyValuesChain(handle, &sourcesCount, &sources, &valuesCount, &values);
}
HRESULT read_visibility(IVisualTreeService* service, InstanceHandle handle, Visibility& result) {
    PropertyValues properties;
    HRESULT hr = properties.read(service, handle);
    if (FAILED(hr)) return hr;
    bool found = false;
    for (unsigned i = 0; i < properties.valuesCount; ++i) {
        const auto& value = properties.values[i];
        if (str(value.PropertyName) != L"Visibility") continue;
        // Never replace a binding, object reference, expression, or animation.
        if (value.MetadataBits != 0 || value.PropertyChainIndex >= properties.sourcesCount) return E_NOTIMPL;
        const auto source = properties.sources[value.PropertyChainIndex].Source;
        if (source != BaseValueSourceDefault && source != BaseValueSourceBuiltInStyle &&
            source != BaseValueSourceStyle && source != BaseValueSourceLocal) return E_NOTIMPL;
        if (!value.Overridden) {
            if (found) return E_UNEXPECTED;
            result = {value.Index, str(value.Type), str(value.Value), source == BaseValueSourceLocal};
            found = true;
        }
    }
    if (!found) return HRESULT_FROM_WIN32(ERROR_NOT_FOUND);
    if (result.type != L"Microsoft.UI.Xaml.Visibility" && result.type != L"Windows.UI.Xaml.Visibility") return E_NOTIMPL;
    if (result.value != L"Visible" && result.value != L"Collapsed") return E_NOTIMPL;
    return S_OK;
}
static HRESULT set(IVisualTreeService* service, InstanceHandle h, const Visibility& property, const wchar_t* value) {
    Bstr type(property.type.c_str()), text(value);
    InstanceHandle instance = 0;
    HRESULT hr = service->CreateInstance(type.value, text.value, &instance);
    return FAILED(hr) ? hr : service->SetProperty(h, instance, property.index);
}
HRESULT VisibilityLease::pulse(IVisualTreeService* service, InstanceHandle handle, DWORD seconds) {
    if (saved_) return HRESULT_FROM_WIN32(ERROR_BUSY);
    if (seconds < 1 || seconds > 30) return E_INVALIDARG;
    Visibility original;
    HRESULT hr = read_visibility(service, handle, original);
    if (FAILED(hr)) return hr;
    if (original.value != L"Visible") return S_FALSE;
    saved_ = Saved{handle, original, GetTickCount64() + seconds * 1000ULL};
    hr = set(service, handle, original, L"Collapsed");
    if (SUCCEEDED(hr)) {
        Visibility actual;
        hr = read_visibility(service, handle, actual);
        if (SUCCEEDED(hr) && actual.value != L"Collapsed") hr = E_FAIL;
    }
    if (FAILED(hr)) restore(service);
    return hr;
}
HRESULT VisibilityLease::restore(IVisualTreeService* service) {
    if (!saved_) return S_FALSE;
    const auto& s = *saved_;
    Visibility current;
    HRESULT hr = read_visibility(service, s.handle, current);
    if (FAILED(hr)) return hr;
    // Dia may have changed its own value. Do not overwrite that newer state.
    if (!current.local || current.value != L"Collapsed") { saved_.reset(); return S_FALSE; }
    hr = s.original.local ? set(service, s.handle, s.original, s.original.value.c_str())
                          : service->ClearProperty(s.handle, s.original.index);
    if (SUCCEEDED(hr)) {
        Visibility actual;
        hr = read_visibility(service, s.handle, actual);
        if (SUCCEEDED(hr) && (actual.local != s.original.local || actual.value != s.original.value)) hr = E_FAIL;
    }
    if (SUCCEEDED(hr)) saved_.reset();
    return hr;
}
}
