import Foundation

enum ModCategory: String, CaseIterable, Identifiable {
    case performance
    case visual
    case interface
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .performance: "Performance"
        case .visual: "Visual"
        case .interface: "Interface"
        case .privacy: "Privacy"
        }
    }
}

struct ClientMod: Identifiable, Hashable {
    var id: String
    var title: String
    var detail: String
    var category: ModCategory
    var flags: [String: AnyHashable]
}

enum RobloxClientSettings {
    static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Roblox/ClientSettings/ClientAppSettings.json")
    }

    static func write(_ flags: [String: Any]) {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: flags, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

enum ClientModCatalog {
    static let all: [ClientMod] = [
        ClientMod(
            id: "no-postfx",
            title: "Disable post-processing",
            detail: "Turns off bloom, blur, and other extra passes.",
            category: .performance,
            flags: ["FFlagDisablePostFx": "True"]
        ),
        ClientMod(
            id: "low-textures",
            title: "Lowest textures",
            detail: "Forces the cheapest texture quality.",
            category: .performance,
            flags: [
                "DFIntTextureQualityOverrideEnabled": "True",
                "DFIntTextureQualityOverride": 1
            ]
        ),
        ClientMod(
            id: "no-shadows",
            title: "Disable shadows",
            detail: "Drops shadow intensity for a cheaper frame.",
            category: .performance,
            flags: ["FIntRenderShadowIntensity": 0]
        ),
        ClientMod(
            id: "no-msaa",
            title: "Disable anti-aliasing",
            detail: "Turns MSAA off.",
            category: .performance,
            flags: ["FIntDebugForceMSAASamples": 0]
        ),
        ClientMod(
            id: "low-frm",
            title: "Force low graphics",
            detail: "Pins the quality slider to the bottom.",
            category: .performance,
            flags: ["DFIntDebugFRMQualityLevelOverride": 1]
        ),
        ClientMod(
            id: "no-grass",
            title: "Reduce grass",
            detail: "Pulls grass draw distance way down.",
            category: .performance,
            flags: [
                "FIntFRMMinGrassDistance": 0,
                "DFIntFRMMaxGrassDistance": 0
            ]
        ),
        ClientMod(
            id: "unfocused",
            title: "Pause when unfocused",
            detail: "Stops rendering while Roblox is in the background.",
            category: .performance,
            flags: ["FFlagDebugGraphicsDisableUnfocusedRendering": "True"]
        ),
        ClientMod(
            id: "no-menu-blur",
            title: "No menu blur",
            detail: "Removes the frosted pause-menu backdrop.",
            category: .visual,
            flags: ["FIntRobloxGuiBlurIntensity": 0]
        ),
        ClientMod(
            id: "metal",
            title: "Prefer Metal",
            detail: "Asks the Mac client to use Metal.",
            category: .visual,
            flags: ["FFlagDebugGraphicsPreferMetal": "True"]
        ),
        ClientMod(
            id: "no-ads",
            title: "Disable in-experience ads",
            detail: "Tries to keep portal ads off. Roblox can ignore this.",
            category: .interface,
            flags: ["FFlagAdServiceEnabled": "False"]
        ),
        ClientMod(
            id: "no-vr",
            title: "Disable VR",
            detail: "Hides VR startup and headset hooks.",
            category: .interface,
            flags: ["FFlagVREnabled": "False"]
        ),
        ClientMod(
            id: "alt-enter",
            title: "Manual fullscreen",
            detail: "Lets Option-Enter handle fullscreen instead of the desktop overlay.",
            category: .interface,
            flags: ["FFlagHandleAltEnterFullscreenManually": "True"]
        ),
        ClientMod(
            id: "no-telemetry",
            title: "Reduce telemetry",
            detail: "Turns off a few client analytics sinks.",
            category: .privacy,
            flags: [
                "FFlagDebugDisableTelemetryEphemeralStat": "True",
                "FFlagDebugDisableTelemetryPoint": "True",
                "FFlagDebugDisableTelemetryV2Counter": "True",
                "FFlagDebugDisableTelemetryV2Event": "True"
            ]
        )
    ]

    static func mods(in category: ModCategory) -> [ClientMod] {
        all.filter { $0.category == category }
    }

    static func flags(enabledIDs: Set<String>, customJSON: String) -> [String: Any] {
        var flags: [String: Any] = [:]
        for mod in all where enabledIDs.contains(mod.id) {
            for (key, value) in mod.flags {
                flags[key] = value
            }
        }
        if let custom = parseCustom(customJSON) {
            for (key, value) in custom {
                flags[key] = value
            }
        }
        return flags
    }

    static func parseCustom(_ json: String) -> [String: Any]? {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object
    }
}
