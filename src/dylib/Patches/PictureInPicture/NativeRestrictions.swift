struct DPPiPRestrictions: Equatable {
    var play = false, scrub = false, skip = false, close = false
    let minimize: Bool

    init?(player: Any) {
        guard let config = DPPiPChild(player, "customPIPConfig"),
              String(reflecting: type(of: config)) == "PictureInPicture.CustomPIPConfig",
              let minimize = DPPiPChild(config, "minimizeEnabled") as? Bool,
              let attributes = DPPiPChild(config, "customAttributes") else { return nil }
        let knownType = "WebContentBehaviorConfigurationClient.WebContentBehaviorConfiguration.PIPCustomAttribute"
        guard String(reflecting: type(of: attributes)) == "Swift.Array<\(knownType)>" else { return nil }
        self.minimize = minimize
        for attribute in Mirror(reflecting: attributes).children.map(\.value) {
            guard String(reflecting: type(of: attribute)) == knownType else { return nil }
            switch String(describing: attribute) {
            case "disablePlayButton": play = true
            case "disableScrubButton": scrub = true
            case "disableSkipButton": skip = true
            case "disableCloseButton": close = true
            case "activatesWhenInaudible": break
            default: return nil
            }
        }
    }
}
