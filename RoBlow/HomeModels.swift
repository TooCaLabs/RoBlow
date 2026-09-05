import AppKit
import Darwin
import SwiftUI

struct GridSize: Hashable, Codable {
    var columns: Int
    var rows: Int

    var label: String { "\(columns):\(rows)" }

    static let oneByOne = GridSize(columns: 1, rows: 1)
    static let twoByOne = GridSize(columns: 2, rows: 1)
    static let oneByTwo = GridSize(columns: 1, rows: 2)
    static let twoByTwo = GridSize(columns: 2, rows: 2)
    static let threeByOne = GridSize(columns: 3, rows: 1)
    static let fourByOne = GridSize(columns: 4, rows: 1)
    static let fourByTwo = GridSize(columns: 4, rows: 2)
}

enum WidgetKind: String, CaseIterable, Codable, Identifiable {
    case quickLaunch
    case recentGames
    case pinnedFavorites
    case privateServers
    case instanceStatus
    case accountSwitcher
    case playtime
    case hardware
    case platformStatus
    case fastFlag
    case newsFeed
    case patchNotes
    case separator
    case subtitle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quickLaunch: "Quick launch card"
        case .recentGames: "Recent games carousel"
        case .pinnedFavorites: "Pinned favorites grid"
        case .privateServers: "Private server shortcuts"
        case .instanceStatus: "Multi-instance status center"
        case .accountSwitcher: "Account switcher quick-list"
        case .playtime: "Playtime analytics"
        case .hardware: "Hardware resource monitor"
        case .platformStatus: "Roblox platform status"
        case .fastFlag: "FastFlag profile overview"
        case .newsFeed: "Global news feed"
        case .patchNotes: "RoBlow patch notes"
        case .separator: "Separator"
        case .subtitle: "Subtitle"
        }
    }

    var isLayoutItem: Bool {
        self == .separator || self == .subtitle
    }

    var defaultSize: GridSize {
        switch self {
        case .recentGames: .fourByOne
        case .pinnedFavorites: .twoByTwo
        case .privateServers: .twoByOne
        case .instanceStatus: .twoByTwo
        case .accountSwitcher: .oneByTwo
        case .playtime: .twoByOne
        case .fastFlag: .twoByOne
        case .newsFeed: .twoByTwo
        case .patchNotes: .oneByTwo
        case .separator, .subtitle: .fourByOne
        default: .oneByOne
        }
    }

    var allowedSizes: [GridSize] {
        switch self {
        case .quickLaunch: [.oneByOne, .twoByOne]
        case .recentGames: [.threeByOne, .fourByTwo]
        case .pinnedFavorites: [.twoByTwo]
        case .privateServers: [.twoByOne]
        case .instanceStatus: [.twoByTwo]
        case .accountSwitcher: [.oneByTwo]
        case .playtime: [.twoByOne]
        case .hardware: [.oneByOne, .twoByOne]
        case .platformStatus: [.oneByOne]
        case .fastFlag: [.twoByOne]
        case .newsFeed: [.twoByTwo]
        case .patchNotes: [.oneByTwo]
        case .separator, .subtitle: [.fourByOne]
        }
    }

    var contentNote: String {
        switch self {
        case .quickLaunch: "Large game artwork, title, and a central play button."
        case .recentGames: "Thumbnails for the last 4–6 played experiences."
        case .pinnedFavorites: "A 2×2 grid of pinned game shortcuts."
        case .privateServers: "Named private-server links."
        case .instanceStatus: "Active slots, usernames, uptime, and window icons."
        case .accountSwitcher: "Logged-in profiles with avatars and display names."
        case .playtime: "Daily or weekly session hours as a line graph."
        case .hardware: "CPU, RAM, and GPU gauges with sparklines."
        case .platformStatus: "Color-coded status and live connection text."
        case .fastFlag: "FPS cap, rendering mode, and texture scale."
        case .newsFeed: "Headlines, dates, and preview tiles from official blogs."
        case .patchNotes: "Version, changelog, and active bugs."
        case .separator: "A divider line across the grid."
        case .subtitle: "A section heading you can rename."
        }
    }

    var featureNote: String {
        switch self {
        case .quickLaunch: "Each card keeps its own game. Add more than one."
        case .recentGames: "Hover to see which account last opened each game."
        case .pinnedFavorites: "Drag slots to organize daily farming games."
        case .privateServers: "Opens a specific private-server link ID."
        case .instanceStatus: "Close all instances or focus a window."
        case .accountSwitcher: "Sets the default launch target."
        case .playtime: "Filter combined hours or a single alt."
        case .hardware: "Glows red when multi-instance load is high."
        case .platformStatus: "Pings Roblox endpoints for outages."
        case .fastFlag: "Clear cache or swap low-spec / high-spec."
        case .newsFeed: "Opens the source link in a browser."
        case .patchNotes: "Shows an Update Available badge for new builds."
        case .separator: "Stretch it across a row to split groups."
        case .subtitle: "Edit the label in customize mode."
        }
    }
}

struct WidgetPlacement: Identifiable, Hashable, Codable {
    var id: UUID
    var kind: WidgetKind
    var size: GridSize
    var column: Int
    var row: Int
    var title: String?
    var refID: String?

    init(
        id: UUID = UUID(),
        kind: WidgetKind,
        size: GridSize,
        column: Int,
        row: Int,
        title: String? = nil,
        refID: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.size = size
        self.column = column
        self.row = row
        self.title = title
        self.refID = refID
    }

    var cells: Set<GridCell> {
        var result: Set<GridCell> = []
        for columnOffset in 0..<size.columns {
            for rowOffset in 0..<size.rows {
                result.insert(GridCell(column: column + columnOffset, row: row + rowOffset))
            }
        }
        return result
    }
}

struct GridCell: Hashable {
    var column: Int
    var row: Int
}

struct WidgetDragSession {
    var id: UUID
    var start: WidgetPlacement
    var startLocation: CGPoint
    var startFrame: CGRect
    var isResizing: Bool
}

struct DemoGame: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var placeID: String
    var hue: Double
    var thumbnailURL: String?
    var lastPlayedBy: String?
}

struct AccountProfile: Identifiable, Hashable, Codable {
    var id: UUID
    var userID: Int
    var displayName: String
    var username: String
    var initials: String
    var hue: Double
    var avatarURL: String?

    static let unsigned = AccountProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        userID: 0,
        displayName: "Not signed in",
        username: "none",
        initials: "?",
        hue: 0.62
    )

    init(
        id: UUID = UUID(),
        userID: Int,
        displayName: String,
        username: String,
        initials: String,
        hue: Double,
        avatarURL: String? = nil
    ) {
        self.id = id
        self.userID = userID
        self.displayName = displayName
        self.username = username
        self.initials = initials
        self.hue = hue
        self.avatarURL = avatarURL
    }

    var isSignedIn: Bool { userID != 0 }
}

struct RunningInstance: Identifiable, Hashable {
    var id: UUID
    var slot: Int
    var account: AccountProfile
    var gameTitle: String
    var startedAt: Date
    var processID: pid_t?
}

struct PrivateServerLink: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var placeID: String
    var linkCode: String
}

struct NewsItem: Identifiable, Hashable {
    var id: UUID
    var title: String
    var date: String
    var source: String
    var url: URL
    var hue: Double
}

enum FastFlagSpec: String, CaseIterable, Codable {
    case low = "Low spec"
    case high = "High spec"
}

enum PlaytimeScope: String, CaseIterable, Identifiable {
    case combined
    case account

    var id: String { rawValue }

    var title: String {
        switch self {
        case .combined: "Combined"
        case .account: "Account"
        }
    }
}

@MainActor
@Observable
final class HomeBoard {
    static let columns = 4
    static let persistenceKey = "roblox.home.placements"
    static let accountsKey = "roblox.accounts.profiles"
    static let activeAccountKey = "roblox.accounts.active"
    static let pinsKey = "roblox.home.pins"
    static let serversKey = "roblox.home.servers"
    static let recentsKey = "roblox.home.recents"
    static let playtimeKey = "roblox.home.playtime"
    static let quickLaunchKey = "roblox.home.quickLaunch"
    static let flagsKey = "roblox.home.fastflags"
    static let separatorRowHeight: CGFloat = 28
    static let subtitleRowHeight: CGFloat = 36

    var isEditing = false
    var showCatalog = false
    var showAddAccount = false
    var showAddServer = false
    var draftServerName = ""
    var draftServerPlace = ""
    var draftServerCode = ""
    var isRefreshingLibrary = false
    private var playtimeSaveCounter = 0
    var placements: [WidgetPlacement] = []
    var pendingOrigin: GridCell?
    var isInteracting = false
    var dragSession: WidgetDragSession?
    var editingSubtitleID: WidgetPlacement.ID?
    var dragHasMoved = false

    var accounts: [AccountProfile]
    var activeAccountID: UUID
    var games: [DemoGame]
    var recentGames: [DemoGame]
    var pinnedIDs: [String]
    var privateServers: [PrivateServerLink]
    var instances: [RunningInstance]
    var playtimeScope: PlaytimeScope = .combined
    var playtimeAccountID: UUID
    var weeklyHours: [String: [Double]]
    var fastFlagSpec: FastFlagSpec = .high
    var fpsCap = 240
    var renderingMode = "Future"
    var textureScale = "1x"
    var updateAvailable = false
    var quickLaunchID: String?
    var platformStatusText = "Checking Roblox…"
    var platformHealthy = true
    var platformChecked = false
    var cpuLoad = 0.28
    var ramLoad = 0.41
    var gpuLoad = 0.33
    var cpuHistory: [Double] = Array(repeating: 0.28, count: 18)
    var ramHistory: [Double] = Array(repeating: 0.41, count: 18)
    var gpuHistory: [Double] = Array(repeating: 0.33, count: 18)

    var news: [NewsItem] = []
    var newsFailed = false
    var patchVersion: String {
        RoBlowVersion.displayed
    }
    let changelog = [
        "Real Roblox account sign-in and instance launch",
        "Multiple instances with per-slot accounts",
        "Home widgets use live Roblox data"
    ]
    let knownBugs = [
        "GPU load is estimated from CPU and running instances",
        "Playtime is tracked while RoBlow is open"
    ]

    var activeAccount: AccountProfile {
        accounts.first(where: { $0.id == activeAccountID }) ?? accounts.first ?? .unsigned
    }

    var isBottlenecked: Bool {
        cpuLoad > 0.82 || ramLoad > 0.86
    }

    var occupied: Set<GridCell> {
        Set(placements.flatMap(\.cells))
    }

    var rowCount: Int {
        let used = placements.map { $0.row + $0.size.rows }.max() ?? 0
        return max(used, isEditing ? used + 2 : used)
    }

    init() {
        self.accounts = []
        self.activeAccountID = AccountProfile.unsigned.id
        self.playtimeAccountID = AccountProfile.unsigned.id
        self.games = []
        self.recentGames = []
        self.pinnedIDs = []
        self.privateServers = []
        self.instances = []
        self.weeklyHours = ["combined": Array(repeating: 0, count: 7)]
        load()
        loadAccounts()
        loadLibrary()
        normalizeLayoutItems()
        migrateQuickLaunchBindings()
        expandUndersizedWidgets()
        Task {
            await importPlayerSessionIfNeeded()
            await refreshLibrary()
            await refreshNews()
        }
    }

    func upsertAccount(_ profile: AccountProfile, cookie: String) {
        RobloxSecrets.setCookie(cookie, for: profile.userID)
        if let index = accounts.firstIndex(where: { $0.userID == profile.userID }) {
            var updated = profile
            updated.id = accounts[index].id
            accounts[index] = updated
            activeAccountID = updated.id
        } else {
            accounts.append(profile)
            activeAccountID = profile.id
        }
        playtimeAccountID = activeAccountID
        saveAccounts()
        Task { await refreshLibrary() }
    }

    func selectAccount(_ id: AccountProfile.ID) {
        activeAccountID = id
        playtimeAccountID = id
        saveAccounts()
        Task { await refreshLibrary() }
    }

    func removeAccount(_ id: AccountProfile.ID) {
        if let account = accounts.first(where: { $0.id == id }) {
            RobloxSecrets.deleteCookie(for: account.userID)
        }
        accounts.removeAll { $0.id == id }
        if activeAccountID == id {
            activeAccountID = accounts.first?.id ?? AccountProfile.unsigned.id
        }
        saveAccounts()
    }

    func importPlayerSessionIfNeeded() async {
        guard accounts.isEmpty, let cookie = RobloxSecrets.cookieFromPlayerInstall() else { return }
        do {
            let profile = try await RobloxAuth.profile(from: cookie)
            upsertAccount(profile, cookie: cookie)
        } catch {
            return
        }
    }

    func beginEditing() {
        isEditing = true
    }

    func finishEditing() {
        isEditing = false
        showCatalog = false
        pendingOrigin = nil
        editingSubtitleID = nil
        endDrag()
        for placement in placements {
            snapPlacement(placement.id)
        }
        save()
    }

    func openCatalog(at cell: GridCell? = nil) {
        pendingOrigin = cell
        showCatalog = true
    }

    func addWidget(kind: WidgetKind) {
        if kind == .separator {
            addSeparator()
            return
        }
        if kind == .subtitle {
            addSubtitle()
            return
        }
        let size = kind.defaultSize
        let origin = pendingOrigin.flatMap { cell in
            canPlace(size: size, column: cell.column, row: cell.row) ? cell : nil
        }
        guard let spot = origin ?? firstFit(for: size) else { return }
        var placement = WidgetPlacement(kind: kind, size: size, column: spot.column, row: spot.row)
        if kind == .quickLaunch {
            placement.refID = nextUnusedQuickLaunchID()
        }
        placements.append(placement)
        showCatalog = false
        pendingOrigin = nil
    }

    func addSeparator() {
        addLayoutItem(kind: .separator)
    }

    func addSubtitle() {
        addLayoutItem(kind: .subtitle, title: "Subtitle")
        if let id = placements.last(where: { $0.kind == .subtitle })?.id {
            editingSubtitleID = id
        }
    }

    private func addLayoutItem(kind: WidgetKind, title: String? = nil) {
        let size = GridSize.fourByOne
        guard let spot = firstFit(for: size) else { return }
        placements.append(WidgetPlacement(kind: kind, size: size, column: 0, row: spot.row, title: title))
    }

    func beginDrag(_ session: WidgetDragSession) {
        if dragSession == nil {
            dragSession = session
            dragHasMoved = false
        }
        isInteracting = true
        if editingSubtitleID != session.id {
            editingSubtitleID = nil
        }
    }

    func endDrag() {
        if let session = dragSession {
            if session.start.kind == .subtitle, !dragHasMoved {
                editingSubtitleID = session.id
            }
            if dragHasMoved {
                snapPlacement(session.id)
            }
        }
        dragSession = nil
        dragHasMoved = false
        isInteracting = false
    }

    func moveWidget(_ id: WidgetPlacement.ID, column: Int, row: Int) {
        guard let index = placements.firstIndex(where: { $0.id == id }) else { return }
        if placements[index].kind.isLayoutItem {
            placements[index].column = 0
            placements[index].size = .fourByOne
            placements[index].row = max(0, row)
            return
        }
        let size = placements[index].size
        placements[index].column = max(0, min(column, HomeBoard.columns - size.columns))
        placements[index].row = max(0, row)
    }

    func resizeWidget(_ id: WidgetPlacement.ID, columns: Int, rows: Int, column: Int, row: Int) {
        guard let index = placements.firstIndex(where: { $0.id == id }) else { return }
        if placements[index].kind.isLayoutItem { return }
        let nextColumn = max(0, column)
        let nextRow = max(0, row)
        let nextColumns = min(max(1, columns), HomeBoard.columns - nextColumn)
        let nextRows = max(1, min(8, rows))
        placements[index].size = GridSize(columns: nextColumns, rows: nextRows)
        placements[index].column = nextColumn
        placements[index].row = nextRow
    }

    func rowHeight(_ row: Int, cellSize: CGFloat, ignoring id: WidgetPlacement.ID? = nil) -> CGFloat {
        let occupants = placements.filter { placement in
            placement.id != id && placement.row <= row && placement.row + placement.size.rows > row
        }
        if occupants.contains(where: { $0.kind == .separator }) {
            return HomeBoard.separatorRowHeight
        }
        if occupants.contains(where: { $0.kind == .subtitle }) {
            return HomeBoard.subtitleRowHeight
        }
        return cellSize
    }

    func yOrigin(forRow row: Int, cellSize: CGFloat, spacing: CGFloat, ignoring id: WidgetPlacement.ID? = nil) -> CGFloat {
        guard row > 0 else { return 0 }
        var y: CGFloat = 0
        for index in 0..<row {
            y += rowHeight(index, cellSize: cellSize, ignoring: id) + spacing
        }
        return y
    }

    func measuredHeight(cellSize: CGFloat, spacing: CGFloat) -> CGFloat {
        let rows = max(rowCount, placements.isEmpty ? 2 : 1)
        guard rows > 0 else { return 0 }
        return yOrigin(forRow: rows, cellSize: cellSize, spacing: spacing)
    }

    func frame(for placement: WidgetPlacement, cellSize: CGFloat, spacing: CGFloat) -> CGRect {
        let x = CGFloat(placement.column) * (cellSize + spacing)
        let y = yOrigin(forRow: placement.row, cellSize: cellSize, spacing: spacing)

        if placement.kind.isLayoutItem {
            let width = cellSize * CGFloat(HomeBoard.columns) + spacing * CGFloat(HomeBoard.columns - 1)
            let height = placement.kind == .subtitle ? HomeBoard.subtitleRowHeight : HomeBoard.separatorRowHeight
            return CGRect(x: 0, y: y, width: width, height: height)
        }

        let width = cellSize * CGFloat(placement.size.columns) + spacing * CGFloat(max(placement.size.columns - 1, 0))
        var height: CGFloat = 0
        for offset in 0..<placement.size.rows {
            if offset > 0 { height += spacing }
            height += rowHeight(placement.row + offset, cellSize: cellSize)
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    func placement(at point: CGPoint, cellSize: CGFloat, spacing: CGFloat) -> WidgetPlacement? {
        let ordered = placements.reversed()
        return ordered.first { frame(for: $0, cellSize: cellSize, spacing: spacing).contains(point) }
    }

    func handlePress(at point: CGPoint, cellSize: CGFloat, spacing: CGFloat) {
        guard let target = placement(at: point, cellSize: cellSize, spacing: spacing) else { return }
        let rect = frame(for: target, cellSize: cellSize, spacing: spacing)
        let local = CGPoint(x: point.x - rect.minX, y: point.y - rect.minY)

        if local.x <= 44 && local.y <= 44 {
            removeWidget(target.id)
            return
        }

        let resizing = !target.kind.isLayoutItem
            && local.x >= rect.width - 40
            && local.y >= rect.height - 40

        beginDrag(
            WidgetDragSession(
                id: target.id,
                start: target,
                startLocation: point,
                startFrame: rect,
                isResizing: resizing
            )
        )
    }

    func handleDrag(at point: CGPoint, cellSize: CGFloat, spacing: CGFloat) {
        guard let session = dragSession else { return }
        let origin = CGPoint(
            x: session.startFrame.minX + (point.x - session.startLocation.x),
            y: session.startFrame.minY + (point.y - session.startLocation.y)
        )

        if hypot(point.x - session.startLocation.x, point.y - session.startLocation.y) > 6 {
            dragHasMoved = true
        }

        if session.isResizing {
            let stride = max(cellSize + spacing, 1)
            let deltaColumns = Int(((point.x - session.startLocation.x) / stride).rounded())
            let deltaRows = Int(((point.y - session.startLocation.y) / stride).rounded())
            resizeWidget(
                session.id,
                columns: session.start.size.columns + deltaColumns,
                rows: session.start.size.rows + deltaRows,
                column: session.start.column,
                row: session.start.row
            )
            return
        }

        if session.start.kind.isLayoutItem {
            moveWidget(session.id, column: 0, row: rowIndex(atY: origin.y, cellSize: cellSize, spacing: spacing))
            return
        }

        moveWidget(
            session.id,
            column: columnIndex(atX: origin.x, cellSize: cellSize, spacing: spacing),
            row: rowIndex(atY: origin.y, cellSize: cellSize, spacing: spacing)
        )
    }

    func columnIndex(atX x: CGFloat, cellSize: CGFloat, spacing: CGFloat) -> Int {
        let stride = max(cellSize + spacing, 1)
        return max(0, min(Int((x / stride).rounded()), HomeBoard.columns - 1))
    }

    func rowIndex(atY y: CGFloat, cellSize: CGFloat, spacing: CGFloat) -> Int {
        let limit = max(rowCount + 6, 8)
        var closest = 0
        var closestDistance = CGFloat.greatestFiniteMagnitude
        for row in 0..<limit {
            let top = yOrigin(forRow: row, cellSize: cellSize, spacing: spacing)
            let height = rowHeight(row, cellSize: cellSize)
            let center = top + height / 2
            let distance = abs(y - center)
            if distance < closestDistance {
                closestDistance = distance
                closest = row
            }
        }
        return closest
    }

    func expandUndersizedWidgets() {
        for index in placements.indices {
            let kind = placements[index].kind
            guard !kind.isLayoutItem else { continue }
            let minimum = kind.defaultSize
            let current = placements[index].size
            if current.columns >= minimum.columns && current.rows >= minimum.rows {
                continue
            }
            let id = placements[index].id
            if canPlace(size: minimum, column: placements[index].column, row: placements[index].row, ignoring: id) {
                placements[index].size = minimum
            } else if let spot = nearestFit(for: minimum, column: placements[index].column, row: placements[index].row, ignoring: id) {
                placements[index].size = minimum
                placements[index].column = spot.column
                placements[index].row = spot.row
            }
        }
    }

    func migrateQuickLaunchBindings() {
        var used = Set(quickLaunchCards.compactMap(\.refID))
        if let quickLaunchID, used.isEmpty {
            if let index = placements.firstIndex(where: { $0.kind == .quickLaunch }) {
                placements[index].refID = quickLaunchID
                used.insert(quickLaunchID)
            }
        }
        for index in placements.indices where placements[index].kind == .quickLaunch && placements[index].refID == nil {
            if let next = recentGames.first(where: { !used.contains($0.id) })?.id
                ?? games.first(where: { !used.contains($0.id) })?.id {
                placements[index].refID = next
                used.insert(next)
            }
        }
    }

    func normalizeLayoutItems() {
        for index in placements.indices where placements[index].kind.isLayoutItem {
            placements[index].size = .fourByOne
            placements[index].column = 0
            if !canPlace(size: .fourByOne, column: 0, row: placements[index].row, ignoring: placements[index].id),
               let spot = firstFit(for: .fourByOne, ignoring: placements[index].id) {
                placements[index].row = spot.row
            }
        }
    }

    func updateTitle(_ id: WidgetPlacement.ID, _ title: String) {
        guard let index = placements.firstIndex(where: { $0.id == id }) else { return }
        placements[index].title = title
    }

    func removeWidget(_ id: WidgetPlacement.ID) {
        if editingSubtitleID == id {
            editingSubtitleID = nil
        }
        placements.removeAll { $0.id == id }
        save()
    }

    func game(id: String) -> DemoGame? {
        games.first { $0.id == id } ?? recentGames.first { $0.id == id }
    }

    var quickLaunchCards: [WidgetPlacement] {
        placements.filter { $0.kind == .quickLaunch }
    }

    var quickLaunchGame: DemoGame? {
        if let id = quickLaunchID, let game = game(id: id) { return game }
        return recentGames.first ?? games.first
    }

    func game(for placement: WidgetPlacement) -> DemoGame? {
        if let id = placement.refID, let match = game(id: id) {
            return match
        }
        if placement.kind == .quickLaunch {
            return quickLaunchGame
        }
        return nil
    }

    func quickLaunchLabel(for placement: WidgetPlacement) -> String {
        game(for: placement)?.title ?? "Empty card"
    }

    func nextUnusedQuickLaunchID() -> String? {
        let used = Set(quickLaunchCards.compactMap(\.refID))
        return recentGames.first(where: { !used.contains($0.id) })?.id
            ?? games.first(where: { !used.contains($0.id) })?.id
            ?? pinnedIDs.first(where: { !used.contains($0) })
    }

    func setPinned(_ ids: [String]) {
        pinnedIDs = Array(ids.prefix(4))
        saveLibrary()
    }

    func pin(_ game: DemoGame) {
        mergeGame(game)
        var ids = pinnedIDs.filter { $0 != game.id }
        ids.insert(game.id, at: 0)
        setPinned(ids)
    }

    func unpin(_ id: String) {
        setPinned(pinnedIDs.filter { $0 != id })
    }

    func setQuickLaunch(_ game: DemoGame, for id: WidgetPlacement.ID? = nil) {
        mergeGame(game)
        quickLaunchID = game.id
        let target = id ?? quickLaunchCards.first?.id
        if let target, let index = placements.firstIndex(where: { $0.id == target }) {
            placements[index].refID = game.id
            save()
        }
        saveLibrary()
    }

    func snapPlacement(_ id: WidgetPlacement.ID) {
        guard let index = placements.firstIndex(where: { $0.id == id }) else { return }
        var placement = placements[index]
        if placement.kind.isLayoutItem {
            placement.column = 0
            placement.size = .fourByOne
            placement.row = max(0, placement.row)
            if !canPlace(size: placement.size, column: 0, row: placement.row, ignoring: id),
               let spot = nearestFit(for: placement.size, column: 0, row: placement.row, ignoring: id) {
                placement.row = spot.row
            }
            placements[index] = placement
            return
        }

        placement.column = max(0, min(placement.column, HomeBoard.columns - placement.size.columns))
        placement.row = max(0, placement.row)
        placement.size.columns = min(placement.size.columns, HomeBoard.columns - placement.column)
        placement.size.rows = max(1, placement.size.rows)
        if !canPlace(size: placement.size, column: placement.column, row: placement.row, ignoring: id),
           let spot = nearestFit(for: placement.size, column: placement.column, row: placement.row, ignoring: id) {
            placement.column = spot.column
            placement.row = spot.row
        }
        placements[index] = placement
    }

    func nearestFit(for size: GridSize, column: Int, row: Int, ignoring id: WidgetPlacement.ID? = nil) -> GridCell? {
        if canPlace(size: size, column: column, row: row, ignoring: id) {
            return GridCell(column: column, row: row)
        }
        let rows = max(rowCount, row) + size.rows + 2
        var best: GridCell?
        var bestDistance = Int.max
        for nextRow in 0..<rows {
            for nextColumn in 0...(HomeBoard.columns - size.columns) {
                guard canPlace(size: size, column: nextColumn, row: nextRow, ignoring: id) else { continue }
                let distance = abs(nextColumn - column) + abs(nextRow - row)
                if distance < bestDistance {
                    bestDistance = distance
                    best = GridCell(column: nextColumn, row: nextRow)
                }
            }
        }
        return best ?? firstFit(for: size, ignoring: id)
    }

    func addPrivateServer() {
        let place = draftServerPlace.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = draftServerCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = draftServerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !place.isEmpty, !code.isEmpty else { return }
        privateServers.append(
            PrivateServerLink(
                id: UUID(),
                name: name.isEmpty ? "Private server" : name,
                placeID: place,
                linkCode: code
            )
        )
        draftServerName = ""
        draftServerPlace = ""
        draftServerCode = ""
        showAddServer = false
        saveLibrary()
        Task {
            let cookie = RobloxSecrets.cookie(for: activeAccount.userID)
            if let game = await RobloxLibrary.placeDetails(placeID: place, cookie: cookie) {
                mergeGame(game)
            }
        }
    }

    func removePrivateServer(_ id: PrivateServerLink.ID) {
        privateServers.removeAll { $0.id == id }
        saveLibrary()
    }

    func launch(_ game: DemoGame) {
        Task { await launchExperience(placeID: game.placeID) }
        rememberRecent(game)
    }

    func launchPlaceID(_ placeID: String, for placementID: WidgetPlacement.ID? = nil) {
        let trimmed = placeID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            let cookie = RobloxSecrets.cookie(for: activeAccount.userID)
            let game = await RobloxLibrary.placeDetails(placeID: trimmed, cookie: cookie)
                ?? DemoGame(id: trimmed, title: "Place \(trimmed)", placeID: trimmed, hue: 0.58)
            setQuickLaunch(game, for: placementID)
            launch(game)
        }
    }

    func launch(server: PrivateServerLink) {
        Task { await launchExperience(placeID: server.placeID, linkCode: server.linkCode) }
    }

    func launchExperience(placeID: String, linkCode: String? = nil) async {
        if activeAccount.isSignedIn, let cookie = RobloxSecrets.cookie(for: activeAccount.userID),
           let ticket = try? await RobloxAuth.authenticationTicket(cookie: cookie),
           let url = RobloxAuth.playerLaunchURL(ticket: ticket, placeID: placeID, linkCode: linkCode) {
            NSWorkspace.shared.open(url)
            return
        }
        openRoblox(placeID: placeID, linkCode: linkCode)
    }

    func refreshLibrary() async {
        guard !isRefreshingLibrary else { return }
        isRefreshingLibrary = true
        defer { isRefreshingLibrary = false }
        guard activeAccount.isSignedIn, let cookie = RobloxSecrets.cookie(for: activeAccount.userID) else { return }

        let recents = await RobloxLibrary.recentlyPlayed(userID: activeAccount.userID, cookie: cookie)
        let favorites = await RobloxLibrary.favoriteGames(userID: activeAccount.userID, cookie: cookie)
        for game in recents + favorites {
            var item = game
            item.lastPlayedBy = activeAccount.username
            mergeGame(item)
        }
        if !recents.isEmpty {
            recentGames = recents
        } else if recentGames.isEmpty {
            recentGames = Array(favorites.prefix(6))
        }
        if pinnedIDs.isEmpty {
            pinnedIDs = Array(favorites.prefix(4).map(\.id))
        }
        if quickLaunchID == nil {
            quickLaunchID = recentGames.first?.id ?? pinnedIDs.first
        }
        saveLibrary()
    }

    func refreshNews() async {
        let items = await RobloxLibrary.news()
        if items.isEmpty {
            newsFailed = news.isEmpty
        } else {
            news = items
            newsFailed = false
        }
    }

    func tickPlaytime(accountIDs: [UUID]) {
        let slice = 1.2 / 3600
        var combined = weeklyHours["combined"] ?? Array(repeating: 0, count: 7)
        if combined.count < 7 { combined = Array(repeating: 0, count: 7) }
        combined[6] += slice * Double(max(accountIDs.count, accountIDs.isEmpty ? 0 : 1))
        weeklyHours["combined"] = combined
        for id in Set(accountIDs) {
            var hours = weeklyHours[id.uuidString] ?? Array(repeating: 0, count: 7)
            if hours.count < 7 { hours = Array(repeating: 0, count: 7) }
            hours[6] += slice
            weeklyHours[id.uuidString] = hours
        }
        playtimeSaveCounter += 1
        if playtimeSaveCounter >= 25 {
            playtimeSaveCounter = 0
            saveLibrary()
        }
    }

    func closeAllInstances() {
        for instance in instances {
            if let pid = instance.processID, let app = NSRunningApplication(processIdentifier: pid) {
                app.terminate()
            }
        }
        for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier == InstanceManager.playerBundleID {
            app.terminate()
        }
        instances.removeAll()
    }

    func closeInstance(_ id: UUID) {
        if let instance = instances.first(where: { $0.id == id }),
           let pid = instance.processID,
           let app = NSRunningApplication(processIdentifier: pid) {
            app.terminate()
        }
        instances.removeAll { $0.id == id }
    }

    func focusInstance(_ instance: RunningInstance) {
        if let pid = instance.processID, let app = NSRunningApplication(processIdentifier: pid) {
            app.unhide()
            app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            return
        }
        NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == InstanceManager.playerBundleID })?
            .activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }

    func applySpec(_ spec: FastFlagSpec) {
        fastFlagSpec = spec
        switch spec {
        case .low:
            fpsCap = 60
            renderingMode = "Compatible"
            textureScale = "0.5x"
        case .high:
            fpsCap = 240
            renderingMode = "Future"
            textureScale = "1x"
        }
        saveLibrary()
    }

    func clearRobloxCache() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let folders = [
            home.appendingPathComponent("Library/Caches/com.roblox.RobloxPlayer"),
            home.appendingPathComponent("Library/Caches/Roblox"),
            home.appendingPathComponent("Library/Logs/Roblox")
        ]
        for url in folders {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func hours(for scope: PlaytimeScope) -> [Double] {
        let values: [Double]
        switch scope {
        case .combined:
            values = weeklyHours["combined"] ?? []
        case .account:
            values = weeklyHours[playtimeAccountID.uuidString] ?? []
        }
        return values.isEmpty ? Array(repeating: 0, count: 7) : values
    }

    func tickResources(runningInstances: Int = 0) {
        guard !isInteracting, !isEditing else { return }
        let cpu = HostStats.cpuUsage()
        let ram = HostStats.memoryUsage()
        let instancePressure = min(1, Double(runningInstances) * 0.18)
        let gpu = min(1, (cpu * 0.55) + instancePressure + 0.08)

        cpuLoad = cpuLoad * 0.55 + cpu * 0.45
        ramLoad = ramLoad * 0.6 + ram * 0.4
        gpuLoad = gpuLoad * 0.55 + gpu * 0.45

        cpuHistory = Array((cpuHistory + [cpuLoad]).suffix(18))
        ramHistory = Array((ramHistory + [ramLoad]).suffix(18))
        gpuHistory = Array((gpuHistory + [gpuLoad]).suffix(18))
    }

    func refreshPlatformStatus() async {
        do {
            guard let url = URL(string: "https://status.roblox.com/api/v2/status.json") else { return }
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let status = json?["status"] as? [String: Any]
            let indicator = (status?["indicator"] as? String) ?? "none"
            let description = (status?["description"] as? String) ?? "Roblox is reachable."
            platformHealthy = indicator == "none" || indicator == "minor"
            platformStatusText = description
        } catch {
            platformHealthy = false
            platformStatusText = "Could not reach Roblox status."
        }
        platformChecked = true
    }

    func firstFit(for size: GridSize, ignoring id: WidgetPlacement.ID? = nil) -> GridCell? {
        let rows = max(rowCount, 1) + size.rows
        for row in 0..<rows {
            for column in 0...(HomeBoard.columns - size.columns) {
                if canPlace(size: size, column: column, row: row, ignoring: id) {
                    return GridCell(column: column, row: row)
                }
            }
        }
        return nil
    }

    func canPlace(size: GridSize, column: Int, row: Int, ignoring id: WidgetPlacement.ID? = nil) -> Bool {
        guard column >= 0, row >= 0, column + size.columns <= HomeBoard.columns else { return false }
        let blocked = Set(
            placements
                .filter { $0.id != id }
                .flatMap(\.cells)
        )
        for columnOffset in 0..<size.columns {
            for rowOffset in 0..<size.rows {
                if blocked.contains(GridCell(column: column + columnOffset, row: row + rowOffset)) {
                    return false
                }
            }
        }
        return true
    }

    private func openRoblox(placeID: String, linkCode: String? = nil) {
        var web = "https://www.roblox.com/games/\(placeID)"
        if let linkCode {
            web += "?privateServerLinkCode=\(linkCode)"
        }
        _ = web
    }

    private func mergeGame(_ game: DemoGame) {
        if let index = games.firstIndex(where: { $0.id == game.id || $0.placeID == game.placeID }) {
            games[index] = game
        } else {
            games.append(game)
        }
    }

    func rememberRecent(_ game: DemoGame) {
        var item = game
        item.lastPlayedBy = activeAccount.username
        mergeGame(item)
        recentGames.removeAll { $0.id == item.id }
        recentGames.insert(item, at: 0)
        recentGames = Array(recentGames.prefix(6))
        if quickLaunchID == nil {
            quickLaunchID = item.id
        }
        saveLibrary()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(placements) {
            UserDefaults.standard.set(data, forKey: HomeBoard.persistenceKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: HomeBoard.persistenceKey),
              let decoded = try? JSONDecoder().decode([WidgetPlacement].self, from: data)
        else { return }
        placements = decoded
    }

    private func saveAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: HomeBoard.accountsKey)
        }
        UserDefaults.standard.set(activeAccountID.uuidString, forKey: HomeBoard.activeAccountKey)
    }

    private func saveLibrary() {
        UserDefaults.standard.set(pinnedIDs, forKey: HomeBoard.pinsKey)
        UserDefaults.standard.set(quickLaunchID, forKey: HomeBoard.quickLaunchKey)
        if let data = try? JSONEncoder().encode(privateServers) {
            UserDefaults.standard.set(data, forKey: HomeBoard.serversKey)
        }
        if let data = try? JSONEncoder().encode(recentGames) {
            UserDefaults.standard.set(data, forKey: HomeBoard.recentsKey)
        }
        if let data = try? JSONEncoder().encode(weeklyHours) {
            UserDefaults.standard.set(data, forKey: HomeBoard.playtimeKey)
        }
        if let data = try? JSONEncoder().encode(games) {
            UserDefaults.standard.set(data, forKey: "roblox.home.games")
        }
        UserDefaults.standard.set(fastFlagSpec.rawValue, forKey: HomeBoard.flagsKey)
        UserDefaults.standard.set(fpsCap, forKey: "roblox.home.fpsCap")
        UserDefaults.standard.set(renderingMode, forKey: "roblox.home.rendering")
        UserDefaults.standard.set(textureScale, forKey: "roblox.home.textures")
    }

    private func loadLibrary() {
        pinnedIDs = UserDefaults.standard.stringArray(forKey: HomeBoard.pinsKey) ?? []
        quickLaunchID = UserDefaults.standard.string(forKey: HomeBoard.quickLaunchKey)
        if let data = UserDefaults.standard.data(forKey: HomeBoard.serversKey),
           let servers = try? JSONDecoder().decode([PrivateServerLink].self, from: data) {
            privateServers = servers
        }
        if let data = UserDefaults.standard.data(forKey: HomeBoard.recentsKey),
           let recents = try? JSONDecoder().decode([DemoGame].self, from: data) {
            recentGames = recents
        }
        if let data = UserDefaults.standard.data(forKey: HomeBoard.playtimeKey),
           let hours = try? JSONDecoder().decode([String: [Double]].self, from: data) {
            weeklyHours = hours
        }
        if let data = UserDefaults.standard.data(forKey: "roblox.home.games"),
           let catalog = try? JSONDecoder().decode([DemoGame].self, from: data) {
            games = catalog
        }
        if let raw = UserDefaults.standard.string(forKey: HomeBoard.flagsKey),
           let spec = FastFlagSpec(rawValue: raw) {
            fastFlagSpec = spec
        }
        let storedFPS = UserDefaults.standard.integer(forKey: "roblox.home.fpsCap")
        if storedFPS > 0 { fpsCap = storedFPS }
        if let mode = UserDefaults.standard.string(forKey: "roblox.home.rendering") {
            renderingMode = mode
        }
        if let scale = UserDefaults.standard.string(forKey: "roblox.home.textures") {
            textureScale = scale
        }
    }

    private func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: HomeBoard.accountsKey),
           let decoded = try? JSONDecoder().decode([AccountProfile].self, from: data) {
            accounts = decoded.filter(\.isSignedIn)
        }
        if let raw = UserDefaults.standard.string(forKey: HomeBoard.activeAccountKey),
           let id = UUID(uuidString: raw),
           accounts.contains(where: { $0.id == id }) {
            activeAccountID = id
        } else {
            activeAccountID = accounts.first?.id ?? AccountProfile.unsigned.id
        }
        playtimeAccountID = accounts.contains(where: { $0.id == playtimeAccountID })
            ? playtimeAccountID
            : activeAccountID
    }

}

enum HostStats {
    private static var lastCPU: host_cpu_load_info?

    static func cpuUsage() -> Double {
        var load = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &load) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        defer { lastCPU = load }
        guard result == KERN_SUCCESS else { return 0.3 }
        guard let previous = lastCPU else { return 0.2 }
        let user = Double(Int64(load.cpu_ticks.0) - Int64(previous.cpu_ticks.0))
        let system = Double(Int64(load.cpu_ticks.1) - Int64(previous.cpu_ticks.1))
        let idle = Double(Int64(load.cpu_ticks.2) - Int64(previous.cpu_ticks.2))
        let nice = Double(Int64(load.cpu_ticks.3) - Int64(previous.cpu_ticks.3))
        let total = user + system + idle + nice
        guard total > 0 else { return 0.2 }
        return min(1, max(0, (user + system + nice) / total))
    }

    static func memoryUsage() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0.4 }
        let used = Double(stats.active_count + stats.wire_count + stats.inactive_count)
        let total = used + Double(stats.free_count)
        guard total > 0 else { return 0.4 }
        return min(1, max(0.1, used / total))
    }
}
