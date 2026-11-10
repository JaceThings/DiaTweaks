import SwiftUI

// Match Dia's BasicScrubber: a rounded track, with no separate thumb.
struct DPPiPSeekbarTrack: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let progress: Double
    let active: Bool
    var trackHeight: CGFloat { active ? 10 : 5 }
    private var fraction: CGFloat { progress.isFinite ? CGFloat(min(1, max(0, progress))) : 0 }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: trackHeight / 2).fill(.white.opacity(0.3))
                RoundedRectangle(cornerRadius: trackHeight / 2).fill(.white)
                    .frame(width: geometry.size.width * fraction)
            }
            .frame(width: geometry.size.width, height: trackHeight)
            .frame(height: 15)
            .animation(reduceMotion ? nil : .timingCurve(0.25, 0.1, 0.25, 1, duration: 0.2), value: active)
        }
        .frame(height: 15)
        .accessibilityHidden(true)
    }
}
