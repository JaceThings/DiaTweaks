import SwiftUI

// Dia uses the same four width classes for its native video controls.
struct DPPiPPlaybackMetrics: Equatable {
    let sizeClass: Int
    let smallPlayPause: Bool

    init(width: CGFloat, smallPlayPause: Bool) {
        sizeClass = width < 280 ? 0 : width < 400 ? 1 : width < 600 ? 2 : 3
        self.smallPlayPause = smallPlayPause
    }

    // Scale the native metrics, so the smaller controls still respond to resizing.
    private var scale: CGFloat { smallPlayPause ? 0.5 : 1 }
    var playSize: CGFloat { [48, 50, 75, 75][sizeClass] * scale }
    var playFont: CGFloat { playSize }
    var playPadding: CGFloat { (sizeClass == 0 ? 0 : 8) * scale }
    var skipSize: CGFloat { [0, 36, 44, 44][sizeClass] * scale }
    var skipPadding: CGFloat { (sizeClass >= 2 ? 10 : 0) * scale }
    var skipFont: CGFloat { [0, 10.8, 13.2, 13.2][sizeClass] * scale }
    var rowHeight: CGFloat { max(max(44, playSize), skipSize + skipPadding * 2) }
}
