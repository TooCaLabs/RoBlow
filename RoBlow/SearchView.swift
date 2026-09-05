import AppKit
import SwiftUI

enum SearchScope: String, CaseIterable, Identifiable {
    case experiences
    case people

    var id: String { rawValue }

    var title: String {
        switch self {
        case .experiences: "Experiences"
        case .people: "People"
        }
    }
}

struct SearchExperience: Identifiable, Hashable {
    var placeID: String
    var universeID: String? = nil
    var title: String
    var creator: String?
    var detail: String?
    var playing: Int?
    var thumbnailURL: String?
    var hue: Double

    var id: String { placeID }

    func asGame() -> DemoGame {
        DemoGame(id: placeID, title: title, placeID: placeID, hue: hue, thumbnailURL: thumbnailURL)
    }
}

struct SearchPerson: Identifiable, Hashable {
    var userID: String
    var username: String
    var displayName: String
    var avatarURL: String?

    var id: String { userID }

    var profileURL: URL? {
        URL(string: "https://www.roblox.com/users/\(userID)/profile")
    }
}

@MainActor
@Observable
final class SearchBoard {
    var query = ""
    var submitted = ""
    var scope: SearchScope = .experiences
    var experiences: [SearchExperience] = []
    var people: [SearchPerson] = []
    var isSearching = false
    var didSearch = false
    var error: String?

    var hasQuery: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func search(cookie: String?) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        submitted = trimmed
        isSearching = true
        error = nil
        defer { isSearching = false }

        switch scope {
        case .experiences:
            let hits = await RobloxLibrary.searchExperiences(trimmed, cookie: cookie)
            experiences = hits
            if hits.isEmpty {
                error = "No experiences for “\(trimmed)”."
            }
        case .people:
            let hits = await RobloxLibrary.searchPeople(trimmed)
            people = hits
            if hits.isEmpty {
                error = "No people for “\(trimmed)”."
            }
        }
        didSearch = true
    }

    func feelingLucky(cookie: String?) async -> SearchExperience? {
        scope = .experiences
        await search(cookie: cookie)
        return experiences.first
    }
}

struct SearchView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var searchFocused: Bool

    var body: some View {
        let search = model.search
        Group {
            if search.didSearch {
                resultsLayout
            } else {
                homeLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { searchFocused = true }
    }

    private var homeLayout: some View {
        VStack(spacing: 22) {
            Spacer()
            wordmark(large: true)
            searchField(wide: true)
            if !model.term.isEnabled {
                actionRow
            }
            Spacer()
            Text(model.term.isEnabled
                 ? "play <place|name>  ·  search <query>"
                 : "Search Roblox experiences and people. Play opens with your active account.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.controlInk.opacity(0.4))
                .padding(.bottom, 18)
        }
        .padding(.horizontal, 40)
    }

    private var resultsLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Button {
                    model.search.didSearch = false
                    model.search.error = nil
                    searchFocused = true
                } label: {
                    wordmark(large: false)
                }
                .buttonStyle(.plain)

                searchField(wide: false)
            }

            if !model.term.isEnabled {
                scopeTabs
                actionRow
            }

            if model.search.isSearching {
                Text("Searching Roblox…")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.controlInk.opacity(0.5))
                    .padding(.top, 8)
            } else if let error = model.search.error {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.controlInk.opacity(0.5))
                    .padding(.top, 8)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if model.search.scope == .experiences {
                            ForEach(model.search.experiences) { hit in
                                experienceRow(hit)
                            }
                        } else {
                            ForEach(model.search.people) { person in
                                personRow(person)
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(22)
    }

    private func wordmark(large: Bool) -> some View {
        VStack(spacing: 2) {
            Text("RoBlow")
                .font(.system(size: large ? 42 : 22, weight: .semibold))
                .foregroundStyle(Theme.controlInk)
            if large {
                Text("Search")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.controlInk.opacity(0.45))
            }
        }
    }

    private func searchField(wide: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.controlInk.opacity(0.4))
            TextField("Search Roblox", text: Binding(
                get: { model.search.query },
                set: { model.search.query = $0 }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 16))
            .foregroundStyle(Theme.controlInk)
            .focused($searchFocused)
            .onSubmit { Task { await runSearch() } }

            if model.search.hasQuery {
                Button {
                    model.search.query = ""
                    model.search.didSearch = false
                    model.search.error = nil
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.controlInk.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            Capsule().fill(Color.white.opacity(0.48))
        }
        .overlay {
            Capsule().strokeBorder(Theme.controlInk.opacity(0.08), lineWidth: 1)
        }
        .frame(maxWidth: wide ? 560 : .infinity)
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button("Search Roblox") {
                Task { await runSearch() }
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background { Capsule().fill(Color.white.opacity(0.42)) }
            .foregroundStyle(Theme.controlInk)
            .disabled(!model.search.hasQuery || model.search.isSearching)

            Button("I'm Feeling Lucky") {
                Task { await lucky() }
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background { Capsule().fill(Theme.menuBlue.opacity(0.18)) }
            .foregroundStyle(Theme.menuBlue)
            .disabled(!model.search.hasQuery || model.search.isSearching)
        }
    }

    private var scopeTabs: some View {
        HStack(spacing: 16) {
            ForEach(SearchScope.allCases) { scope in
                Button {
                    model.search.scope = scope
                    if model.search.didSearch {
                        Task { await runSearch() }
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(scope.title)
                            .font(.system(size: 13, weight: model.search.scope == scope ? .semibold : .medium))
                            .foregroundStyle(model.search.scope == scope ? Theme.menuBlue : Theme.controlInk.opacity(0.5))
                        Rectangle()
                            .fill(model.search.scope == scope ? Theme.menuBlue : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if !model.search.submitted.isEmpty {
                Text("Results for “\(model.search.submitted)”")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.controlInk.opacity(0.4))
            }
        }
    }

    private func experienceRow(_ hit: SearchExperience) -> some View {
        HStack(alignment: .top, spacing: 12) {
            GameArtwork(game: hit.asGame())
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                if model.term.isEnabled {
                    Text(hit.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.controlInk)
                        .lineLimit(1)
                } else {
                    Button {
                        play(hit)
                    } label: {
                        Text(hit.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.menuBlue)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }

                Text("roblox.com/games/\(hit.placeID)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.22, green: 0.52, blue: 0.32))

                HStack(spacing: 8) {
                    if let playing = hit.playing {
                        Text("\(formatted(playing)) playing")
                    }
                    if let creator = hit.creator, !creator.isEmpty {
                        Text(creator)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(Theme.controlInk.opacity(0.5))

                if let detail = hit.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.controlInk.opacity(0.62))
                        .lineLimit(2)
                }
            }

            Spacer()

            if model.term.isEnabled {
                Text("play \(hit.placeID)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.controlInk.opacity(0.4))
            } else {
                VStack(spacing: 6) {
                    Button("Play") { play(hit) }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background { Capsule().fill(Theme.launchGreen.opacity(0.9)) }
                        .foregroundStyle(.white)

                    Button("Pin") {
                        model.home.pin(hit.asGame())
                        model.setStatus("Pinned \(hit.title)")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.menuBlue)
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.28))
        }
        .contextMenu {
            if !model.term.isEnabled {
                Button("Play") { play(hit) }
                Button("Pin") { model.home.pin(hit.asGame()) }
                AssignQuickLaunchButtons(game: hit.asGame())
                Button("Copy place ID") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(hit.placeID, forType: .string)
                }
            }
        }
    }

    @ViewBuilder
    private func personRow(_ person: SearchPerson) -> some View {
        let row = HStack(spacing: 12) {
            Group {
                if let url = person.avatarURL.flatMap(URL.init(string:)) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.white.opacity(0.4))
                    }
                } else {
                    Circle().fill(Color.white.opacity(0.4))
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(person.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(model.term.isEnabled ? Theme.controlInk : Theme.menuBlue)
                Text("@\(person.username)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.controlInk.opacity(0.5))
                Text(model.term.isEnabled
                     ? "go /users/\(person.userID)/profile"
                     : "roblox.com/users/\(person.userID)/profile")
                    .font(.system(size: 11, design: model.term.isEnabled ? .monospaced : .default))
                    .foregroundStyle(Color(red: 0.22, green: 0.52, blue: 0.32))
            }
            Spacer()
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.28))
        }

        if model.term.isEnabled {
            row
        } else {
            Button {
                if let url = person.profileURL {
                    model.openNewUISite(url)
                }
            } label: {
                row
            }
            .buttonStyle(.plain)
        }
    }

    private func runSearch() async {
        await model.search.search(cookie: RobloxSecrets.cookie(for: model.home.activeAccount.userID))
    }

    private func lucky() async {
        if let hit = await model.search.feelingLucky(cookie: RobloxSecrets.cookie(for: model.home.activeAccount.userID)) {
            play(hit)
        } else {
            model.setStatus("Nothing lucky this time")
        }
    }

    private func play(_ hit: SearchExperience) {
        model.home.rememberRecent(hit.asGame())
        Task { await model.playPlace(hit.placeID, title: hit.title) }
    }

    private func formatted(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }
}
