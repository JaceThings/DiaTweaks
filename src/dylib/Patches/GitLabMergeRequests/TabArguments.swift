// The two arguments CreateTab.swift passes Dia's createTab, made by Dia's own code: a TabModel through its Codable, and an
// InsertionLocation through its value witnesses. Each is read back before it's used.
import Foundation

private struct Encoded: Encodable {
    let value: Encodable
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}

private func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> Any { try JSONDecoder().decode(type, from: data) }

// A tab like `template` on `url`, decoded as Dia decodes tabs from disk, with ids of its own and nothing tying it to a
// live item, a task or another tab.
func tabModel(like template: Any, url: String, title: String, id: String) -> Any? {
    guard let encodable = template as? Encodable, let decodable = type(of: template) as? Decodable.Type,
          let data = try? JSONEncoder().encode(Encoded(value: encodable)),
          var tab = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          var pane = (tab["contents"] as? [[String: Any]])?.first, var variant = pane["variant"] as? [String: Any],
          var web = variant["webContent"] as? [String: Any], var content = web["_0"] as? [String: Any],
          content["url"] is String, tab["id"] is String, pane["id"] is String else { return nil }
    let now = Date().timeIntervalSinceReferenceDate
    content["url"] = url
    content["title"] = title
    web["_0"] = content
    variant["webContent"] = web
    pane["variant"] = variant
    pane["id"] = UUID().uuidString
    for key in ["tabSessionID", "customTitle", "customIcon", "lastActiveDate"] { pane.removeValue(forKey: key) }
    if pane["creationDate"] is Double { pane["creationDate"] = now }
    tab["contents"] = [pane]
    tab["id"] = id
    for key in ["liveItemID", "workspacePresentation", "splitViewWidths", "assistantSession", "taskID", "referrerID",
                "activeTabIDBeforeCreation", "pendingCleanDate", "lastActiveDate"] { tab.removeValue(forKey: key) }
    if tab["didRestoreFromCleanUp"] != nil { tab["didRestoreFromCleanUp"] = false }
    if tab["creationDate"] is Double { tab["creationDate"] = now }
    guard let json = try? JSONSerialization.data(withJSONObject: tab), let made = try? decode(decodable, json),
          mirrorText(mirrorStep(made, "id") ?? "") == id, mirrorStep(made, "liveItemID") == nil,
          mirrorWalk(made, "contents.[0].variant.webContent.url").map({ String(describing: $0) }) == url else { return nil }
    return made
}

// InsertionLocation(parent: .group(groupID), position: .fromEnd(0)), in a buffer to destroy and deallocate.
func endOfGroup(_ groupID: String) -> (buffer: UnsafeMutableRawPointer, witnesses: Witnesses)? {
    guard let locationType = _typeByName("9TabModels17TabStoreUtilitiesV17InsertionLocationV"),
          let parentType = _typeByName("9TabModels13TabItemParentO"), let positionType = _typeByName("9TabModels17InsertionPositionO"),
          String(reflecting: locationType) == "TabModels.TabStoreUtilities.InsertionLocation" else { return nil }
    let location = Witnesses(locationType), parentWitnesses = Witnesses(parentType), positionWitnesses = Witnesses(positionType)
    let offsets = fieldOffsets(locationType)
    guard offsets.count == 2, offsets[1] + positionWitnesses.size <= location.size,
          let parent = enumValue(parentType, tag: 1, payloadSize: MemoryLayout<String>.size, payload: {
              $0.initializeMemory(as: String.self, repeating: groupID, count: 1) }) else { return nil }
    defer { parentWitnesses.destroy(parent); parent.deallocate() }
    guard let position = enumValue(positionType, tag: 1, payloadSize: MemoryLayout<Int>.size, payload: {
              $0.initializeMemory(as: Int.self, repeating: 0, count: 1) }) else { return nil }
    defer { positionWitnesses.destroy(position); position.deallocate() }
    let buffer = location.allocate()
    parentWitnesses.copy(buffer + offsets[0], parent)
    positionWitnesses.copy(buffer + offsets[1], position)
    // The tags were read from the binary; Dia's own description confirms them.
    let described = String(describing: location.value(at: buffer))
    guard described.contains("group(\(groupID))"), described.contains("fromEnd(0)") else {
        log("the insertion location came out as \(described)")
        location.destroy(buffer)
        buffer.deallocate()
        return nil
    }
    return (buffer, location)
}
