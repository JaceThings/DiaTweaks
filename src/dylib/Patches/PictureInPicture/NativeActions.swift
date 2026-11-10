import AppKit

func DPPiPSeekTarget(_ seconds: Double, duration: Double) -> Int64? {
    guard seconds.isFinite, duration.isFinite, duration > 0 else { return nil }
    let maximum = min(duration, Double(Int64.max / 1_000_000))
    return Int64(min(maximum, max(0, seconds)).rounded(.down))
}

private func DPPiPSome(_ value: Any?) -> Any? {
    guard let value else { return nil }
    let mirror = Mirror(reflecting: value)
    guard mirror.displayStyle == .optional else { return nil }
    return mirror.children.first { $0.label == "some" }?.value
}

private func DPPiPTypedChild(_ value: Any, _ name: String, _ type: String) -> Any? {
    guard let child = DPPiPChild(value, name), String(reflecting: Swift.type(of: child)) == type else { return nil }
    return child
}

@MainActor
private func DPPiPMediaSession(_ player: Any) -> Any? {
    guard let source = DPPiPTypedChild(player, "sourcePlayer", "PictureInPicture.PIPPlaybackController"),
          let model = DPPiPTypedChild(source, "viewModel", "PIP.VideoPIPWindowViewModel"),
          let delegate = DPPiPSome(DPPiPChild(model, "delegate")),
          String(reflecting: type(of: delegate)) == "PIP.VideoPIPContentController",
          let controller = DPPiPSome(DPPiPChild(delegate, "pipSessionController")),
          String(reflecting: type(of: controller)) == "ADK2.PIPSessionController" else { return nil }
    return DPPiPTypedChild(controller, "mediaSession", "ADK2.MediaSessionProxy")
}

enum DPPiPNativeActionError: Error { case stale, unavailable }

// Only the native host and player identities are kept, both weakly. Native closures may
// capture a window or source, so resolve them for each click instead of storing them.
@MainActor
struct DPPiPNativeActions {
    private typealias PlaybackAction = @MainActor () throws -> Void
    private typealias WindowAction = () -> Void
    private weak var host: NSView?
    private weak var source: AnyObject?
    private let captured: DPPiPCapabilities

    init?(host: NSView, source: AnyObject) {
        guard let content = DPPiPNativeContent(host), let player = DPPiPPlayer(host),
              player as AnyObject === source else { return nil }
        self.host = host; self.source = source
        var capabilities = DPPiPCapabilities()
        capabilities.back = DPPiPSome(DPPiPChild(content, "onBackToTab")) is WindowAction
        capabilities.close = DPPiPSome(DPPiPChild(content, "onClose")) is WindowAction
        if let media = DPPiPMediaSession(player) {
            capabilities.play = DPPiPChild(media, "_play") is PlaybackAction && DPPiPChild(media, "_pause") is PlaybackAction
            capabilities.seek = DPPiPReadSeek(media) != nil
            capabilities.next = DPPiPChild(media, "_playNextTrack") is PlaybackAction
            capabilities.previous = DPPiPChild(media, "_playPreviousTrack") is PlaybackAction
        }
        captured = capabilities
    }

    var capabilities: DPPiPCapabilities { host != nil && source != nil ? captured : DPPiPCapabilities() }

    func matchesCurrentSource() -> Bool {
        guard let host, let source, let player = DPPiPPlayer(host) else { return false }
        return player as AnyObject === source
    }

    func perform(_ action: Int32, seconds: Double, duration: Double) throws {
        guard let host, let source, let content = DPPiPNativeContent(host),
              let player = DPPiPPlayer(host), player as AnyObject === source else { throw DPPiPNativeActionError.stale }
        if action == 3 || action == 4 {
            let name = action == 3 ? "onBackToTab" : "onClose"
            guard let callback = DPPiPSome(DPPiPChild(content, name)) as? WindowAction else { throw DPPiPNativeActionError.stale }
            callback()
            return
        }
        guard let media = DPPiPMediaSession(player) else { throw DPPiPNativeActionError.stale }
        if action == 2 {
            guard let target = DPPiPSeekTarget(seconds, duration: duration) else { throw DPPiPNativeActionError.unavailable }
            guard let callback = DPPiPReadSeek(media) else { throw DPPiPNativeActionError.stale }
            try callback(target)
            return
        }
        let name: String
        switch action {
        case 0: name = "_play"
        case 1: name = "_pause"
        case 5: name = "_playNextTrack"
        case 6: name = "_playPreviousTrack"
        default: throw DPPiPNativeActionError.unavailable
        }
        guard let callback = DPPiPChild(media, name) as? PlaybackAction else { throw DPPiPNativeActionError.stale }
        try callback()
    }
}
