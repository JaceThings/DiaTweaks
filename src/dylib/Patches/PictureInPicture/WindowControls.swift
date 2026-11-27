import SwiftUI

struct DPPiPReturnButton: View {
    @ObservedObject var model: DPPiPPlayerModel
    var showsTitle = false
    let width: CGFloat
    var body: some View {
        DPPiPWindowButton(title: "Back to Tab", isReturn: true, showsTitle: showsTitle,
                          width: width, enabled: model.capabilities.back) {
            model.perform(3, description: "return to the tab")
        }
    }
}

struct DPPiPCloseButton: View {
    @ObservedObject var model: DPPiPPlayerModel
    var showsTitle = false
    let width: CGFloat
    var body: some View {
        if !model.restrictions.close {
            DPPiPWindowButton(title: "Close", showsTitle: showsTitle, width: width, enabled: model.capabilities.close) {
                model.perform(4, description: "close picture in picture")
            }
        }
    }
}

struct DPPiPTopControls: View {
    @ObservedObject var model: DPPiPPlayerModel
    let width: CGFloat
    private var titles: Bool { !model.options.iconsOnly && width >= 280 }

    var body: some View {
        ZStack {
            if !model.options.hideDomain, let origin = model.origin, !origin.isEmpty {
                Text(origin).font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
                    .lineLimit(1).truncationMode(.middle)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .frame(maxWidth: max(0, width - (titles ? 266 : 128)))
                    .allowsHitTesting(false)
                    .accessibilityLabel("Website").accessibilityValue(origin)
            }
            HStack {
                DPPiPReturnButton(model: model, showsTitle: titles, width: width)
                Spacer(minLength: 0)
                DPPiPCloseButton(model: model, showsTitle: titles, width: width)
            }
        }
        .frame(height: 44)
    }
}

struct DPPiPCompactControls: View {
    @ObservedObject var model: DPPiPPlayerModel
    let width: CGFloat
    private var titles: Bool { !model.options.iconsOnly && width >= 280 }

    var body: some View {
        HStack(spacing: 0) {
            DPPiPReturnButton(model: model, showsTitle: titles, width: width)
            Spacer(minLength: 0)
            if model.showControls { DPPiPPlayButton(model: model, width: width) }
            Spacer(minLength: 0)
            DPPiPCloseButton(model: model, showsTitle: titles, width: width)
        }
        .padding(.horizontal, 8)
    }
}
