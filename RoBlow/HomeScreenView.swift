import SwiftUI

struct HomeScreenView: View {
    @Environment(AppModel.self) private var model

    private let spacing: CGFloat = 12

    var body: some View {
        @Bindable var home = model.home

        VStack(alignment: .leading, spacing: 16) {
            header

            GeometryReader { proxy in
                let cellSize = floor(
                    (proxy.size.width - spacing * CGFloat(HomeBoard.columns - 1)) / CGFloat(HomeBoard.columns)
                )
                let boardWidth = cellSize * CGFloat(HomeBoard.columns) + spacing * CGFloat(HomeBoard.columns - 1)
                let board = boardStack(cellSize: cellSize, size: CGSize(width: boardWidth, height: proxy.size.height))

                ScrollView {
                    board
                }
                .scrollIndicators(.hidden)
                .coordinateSpace(name: "homeBoard")
            }
        }
        .padding(22)
        .sheet(isPresented: $home.showCatalog) {
            WidgetCatalogView()
                .environment(model)
        }
        .task {
            await home.refreshPlatformStatus()
            await home.refreshLibrary()
            await home.refreshNews()
        }
        .onReceive(Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()) { _ in
            let running = model.instances.slots.filter(\.isRunning)
            home.tickResources(runningInstances: running.count)
            home.tickPlaytime(accountIDs: running.map { model.account(for: $0).id })
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Home")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.controlInk)
                Text(model.home.isEditing ? "Customize mode: cards snap to the grid. Add another Quick launch if you want a second game." : "Welcome back.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.controlInk.opacity(0.58))
            }

            Spacer()

            if model.home.isEditing {
                Button {
                    model.home.addSeparator()
                } label: {
                    Label("Add separator", systemImage: "minus")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background {
                    Capsule().fill(Color.white.opacity(0.42))
                }

                Button {
                    model.home.addSubtitle()
                } label: {
                    Label("Add subtitle", systemImage: "textformat")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background {
                    Capsule().fill(Color.white.opacity(0.42))
                }

                Button {
                    model.home.openCatalog()
                } label: {
                    Label("Add widget", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background {
                    Capsule().fill(Color.white.opacity(0.42))
                }

                Button("Done") {
                    model.home.finishEditing()
                    model.setStatus("Home screen saved")
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    Capsule().fill(Theme.menuBlue.opacity(0.86))
                }
                .foregroundStyle(.white)
            } else {
                Button {
                    model.home.beginEditing()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.controlInk)
                        .frame(width: 34, height: 34)
                        .background {
                            Circle().fill(Color.white.opacity(0.42))
                        }
                }
                .buttonStyle(.plain)
                .help("Edit home screen")
                .accessibilityLabel("Edit home screen")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Theme.controlInk.opacity(0.35))
            Text("Your home is empty")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.controlInk)
            Text("Click edit, press a name to add it, then drag to move or resize.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.controlInk.opacity(0.55))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func boardStack(cellSize: CGFloat, size: CGSize) -> some View {
        let boardHeight = max(model.home.measuredHeight(cellSize: cellSize, spacing: spacing), size.height)

        return ZStack(alignment: .topLeading) {
            Color.clear

            if model.home.isEditing {
                HomeGridBackground(cellSize: cellSize, spacing: spacing, boardSize: CGSize(width: size.width, height: boardHeight))
            }

            ForEach(model.home.placements) { placement in
                let live = model.home.placements.first(where: { $0.id == placement.id }) ?? placement
                let rect = model.home.frame(for: live, cellSize: cellSize, spacing: spacing)
                PlacedWidgetView(placement: live, cellSize: cellSize, spacing: spacing)
                    .frame(width: rect.width, height: rect.height)
                    .clipped()
                    .contentShape(Rectangle())
                    .position(x: rect.midX, y: rect.midY)
                    .zIndex(model.home.dragSession?.id == placement.id ? 20 : 1)
            }

            if model.home.isEditing {
                BoardPointerOverlay(
                    cellSize: cellSize,
                    spacing: spacing,
                    onDown: { point in
                        model.home.handlePress(at: point, cellSize: cellSize, spacing: spacing)
                    },
                    onDrag: { point in
                        model.home.handleDrag(at: point, cellSize: cellSize, spacing: spacing)
                    },
                    onUp: {
                        model.home.endDrag()
                    }
                )
                .frame(width: size.width, height: boardHeight)
                .zIndex(100)
            }

            if model.home.isEditing, let id = model.home.editingSubtitleID,
               let subtitle = model.home.placements.first(where: { $0.id == id }) {
                let rect = model.home.frame(for: subtitle, cellSize: cellSize, spacing: spacing)
                SubtitleEditor(placement: subtitle, cellSize: cellSize, spacing: spacing)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .zIndex(101)
            }

            if model.home.placements.isEmpty && !model.home.isEditing {
                emptyState
            }
        }
        .frame(width: size.width, height: boardHeight, alignment: .topLeading)
        .coordinateSpace(name: "homeBoard")
    }
}

private struct HomeGridBackground: View {
    @Environment(AppModel.self) private var model
    let cellSize: CGFloat
    let spacing: CGFloat
    let boardSize: CGSize

    var body: some View {
        let rows = max(model.home.rowCount, 2)
        ZStack {
            ForEach(0..<rows, id: \.self) { row in
                ForEach(0..<HomeBoard.columns, id: \.self) { column in
                    let height = model.home.rowHeight(row, cellSize: cellSize)
                    let x = CGFloat(column) * (cellSize + spacing)
                    let y = model.home.yOrigin(forRow: row, cellSize: cellSize, spacing: spacing)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.controlInk.opacity(0.10), lineWidth: 1)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.controlInk.opacity(0.03))
                        }
                        .frame(width: cellSize, height: height)
                        .position(x: x + cellSize / 2, y: y + height / 2)
                }
            }
        }
        .frame(width: boardSize.width, height: boardSize.height)
        .allowsHitTesting(false)
    }
}

private struct SubtitleEditor: View {
    @Environment(AppModel.self) private var model
    let placement: WidgetPlacement
    let cellSize: CGFloat
    let spacing: CGFloat
    @FocusState private var focused: Bool

    var body: some View {
        TextField("Subtitle", text: Binding(
            get: {
                model.home.placements.first(where: { $0.id == placement.id })?.title ?? "Subtitle"
            },
            set: { model.home.updateTitle(placement.id, $0) }
        ))
        .textFieldStyle(.plain)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(Theme.controlInk)
        .focused($focused)
        .padding(.leading, 34)
        .padding(.trailing, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .onAppear { focused = true }
    }
}

private struct PlacedWidgetView: View {
    @Environment(AppModel.self) private var model
    let placement: WidgetPlacement
    let cellSize: CGFloat
    let spacing: CGFloat

    private var live: WidgetPlacement {
        model.home.placements.first(where: { $0.id == placement.id }) ?? placement
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            widgetChrome
                .allowsHitTesting(!model.home.isEditing)

            if model.home.isEditing {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.red.opacity(0.92))
                    .padding(live.kind.isLayoutItem ? 2 : 8)

                if !live.kind.isLayoutItem {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.controlInk.opacity(0.75))
                        .frame(width: 22, height: 22)
                        .background {
                            Circle().fill(Color.white.opacity(0.95))
                        }
                        .overlay {
                            Circle().strokeBorder(Theme.controlInk.opacity(0.16), lineWidth: 0.8)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(!model.home.isEditing)
    }

    @ViewBuilder
    private var widgetChrome: some View {
        if live.kind.isLayoutItem {
            widgetBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if model.home.isEditing {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    }
                }
        } else {
            WidgetCard(isEditing: model.home.isEditing, fillsCard: live.kind == .quickLaunch) {
                widgetBody
            }
        }
    }

    @ViewBuilder
    private var widgetBody: some View {
        switch live.kind {
        case .quickLaunch: QuickLaunchWidget(placement: live, size: live.size)
        case .recentGames: RecentGamesWidget(size: live.size)
        case .pinnedFavorites: PinnedFavoritesWidget(size: live.size)
        case .privateServers: PrivateServersWidget()
        case .instanceStatus: InstanceStatusWidget()
        case .accountSwitcher: AccountSwitcherWidget()
        case .playtime: PlaytimeWidget()
        case .hardware: HardwareWidget(size: live.size)
        case .platformStatus: PlatformStatusWidget()
        case .fastFlag: FastFlagWidget()
        case .newsFeed: NewsFeedWidget()
        case .patchNotes: PatchNotesWidget()
        case .separator: SeparatorWidget()
        case .subtitle: SubtitleWidget(placement: live)
        }
    }
}

struct WidgetCard<Content: View>: View {
    var isEditing: Bool
    var fillsCard = false
    @ViewBuilder var content: Content

    private let corner: CGFloat = 16

    var body: some View {
        content
            .padding(fillsCard ? 0 : 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                GlassSurface(style: .panel, cornerRadius: corner)
            }
            .overlay {
                GlassStroke(cornerRadius: corner, lineWidth: 0.6)
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

struct WidgetCatalogView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Widgets")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button("Close") {
                    model.home.showCatalog = false
                    dismiss()
                }
                .buttonStyle(.plain)
            }

            Text("Press a name to drop it on the grid. You can add Quick launch more than once.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.controlInk.opacity(0.5))

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    catalogSection("Widgets", kinds: WidgetKind.allCases.filter { !$0.isLayoutItem })
                }
            }
        }
        .padding(20)
        .frame(width: 360, height: 560)
        .background(GlassSurface(style: .panel, cornerRadius: 22))
    }

    private func catalogSection(_ title: String, kinds: [WidgetKind]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.controlInk.opacity(0.45))
                .padding(.horizontal, 4)

            ForEach(kinds) { kind in
                Button {
                    model.home.addWidget(kind: kind)
                    dismiss()
                } label: {
                    Text(kind.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.controlInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.32))
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
