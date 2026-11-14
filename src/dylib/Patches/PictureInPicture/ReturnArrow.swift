import SwiftUI

// Match Dia's animated return arrow instead of substituting a PiP symbol.
struct DPPiPReturnArrow: Shape {
    var lengthScale: CGFloat

    var animatableData: CGFloat {
        get { lengthScale }
        set { lengthScale = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let tip = CGPoint(x: rect.midX, y: rect.minY)
        let tail = CGPoint(x: rect.midX, y: lengthScale * rect.maxY)
        let left = CGPoint(x: rect.midX - 0.4 * rect.width, y: rect.minY + 0.4 * rect.width)
        let right = CGPoint(x: rect.midX + 0.4 * rect.width, y: rect.minY + 0.4 * rect.width)
        var path = Path()
        path.move(to: tail)
        path.addLine(to: tip)
        path.move(to: left)
        path.addLine(to: tip)
        path.addLine(to: right)
        return path
    }
}
