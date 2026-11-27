import AppKit
import Combine

struct DPPiPOptions: Equatable {
    var iconsOnly: Bool, smallPlayPause: Bool, hideDomain: Bool
    var enabled: Bool { iconsOnly || smallPlayPause || hideDomain }
}

struct DPPiPCapabilities: Equatable {
    var play = false, seek = false, previous = false, next = false, back = false, close = false

    func supports(controls: Bool, next showNext: Bool, previous showPrevious: Bool,
                  restrictions: DPPiPRestrictions) -> Bool {
        back && (close || restrictions.close) && (!controls ||
            ((play || restrictions.play) && (seek || restrictions.scrub) &&
             (next || !showNext || restrictions.skip) && (previous || !showPrevious || restrictions.skip)))
    }
}

@MainActor
final class DPPiPPlayerModel: ObservableObject {
    @Published var playing = false
    @Published var duration = 0.0
    @Published var time = 0.0
    @Published var showControls = false
    @Published var showNext = false
    @Published var showPrevious = false
    @Published var showMicrophone = false
    @Published var showCamera = false
    @Published var showHangUp = false
    @Published var origin: String?
    @Published var options: DPPiPOptions
    @Published var capabilities = DPPiPCapabilities()
    @Published var actionError: String?
    @Published private(set) var restrictions: DPPiPRestrictions
    lazy var scrubbing = DPPiPScrubbing(model: self)
    var onUnsupported: (() -> Void)?
    private weak var source: AnyObject?
    private var actions: DPPiPNativeActions?
    private var nativeTime: Published<Double>?
    private var subscriptions = Set<AnyCancellable>()

    init(native: DPPiPNativePlayer, options: DPPiPOptions) {
        actions = native.actions; self.options = options; restrictions = native.restrictions
        source = native.source; nativeTime = native.time
        var native = native
        observe(&native.playing, \.playing)
        observe(&native.duration, \.duration)
        observe(&native.time, \.time)
        observe(&native.controls, \.showControls)
        observe(&native.next, \.showNext)
        observe(&native.previous, \.showPrevious)
        observe(&native.origin, \.origin)
        observe(&native.microphone, \.showMicrophone)
        observe(&native.camera, \.showCamera)
        observe(&native.hangUp, \.showHangUp)
        refreshCapabilities()
    }

    private func observe<Value>(_ source: inout Published<Value>, _ key: ReferenceWritableKeyPath<DPPiPPlayerModel, Value>) {
        source.projectedValue.sink { [weak self] value in
            if Thread.isMainThread {
                MainActor.assumeIsolated { self?.receive(value, key) }
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.receive(value, key)
                }
            }
        }.store(in: &subscriptions)
    }

    private func receive<Value>(_ value: Value, _ key: ReferenceWritableKeyPath<DPPiPPlayerModel, Value>) {
        self[keyPath: key] = value
        refreshCapabilities()
        if showMicrophone || showCamera || showHangUp || !supportsVisibleControls { onUnsupported?() }
    }

    func revalidateSupport() -> Int32 {
        guard let source, actions?.matchesCurrentSource() == true,
              let current = DPPiPRestrictions(player: source) else { return -1 }
        if showMicrophone || showCamera || showHangUp || current.minimize { return 0 }
        if restrictions != current { restrictions = current }
        guard supportsVisibleControls else { return -1 }
        return 1
    }

    func matchesSource(_ identity: ObjectIdentifier?) -> Bool {
        source.map { ObjectIdentifier($0) == identity } ?? false
    }

    func refreshCapabilities() {
        let current = actions?.capabilities ?? DPPiPCapabilities()
        if capabilities != current { capabilities = current }
    }

    private var supportsVisibleControls: Bool {
        capabilities.supports(controls: showControls, next: showNext, previous: showPrevious, restrictions: restrictions)
    }

    var canSeek: Bool { capabilities.seek && duration.isFinite && duration > 0 && !restrictions.scrub }

    @discardableResult
    func perform(_ action: Int32, seconds: Double = 0, description: String) -> Bool {
        guard revalidateSupport() == 1, let actions else { onUnsupported?(); return false }
        let seekTarget = action == 2 ? DPPiPSeekTarget(seconds, duration: duration) : nil
        let allowed: Bool
        switch action {
        case 0, 1: allowed = showControls && capabilities.play && !restrictions.play
        case 2: allowed = showControls && canSeek && seekTarget != nil
        case 3: allowed = capabilities.back
        case 4: allowed = capabilities.close && !restrictions.close
        case 5: allowed = showControls && showNext && capabilities.next && !restrictions.skip
        case 6: allowed = showControls && showPrevious && capabilities.previous && !restrictions.skip
        default: allowed = false
        }
        guard allowed else { actionError = "This control is not available."; return false }
        do {
            try actions.perform(action, seconds: seconds, duration: duration)
            if let seekTarget {
                guard actions.matchesCurrentSource() else { throw DPPiPNativeActionError.stale }
                if var nativeTime {
                    // Match native paused seeking: its timer reads position only while playing.
                    Just(Double(seekTarget)).assign(to: &nativeTime.projectedValue)
                }
            }
            actionError = nil
            refreshCapabilities()
            return true
        } catch {
            actionError = "Couldn’t \(description)."
            NSLog("DiaTweaks PiP: %@", actionError ?? "Action failed")
            if let nativeError = error as? DPPiPNativeActionError, case .stale = nativeError { onUnsupported?() }
            refreshCapabilities()
            return false
        }
    }

    func seek(to seconds: Double) {
        guard canSeek, seconds.isFinite else { return }
        perform(2, seconds: seconds, description: "seek in this video")
    }

    func cancel() { onUnsupported = nil; scrubbing.end(); subscriptions.removeAll(); actions = nil; nativeTime = nil; refreshCapabilities() }
}
