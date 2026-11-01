#include "visibility.h"
#include <sstream>

namespace dt {
std::wstring describe_visibility(IVisualTreeService* service, InstanceHandle handle) {
    PropertyValues properties;
    const auto hr = properties.read(service, handle);
    std::wostringstream out;
    if (FAILED(hr)) {
        out << L"GetPropertyValuesChain failed: 0x" << std::hex << static_cast<unsigned long>(hr) << L'\n';
        return out.str();
    }
    bool found = false;
    for (unsigned i = 0; i < properties.valuesCount; ++i) {
        const auto& v = properties.values[i];
        if (str(v.PropertyName) != L"Visibility") continue;
        found = true;
        // Only Visibility metadata is exposed; never dump arbitrary properties
        // such as text, URLs or user input while diagnosing a control.
        out << L"Visibility chain: index=" << v.Index << L"; type=" << str(v.Type)
            << L"; valueType=" << str(v.ValueType) << L"; value=" << str(v.Value)
            << L"; overridden=" << v.Overridden << L"; metadata=0x" << std::hex
            << v.MetadataBits << std::dec << L"; sourceIndex=" << v.PropertyChainIndex;
        if (v.PropertyChainIndex < properties.sourcesCount)
            out << L"; source=" << properties.sources[v.PropertyChainIndex].Source;
        out << L'\n';
    }
    if (!found) out << L"No Visibility property in the diagnostics chain.\n";
    return out.str();
}
}
