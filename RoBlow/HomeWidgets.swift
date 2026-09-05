import AppKit
import SwiftUI

struct QuickLaunchWidget: View {
    @Environment(AppModel.self) private var model
    let placement: WidgetPlacement
    let size: GridSize
    @State private var draftPlaceID = ""

    var body: some View {
        let compact = size.columns == 1 && size.rows == 1
        if let game = model.home.game(for: placement) {
            ZStack {
                GameArtwork(game: game)

                VStack(spacing: 8) {
                    Spacer()
                    Button {
                        model.home.launch(game)
                        model.setStatus("Launching \(game.title) as \(model.home.activeAccount.username)")
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: compact ? 15 : 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: compact ? 36 : 44, height: compact ? 36 : 44)
                            .background(Circle().fill(.black.opacity(0.45)))
                    }
                    .buttonStyle(.plain)
                    .help("Launch with the active account")

                    VStack(spacing: 2) {
                        Menu {
                            ForEach(model.home.games) { option in
                                Button(option.title) {
                                    model.home.setQuickLaunch(option, for: placement.id)
                                }
                            }
                        } label: {
                            Text(game.title)
                                .font(.system(size: compact ? 12 : 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        .menuStyle(.borderlessButton)
                        if !compact {
                            Text("via \(model.home.activeAccount.displayName)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.82))
                        }
                    }
                    Spacer()
                }
                .padding(14)
            }
        } else {
            emptyLaunch(compact: compact)
        }
    }

    private func emptyLaunch(compact: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "play.circle")
                .font(.system(size: compact ? 20 : 26, weight: .medium))
            Text(model.home.activeAccount.isSignedIn ? "No recent game yet" : "Add an account to launch")
                .font(.system(size: 12, weight: .semibold))
                .multilineTextAlignment(.center)
            if !model.home.activeAccount.isSignedIn {
                Button("Add account") {
                    model.home.showAddAccount = true
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.menuBlue)
            } else {
                HStack(spacing: 6) {
                    TextField("Place ID", text: $draftPlaceID)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.mini)
                        .frame(maxWidth: 110)
                    Button("Play") {
                        model.home.launchPlaceID(draftPlaceID, for: placement.id)
                        model.setStatus("Launching place \(draftPlaceID)")
                        draftPlaceID = ""
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.menuBlue)
                    .disabled(draftPlaceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .foregroundStyle(Theme.controlInk.opacity(0.7))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AssignQuickLaunchButtons: View {
    @Environment(AppModel.self) private var model
    let game: DemoGame

    var body: some View {
        let cards = model.home.quickLaunchCards
        if cards.count <= 1 {
            Button("Set as quick launch") {
                model.home.setQuickLaunch(game, for: cards.first?.id)
            }
        } else {
            Menu("Set as quick launch") {
                ForEach(cards) { card in
                    Button(model.home.quickLaunchLabel(for: card)) {
                        model.home.setQuickLaunch(game, for: card.id)
                    }
                }
            }
        }
    }
}

struct RecentGamesWidget: View {
    @Environment(AppModel.self) private var model
    let size: GridSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent games")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.controlInk.opacity(0.55))
                Spacer()
                if model.home.activeAccount.isSignedIn {
                    Button {
                        Task {
                            await model.home.refreshLibrary()
                            model.setStatus("Refreshed recent games")
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.controlInk.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                    .disabled(model.home.isRefreshingLibrary)
                }
            }

            if model.home.recentGames.isEmpty {
                Text(model.home.activeAccount.isSignedIn ? "Play a game to fill this list." : "Add an account to load recents.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.controlInk.opacity(0.5))
            } else {
                let columns = max(1, min(size.columns, 4))
                let limit = max(columns * max(size.rows, 1), 1)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                    ForEach(Array(model.home.recentGames.prefix(limit))) { game in
                        recentTile(game, tall: size.rows >= 2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    private func recentTile(_ game: DemoGame, tall: Bool) -> some View {
        let last = game.lastPlayedBy ?? model.home.activeAccount.username
        return Button {
            model.home.launch(game)
            model.setStatus("Opening \(game.title)")
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                GameArtwork(game: game)
                    .frame(maxWidth: .infinity)
                    .frame(height: tall ? 64 : 46)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(game.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.controlInk)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .help(last.isEmpty ? game.title : "Last opened by @\(last)")
        .contextMenu {
            Button("Pin") { model.home.pin(game) }
            AssignQuickLaunchButtons(game: game)
        }
    }
}

struct PinnedFavoritesWidget: View {
    @Environment(AppModel.self) private var model
    var size: GridSize = .twoByTwo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pinned favorites")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.controlInk.opacity(0.55))

            if model.home.pinnedIDs.isEmpty {
                Text("Right-click a recent game to pin it.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.controlInk.opacity(0.5))
            } else {
                let columns = max(1, min(size.columns, 2))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                    ForEach(Array(model.home.pinnedIDs.prefix(columns * max(size.rows, 1)).enumerated()), id: \.offset) { index, gameID in
                        if let game = model.home.game(id: gameID) {
                            pinnedSlot(game, index: index)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    private func pinnedSlot(_ game: DemoGame, index: Int) -> some View {
        Button {
            model.home.launch(game)
            model.setStatus("Launching \(game.title)")
        } label: {
            VStack(spacing: 5) {
                GameArtwork(game: game)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(game.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.controlInk)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(6)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.22))
            }
        }
        .buttonStyle(.plain)
        .onDrag {
            NSItemProvider(object: game.id as NSString)
        }
        .contextMenu {
            Button("Unpin", role: .destructive) {
                model.home.unpin(game.id)
            }
            AssignQuickLaunchButtons(game: game)
        }
        .onDrop(of: [.text], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { value, _ in
                guard let sourceID = value as? String else { return }
                Task { @MainActor in
                    movePinned(from: sourceID, to: index)
                }
            }
            return true
        }
    }

    private func movePinned(from sourceID: String, to index: Int) {
        var ids = model.home.pinnedIDs
        guard let from = ids.firstIndex(of: sourceID) else { return }
        ids.remove(at: from)
        ids.insert(sourceID, at: min(index, ids.count))
        model.home.setPinned(ids)
    }
}

struct PrivateServersWidget: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var home = model.home

        VStack(alignment: .leading, spacing: 8) {
            Text("Private servers")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.controlInk.opacity(0.55))

            if model.home.privateServers.isEmpty && !model.home.showAddServer {
                Text("Save a private-server link to join it instantly.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.controlInk.opacity(0.5))
            }

            ForEach(model.home.privateServers) { server in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(server.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.controlInk)
                        Text("ID \(server.linkCode)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Theme.controlInk.opacity(0.5))
                    }
                    Spacer()
                    Button("Join") {
                        model.home.launch(server: server)
                        model.setStatus("Joining \(server.name)")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background {
                        Capsule().fill(Theme.menuBlue.opacity(0.18))
                    }
                    .foregroundStyle(Theme.menuBlue)
                    Button {
                        model.home.removePrivateServer(server.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.controlInk.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                }
            }

            if model.home.showAddServer {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Name", text: $home.draftServerName)
                    TextField("Place ID", text: $home.draftServerPlace)
                    TextField("Link code", text: $home.draftServerCode)
                    HStack {
                        Button("Save") {
                            model.home.addPrivateServer()
                            model.setStatus("Saved private server")
                        }
                        Button("Cancel") {
                            model.home.showAddServer = false
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                }
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
            } else {
                Button("Add server") {
                    model.home.showAddServer = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.menuBlue)
            }
        }
    }
}

struct InstanceStatusWidget: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Instances")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.controlInk.opacity(0.55))
                Spacer()
                Button("Close All Instances") {
                    model.instances.terminateAll()
                    model.home.closeAllInstances()
                    model.setStatus("Closed all instances")
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.red.opacity(0.8))
            }

            let running = model.instances.slots.filter(\.isRunning)
            if running.isEmpty {
                Text("No running instances")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.controlInk.opacity(0.45))
            } else {
                ForEach(running) { slot in
                    HStack(spacing: 8) {
                        Image(systemName: "macwindow")
                            .foregroundStyle(Theme.menuBlue)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(slot.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.controlInk)
                            Text(model.account(for: slot).username)
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.controlInk.opacity(0.5))
                        }
                        Spacer()
                        Button("Focus") {
                            model.setStatus(model.instances.bringToFront(slot))
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.menuBlue)
                        Button("Close") {
                            model.setStatus(model.instances.terminate(slot))
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.terminateRed)
                    }
                }
            }
        }
    }
}

struct AccountSwitcherWidget: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Launch target")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.controlInk.opacity(0.55))

            Button("Add Roblox account") {
                model.home.showAddAccount = true
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.menuBlue)

            if model.home.accounts.isEmpty {
                Text("No Roblox accounts yet.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.controlInk.opacity(0.5))
            }

            ForEach(model.home.accounts) { account in
                Button {
                    model.home.selectAccount(account.id)
                    model.setStatus("Default launch target: \(account.displayName)")
                } label: {
                    HStack(spacing: 8) {
                        AvatarView(account: account)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(account.displayName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.controlInk)
                            Text("@\(account.username)")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.controlInk.opacity(0.5))
                        }
                        Spacer()
                        if model.home.activeAccountID == account.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.menuBlue)
                        }
                    }
                    .padding(6)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(model.home.activeAccountID == account.id ? 0.4 : 0.12))
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Remove account", role: .destructive) {
                        model.home.removeAccount(account.id)
                        model.setStatus("Removed \(account.displayName)")
                    }
                }
            }
        }
    }
}

struct PlaytimeWidget: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var home = model.home
        let hours = home.hours(for: home.playtimeScope)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Playtime")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.controlInk.opacity(0.55))
                Spacer()
                Picker("", selection: $home.playtimeScope) {
                    ForEach(PlaytimeScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .labelsHidden()
                .frame(width: 110)
                .controlSize(.mini)

                if home.playtimeScope == .account {
                    Picker("", selection: $home.playtimeAccountID) {
                        ForEach(home.accounts) { account in
                            Text(account.displayName).tag(account.id)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 92)
                    .controlSize(.mini)
                }
            }

            Sparkline(values: hours, color: Theme.menuBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text("\(hours.reduce(0, +), specifier: "%.1f")h this week")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.controlInk.opacity(0.55))
        }
    }
}

struct HardwareWidget: View {
    @Environment(AppModel.self) private var model
    let size: GridSize

    var body: some View {
        let stressed = model.home.isBottlenecked
        let compact = size.columns == 1

        VStack(alignment: .leading, spacing: 8) {
            Text("Hardware")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(stressed ? Color.red.opacity(0.8) : Theme.controlInk.opacity(0.55))

            HStack(spacing: compact ? 8 : 16) {
                GaugeDial(title: "CPU", value: model.home.cpuLoad, stressed: stressed)
                GaugeDial(title: "RAM", value: model.home.ramLoad, stressed: stressed)
                if !compact {
                    GaugeDial(title: "GPU", value: model.home.gpuLoad, stressed: stressed)
                }
            }

            if !compact {
                HStack(spacing: 8) {
                    Sparkline(values: model.home.cpuHistory, color: stressed ? .red : Theme.menuBlue)
                    Sparkline(values: model.home.ramHistory, color: stressed ? .red : Theme.menuBlue)
                    Sparkline(values: model.home.gpuHistory, color: stressed ? .red : Theme.menuBlue)
                }
                .frame(height: 28)
            }
        }
        .padding(2)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(stressed ? Color.red.opacity(0.55) : .clear, lineWidth: 1.2)
                .shadow(color: stressed ? .red.opacity(0.35) : .clear, radius: stressed ? 10 : 0)
        }
    }
}

struct PlatformStatusWidget: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Roblox status")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.controlInk.opacity(0.55))

            HStack(spacing: 8) {
                Circle()
                    .fill(model.home.platformHealthy ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(model.home.platformHealthy ? "Operational" : "Degraded")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.controlInk)
            }

            Text(model.home.platformStatusText)
                .font(.system(size: 11))
                .foregroundStyle(Theme.controlInk.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
            Text(model.home.platformChecked ? "Live ping to status.roblox.com" : "Waiting for ping…")
                .font(.system(size: 10))
                .foregroundStyle(Theme.controlInk.opacity(0.4))
        }
        .task {
            await model.home.refreshPlatformStatus()
        }
    }
}

struct FastFlagWidget: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FastFlag profile")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.controlInk.opacity(0.55))

            HStack {
                flag("FPS cap", "\(model.home.fpsCap)")
                flag("Render", model.home.renderingMode)
                flag("Textures", model.home.textureScale)
            }

            HStack(spacing: 8) {
                ForEach(FastFlagSpec.allCases, id: \.self) { spec in
                    Button(spec.rawValue) {
                        model.home.applySpec(spec)
                        for slot in model.instances.slots {
                            slot.fps = spec == .low ? .sixty : .twoForty
                            slot.graphics = spec == .low ? .min : .max
                        }
                        model.instances.persist()
                        model.publishClientSettings()
                        model.setStatus("Switched to \(spec.rawValue)")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background {
                        Capsule().fill(model.home.fastFlagSpec == spec ? Theme.menuBlue.opacity(0.22) : Color.white.opacity(0.2))
                    }
                    .foregroundStyle(Theme.controlInk)
                }

                Spacer()

                Button("Clear cache") {
                    model.home.clearRobloxCache()
                    model.setStatus("Cleared local Roblox cache")
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.menuBlue)
            }
        }
    }

    private func flag(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Theme.controlInk.opacity(0.45))
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.controlInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NewsFeedWidget: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("News")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.controlInk.opacity(0.55))

            if model.home.news.isEmpty {
                if model.home.newsFailed {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Couldn’t load the Roblox blog.")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.controlInk.opacity(0.5))
                        Button("Retry") {
                            Task { await model.home.refreshNews() }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.menuBlue)
                    }
                } else {
                    Text("Fetching the Roblox blog…")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.controlInk.opacity(0.5))
                }
            }

            ForEach(model.home.news) { item in
                Button {
                    NSWorkspace.shared.open(item.url)
                } label: {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hue: item.hue, saturation: 0.45, brightness: 0.86),
                                        Color(hue: item.hue, saturation: 0.62, brightness: 0.62)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 42, height: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.controlInk)
                                .lineLimit(1)
                            Text("\(item.source) · \(item.date)")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.controlInk.opacity(0.5))
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .help(item.url.absoluteString)
            }
        }
    }
}

struct PatchNotesWidget: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("RoBlow \(model.home.patchVersion)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.controlInk)
                Spacer()
                Text("Local build")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.4)))
                    .foregroundStyle(Theme.controlInk.opacity(0.7))
            }

            Text("Changelog")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.controlInk.opacity(0.45))
            ForEach(model.home.changelog, id: \.self) { line in
                Text("• \(line)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.controlInk.opacity(0.78))
            }

            Text("Active bugs")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.controlInk.opacity(0.45))
                .padding(.top, 2)
            ForEach(model.home.knownBugs, id: \.self) { line in
                Text("• \(line)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.controlInk.opacity(0.62))
            }
        }
    }
}

struct SeparatorWidget: View {
    var body: some View {
        VStack {
            Spacer()
            Rectangle()
                .fill(Theme.controlInk.opacity(0.18))
                .frame(height: 1)
                .padding(.horizontal, 8)
            Spacer()
        }
    }
}

struct SubtitleWidget: View {
    @Environment(AppModel.self) private var model
    let placement: WidgetPlacement

    var body: some View {
        Text(model.home.editingSubtitleID == placement.id ? "" : (placement.title ?? "Subtitle"))
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.controlInk)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct GameArtwork: View {
    let game: DemoGame

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hue: game.hue, saturation: 0.55, brightness: 0.88),
                    Color(hue: game.hue, saturation: 0.72, brightness: 0.45)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let url = game.thumbnailURL.flatMap(URL.init(string:)) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    controller
                }
            } else {
                controller
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var controller: some View {
        Image(systemName: "gamecontroller.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white.opacity(0.88))
    }
}

struct AvatarView: View {
    let account: AccountProfile

    var body: some View {
        Group {
            if let url = account.avatarURL.flatMap(URL.init(string:)) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initials
                }
            } else {
                initials
            }
        }
        .frame(width: 26, height: 26)
        .clipShape(Circle())
    }

    private var initials: some View {
        Text(account.initials)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background {
                Circle().fill(Color(hue: account.hue, saturation: 0.55, brightness: 0.72))
            }
    }
}

struct GaugeDial: View {
    let title: String
    let value: Double
    var stressed: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.28), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: value)
                    .stroke(stressed ? Color.red : Theme.menuBlue, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(value * 100))")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.controlInk)
            }
            .frame(width: 42, height: 42)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.controlInk.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

struct Sparkline: View {
    let values: [Double]
    var color: Color

    var body: some View {
        GeometryReader { proxy in
            let maxValue = max(values.max() ?? 1, 0.01)
            Path { path in
                for (index, value) in values.enumerated() {
                    let x = proxy.size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
                    let y = proxy.size.height * (1 - CGFloat(value / maxValue))
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
    }
}
