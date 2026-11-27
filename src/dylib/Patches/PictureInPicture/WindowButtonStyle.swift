import SwiftUI

struct DPPiPWindowButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    var title: String
    var isReturn = false
    var showsTitle = false
    var width: CGFloat
    var enabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isReturn {
                    DPPiPReturnArrow(lengthScale: hovering ? 1.2 : 0.8)
                        .stroke(style: StrokeStyle(lineWidth: 1, lineCap: .round))
                        .frame(width: 12, height: 12)
                        .offset(y: hovering ? -2 : 2)
                        .rotationEffect(.degrees(-45))
                } else {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .medium))
                }
                if showsTitle {
                    Text(title).font(.system(size: 12, weight: .medium)).kerning(0.1)
                }
            }
            .foregroundStyle(.white.opacity(enabled ? 1 : 0.4))
            .animation(reduceMotion ? nil : DPPiPWindowButtonStyle.animation, value: hovering)
        }
        .buttonStyle(DPPiPWindowButtonStyle(hovering: hovering, horizontalPadding: width < 280 ? 8 : 10))
        .onHover { hovering = $0 }
        .disabled(!enabled)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityIdentifier("DiaTweaks.PiP.\(isReturn ? "BackToTab" : "xmark")")
    }
}

struct DPPiPWindowButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var hovering: Bool
    var horizontalPadding: CGFloat
    static let animation = Animation.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.3)

    private func background(pressed: Bool) -> Color {
        if reduceTransparency { return Color(white: pressed || hovering ? 0.24 : 0.18) }
        if pressed { return .white.opacity(0.15) }
        return Color(red: 0.98, green: 0.984, blue: 1).opacity(hovering ? 0.15 : 0.1)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, horizontalPadding)
            .frame(height: 28)
            .background(background(pressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: 6))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .animation(reduceMotion ? nil : Self.animation, value: configuration.isPressed)
            .animation(reduceMotion ? nil : Self.animation, value: hovering)
    }
}
