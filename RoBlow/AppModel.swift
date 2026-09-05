import AppKit
import SwiftUI

enum AppMenu: String, CaseIterable, Identifiable {
    case file, edit, window, view, settings, help

    var id: String { rawValue }

    var title: String {
        switch self {
        case .file: "File"
        case .edit: "Edit"
        case .window: "Window"
        case .view: "View"
        case .settings: "Settings"
        case .help: "Help"
        }
    }

    var isLeading: Bool {
        switch self {
        case .file, .edit, .window: true
        case .view, .settings, .help: false
        }
    }
}

enum SidebarItem: Hashable, Identifiable {
    case home
    case mods
    case instance(UUID)
    case newUI(UUID)
    case document(AppDocument.ID)

    var id: String {
        switch self {
        case .home: "home"
        case .mods: "mods"
        case .instance(let id): "instance-\(id.uuidString)"
        case .newUI(let id): "newui-\(id.uuidString)"
        case .document(let id): id.uuidString
        }
    }
}

struct AppDocument: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var body: String
}

@MainActor
@Observable
final class AppModel {
    var isSidebarVisible = true
    var isGlassExpanded = false
    var openMenu: AppMenu?
    var documents: [AppDocument] = []
    var selectedDocumentID: AppDocument.ID?
    var selectedSidebarItem: SidebarItem = .home
    var showSettings = false
    var showAbout = false
    var statusMessage: String?
    var hostWindow: NSWindow?
    var home = HomeBoard()
    var instances = InstanceManager()
    var search = SearchBoard()
    var searchOverlayInstanceID: UUID?
    var newUIPage: NewUIPage = .home
    var newUIDestination: URL? = NewUIPage.home.siteURL
    var openNewUIInstanceIDs: Set<UUID> = []
    var term = QuickTerm()
    var webMods = WebModLibrary.shared
    var webViewEpoch = 0
    var showWebModStore = false
    var webModStoreQuery: String?
    var webModStoreInstanceID: UUID?

    init() {
        instances.load()
    }

    func openWebModStore(for slot: GameInstance? = nil, query: String? = nil) {
        webModStoreInstanceID = slot?.id
            ?? newUIInstanceID
            ?? instances.editingModInstanceID
            ?? selectedInstance?.id
        webModStoreQuery = query
        showWebModStore = true
        term.close()
    }

    func closeWebModStore() {
        showWebModStore = false
        webModStoreQuery = nil
    }

    func reloadNewUI() {
        webViewEpoch += 1
    }

    func launchInstance(_ slot: GameInstance) async {
        instances.writeClientSettings(for: slot)
        showRobloxBrowser(for: slot)
        closeExtraWindows()
        setStatus("Opened New UI for \(slot.name)")
    }

    func openNewUIPage(_ page: NewUIPage) {
        newUIPage = page
        if page != .search, let url = page.siteURL {
            newUIDestination = url
        }
    }

    func openNewUISite(_ url: URL) {
        newUIPage = .home
        newUIDestination = url
        if let id = newUIInstanceID {
            selectedSidebarItem = .newUI(id)
        }
    }

    func openNewUIGamePage(placeID: String) {
        newUIPage = .home
        newUIDestination = URL(string: "https://www.roblox.com/games/\(placeID)")
        if let id = newUIInstanceID {
            selectedSidebarItem = .newUI(id)
        }
    }

    func handleRobloxWebPlay(_ url: URL) {
        Task { await playFromNewUI(url) }
    }

    func playPlace(_ placeID: String, title: String? = nil) async {
        guard let slot = newUISlot ?? selectedInstance ?? instances.slots.first else {
            await home.launchExperience(placeID: placeID)
            setStatus("Launching \(title ?? placeID)")
            return
        }
        let message = await instances.launch(slot, account: account(for: slot), placeID: placeID)
        setStatus(title.map { "Launching \($0)" } ?? message)
    }

    func playFromNewUI(_ url: URL) async {
        if let placeID = placeID(fromWebPlay: url) {
            await playPlace(placeID)
            return
        }
        if url.scheme?.lowercased().hasPrefix("roblox") == true {
            if let slot = newUISlot ?? selectedInstance {
                instances.writeClientSettings(for: slot)
                let message = await instances.launch(slot, account: account(for: slot), playerURL: url)
                setStatus(message)
                return
            }
            NSWorkspace.shared.open(url)
            setStatus("Launching")
        }
    }

    func showRobloxBrowser(for slot: GameInstance) {
        searchOverlayInstanceID = slot.id
        newUIPage = .home
        newUIDestination = NewUIPage.home.siteURL
        openNewUIInstanceIDs.insert(slot.id)
        selectedSidebarItem = .newUI(slot.id)
        closeExtraWindows()
    }

    func dismissNewUI(for id: UUID? = nil) {
        let target = id ?? newUIInstanceID
        guard let target else { return }
        openNewUIInstanceIDs.remove(target)
        if case .newUI(let selected) = selectedSidebarItem, selected == target {
            selectedSidebarItem = .instance(target)
        }
    }

    func closeExtraWindows() {
        for window in NSApp.windows {
            if window === hostWindow { continue }
            if window.identifier?.rawValue == "main" { continue }
            if window.level != .normal { continue }
            window.close()
        }
    }

    var newUIInstanceID: UUID? {
        if case .newUI(let id) = selectedSidebarItem { return id }
        return searchOverlayInstanceID
    }

    var newUISlot: GameInstance? {
        newUIInstanceID.flatMap { instances.instance(for: $0) }
    }

    private func placeID(fromWebPlay url: URL) -> String? {
        let raw = url.absoluteString
        let decoded = raw.removingPercentEncoding ?? raw
        for text in [raw, decoded] {
            for key in ["placeId=", "placeid=", "placeID="] {
                if let range = text.range(of: key, options: .caseInsensitive) {
                    let digits = text[range.upperBound...].prefix(while: \.isNumber)
                    if !digits.isEmpty { return String(digits) }
                }
            }
            if let regex = try? NSRegularExpression(pattern: #"/games/(\d+)"#),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }
        return nil
    }

    func publishClientSettings(for slot: GameInstance? = nil) {
        let target = slot
            ?? instances.editingModInstanceID.flatMap { instances.instance(for: $0) }
            ?? selectedInstance
            ?? instances.slots.first
        guard let target else { return }
        instances.writeClientSettings(for: target)
    }

    var selectedInstance: GameInstance? {
        switch selectedSidebarItem {
        case .instance(let id), .newUI(let id):
            return instances.instance(for: id)
        default:
            return nil
        }
    }

    var selectedDocument: AppDocument? {
        documents.first(where: { $0.id == selectedDocumentID })
    }

    var selectedDocumentBinding: Binding<AppDocument>? {
        guard let index = documents.firstIndex(where: { $0.id == selectedDocumentID }) else {
            return nil
        }
        return Binding(
            get: { self.documents[index] },
            set: { self.documents[index] = $0 }
        )
    }

    func toggleSidebar() {
        withAnimation(.spring(duration: 0.38, bounce: 0.12)) {
            isSidebarVisible.toggle()
        }
        dismissMenus()
    }

    func toggleGlassExpanded() {
        withAnimation(.spring(duration: 0.45, bounce: 0.08)) {
            isGlassExpanded.toggle()
        }
        hostWindow?.zoom(nil)
        dismissMenus()
    }

    func closeApp() {
        hostWindow?.close()
    }

    func minimizeApp() {
        hostWindow?.miniaturize(nil)
        dismissMenus()
    }

    func createInstance() {
        let created = instances.createInstance()
        selectedSidebarItem = .instance(created.id)
        if !isSidebarVisible {
            toggleSidebar()
        }
        setStatus("Created \(created.name)")
        dismissMenus()
    }

    func createDocument() {
        createInstance()
    }

    func deleteInstance(_ id: UUID) {
        let remaining = instances.slots.filter { $0.id != id }
        instances.deleteInstance(id)
        openNewUIInstanceIDs.remove(id)
        switch selectedSidebarItem {
        case .instance(let selected), .newUI(let selected):
            if selected == id {
                selectedSidebarItem = remaining.first.map { .instance($0.id) } ?? .home
            }
        default:
            break
        }
        setStatus("Removed instance")
    }

    func account(for slot: GameInstance) -> AccountProfile {
        if let id = slot.accountID, let match = home.accounts.first(where: { $0.id == id }) {
            return match
        }
        return home.activeAccount
    }

    func updateSelectedDocument(_ document: AppDocument) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        documents[index] = document
    }

    func selectDocument(_ id: AppDocument.ID) {
        selectedDocumentID = id
        selectedSidebarItem = .document(id)
    }

    func selectSidebarItem(_ item: SidebarItem) {
        selectedSidebarItem = item
        if case .instance(let id) = item {
            instances.editingModInstanceID = id
        }
        if case .newUI(let id) = item {
            instances.editingModInstanceID = id
            searchOverlayInstanceID = id
        }
        if case .document(let id) = item {
            selectedDocumentID = id
        }
        dismissMenus()
    }

    func performEdit(_ action: String) {
        setStatus(action)
        dismissMenus()
    }

    func openSettings() {
        showAbout = false
        showSettings = true
        dismissMenus()
    }

    func openAbout() {
        showSettings = false
        showAbout = true
        dismissMenus()
    }

    func dismissOverlays() {
        showSettings = false
        showAbout = false
        dismissMenus()
    }

    func dismissMenus() {
        openMenu = nil
    }

    func toggleMenu(_ menu: AppMenu) {
        openMenu = openMenu == menu ? nil : menu
    }

    func setStatus(_ message: String) {
        statusMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            if statusMessage == message {
                statusMessage = nil
            }
        }
    }
}
