import SwiftUI

struct DPPiPPlaybackControls: View {
    @ObservedObject var model: DPPiPPlayerModel
    let width: CGFloat

    var metrics: DPPiPPlaybackMetrics { .init(width: width, smallPlayPause: model.options.smallPlayPause) }
    private var hasRoomForTracks: Bool { width >= 280 }

    var body: some View {
        HStack(spacing: 0) {
            if !model.restrictions.skip && hasRoomForTracks {
                if model.showPrevious && hasRoomForTracks {
                    DPPiPControlButton(symbol: "backward.end.fill", title: "Previous track",
                                       enabled: model.capabilities.previous) {
                        model.perform(6, description: "play the previous track")
                    }
                }
                DPPiPSkipButton(forward: false, metrics: metrics,
                                   enabled: model.canSeek && model.time.isFinite && model.time > 0) {
                    model.seek(to: model.time - 15)
                }
            }
            DPPiPPlayButton(model: model, width: width)
            if !model.restrictions.skip && hasRoomForTracks {
                DPPiPSkipButton(forward: true, metrics: metrics,
                                   enabled: model.canSeek && model.time.isFinite && model.time < model.duration) {
                    model.seek(to: model.time + 15)
                }
                if model.showNext && hasRoomForTracks {
                    DPPiPControlButton(symbol: "forward.end.fill", title: "Next track",
                                       enabled: model.capabilities.next) {
                        model.perform(5, description: "play the next track")
                    }
                }
            }
        }
    }
}

struct DPPiPPlayButton: View {
    @ObservedObject var model: DPPiPPlayerModel
    let width: CGFloat
    var metrics: DPPiPPlaybackMetrics { .init(width: width, smallPlayPause: model.options.smallPlayPause) }
    var body: some View {
        if !model.restrictions.play {
            DPPiPControlButton(symbol: model.playing ? "pause" : "play.fill", title: model.playing ? "Pause" : "Play",
                               diameter: metrics.playSize, iconSize: metrics.playFont, enabled: model.capabilities.play) {
                model.perform(model.playing ? 1 : 0, description: model.playing ? "pause this video" : "play this video")
            }
            .padding(.horizontal, metrics.playPadding)
        }
    }
}
