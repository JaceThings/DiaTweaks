// Reads Dia's Swift objects by field name for the GitLab merge requests patch. Segments, dot-separated:
// name = a Swift stored property, @name = an ObjC getter returning an object, [n] = element n.
import AppKit

// A failure worth a line in Console, as DPGitLabLog writes from Objective-C.
func log(_ text: String) { NSLog("DiaPatches: GitLab merge requests: %@", text) }

func mirrorUnwrapped(_ value: Any) -> Any? {
    let mirror = Mirror(reflecting: value)
    guard mirror.displayStyle == .optional else { return value }
    return mirror.children.first.flatMap { mirrorUnwrapped($0.value) }
}

func mirrorStep(_ value: Any, _ segment: Substring) -> Any? {
    if segment.hasPrefix("@") {
        guard let object = value as? NSObject else { return nil }
        let selector = NSSelectorFromString(String(segment.dropFirst()))
        guard object.responds(to: selector) else { return nil }
        return object.perform(selector)?.takeUnretainedValue()
    }
    if segment.hasPrefix("["), let index = Int(segment.dropFirst().dropLast()) {
        if let array = value as? NSArray { return index < array.count ? array[index] : nil }
        let children = Array(Mirror(reflecting: value).children)
        return index < children.count ? children[index].value : nil
    }
    var mirror: Mirror? = Mirror(reflecting: value)
    while let current = mirror {
        if let child = current.children.first(where: { $0.label == String(segment) }) { return mirrorUnwrapped(child.value) }
        mirror = current.superclassMirror
    }
    return nil
}

func mirrorWalk(_ root: Any, _ path: NSString) -> Any? {
    var current: Any = root
    for segment in (path as String).split(separator: ".") {
        guard let next = mirrorStep(current, segment) else { return nil }
        current = next
    }
    return current
}

@_cdecl("DPGitLabEval")
public func DPGitLabEval(_ root: AnyObject?, _ path: NSString) -> NSString? {
    guard let root, let value = mirrorWalk(root, path) else { return nil }
    return String(describing: value) as NSString
}

@_cdecl("DPGitLabEvalObject")
public func DPGitLabEvalObject(_ root: AnyObject?, _ path: NSString) -> AnyObject? {
    guard let root, let value = mirrorWalk(root, path) else { return nil }
    return value as AnyObject
}

func mirrorEntries(_ value: Any) -> [(key: Any, value: Any)] {
    Mirror(reflecting: value).children.compactMap { child in
        let pair = Array(Mirror(reflecting: child.value).children)
        return pair.count == 2 ? (pair[0].value, pair[1].value) : nil
    }
}

func mirrorText(_ value: Any) -> String {
    if let raw = mirrorStep(value, "rawValue") { return String(describing: raw) }
    return String(describing: value)
}
