// Changes a Pull Requests folder through Dia's own TabStoreUtilities: createTab makes a tab straight inside it, so it
// never shows loose and slides in, and removeItems takes out tabs Dia hasn't loaded, which nothing else can close.
// Dia's types can't be named here, so every argument is made by Dia's own code (Codable, value witnesses) and read back
// before the call. The call itself rests on Swift's calling convention, checked on every Dia build rather than pinned to
// one: the closure's type must be exactly the one these were written against, and each value it takes by reference must be
// too big for registers, so Swift passes it as a pointer, as the C helpers in CallSwift.m do. Read from Dia 1.55.1 (89833).
// When anything differs these return without calling, and the caller falls back to what works without them.
import Foundation

private let createTab = (name: "_createTab",
                         type: "@Swift.MainActor @Sendable (TabModels.TabModel, TabModels.TabStoreUtilities.InsertionLocation) -> ()")
private let removeItems = (name: "_removeItems", type: "@Swift.MainActor @Sendable (Swift.Set<TabModels.TabItem.ID>) -> ()")

// Swift passes a value in registers when it fits in four; anything bigger goes by pointer.
private let registerBytes = 4 * MemoryLayout<UInt>.size

// The closure as two words, function and context, if its type is the one expected.
private func verified(_ closure: Any, _ expected: (name: String, type: String)) -> (function: UInt, context: UInt)? {
    let type = String(reflecting: Swift.type(of: closure))
    var held = closure
    let (function, context) = withUnsafeBytes(of: &held) { ($0.load(as: UInt.self), $0.load(fromByteOffset: 8, as: UInt.self)) }
    guard type == expected.type, function != 0, context != 0 else {
        log("\(expected.name) is \(type), not the closure this was written against")
        return nil
    }
    return (function, context)
}

private func caller<T>(_ name: String, _: T.Type) -> T? {  // CallSwift.m
    dlsym(UnsafeMutableRawPointer(bitPattern: -2), name).map { unsafeBitCast($0, to: T.self) }
}

// The new tab's id, or nil without having called Dia.
@_cdecl("DPGitLabCreateTabInGroup")
public func DPGitLabCreateTabInGroup(_ appDelegate: AnyObject?, _ groupID: NSString, _ url: NSString, _ title: NSString) -> NSString? {
    guard Thread.isMainThread, let appDelegate, let store = tabStore(appDelegate, holding: groupID as String),
          let closure = tabStoreUtility(appDelegate, createTab.name, for: store), let call = verified(closure, createTab),
          let invoke = caller("DPGitLabCallSwiftClosure2", (@convention(c) (UInt, UInt, UnsafeRawPointer, UnsafeRawPointer) -> Void).self)
    else { return nil }
    // A tab with one web page to clone, which any Space that has used Dia has.
    guard let tabs = mirrorStep(store.model, "tabs"), let template = mirrorEntries(tabs).map(\.value).first(where: {
              (mirrorStep($0, "contents").map { Mirror(reflecting: $0).children.count } ?? 0) == 1 && mirrorWalk($0, "contents.[0].variant.webContent") != nil
          }) else { return nil }
    let id = UUID().uuidString
    guard let tab = tabModel(like: template, url: url as String, title: title as String, id: id) else { log("a tab didn't clone as expected"); return nil }
    guard let location = endOfGroup(groupID as String) else { return nil }
    defer { location.witnesses.destroy(location.buffer); location.buffer.deallocate() }
    guard Witnesses(type(of: tab)).size > registerBytes, location.witnesses.size > registerBytes else {
        log("createTab's arguments fit in registers on this Dia: not calling it")
        return nil
    }
    func pass<T>(_ value: T) {
        withUnsafePointer(to: value) { invoke(call.function, call.context, UnsafeRawPointer($0), UnsafeRawPointer(location.buffer)) }
    }
    withExtendedLifetime(closure) { _openExistential(tab, do: pass) }
    // Dia made a tab even if it isn't in the group: falling back would open a second. A refresh closes any copy.
    if !((DPGitLabGroupMembers(appDelegate, groupID) as? [[String]])?.contains { $0.first == id } ?? false) { log("tab \(id) isn't in its folder") }
    return id as NSString
}

private func set<T: Hashable>(_ type: T.Type, _ values: [UnsafeRawPointer]) -> Any { Set(values.map { $0.load(as: T.self) }) }

@_cdecl("DPGitLabRemoveTabs")
public func DPGitLabRemoveTabs(_ appDelegate: AnyObject?, _ groupID: NSString, _ tabIDs: NSArray) -> Bool {
    guard Thread.isMainThread, let appDelegate, let ids = tabIDs as? [String], !ids.isEmpty,
          let store = tabStore(appDelegate, holding: groupID as String),
          let closure = tabStoreUtility(appDelegate, removeItems.name, for: store), let call = verified(closure, removeItems),
          let invoke = caller("DPGitLabCallSwiftClosure1", (@convention(c) (UInt, UInt, UInt) -> Void).self),
          let idType = _typeByName("9TabModels7TabItemO2IDO"), String(reflecting: idType) == "TabModels.TabItem.ID",
          let hashable = idType as? any Hashable.Type else { return false }
    // TabItem.ID.tab(id) for each, checked as Dia describes it.
    let witnesses = Witnesses(idType)
    let items = ids.compactMap { id in
        enumValue(idType, tag: 0, payloadSize: MemoryLayout<String>.size) { $0.initializeMemory(as: String.self, repeating: id, count: 1) }
    }
    defer { items.forEach { witnesses.destroy($0); $0.deallocate() } }
    guard items.count == ids.count, zip(items, ids).allSatisfy({ String(describing: witnesses.value(at: $0)) == "tab(\($1))" }) else {
        log("tab items didn't come out as expected")
        return false
    }
    let itemSet = set(hashable, items.map { UnsafeRawPointer($0) })
    var called = false
    func pass<S>(_ value: S) {
        guard MemoryLayout<S>.size == MemoryLayout<UInt>.size else { return }  // A Set is one word: its storage.
        invoke(call.function, call.context, unsafeBitCast(value, to: UInt.self))
        called = true
    }
    withExtendedLifetime(closure) { withExtendedLifetime(itemSet) { _openExistential(itemSet, do: pass) } }
    return called
}
