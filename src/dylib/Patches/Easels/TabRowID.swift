import AppKit

// Resolve the stable tab ID from either native tab layout.
private func field(_ value: Any?, _ name: String) -> Any? {
    guard let value = unwrap(value) else { return nil }
    return Mirror(reflecting: value).children.first { $0.label == name }?.value
}

private func unwrap(_ value: Any?) -> Any? {
    guard let value else { return nil }
    let mirror = Mirror(reflecting: value)
    return mirror.displayStyle == .optional ? unwrap(mirror.children.first?.value) : value
}

private func identifier(_ value: Any?) -> String? {
    field(value, "rawValue") as? String
}

private func tabID(_ item: Any) -> String? {
    let payload = Mirror(reflecting: item).children.first
    guard payload?.label == "tab" else { return nil }
    return identifier(payload?.value)
}

@_cdecl("DPEaselTabIdentifier")
public func DPEaselTabIdentifier(_ row: AnyObject?) -> NSString? {
    let model = field(row, "viewModel")
    if let id = identifier(field(model, "tabID")) { return id as NSString }
    guard let item = unwrap(field(field(model, "delegate"), "itemID")) else { return nil }
    return tabID(item) as NSString?
}
