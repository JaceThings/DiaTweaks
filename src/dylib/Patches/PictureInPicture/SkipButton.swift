import AppKit
import SwiftUI

// Load Dia's own template artwork without copying assets into the tweak.
enum DPPiPArtwork {
    static func skip(forward: Bool, bundle: Bundle = .main) -> NSImage? {
        guard let url = bundle.url(forResource: "ARC_PictureInPicture", withExtension: "bundle"),
              let resources = Bundle(url: url) else { return nil }
        return resources.image(forResource: NSImage.Name(forward ? "GoForward" : "GoBack"))
    }
}

struct DPPiPSkipButton: View {
    let forward: Bool
    let metrics: DPPiPPlaybackMetrics
    var enabled: Bool
    var action: () -> Void
    private var title: String { forward ? "Skip forward 15 seconds" : "Skip back 15 seconds" }

    var body: some View {
        Button(action: action) { Color.clear.frame(width: metrics.skipSize, height: metrics.skipSize) }
            .buttonStyle(DPPiPSkipStyle(forward: forward, metrics: metrics))
            .disabled(!enabled)
            .help(title).accessibilityLabel(title)
            .accessibilityIdentifier("DiaTweaks.PiP.\(forward ? "goforward.15" : "gobackward.15")")
        }
}

private struct DPPiPSkipStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled
    let forward: Bool
    let metrics: DPPiPPlaybackMetrics

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            if let image = DPPiPArtwork.skip(forward: forward) {
                Image(nsImage: image).resizable().renderingMode(.template)
                    .frame(width: metrics.skipSize, height: metrics.skipSize)
                    .rotationEffect(.degrees(configuration.isPressed ? (forward ? 45 : -45) : 0))
                Text("15").font(.system(size: metrics.skipFont, weight: .bold))
            } else {
                Image(systemName: forward ? "goforward.15" : "gobackward.15")
                    .resizable().scaledToFit().frame(width: metrics.skipSize, height: metrics.skipSize)
            }
        }
        .foregroundStyle(.white.opacity(enabled ? 1 : 0.4))
        .padding(metrics.skipPadding)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7, blendDuration: 0.1),
                   value: configuration.isPressed)
    }
}
