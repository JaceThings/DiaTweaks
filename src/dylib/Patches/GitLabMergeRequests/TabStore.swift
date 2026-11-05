// What the patch reads from Dia's Swift model, by field name: its Live Folders, its tab store and a tab store's
// utilities. Nothing here writes.
import AppKit

private let contextsPath: NSString = "controller.userDataController.browserContextDataControllers"
private let storesPath: NSString = "controller.userDataController.tabStoreManager.tabStoreStates"

// Every Live Folder's configuration, in every browser context, with the id of the group it shows.
private func liveFolders(_ appDelegate: AnyObject) -> [(group: String, configuration: Any)] {
    guard let contexts = mirrorWalk(appDelegate, contextsPath) else { return [] }
    return mirrorEntries(contexts).flatMap { context in
        mirrorWalk(context.value, "liveFolderManager.persistedConfigurations").map { configurations in
            mirrorEntries(configurations).map { (mirrorText($0.key), $0.value) }
        } ?? []
    }
}

// The tab store holding a group: its model, and the browser context it belongs to.
func tabStore(_ appDelegate: AnyObject, holding groupID: String) -> (model: Any, context: Any)? {
    guard let stores = mirrorWalk(appDelegate, storesPath) else { return nil }
    for store in mirrorEntries(stores) {
        guard let controller = mirrorStep(store.value, "ready"), let model = mirrorWalk(controller, "modelChannel._value._value"),
              let groups = mirrorStep(model, "groups"), mirrorEntries(groups).contains(where: { mirrorText($0.key) == groupID }) else { continue }
        return (model, store.key)
    }
    return nil
}

// A closure of the TabStoreUtilities that edits that tab store.
func tabStoreUtility(_ appDelegate: AnyObject, _ name: String, for store: (model: Any, context: Any)) -> Any? {
    let context = String(describing: store.context)
    guard let contexts = mirrorWalk(appDelegate, contextsPath),
          let data = mirrorEntries(contexts).first(where: { String(describing: $0.key) == context })?.value else { return nil }
    return mirrorWalk(data, ("tabStoreUtilities." + name) as NSString)
}

@_cdecl("DPGitLabPullRequestFolderIDs")
public func DPGitLabPullRequestFolderIDs(_ appDelegate: AnyObject?) -> NSArray {
    guard let appDelegate else { return [] }
    return liveFolders(appDelegate).filter { folder in
        mirrorStep(folder.configuration, "dataSourceType").map { String(describing: $0) } == "pullRequests"
    }.map { $0.group as NSString } as NSArray
}

// The folder's own Created by Me and Review Requests switches, as Dia keeps them for it: [created, review], or nil.
@_cdecl("DPGitLabFolderBuckets")
public func DPGitLabFolderBuckets(_ appDelegate: AnyObject?, _ groupID: NSString) -> NSArray? {
    guard let appDelegate, let folder = liveFolders(appDelegate).first(where: { $0.group == groupID as String }),
          let pullRequests = mirrorWalk(folder.configuration, "dataSourceConfig.pullRequests"),
          let created = mirrorStep(pullRequests, "includeCreatedByMe") as? Bool,
          let review = mirrorStep(pullRequests, "includeAwaitingReview") as? Bool else { return nil }
    return [created, review] as NSArray
}

// A group's tabs in order as [tab id, URL], or nil if no tab store has it. The tab store holds the tabs of a collapsed
// folder and tabs Dia hasn't loaded since launch, which neither the sidebar's views nor Dia's scripting show.
@_cdecl("DPGitLabGroupMembers")
public func DPGitLabGroupMembers(_ appDelegate: AnyObject?, _ groupID: NSString) -> NSArray? {
    guard let appDelegate, let store = tabStore(appDelegate, holding: groupID as String),
          let groups = mirrorStep(store.model, "groups"), let tabs = mirrorStep(store.model, "tabs"),
          let group = mirrorEntries(groups).first(where: { mirrorText($0.key) == groupID as String })?.value,
          let children = mirrorStep(group, "childIDs") else { return nil }
    var tabsByID: [String: Any] = [:]
    for tab in mirrorEntries(tabs) { tabsByID[mirrorText(tab.key)] = tab.value }
    return Mirror(reflecting: children).children.compactMap { child -> NSArray? in
        guard let id = mirrorStep(child.value, "tab").map(mirrorText), let tab = tabsByID[id] else { return nil }  // A nested group isn't a tab.
        let url = mirrorWalk(tab, "contents.[0].variant.webContent.url").map { String(describing: $0) } ?? ""
        return [id as NSString, url as NSString]
    } as NSArray
}

// Whether a tab store has the group, without reading its tabs: cheap enough for .verify.
@_cdecl("DPGitLabHasGroup")
public func DPGitLabHasGroup(_ appDelegate: AnyObject?, _ groupID: NSString) -> Bool {
    guard let appDelegate else { return false }
    return tabStore(appDelegate, holding: groupID as String) != nil
}

// The Space whose pinned area holds a group, from the tab store: there whether or not the sidebar is showing.
@_cdecl("DPGitLabGroupSpace")
public func DPGitLabGroupSpace(_ appDelegate: AnyObject?, _ groupID: NSString) -> NSString? {
    guard let appDelegate, let store = tabStore(appDelegate, holding: groupID as String),
          let parents = mirrorStep(store.model, "itemParentMap"),
          let parent = mirrorEntries(parents).first(where: { mirrorStep($0.key, "group").map(mirrorText) == groupID as String })?.value,
          let space = mirrorWalk(parent, "container.pinned") else { return nil }
    return mirrorText(space) as NSString
}
