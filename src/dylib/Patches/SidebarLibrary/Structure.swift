import Foundation
#if DPLIBRARY_DIAGNOSTICS
@_cdecl("DPLibraryStructure")
public func DPLibraryStructure(_ object: AnyObject?) -> NSDictionary {
    guard let object else { return [:] }
    var result: [String: String] = [:]
    var mirror: Mirror? = Mirror(reflecting: object)
    var depth = 0
    while let value = mirror, depth < 4 {
        for child in value.children {
            if let label = child.label { result[label] = String(reflecting: type(of: child.value)) }
        }
        mirror = value.superclassMirror; depth += 1
    }
    return result as NSDictionary
}
#endif
#if DPLIBRARY_DIAGNOSTICS
@_cdecl("DPLibraryStateShape")
public func DPLibraryStateShape(_ object: AnyObject?) -> NSDictionary {
    guard let object else { return [:] }
    var result: [String: String] = [:]
    let paths: Set<String> = ["viewModel", "stateSubject", "currentValue", "state", "activeSpace", "activeSpaceID", "selectedSpace", "selectedSpaceID", "browserContext", "browser", "context", "profile", "activeBrowser", "browserID", "activeBrowserID", "contextID", "profileID", "regular", "profile", "rawValue"]
    func inspect(_ value: Any, _ path: String, _ depth: Int) {
        guard depth < 8, result.count < 150 else { return }
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            if let child = mirror.children.first { inspect(child.value, path, depth + 1) }
            return
        }
        for child in mirror.children {
            guard let label = child.label else { continue }
            let key = path.isEmpty ? label : path + "." + label
            result[key] = String(reflecting: type(of: child.value))
            if label == "contextID" { result[key + ".description"] = String(describing: child.value) }
            if paths.contains(label) { inspect(child.value, key, depth + 1) }
        }
    }
    inspect(object, "", 0)
    return result as NSDictionary
}
#endif
