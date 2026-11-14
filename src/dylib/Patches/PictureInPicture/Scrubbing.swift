import Foundation

// The model owns the transaction so overlay teardown can finish it before actions expire.
@MainActor
final class DPPiPScrubbing {
    private weak var model: DPPiPPlayerModel?
    private var active = false
    private var resume = false

    init(model: DPPiPPlayerModel) { self.model = model }

    func begin() {
        guard !active, let model, model.canSeek else { return }
        active = true
        resume = model.playing && model.perform(1, description: "pause this video")
    }

    func end() {
        guard active else { return }
        active = false
        let shouldResume = resume
        resume = false
        if shouldResume { model?.perform(0, description: "resume this video") }
    }
}
