import SwiftUI

struct DPPiPControlsView: View {
    @ObservedObject var model: DPPiPPlayerModel
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var seekPrecision: Int?
    @State private var hovering = false

    private var visible: Bool { hovering || voiceOver }

    var body: some View {
        GeometryReader { geometry in
            DPPiPOverlayLayer(visible: visible) {
                controls(size: geometry.size)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private func controls(size: CGSize) -> some View {
        let playHeight = DPPiPPlaybackMetrics(width: size.width, smallPlayPause: model.options.smallPlayPause).rowHeight
        if size.height < max(104, playHeight + 52) {
            DPPiPCompactControls(model: model, width: size.width)
        } else if size.height < 160 {
            VStack(spacing: 0) {
                DPPiPTopControls(model: model, width: size.width)
                Spacer(minLength: 0)
                if model.showControls { DPPiPPlaybackPresentation(model: model, width: size.width, precision: seekPrecision) }
                Spacer(minLength: 0)
                bottom(showSeek: size.height >= playHeight + 74, width: size.width)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
        } else {
            ZStack {
                VStack(spacing: 0) {
                    DPPiPTopControls(model: model, width: size.width)
                    Spacer(minLength: 0)
                    bottom(showSeek: true, width: size.width)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                if model.showControls { DPPiPPlaybackPresentation(model: model, width: size.width, precision: seekPrecision) }
            }
        }
    }

    private func bottom(showSeek: Bool, width: CGFloat) -> some View {
        VStack(spacing: 0) {
            if let error = model.actionError {
                Text(error).font(.system(size: 11)).foregroundStyle(.white)
                    .padding(6).background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
                    .accessibilityLabel(error)
            }
            if showSeek && model.showControls && !model.restrictions.scrub {
                // Complete native 12/16-point side and 4/8-point bottom insets.
                DPPiPSeekbar(model: model, onPrecisionChange: { seekPrecision = $0 })
                    .padding(.horizontal, width < 280 ? 4 : 8)
                    .padding(.vertical, width < 280 ? 0 : 4)
            }
        }
    }
}
