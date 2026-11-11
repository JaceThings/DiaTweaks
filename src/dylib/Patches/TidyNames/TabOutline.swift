import AppKit

// Read the outline's stable IDs. Collection view indices change during a drag
// and don't include the children of collapsed folders.
private func field(_ value: Any?, _ name: String) -> Any? {
    guard let value = unwrap(value) else { return nil }
    return Mirror(reflecting: value).children.first { $0.label == name }?.value
}

private func unwrap(_ value: Any?) -> Any? {
    guard let value else { return nil }
    let mirror = Mirror(reflecting: value)
    return mirror.displayStyle == .optional ? unwrap(mirror.children.first?.value) : value
}

private func elements(_ value: Any?) -> [Any] {
    guard let value = unwrap(value) else { return [] }
    let mirror = Mirror(reflecting: value)
    if mirror.displayStyle == .collection || mirror.displayStyle == .dictionary || mirror.displayStyle == .set {
        return mirror.children.map(\.value)
    }
    if let storage = field(value, "_elements") ?? field(value, "_storage") {
        return elements(storage)
    }
    return []
}

private func identifier(_ value: Any?) -> String? {
    field(value, "rawValue") as? String
}

private func tabID(_ item: Any) -> String? {
    let payload = Mirror(reflecting: item).children.first
    guard payload?.label == "tab" else { return nil }
    return identifier(payload?.value)
}

@_cdecl("DPTidyTabIdentifier")
public func DPTidyTabIdentifier(_ row: AnyObject?) -> NSString? {
    let model = field(row, "viewModel")
    if let id = identifier(field(model, "tabID")) { return id as NSString }
    guard let item = unwrap(field(field(model, "delegate"), "itemID")) else { return nil }
    return tabID(item) as NSString?
}

@_cdecl("DPTidyTabLocations")
public func DPTidyTabLocations(_ list: AnyObject?) -> NSDictionary? {
    let subject = field(field(list, "viewModel"), "stateSubject")
    let stripModel = field(field(subject, "currentValue"), "model")
    let outline = field(list, "appliedOutlineModel") ?? field(stripModel, "outline")
    guard let sections = field(outline, "sections"),
          let itemSections = field(outline, "itemToSection") else { return nil }
    var locations: [String: String] = [:]
    for case let (item, section) as (Any, Any) in elements(itemSections) {
        guard let id = tabID(item) else { continue }
        switch String(describing: section) {
        case "pinned": locations[id] = "pinned"
        case "favorites": locations[id] = "favorites"
        case "tabs": locations[id] = "tabs"
        default: continue
        }
    }
    for case let (item, _) as (Any, Any) in elements(field(field(list, "dockView"), "itemViews")) {
        if let id = tabID(item), locations[id] == nil { locations[id] = "favorites" }
    }
    var containingGroups: [String: (id: String, size: Int)] = [:]
    for entry in elements(sections) {
        let pair = Mirror(reflecting: entry).children.map(\.value)
        guard pair.count == 2, let groups = field(pair[1], "groups") else { continue }
        let section = String(describing: pair[0])
        for case let (group, items) as (Any, Any) in elements(groups) {
            guard let groupID = identifier(group) else { continue }
            let members = elements(items)
            for item in members {
                guard let id = tabID(item) else { continue }
                if locations[id] == nil && (section == "pinned" || section == "tabs") {
                    locations[id] = section
                }
                if let previous = containingGroups[id],
                   (previous.size, previous.id) <= (members.count, groupID) { continue }
                containingGroups[id] = (groupID, members.count)
            }
        }
    }
    for (id, group) in containingGroups {
        if let section = locations[id] { locations[id] = section + ":" + group.id }
    }
    return locations as NSDictionary
}

@_cdecl("DPTidyNewlyPinnedTabs")
public func DPTidyNewlyPinnedTabs(_ previous: NSDictionary, _ current: NSDictionary) -> NSArray {
    guard let previous = previous as? [String: String], let current = current as? [String: String] else { return [] }
    return current.keys.filter { id in
        guard let before = previous[id], let after = current[id], before != after else { return false }
        if after == "favorites" { return true }
        let wasPinned = before == "favorites" || before == "pinned" || before.hasPrefix("pinned:")
        return !wasPinned && (after == "pinned" || after.hasPrefix("pinned:"))
    }.sorted() as NSArray
}

// Zero means Dia hasn't supplied enough metadata to distinguish a manual title.
@_cdecl("DPTidyTabTitleStatus")
public func DPTidyTabTitleStatus(_ content: AnyObject?) -> Int32 {
    guard let controller = field(field(content, "viewModel"), "delegate"),
          let attributesController = unwrap(field(controller, "attributesController")) else { return 0 }
    guard let payload = Mirror(reflecting: attributesController).children.first,
          payload.label == "webContent" else { return 1 }
    let stored = field(payload.value, "tabStoreAttributesController")
    let streamed = field(stored, "_titleAttributes") ?? field(stored, "_attributes")
    let attributes = field(field(streamed, "channel"), "value")
    guard let attributes, let title = field(attributes, "customTitle") else { return 0 }
    return unwrap(title) == nil ? 2 : 1
}


@_cdecl("DPTidyTabFavicon")
public func DPTidyTabFavicon(_ content: AnyObject?) -> NSView? {
    unwrap(field(content, "$__lazy_storage_$_iconView")) as? NSView
}
