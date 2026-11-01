#include "session.h"

namespace {
using namespace dt;
using namespace Microsoft::WRL;
std::atomic<bool> started{false};
class Tap final : public RuntimeClass<RuntimeClassFlags<ClassicCom>, IObjectWithSite> {
    ComPtr<IUnknown> site_;
    ComPtr<Session> session_;
public:
    HRESULT STDMETHODCALLTYPE SetSite(IUnknown* site) noexcept override {
        try {
            if (!site) { if (session_) session_->stopping = true; site_.Reset(); return S_OK; }
            if (started.exchange(true)) return HRESULT_FROM_WIN32(ERROR_ALREADY_EXISTS);
            site_ = site;
            session_ = Make<Session>();
            return session_ ? session_->start(site) : E_OUTOFMEMORY;
        } catch (HRESULT hr) { return hr; } catch (...) { return E_FAIL; }
    }
    HRESULT STDMETHODCALLTYPE GetSite(REFIID iid, void** output) noexcept override {
        if (!output) return E_POINTER;
        *output = nullptr;
        return site_ ? site_->QueryInterface(iid, output) : E_NOINTERFACE;
    }
};
class Factory final : public RuntimeClass<RuntimeClassFlags<ClassicCom>, IClassFactory> {
public:
    HRESULT STDMETHODCALLTYPE CreateInstance(IUnknown* outer, REFIID iid, void** output) noexcept override {
        if (!output) return E_POINTER;
        *output = nullptr;
        if (outer) return CLASS_E_NOAGGREGATION;
        auto tap = Make<Tap>();
        return tap ? tap->QueryInterface(iid, output) : E_OUTOFMEMORY;
    }
    HRESULT STDMETHODCALLTYPE LockServer(BOOL) noexcept override { return S_OK; }
};
}
extern "C" HRESULT WINAPI DllGetClassObject(REFCLSID clsid, REFIID iid, void** value) {
    if (!value) return E_POINTER;
    *value = nullptr;
    if (clsid != dt::TapClsid) return CLASS_E_CLASSNOTAVAILABLE;
    auto factory = Microsoft::WRL::Make<Factory>();
    return factory ? factory->QueryInterface(iid, value) : E_OUTOFMEMORY;
}
extern "C" HRESULT WINAPI DllCanUnloadNow() { return S_FALSE; }
