import SwiftUI

// Keep the dimmer and controls on the same visibility transition.
struct DPPiPOverlayLayer<Controls: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let visible: Bool
    let controls: Controls

    init(visible: Bool, @ViewBuilder controls: () -> Controls) {
        self.visible = visible
        self.controls = controls()
    }

    var body: some View {
        ZStack {
            Color.clear
            ZStack {
                // Dia's native hover overlay dims the entire video by 33%.
                Color.black.opacity(0.33).allowsHitTesting(false)
                controls
            }
            .opacity(visible ? 1 : 0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: visible)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
        }
        .contentShape(Rectangle())
    }
}
