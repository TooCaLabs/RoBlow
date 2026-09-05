import Foundation

struct NewUIConfig: Codable, Equatable {
    var isEnabled = false
    var variant: NewUIVariant = .chrome
    var searchTab = true
}

enum NewUIVariant: String, CaseIterable, Codable, Identifiable {
    case chrome

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chrome: "Chrome menu"
        }
    }

    var detail: String {
        switch self {
        case .chrome: "Asks the client for the newer in-experience menu."
        }
    }
}

enum NewUIMod {
    static let name = "New UI"
    static let blurb = "Our chrome on top of Roblox’s website — Home, Discover, and a Search tab."

    static func flags(for config: NewUIConfig) -> [String: Any] {
        guard config.isEnabled else { return [:] }
        var flags: [String: Any] = [
            "FFlagEnableInGameMenuChrome": "True",
            "FFlagEnableInGameMenuModernization": "True",
            "FFlagEnableChromePinnedChat": "True"
        ]
        if config.searchTab {
            flags["FFlagEnableInExperienceSearch"] = "True"
            flags["FFlagEnableChromeSearchBar"] = "True"
            flags["FFlagInGameSearchEnabled"] = "True"
        }
        return flags
    }

    static let stages: [NewUIStage] = [
        NewUIStage(id: "search", title: "Search tab", state: .now, detail: "Google-style search over the Roblox site. Play still uses the official player."),
        NewUIStage(id: "look", title: "Look settings", state: .next, detail: "Accent, density, and which pieces of the menu we keep."),
        NewUIStage(id: "chrome", title: "Quieter unibar", state: .later, detail: "Pin chat and hide extra Chrome icons if the flags still allow it.")
    ]
}

struct NewUIStage: Identifiable, Hashable {
    enum State: String {
        case now
        case next
        case later
    }

    var id: String
    var title: String
    var state: State
    var detail: String

    var label: String {
        switch state {
        case .now: "Now"
        case .next: "Next"
        case .later: "Later"
        }
    }
}
