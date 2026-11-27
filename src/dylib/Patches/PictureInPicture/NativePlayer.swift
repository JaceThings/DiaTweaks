import AppKit
import Combine
import SwiftUI

@MainActor
private protocol DPPiPNativeRoot { func pipNativeRoot() -> Any }

extension NSHostingView: DPPiPNativeRoot {
    fileprivate func pipNativeRoot() -> Any { rootView }
}

func DPPiPChild(_ value: Any, _ name: String) -> Any? {
    Mirror(reflecting: value).children.first { $0.label == name }?.value
}

// A value-only wrapper would create a detached publisher when copied. Fail closed in that case.
private func DPPiPSharedPublished<Value>(_ player: Any, _ name: String) -> Published<Value>? {
    guard let property = DPPiPChild(player, name) as? Published<Value>,
          let storage = DPPiPChild(property, "storage"), DPPiPChild(storage, "publisher") != nil else { return nil }
    return property
}

private func DPPiPCurrentFlag(_ property: Published<Bool>) -> Bool {
    var property = property
    var value = false
    let read = property.projectedValue.prefix(1).sink { value = $0 }
    read.cancel()
    return value
}

@MainActor
func DPPiPNativeContent(_ host: NSView) -> Any? {
    guard let root = (host as? any DPPiPNativeRoot)?.pipNativeRoot(),
          let content = DPPiPChild(root, "content"),
          String(reflecting: type(of: content)) == "PictureInPicture.PIPOverlayView" else { return nil }
    return content
}

@MainActor
func DPPiPPlayer(_ host: NSView) -> Any? {
    guard let content = DPPiPNativeContent(host), let player = DPPiPChild(content, "player"),
          String(reflecting: type(of: player)) == "PictureInPicture.ObservablePlayer" else { return nil }
    return player
}

private func DPPiPIsMeeting(_ player: Any) -> Bool? {
    for name in ["_showMicrophoneButton", "_showCameraButton", "_showHangUpButton"] {
        guard var flag: Published<Bool> = DPPiPSharedPublished(player, name) else { return nil }
        var enabled = false
        let read = flag.projectedValue.prefix(1).sink { enabled = $0 }
        read.cancel()
        if enabled { return true }
    }
    return false
}

// Initialized wrapper copies share native publishers without retaining the player.
// Successful seeks publish their target to the native time publisher, as native controls do.
struct DPPiPNativePlayer {
    var playing: Published<Bool>, duration: Published<Double>, time: Published<Double>
    var controls: Published<Bool>, next: Published<Bool>, previous: Published<Bool>
    var origin: Published<String?>
    var microphone: Published<Bool>, camera: Published<Bool>, hangUp: Published<Bool>
    weak var source: AnyObject?
    let restrictions: DPPiPRestrictions
    let actions: DPPiPNativeActions

    @MainActor init?(host: NSView) {
        guard let player = DPPiPPlayer(host), DPPiPIsMeeting(player) == false,
              let restrictions = DPPiPRestrictions(player: player), !restrictions.minimize,
              let actions = DPPiPNativeActions(host: host, source: player as AnyObject),
              let playing: Published<Bool> = DPPiPSharedPublished(player, "_playing"),
              let duration: Published<Double> = DPPiPSharedPublished(player, "_duration"),
              let time: Published<Double> = DPPiPSharedPublished(player, "_playbackTime"),
              let controls: Published<Bool> = DPPiPSharedPublished(player, "_showPlaybackControls"),
              let next: Published<Bool> = DPPiPSharedPublished(player, "_showNextButton"),
              let previous: Published<Bool> = DPPiPSharedPublished(player, "_showPreviousButton"),
              let origin: Published<String?> = DPPiPSharedPublished(player, "_originHost"),
              let microphone: Published<Bool> = DPPiPSharedPublished(player, "_showMicrophoneButton"),
              let camera: Published<Bool> = DPPiPSharedPublished(player, "_showCameraButton"),
              let hangUp: Published<Bool> = DPPiPSharedPublished(player, "_showHangUpButton") else { return nil }
        guard actions.capabilities.supports(controls: DPPiPCurrentFlag(controls), next: DPPiPCurrentFlag(next),
                                           previous: DPPiPCurrentFlag(previous), restrictions: restrictions) else { return nil }
        self.playing = playing; self.duration = duration; self.time = time
        self.controls = controls; self.next = next; self.previous = previous; self.origin = origin
        self.microphone = microphone; self.camera = camera; self.hangUp = hangUp; source = player as AnyObject
        self.restrictions = restrictions
        self.actions = actions
    }
}

@MainActor
func DPPiPNativeSupport(_ host: NSView) -> Int32 {
    guard let player = DPPiPPlayer(host) else { return -1 }
    guard let meeting = DPPiPIsMeeting(player) else { return -1 }
    if meeting { return 0 }
    guard let restrictions = DPPiPRestrictions(player: player) else { return -1 }
    if restrictions.minimize { return 0 }
    return DPPiPNativePlayer(host: host) == nil ? -1 : 1
}

@MainActor
func DPPiPNativeIdentity(_ host: NSView) -> ObjectIdentifier? {
    DPPiPPlayer(host).map { ObjectIdentifier($0 as AnyObject) }
}

@MainActor
func DPPiPFindNativeHost(_ view: NSView) -> NSView? {
    if NSStringFromClass(type(of: view)) == "PictureInPicture.PIPOverlayHostView" { return view }
    for child in view.subviews {
        if let found = DPPiPFindNativeHost(child) { return found }
    }
    return nil
}
