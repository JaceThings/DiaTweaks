import SwiftUI

// Dia replaces the center controls with a precision guide only during a seek drag.
struct DPPiPPlaybackPresentation: View {
    @ObservedObject var model: DPPiPPlayerModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let width: CGFloat
    let precision: Int?

    var body: some View {
        ZStack {
            DPPiPPlaybackControls(model: model, width: width)
                .opacity(precision == nil ? 1 : 0)
                .allowsHitTesting(precision == nil)
                .accessibilityHidden(precision != nil)
            Text(precision.map { $0 >= 2 ? "Seeking at \($0)× precision" : "Drag upwards to seek precisely" }
                 ?? "Drag upwards to seek precisely")
                .font(.system(.headline))
                .foregroundStyle(.white)
                .opacity(precision == nil ? 0 : 1)
                .allowsHitTesting(false)
                .accessibilityHidden(precision == nil)
        }
        .animation(reduceMotion ? nil : .timingCurve(0.25, 0.1, 0.25, 1, duration: 0.2), value: precision)
    }
}
