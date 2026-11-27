import SwiftUI

struct DPPiPControlButton: View {
    var symbol: String
    var title: String
    var diameter: CGFloat = 28
    var iconSize: CGFloat = 13
    var enabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: iconSize, weight: .bold))
                .frame(width: diameter, height: diameter)
                .foregroundStyle(.white.opacity(enabled ? 1 : 0.4))
        }
        .buttonStyle(DPPiPPlaybackButtonStyle())
        .disabled(!enabled)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityIdentifier("DiaTweaks.PiP.\(symbol)")
    }
}

struct DPPiPPlaybackButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.8 : hovering ? 1.05 : 1)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: hovering)
    }
}
