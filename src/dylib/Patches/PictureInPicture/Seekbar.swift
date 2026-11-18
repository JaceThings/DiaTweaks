import SwiftUI

struct DPPiPSeekbar: View {
    @ObservedObject var model: DPPiPPlayerModel
    var onPrecisionChange: (Int?) -> Void = { _ in }
    @State private var hovering = false
    @State private var drag: DPPiPSeekDrag?

    private var duration: Double { model.duration.isFinite && model.duration > 0 ? model.duration : 1 }
    private var current: Double { model.time.isFinite ? min(duration, max(0, model.time)) : 0 }
    private var position: Double { drag?.target ?? current }

    var body: some View {
        GeometryReader { geometry in
            DPPiPSeekbarTrack(progress: position / duration, active: hovering || drag != nil)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { changed($0, width: geometry.size.width) }
                    .onEnded { _ in finish() })
                .onHover { hovering = $0 }
        }
        .frame(height: 15)
        .disabled(!model.canSeek)
        .focusable(interactions: .activate)
        .onMoveCommand { direction in
            guard model.canSeek else { return }
            switch direction {
            case .left: model.seek(to: current - 5)
            case .right: model.seek(to: current + 5)
            default: break
            }
        }
        .onExitCommand(perform: finish)
        .accessibilityRepresentation {
            // Supply slider semantics without drawing the platform slider UI.
            Slider(value: Binding(get: { position }, set: { model.seek(to: $0) }), in: 0...duration)
                .disabled(!model.canSeek)
                .accessibilityLabel("Video position")
                .accessibilityValue("\(timeLabel(position)) of \(timeLabel(model.duration))")
                .accessibilityIdentifier("DiaTweaks.PiP.Seek")
        }
        .accessibilityIdentifier("DiaTweaks.PiP.Seek")
        .onChange(of: model.canSeek) { _, canSeek in if !canSeek { finish() } }
        .onDisappear(perform: finish)
    }

    private func changed(_ value: DragGesture.Value, width: CGFloat) {
        guard model.canSeek else { return }
        if drag == nil {
            model.scrubbing.begin()
            drag = DPPiPSeekDrag(location: value.startLocation.x, width: width, duration: duration)
        }
        guard var next = drag else { return }
        next.update(location: value.location.x, translationY: value.translation.height, width: width, duration: duration)
        drag = next
        model.seek(to: next.target)
        onPrecisionChange(next.precision)
    }

    private func finish() {
        drag = nil
        onPrecisionChange(nil)
        model.scrubbing.end()
    }

    private func timeLabel(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0, seconds < Double(Int.max) else { return "Unknown" }
        let whole = Int(seconds)
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}
