enum RoBlowVersion {
    /// `vA.BC` then a channel.
    /// A = major, B = minor, C = patch. `v1.10` is minor 1, patch 0.
    /// `-Robbed` = beta. `-Roblox` = full release.
    static let mark = "v1.00-Robbed"

    static var displayed: String {
        let raw = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        guard let raw, !raw.isEmpty else { return mark }
        return raw.hasPrefix("v") ? raw : "v\(raw)"
    }
}
