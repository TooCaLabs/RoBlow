import SwiftUI

struct WebModStoreView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var lane = "featured"
    @State private var listings: [StoreListing] = []
    @State private var selected: StoreListing?
    @State private var isLoading = false
    @State private var note: String?

    private var slot: GameInstance? {
        let id = model.webModStoreInstanceID
            ?? model.instances.editingModInstanceID
            ?? model.newUIInstanceID
            ?? model.selectedInstance?.id
        return id.flatMap { model.instances.instance(for: $0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            chrome
            Divider().opacity(0.15)
            content
        }
        .background(Color.white.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .task {
            if let seed = model.webModStoreQuery, !seed.isEmpty {
                query = seed
                await search(seed)
            } else {
                await load(url: ChromeStore.home, lane: "featured")
            }
        }
        .focusable()
        .onKeyPress(.escape) {
            if selected != nil {
                selected = nil
            } else {
                model.closeWebModStore()
            }
            return .handled
        }
    }

    private var chrome: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    if selected != nil {
                        selected = nil
                    } else {
                        model.closeWebModStore()
                    }
                } label: {
                    Label(selected == nil ? "Back" : "Catalog", systemImage: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.controlInk)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Install mods")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.controlInk)
                    Text(slot.map { "Chrome Web Store wrapper  ·  \($0.name)" } ?? "Chrome Web Store wrapper")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.controlInk.opacity(0.5))
                }

                Spacer()

                Button("Done") {
                    model.closeWebModStore()
                    if let slot {
                        model.instances.editingModInstanceID = slot.id
                        model.selectedSidebarItem = .mods
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.menuBlue)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.controlInk.opacity(0.4))
                TextField("Search extensions", text: $query)
                    .textFieldStyle(.plain)
                    .onSubmit { Task { await search(query) } }
                if !query.isEmpty {
                    Button {
                        query = ""
                        Task { await load(url: ChromeStore.home, lane: "featured") }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.controlInk.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule().fill(Color.white.opacity(0.58))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ChromeStore.lanes, id: \.id) { item in
                        Button {
                            query = item.id == "roblox" ? "roblox" : ""
                            Task { await load(url: item.url, lane: item.id) }
                        } label: {
                            Text(item.title)
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background {
                                    Capsule().fill(lane == item.id ? Theme.menuBlue : Color.white.opacity(0.5))
                                }
                                .foregroundStyle(lane == item.id ? Color.white : Theme.controlInk)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let note {
                Text(note)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.controlInk.opacity(0.55))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        if let selected {
            detail(selected)
        } else if isLoading {
            VStack {
                Spacer()
                ProgressView()
                Text("Loading catalog…")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.controlInk.opacity(0.45))
                    .padding(.top, 8)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 10)], spacing: 10) {
                    ForEach(listings) { item in
                        card(item)
                    }
                }
                .padding(14)
            }
        }
    }

    private func card(_ item: StoreListing) -> some View {
        Button {
            selected = item
        } label: {
            HStack(alignment: .top, spacing: 10) {
                icon(item)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.controlInk)
                        .lineLimit(1)
                    Text(item.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.controlInk.opacity(0.5))
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        if let rating = item.rating {
                            Text(String(format: "★ %.1f", rating))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.controlInk.opacity(0.45))
                        }
                        Spacer()
                        installChip(item)
                    }
                }
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.55))
            }
        }
        .buttonStyle(.plain)
    }

    private func detail(_ item: StoreListing) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    icon(item)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Theme.controlInk)
                        if let rating = item.rating {
                            Text(item.ratings.map { String(format: "★ %.1f  ·  %d ratings", rating, $0) } ?? String(format: "★ %.1f", rating))
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.controlInk.opacity(0.5))
                        }
                        Text(item.id)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.controlInk.opacity(0.35))
                    }
                    Spacer()
                    installChip(item, large: true)
                }
                Text(item.detail)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.controlInk.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                Text("This wrapper reads the Chrome Web Store catalog and installs the package into this instance. It does not open Google’s store page.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.controlInk.opacity(0.45))
            }
            .padding(22)
        }
    }

    @ViewBuilder
    private func installChip(_ item: StoreListing, large: Bool = false) -> some View {
        if slot?.webMods.contains(where: { $0.id == item.id }) == true {
            Text("Added")
                .font(.system(size: large ? 13 : 11, weight: .semibold))
                .foregroundStyle(Theme.launchGreen)
                .padding(.horizontal, large ? 14 : 10)
                .padding(.vertical, large ? 7 : 4)
                .background {
                    Capsule().fill(Theme.launchGreen.opacity(0.16))
                }
        } else {
            Button {
                Task { await install(item) }
            } label: {
                Text(model.webMods.installingID == item.id ? "Installing…" : "Install")
                    .font(.system(size: large ? 13 : 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, large ? 14 : 10)
                    .padding(.vertical, large ? 7 : 4)
                    .background {
                        Capsule().fill(model.webMods.installingID == item.id ? Theme.menuBlue.opacity(0.5) : Theme.menuBlue)
                    }
            }
            .buttonStyle(.plain)
            .disabled(model.webMods.installingID != nil)
        }
    }

    @ViewBuilder
    private func icon(_ item: StoreListing) -> some View {
        if let raw = item.iconURL, let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    placeholderIcon
                }
            }
        } else {
            placeholderIcon
        }
    }

    private var placeholderIcon: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Theme.menuBlue.opacity(0.16))
            .overlay {
                Image(systemName: "puzzlepiece.extension.fill")
                    .foregroundStyle(Theme.menuBlue)
            }
    }

    private func search(_ raw: String) async {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if ChromeStore.isExtensionID(ChromeStore.normalizeID(trimmed)) {
            await load(url: ChromeStore.detailURL(id: ChromeStore.normalizeID(trimmed)), lane: "search")
            return
        }
        await load(url: ChromeStore.searchURL(trimmed), lane: "search")
    }

    private func load(url: URL, lane laneID: String) async {
        isLoading = true
        note = nil
        lane = laneID
        selected = nil
        do {
            listings = try await ChromeStore.loadListings(from: url)
            note = "\(listings.count) extensions"
        } catch {
            listings = []
            note = error.localizedDescription
        }
        isLoading = false
    }

    private func install(_ item: StoreListing) async {
        guard let slot else {
            note = "Open an instance first."
            return
        }
        note = "Installing \(item.name)…"
        do {
            let record = try await model.webMods.install(id: item.id)
            slot.addWebMod(record.id)
            model.instances.persist()
            model.reloadNewUI()
            note = "Added \(record.name) to \(slot.name)."
            model.setStatus("Installed \(record.name)")
        } catch {
            note = error.localizedDescription
        }
    }
}
