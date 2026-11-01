#pragma once
#include "session.h"
#include <atomic>

namespace dt::test {
class FakeService final : public Microsoft::WRL::RuntimeClass<
    Microsoft::WRL::RuntimeClassFlags<Microsoft::WRL::ClassicCom>,
    IVisualTreeService, IXamlDiagnostics, Microsoft::WRL::FtmBase> {
public:
    std::wstring initialization;
    HWND ui = nullptr;
    DWORD owner = GetCurrentThreadId();
    std::atomic<bool> collapsed{false}, local{false}, wrongThread{false};
    LONGLONG metadata = 0;
    BaseValueSource source = BaseValueSourceDefault;
    std::wstring type = L"Microsoft.UI.Xaml.Visibility";
    bool ignoreWrites = false, failWriteOnce = false;
    int clears = 0, sets = 0;
    HRESULT STDMETHODCALLTYPE AdviseVisualTreeChange(IVisualTreeServiceCallback* callback) override {
        SendMessageW(ui, WM_APP + 1, 0, reinterpret_cast<LPARAM>(callback)); return S_OK;
    }
    HRESULT STDMETHODCALLTYPE UnadviseVisualTreeChange(IVisualTreeServiceCallback*) override { return S_OK; }
    HRESULT on_thread() { if (GetCurrentThreadId() == owner) return S_OK; wrongThread = true; return RPC_E_WRONG_THREAD; }
    HRESULT STDMETHODCALLTYPE GetPropertyValuesChain(InstanceHandle, unsigned* sc, PropertyChainSource** sources,
        unsigned* vc, PropertyChainValue** values) override {
        if (FAILED(on_thread())) return RPC_E_WRONG_THREAD;
        *sc = *vc = 1;
        *sources = static_cast<PropertyChainSource*>(CoTaskMemAlloc(sizeof(PropertyChainSource)));
        *values = static_cast<PropertyChainValue*>(CoTaskMemAlloc(sizeof(PropertyChainValue)));
        if (!*sources || !*values) return E_OUTOFMEMORY;
        **sources = {}; **values = {};
        (*sources)->Source = local ? BaseValueSourceLocal : source;
        auto& p = **values;
        p.Index = 17; p.Type = SysAllocString(type.c_str()); p.PropertyName = SysAllocString(L"Visibility");
        p.Value = SysAllocString(collapsed ? L"Collapsed" : L"Visible"); p.MetadataBits = metadata;
        return S_OK;
    }
    HRESULT STDMETHODCALLTYPE CreateInstance(BSTR, BSTR text, InstanceHandle* result) override {
        if (FAILED(on_thread())) return RPC_E_WRONG_THREAD;
        *result = wcscmp(text, L"Collapsed") == 0 ? 2 : 1; return S_OK;
    }
    HRESULT STDMETHODCALLTYPE SetProperty(InstanceHandle, InstanceHandle instance, unsigned) override {
        if (FAILED(on_thread())) return RPC_E_WRONG_THREAD;
        ++sets;
        if (!ignoreWrites) { collapsed = instance == 2; local = true; }
        if (failWriteOnce) { failWriteOnce = false; return E_FAIL; }
        return S_OK;
    }
    HRESULT STDMETHODCALLTYPE ClearProperty(InstanceHandle, unsigned) override {
        if (FAILED(on_thread())) return RPC_E_WRONG_THREAD;
        ++clears; local = false; collapsed = false; return S_OK;
    }
    HRESULT STDMETHODCALLTYPE GetInitializationData(BSTR* data) override { *data = SysAllocString(initialization.c_str()); return *data ? S_OK : E_OUTOFMEMORY; }
    HRESULT STDMETHODCALLTYPE GetEnums(unsigned*, EnumType**) override { return E_NOTIMPL; }
    HRESULT STDMETHODCALLTYPE GetCollectionCount(InstanceHandle, unsigned*) override { return E_NOTIMPL; }
    HRESULT STDMETHODCALLTYPE GetCollectionElements(InstanceHandle, unsigned, unsigned*, CollectionElementValue**) override { return E_NOTIMPL; }
    HRESULT STDMETHODCALLTYPE AddChild(InstanceHandle, InstanceHandle, unsigned) override { return E_NOTIMPL; }
    HRESULT STDMETHODCALLTYPE RemoveChild(InstanceHandle, unsigned) override { return E_NOTIMPL; }
    HRESULT STDMETHODCALLTYPE ClearChildren(InstanceHandle) override { return E_NOTIMPL; }
    HRESULT STDMETHODCALLTYPE GetDispatcher(IInspectable**) override { return E_NOTIMPL; }
    HRESULT STDMETHODCALLTYPE GetUiLayer(IInspectable**) override { return E_NOTIMPL; }
    HRESULT STDMETHODCALLTYPE GetApplication(IInspectable**) override { return E_NOTIMPL; }
    HRESULT STDMETHODCALLTYPE GetIInspectableFromHandle(InstanceHandle, IInspectable**) override { return E_NOTIMPL; }
    HRESULT STDMETHODCALLTYPE GetHandleFromIInspectable(IInspectable*, InstanceHandle*) override { return E_NOTIMPL; }
    HRESULT STDMETHODCALLTYPE HitTest(RECT, unsigned*, InstanceHandle**) override { return E_NOTIMPL; }
    HRESULT STDMETHODCALLTYPE RegisterInstance(IInspectable*, InstanceHandle*) override { return E_NOTIMPL; }
};
}
