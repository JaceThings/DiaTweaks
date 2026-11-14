import CoreGraphics

// Keep the position continuous when an upward drag changes seeking precision.
struct DPPiPSeekDrag {
    private var anchorLocation: CGFloat
    private var anchorTarget: Double
    private(set) var target: Double
    private(set) var precision = 1

    init(location: CGFloat, width: CGFloat, duration: Double) {
        let valid = location.isFinite && width.isFinite && width > 0 && duration.isFinite && duration > 0
        let time = valid ? min(duration, max(0, Double(location / width) * duration)) : 0
        anchorLocation = location.isFinite ? location : 0
        anchorTarget = time
        target = time
    }

    static func precision(for translationY: CGFloat) -> Int {
        guard translationY.isFinite else { return 1 }
        let level = min(4, max(0, (-Double(translationY) / 60).rounded()))
        return 1 << Int(level)
    }

    @discardableResult
    mutating func update(location: CGFloat, translationY: CGFloat, width: CGFloat, duration: Double) -> Double {
        guard location.isFinite, width.isFinite, width > 0, duration.isFinite, duration > 0 else { return target }
        target = min(duration, max(0, anchorTarget + Double((location - anchorLocation) / width) * duration / Double(precision)))
        let nextPrecision = Self.precision(for: translationY)
        if nextPrecision != precision {
            anchorLocation = location
            anchorTarget = target
            precision = nextPrecision
        }
        return target
    }
}
