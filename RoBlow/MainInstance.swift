import AppKit
import SwiftUI

enum InstanceFPS: Int, CaseIterable, Identifiable, Codable {
    case sixty = 60
    case oneTwenty = 120
    case oneFortyFour = 144
    case twoForty = 240
    case unlimited = 0

    var id: Int { rawValue }

    var title: String {
        self == .unlimited ? "Unlimited" : "\(rawValue) FPS"
    }
}

enum GraphicsLevel: String, CaseIterable, Identifiable, Codable {
    case min = "Min (Low Cap)"
    case mid = "Mid"
    case max = "Max"

    var id: String { rawValue }
}

enum UIFontStyle: String, CaseIterable, Identifiable, Codable {
    case productSans = "Product Sans"
    case builderSans = "Builder Sans"
    case gotham = "Gotham"

    var id: String { rawValue }
}

struct InstanceModConfig: Codable, Equatable {
    var enabledIDs: [String] = []
    var customJSON: String = "{\n\n}"
    var newUI: NewUIConfig?
    var webMods: [InstanceWebMod]?
}

struct InstanceConfig: Codable {
    var id: UUID
    var name: String
    var isMain: Bool
    var accountID: UUID?
    var fps: InstanceFPS
    var graphics: GraphicsLevel
    var fontStyle: UIFontStyle
    var bypassMutex: Bool
    var killBackgroundRendering: Bool
    var autoReconnect: Bool
    var mods: InstanceModConfig?
}

@MainActor
@Observable
final class GameInstance: Identifiable {
    var id: UUID
    var name: String
    var isMain: Bool
    var accountID: UUID?
    var fps: InstanceFPS
    var graphics: GraphicsLevel
    var fontStyle: UIFontStyle
    var bypassMutex: Bool
    var killBackgroundRendering: Bool
    var autoReconnect: Bool
    var processIDs: [pid_t] = []
    var launchedAt: Date?
    var isBusy = false
    var userStopped = false
    var showAccountPicker = false
    var enabledModIDs: Set<String>
    var customModJSON: String
    var customModError: String?
    var newUI: NewUIConfig
    var webMods: [InstanceWebMod]

    init(snapshot: InstanceConfig) {
        id = snapshot.id
        name = snapshot.name
        isMain = snapshot.isMain
        accountID = snapshot.accountID
        fps = snapshot.fps
        graphics = snapshot.graphics
        fontStyle = snapshot.fontStyle
        bypassMutex = snapshot.bypassMutex
        killBackgroundRendering = snapshot.killBackgroundRendering
        autoReconnect = snapshot.autoReconnect
        enabledModIDs = Set(snapshot.mods?.enabledIDs ?? [])
        customModJSON = snapshot.mods?.customJSON ?? "{\n\n}"
        newUI = snapshot.mods?.newUI ?? NewUIConfig()
        webMods = snapshot.mods?.webMods ?? []
    }

    convenience init(name: String, isMain: Bool = false) {
        self.init(
            snapshot: InstanceConfig(
                id: UUID(),
                name: name,
                isMain: isMain,
                accountID: nil,
                fps: .oneFortyFour,
                graphics: .min,
                fontStyle: .productSans,
                bypassMutex: true,
                killBackgroundRendering: true,
                autoReconnect: false,
                mods: InstanceModConfig()
            )
        )
    }

    var snapshot: InstanceConfig {
        InstanceConfig(
            id: id,
            name: name,
            isMain: isMain,
            accountID: accountID,
            fps: fps,
            graphics: graphics,
            fontStyle: fontStyle,
            bypassMutex: bypassMutex,
            killBackgroundRendering: killBackgroundRendering,
            autoReconnect: autoReconnect,
            mods: InstanceModConfig(
                enabledIDs: Array(enabledModIDs),
                customJSON: customModJSON,
                newUI: newUI,
                webMods: webMods
            )
        )
    }

    var activeModCount: Int {
        enabledModIDs.count
            + (parsedCustomModFlags()?.isEmpty == false ? 1 : 0)
            + (newUI.isEnabled ? 1 : 0)
            + webMods.filter(\.isEnabled).count
    }

    func isModEnabled(_ id: String) -> Bool {
        enabledModIDs.contains(id)
    }

    func setModEnabled(_ id: String, _ on: Bool) {
        if on {
            enabledModIDs.insert(id)
        } else {
            enabledModIDs.remove(id)
        }
    }

    func copyMods(from other: GameInstance) {
        enabledModIDs = other.enabledModIDs
        customModJSON = other.customModJSON
        customModError = nil
        newUI = other.newUI
        webMods = other.webMods
    }

    func addWebMod(_ id: String) {
        if let index = webMods.firstIndex(where: { $0.id == id }) {
            webMods[index].isEnabled = true
        } else {
            webMods.append(InstanceWebMod(id: id, isEnabled: true))
        }
    }

    func setWebModEnabled(_ id: String, _ on: Bool) {
        if let index = webMods.firstIndex(where: { $0.id == id }) {
            webMods[index].isEnabled = on
        }
    }

    func removeWebMod(_ id: String) {
        webMods.removeAll { $0.id == id }
    }

    func combinedModFlags() -> [String: Any] {
        var flags = ClientModCatalog.flags(enabledIDs: enabledModIDs, customJSON: customModJSON)
        flags.merge(NewUIMod.flags(for: newUI)) { _, new in new }
        return flags
    }

    func saveCustomMods() -> Bool {
        if customModJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            customModJSON = "{\n\n}"
        }
        if parsedCustomModFlags() == nil {
            customModError = "Custom flags must be a JSON object."
            return false
        }
        customModError = nil
        return true
    }

    func parsedCustomModFlags() -> [String: Any]? {
        ClientModCatalog.parseCustom(customModJSON)
    }

    var isRunning: Bool {
        liveApps().isEmpty == false
    }

    func liveApps() -> [NSRunningApplication] {
        processIDs.compactMap { pid in
            guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else { return nil }
            return app
        }
    }
}

@MainActor
@Observable
final class InstanceManager {
    static let persistenceKey = "roblox.instances.v1"
    static let legacyKey = "roblox.main.instance.config"
    static let playerBundleID = "com.roblox.RobloxPlayer"
    static let appURL = URL(fileURLWithPath: "/Applications/Roblox.app")
    static let playerBinary = URL(fileURLWithPath: "/Applications/Roblox.app/Contents/MacOS/RobloxPlayer")

    var slots: [GameInstance] = []
    var isInstalled = FileManager.default.isExecutableFile(atPath: playerBinary.path)
    var isEditingName = false
    var editingModInstanceID: UUID?

    func load() {
        if let data = UserDefaults.standard.data(forKey: Self.persistenceKey),
           let saved = try? JSONDecoder().decode([InstanceConfig].self, from: data),
           !saved.isEmpty {
            slots = saved.map(GameInstance.init(snapshot:))
        } else {
            let main = GameInstance(name: "Main instance", isMain: true)
            if let data = UserDefaults.standard.data(forKey: Self.legacyKey),
               let legacy = try? JSONDecoder().decode(LegacyMainConfig.self, from: data) {
                main.fps = legacy.fps
                main.graphics = legacy.graphics
                main.fontStyle = legacy.fontStyle
                main.bypassMutex = legacy.bypassMutex
                main.killBackgroundRendering = legacy.killBackgroundRendering
                main.autoReconnect = legacy.autoReconnect
            }
            slots = [main]
            persist()
        }
        migrateLegacyGlobalMods()
        refresh()
        cleanupBrokenClones()
    }

    private func migrateLegacyGlobalMods() {
        let enabled = UserDefaults.standard.array(forKey: "roblox.mods.enabled") as? [String]
        let custom = UserDefaults.standard.string(forKey: "roblox.mods.custom")
        guard enabled != nil || custom != nil else { return }
        for slot in slots where slot.enabledModIDs.isEmpty {
            slot.enabledModIDs = Set(enabled ?? [])
            if let custom, slot.customModJSON == "{\n\n}" {
                slot.customModJSON = custom
            }
        }
        UserDefaults.standard.removeObject(forKey: "roblox.mods.enabled")
        UserDefaults.standard.removeObject(forKey: "roblox.mods.custom")
        persist()
    }

    func persist() {
        let payload = slots.map(\.snapshot)
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: Self.persistenceKey)
        }
    }

    func instance(for id: UUID) -> GameInstance? {
        slots.first(where: { $0.id == id })
    }

    func createInstance() -> GameInstance {
        let next = slots.count + 1
        let created = GameInstance(name: "Instance \(next)")
        slots.append(created)
        persist()
        return created
    }

    func deleteInstance(_ id: UUID) {
        guard let index = slots.firstIndex(where: { $0.id == id }) else { return }
        let slot = slots[index]
        if slots.count == 1 { return }
        terminate(slot)
        slots.remove(at: index)
        if editingModInstanceID == id {
            editingModInstanceID = slots.first?.id
        }
        try? FileManager.default.removeItem(at: instanceFolder(for: id))
        persist()
    }

    func refresh() {
        isInstalled = FileManager.default.isExecutableFile(atPath: Self.playerBinary.path)
        for slot in slots {
            slot.processIDs = slot.liveApps().map(\.processIdentifier)
            if !slot.isRunning {
                slot.launchedAt = nil
            }
        }
    }

    func launch(
        _ slot: GameInstance,
        account: AccountProfile,
        placeID: String? = nil,
        linkCode: String? = nil,
        playerURL: URL? = nil
    ) async -> String {
        refresh()
        guard isInstalled else { return "Roblox is not installed in /Applications" }

        slot.userStopped = false
        slot.isBusy = true
        defer { slot.isBusy = false }

        if slot.isRunning && !slot.bypassMutex {
            bringToFront(slot)
            return "\(slot.name) is already running"
        }

        writeClientSettings(for: slot)

        var ticketURL = playerURL
        if ticketURL == nil, account.isSignedIn, let cookie = RobloxSecrets.cookie(for: account.userID) {
            if let ticket = try? await RobloxAuth.authenticationTicket(cookie: cookie) {
                ticketURL = RobloxAuth.playerLaunchURL(ticket: ticket, placeID: placeID, linkCode: linkCode)
            }
        }

        do {
            if let ticketURL {
                try startOfficialPlayerWithOpen(slot: slot, url: ticketURL)
            } else {
                try startOfficialPlayer(slot: slot)
            }
        } catch {
            do {
                try startOfficialPlayer(slot: slot)
            } catch {
                return "Roblox couldn’t be opened. Try launching Roblox.app once from /Applications, then try again."
            }
        }

        slot.launchedAt = slot.launchedAt ?? Date()
        persist()
        return "Launched \(slot.name) as \(account.isSignedIn ? account.username : "the current session")"
    }

    func bringToFront(_ slot: GameInstance) -> String {
        let apps = slot.liveApps()
        guard !apps.isEmpty else { return "\(slot.name) is not running" }
        for app in apps {
            app.unhide()
            app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }
        return "Brought \(slot.name) to the front"
    }

    func terminate(_ slot: GameInstance) -> String {
        slot.userStopped = true
        let apps = slot.liveApps()
        guard !apps.isEmpty else { return "\(slot.name) is not running" }
        for app in apps {
            app.terminate()
        }
        let id = slot.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let slot = self?.instance(for: id) else { return }
            for leftover in slot.liveApps() {
                leftover.forceTerminate()
            }
            self?.refresh()
        }
        slot.processIDs = []
        slot.launchedAt = nil
        return "Terminated \(slot.name)"
    }

    func terminateAll() {
        for slot in slots {
            _ = terminate(slot)
        }
    }

    func handleCrashWatch(accountFor slot: GameInstance, fallback: AccountProfile) async -> String? {
        let running = slot.isRunning
        let hadPIDs = !slot.processIDs.isEmpty || slot.launchedAt != nil
        refresh()
        if hadPIDs && !running && !slot.isRunning {
            slot.launchedAt = nil
            slot.processIDs = []
            if slot.autoReconnect && !slot.userStopped {
                return await launch(slot, account: fallback)
            }
        }
        return nil
    }

    private struct LegacyMainConfig: Codable {
        var fps: InstanceFPS
        var graphics: GraphicsLevel
        var fontStyle: UIFontStyle
        var bypassMutex: Bool
        var killBackgroundRendering: Bool
        var autoReconnect: Bool
    }

    private func instanceFolder(for id: UUID) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/RoBlow/instances/\(id.uuidString)")
    }

    private func cleanupBrokenClones() {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/RoBlow/instances")
        try? FileManager.default.removeItem(at: root)
    }

    private func startOfficialPlayer(slot: GameInstance) throws {
        let process = Process()
        process.executableURL = Self.playerBinary
        process.currentDirectoryURL = Self.playerBinary.deletingLastPathComponent()
        try process.run()
        slot.processIDs.append(process.processIdentifier)
    }

    private func startOfficialPlayerWithOpen(slot: GameInstance, url: URL?) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        var arguments = ["-a", Self.appURL.path]
        if slot.bypassMutex {
            arguments.insert("-n", at: 0)
        }
        if let url {
            arguments.append(url.absoluteString)
        }
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CocoaError(.fileReadUnknown)
        }
        attachNewestPlayer(to: slot)
    }

    private func attachNewestPlayer(to slot: GameInstance) {
        let taken = Set(slots.flatMap(\.processIDs))
        let players = NSWorkspace.shared.runningApplications.filter { app in
            app.bundleIdentifier == Self.playerBundleID
                || app.executableURL?.lastPathComponent == "RobloxPlayer"
        }
        if let fresh = players.first(where: { !taken.contains($0.processIdentifier) }) {
            slot.processIDs.append(fresh.processIdentifier)
        }
    }

    func writeClientSettings(for slot: GameInstance) {
        var flags = clientFlags(for: slot)
        flags.merge(slot.combinedModFlags()) { _, new in new }
        RobloxClientSettings.write(flags)
    }

    func clientFlags(for slot: GameInstance) -> [String: Any] {
        var flags: [String: Any] = [
            "DFIntTaskSchedulerTargetFps": slot.fps == .unlimited ? 999 : slot.fps.rawValue,
            "FFlagHandleAltEnterFullscreenManually": "True",
            "FFlagDebugGraphicsPreferMetal": "True"
        ]

        switch slot.graphics {
        case .min:
            flags["DFIntTextureQualityOverrideEnabled"] = "True"
            flags["DFIntTextureQualityOverride"] = 1
            flags["FFlagDisablePostFx"] = "True"
            flags["FIntRenderShadowIntensity"] = 0
            flags["FIntDebugForceMSAASamples"] = 0
            flags["DFIntDebugFRMQualityLevelOverride"] = 1
        case .mid:
            flags["DFIntTextureQualityOverrideEnabled"] = "True"
            flags["DFIntTextureQualityOverride"] = 2
            flags["FFlagDisablePostFx"] = "False"
            flags["FIntRenderShadowIntensity"] = 1
            flags["DFIntDebugFRMQualityLevelOverride"] = 10
        case .max:
            flags["DFIntTextureQualityOverrideEnabled"] = "False"
            flags["FFlagDisablePostFx"] = "False"
            flags["FIntRenderShadowIntensity"] = 1
            flags["DFIntDebugFRMQualityLevelOverride"] = 21
        }

        if slot.killBackgroundRendering {
            flags["FFlagDebugGraphicsDisableUnfocusedRendering"] = "True"
        }

        switch slot.fontStyle {
        case .productSans:
            flags["FStringDebugOverrideUIFont"] = "ProductSans"
        case .builderSans:
            flags["FStringDebugOverrideUIFont"] = "BuilderSans"
        case .gotham:
            flags["FStringDebugOverrideUIFont"] = "GothamSSm"
        }

        return flags
    }
}
