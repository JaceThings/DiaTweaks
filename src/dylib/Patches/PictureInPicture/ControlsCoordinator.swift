import AppKit
import ObjectiveC
import SwiftUI

@MainActor private var DPPiPCoordinatorKey: UInt8 = 0

@MainActor
private final class DPPiPHostingView: NSHostingView<DPPiPControlsView> {
    override var isOpaque: Bool { false }
    override var mouseDownCanMoveWindow: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
private final class DPPiPCoordinator {
    weak var container: NSView?
    weak var nativeHost: NSView?
    let model: DPPiPPlayerModel
    let host: NSHostingView<DPPiPControlsView>
    let wasHidden: Bool
    private var changingHierarchy = false

    init?(container: NSView, options: DPPiPOptions) {
        guard let nativeHost = DPPiPFindNativeHost(container), let native = DPPiPNativePlayer(host: nativeHost) else { return nil }
        self.container = container; self.nativeHost = nativeHost; wasHidden = nativeHost.isHidden
        model = DPPiPPlayerModel(native: native, options: options)
        host = DPPiPHostingView(rootView: DPPiPControlsView(model: model))
        host.identifier = NSUserInterfaceItemIdentifier("DiaTweaks.PictureInPicture.Controls")
        host.frame = container.bounds; host.autoresizingMask = [.width, .height]
        host.wantsLayer = true; host.layer?.backgroundColor = NSColor.clear.cgColor; host.layer?.isOpaque = false
    }

    func install() {
        guard let container, let nativeHost else { return }
        model.onUnsupported = { [weak self] in
            if let container = self?.container { DPPiPRemove(container) }
        }
        changingHierarchy = true
        container.addSubview(host, positioned: .above, relativeTo: nativeHost)
        nativeHost.isHidden = true
        changingHierarchy = false
    }

    func update(_ options: DPPiPOptions) -> Bool {
        if changingHierarchy { return true }
        guard let container, let nativeHost,
              nativeHost.isDescendant(of: container), DPPiPFindNativeHost(container) === nativeHost,
              model.matchesSource(DPPiPNativeIdentity(nativeHost)),
              host.superview === container else { return false }
        if model.options != options { model.options = options }
        if host.frame != container.bounds { host.frame = container.bounds }
        if !nativeHost.isHidden { nativeHost.isHidden = true }
        return true
    }

    func remove() {
        guard !changingHierarchy else { return }
        changingHierarchy = true
        model.cancel()
        host.removeFromSuperview()
        nativeHost?.isHidden = wasHidden
        changingHierarchy = false
    }
}

@MainActor
private func DPPiPContainer(_ pointer: UnsafeMutableRawPointer?) -> NSView? {
    pointer.flatMap { Unmanaged<AnyObject>.fromOpaque($0).takeUnretainedValue() as? NSView }
}

@MainActor
private func DPPiPRemove(_ container: NSView) {
    (objc_getAssociatedObject(container, &DPPiPCoordinatorKey) as? DPPiPCoordinator)?.remove()
    objc_setAssociatedObject(container, &DPPiPCoordinatorKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
}

@_cdecl("DPPiPShowControls")
public func DPPiPShowControls(_ pointer: UnsafeMutableRawPointer?, _ iconsOnly: Bool,
                            _ smallPlayPause: Bool, _ hideDomain: Bool) -> Bool {
    guard Thread.isMainThread else { return false }
    return MainActor.assumeIsolated {
        guard let container = DPPiPContainer(pointer) else { return false }
        let options = DPPiPOptions(iconsOnly: iconsOnly, smallPlayPause: smallPlayPause, hideDomain: hideDomain)
        guard options.enabled else { DPPiPRemove(container); return false }
        if let current = objc_getAssociatedObject(container, &DPPiPCoordinatorKey) as? DPPiPCoordinator {
            if current.update(options) { return true }
            DPPiPRemove(container)
        }
        guard let coordinator = DPPiPCoordinator(container: container, options: options) else { return false }
        objc_setAssociatedObject(container, &DPPiPCoordinatorKey, coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        coordinator.install()
        return true
    }
}

@_cdecl("DPPiPControlSupport")
public func DPPiPControlSupport(_ pointer: UnsafeMutableRawPointer?) -> Int32 {
    guard Thread.isMainThread else { return -1 }
    return MainActor.assumeIsolated {
        guard let container = DPPiPContainer(pointer) else { return -1 }
        if let coordinator = objc_getAssociatedObject(container, &DPPiPCoordinatorKey) as? DPPiPCoordinator {
            guard let native = DPPiPFindNativeHost(container), native === coordinator.nativeHost,
                  coordinator.model.matchesSource(DPPiPNativeIdentity(native)) else {
                DPPiPRemove(container)
                return DPPiPFindNativeHost(container).map { DPPiPNativeSupport($0) } ?? -1
            }
            let support = coordinator.model.revalidateSupport()
            if support != 1 { DPPiPRemove(container) }
            return support
        }
        guard let host = DPPiPFindNativeHost(container) else { return -1 }
        return DPPiPNativeSupport(host)
    }
}

@_cdecl("DPPiPRemoveControls")
public func DPPiPRemoveControls(_ pointer: UnsafeMutableRawPointer?) {
    guard Thread.isMainThread else { return }
    MainActor.assumeIsolated { if let container = DPPiPContainer(pointer) { DPPiPRemove(container) } }
}

@_cdecl("DPPiPHasControls")
public func DPPiPHasControls(_ pointer: UnsafeMutableRawPointer?) -> Bool {
    guard Thread.isMainThread else { return false }
    return MainActor.assumeIsolated {
        guard let container = DPPiPContainer(pointer),
              let coordinator = objc_getAssociatedObject(container, &DPPiPCoordinatorKey) as? DPPiPCoordinator else { return false }
        return coordinator.host.superview === container && coordinator.nativeHost?.isHidden == true
    }
}
