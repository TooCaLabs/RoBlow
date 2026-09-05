import AppKit
import Foundation

@MainActor
@Observable
final class QuickTerm {
    var isEnabled = false
    var isOpen = false
    var input = ""
    var lines: [Line] = []
    var openKey = ";"
    var binds: [String: String] = [:]

    @ObservationIgnored private var history: [String] = []
    @ObservationIgnored private var historyIndex: Int?
    @ObservationIgnored private var lastConsumedKey: String?
    @ObservationIgnored private var lastConsumedAt: Date?
    @ObservationIgnored var webIsTyping = false
    @ObservationIgnored private static let bindsKey = "roblox.newui.quick.binds"
    @ObservationIgnored private static let openKeyKey = "roblox.newui.quick.open"
    @ObservationIgnored private static let enabledKey = "roblox.newui.quick.enabled"

    struct Line: Identifiable, Hashable {
        let id = UUID()
        var kind: Kind
        var text: String

        enum Kind { case out, err, cmd }
    }

    static let commands: [(name: String, usage: String, detail: String)] = [
        ("help", "help", "List commands"),
        ("menu", "menu", "Roblox menu map"),
        ("home", "home", "Roblox Home"),
        ("discover", "discover", "Discover"),
        ("charts", "charts", "Charts"),
        ("search", "search [query]", "Search"),
        ("avatar", "avatar", "Avatar Editor"),
        ("inventory", "inventory", "Inventory"),
        ("friends", "friends", "Friends"),
        ("messages", "messages", "Messages"),
        ("groups", "groups", "Communities"),
        ("profile", "profile", "Your profile"),
        ("catalog", "catalog", "Catalog"),
        ("creator", "creator", "Creator dashboard"),
        ("settings", "settings", "Roblox settings"),
        ("premium", "premium", "Premium"),
        ("go", "go <path>", "Open a roblox.com path"),
        ("play", "play <place|name>", "Launch a place"),
        ("install", "install [query]", "Chrome Web Store wrapper"),
        ("quick", "quick", "Toggle quick-mode"),
        ("bind", "bind [key] [command]", "Keybind menu, or set a bind"),
        ("unbind", "unbind <key>", "Remove a keybind"),
        ("binds", "binds", "List keybinds"),
        ("open", "open [key]", "Key that opens this terminal"),
        ("clear", "clear", "Clear the scrollback"),
        ("close", "close", "Close the terminal")
    ]

    init() {
        if let key = UserDefaults.standard.string(forKey: Self.openKeyKey), !key.isEmpty {
            openKey = key
        }
        if let data = UserDefaults.standard.data(forKey: Self.bindsKey),
           let saved = try? JSONDecoder().decode([String: String].self, from: data) {
            binds = saved
        }
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        if isEnabled {
            applyDefaults()
        }
        boot()
    }

    func setEnabled(_ on: Bool) {
        isEnabled = on
        if on {
            applyDefaults()
        } else {
            close()
        }
        persist()
    }

    func toggleEnabled() {
        setEnabled(!isEnabled)
    }

    func open() {
        isOpen = true
        input = ""
        historyIndex = nil
    }

    func close() {
        isOpen = false
        input = ""
        historyIndex = nil
        webIsTyping = false
    }

    func toggle() {
        if isOpen { close() } else { open() }
    }

    func submit(using model: AppModel) {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        input = ""
        historyIndex = nil
        guard !raw.isEmpty else { return }
        history.append(raw)
        print(.cmd, ">\(raw)")
        Task { await run(raw, model: model) }
    }

    func historyUp() {
        guard !history.isEmpty else { return }
        if historyIndex == nil {
            historyIndex = history.count - 1
        } else if let index = historyIndex, index > 0 {
            historyIndex = index - 1
        }
        if let index = historyIndex {
            input = history[index]
        }
    }

    func historyDown() {
        guard let index = historyIndex else { return }
        if index + 1 < history.count {
            historyIndex = index + 1
            input = history[index + 1]
        } else {
            historyIndex = nil
            input = ""
        }
    }

    func handleKey(_ event: NSEvent, model: AppModel) -> NSEvent? {
        guard case .newUI = model.selectedSidebarItem else { return event }
        if model.showWebModStore {
            if Self.normalize(event) == "esc" {
                model.closeWebModStore()
                return nil
            }
            return event
        }
        guard isEnabled || isOpen else { return event }
        let key = Self.normalize(event)
        if isOpen {
            if key == "esc" {
                close()
                return nil
            }
            if event.keyCode == 126 {
                historyUp()
                return nil
            }
            if event.keyCode == 125 {
                historyDown()
                return nil
            }
            return event
        }
        if Self.isEditingText() || webIsTyping || Self.isWebViewFirstResponder() {
            return event
        }
        if consumeKey(key, model: model) {
            return nil
        }
        return event
    }

    var stealKeys: [String] {
        guard isEnabled else { return [] }
        return Array(Set([openKey] + binds.keys))
    }

    @discardableResult
    func consumeKey(_ key: String, model: AppModel) -> Bool {
        if isOpen || !isEnabled { return false }
        if Self.isEditingText() || webIsTyping { return false }
        let now = Date()
        if key == lastConsumedKey, let at = lastConsumedAt, now.timeIntervalSince(at) < 0.2 {
            return true
        }
        if key == openKey {
            lastConsumedKey = key
            lastConsumedAt = now
            open()
            return true
        }
        if let command = binds[key] {
            lastConsumedKey = key
            lastConsumedAt = now
            Task { await run(command, model: model) }
            return true
        }
        return false
    }

    func run(_ raw: String, model: AppModel) async {
        let parts = raw.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let name = parts.first?.lowercased() else { return }
        let args = Array(parts.dropFirst())

        switch name {
        case "help", "?":
            print(.out, "roblox menu")
            for command in Self.commands {
                print(.out, "  \(command.usage.padding(toLength: 22, withPad: " ", startingAt: 0)) \(command.detail)")
            }
            print(.out, "\(openKey) menu  ·  q leaves quick-mode  ·  esc closes menu")
        case "menu":
            print(.out, "home  discover  charts  search")
            print(.out, "avatar  inventory  friends  messages  groups  profile")
            print(.out, "catalog  creator  settings  premium")
            print(.out, "play <place>  go <path>")
        case "home":
            go("home", model: model)
        case "discover":
            go("discover", model: model)
        case "charts":
            go("charts", model: model)
        case "search":
            model.openNewUIPage(.search)
            if let query = args.joined(separator: " ").nilIfEmpty {
                model.search.query = query
                await model.search.search(cookie: RobloxSecrets.cookie(for: account(in: model).userID))
            }
            close()
        case "avatar":
            go("avatar", model: model)
        case "inventory":
            go("inventory", model: model)
        case "friends":
            go("friends", model: model)
        case "messages", "inbox":
            go("messages", model: model)
        case "groups", "communities":
            go("groups", model: model)
        case "profile":
            let userID = account(in: model).userID
            if userID != 0, let url = URL(string: "https://www.roblox.com/users/\(userID)/profile") {
                model.openNewUISite(url)
                close()
            } else {
                go("profile", model: model)
            }
        case "catalog", "shop":
            go("catalog", model: model)
        case "creator", "create":
            go("creator", model: model)
        case "settings", "account":
            go("settings", model: model)
        case "premium":
            go("premium", model: model)
        case "go":
            guard let path = args.joined(separator: " ").nilIfEmpty else {
                print(.err, "usage: go <path>")
                return
            }
            openPath(path, model: model)
            close()
        case "install", "store":
            let query: String?
            if args.first?.lowercased() == "mods" {
                query = args.dropFirst().joined(separator: " ").nilIfEmpty
            } else {
                query = args.joined(separator: " ").nilIfEmpty
            }
            model.openWebModStore(for: model.newUISlot, query: query)
            close()
        case "play":
            guard let query = args.joined(separator: " ").nilIfEmpty else {
                print(.err, "usage: play <place|name>")
                return
            }
            if query.allSatisfy(\.isNumber) {
                await model.playPlace(query)
            } else {
                model.search.query = query
                if let hit = await model.search.feelingLucky(cookie: RobloxSecrets.cookie(for: account(in: model).userID)) {
                    await model.playPlace(hit.placeID, title: hit.title)
                } else {
                    print(.err, "nothing for \(query)")
                    return
                }
            }
            close()
        case "quick":
            setEnabled(false)
            print(.out, "quick-mode off")
        case "bind":
            bind(args)
        case "unbind":
            guard let key = args.first else {
                print(.err, "usage: unbind <key>")
                return
            }
            binds.removeValue(forKey: key.lowercased())
            persist()
            print(.out, "unbound \(key)")
        case "binds":
            listBinds()
        case "open":
            if let key = args.first?.lowercased() {
                openKey = key
                persist()
                print(.out, "open key is \(key)")
            } else {
                print(.out, "open key is \(openKey)")
            }
        case "clear":
            lines = []
            boot()
        case "close", "q", "quit", "exit":
            close()
        default:
            print(.err, "unknown: \(name)  try help")
        }
    }

    private func bind(_ args: [String]) {
        if args.isEmpty {
            print(.out, "keybinds")
            print(.out, "  open                 \(openKey)")
            for command in Self.commands where command.name != "bind" && command.name != "unbind" && command.name != "binds" && command.name != "open" {
                let keys = binds.filter { $0.value == command.name }.map(\.key).sorted().joined(separator: ", ")
                print(.out, "  \(command.name.padding(toLength: 20, withPad: " ", startingAt: 0)) \(keys.isEmpty ? "-" : keys)")
            }
            print(.out, "  bind <key> <command>")
            print(.out, "  bind open <key>")
            print(.out, "  unbind <key>")
            return
        }
        if args.count == 2, args[0].lowercased() == "open" {
            openKey = args[1].lowercased()
            persist()
            print(.out, "open key is \(openKey)")
            return
        }
        guard args.count >= 2 else {
            print(.err, "usage: bind <key> <command>")
            return
        }
        let key = args[0].lowercased()
        let command = args.dropFirst().joined(separator: " ")
        binds[key] = command
        persist()
        print(.out, "\(key) -> \(command)")
        print(.out, "esc, then press \(key) on the page")
    }

    private func listBinds() {
        print(.out, "  \(openKey) -> open")
        if binds.isEmpty {
            print(.out, "  no other binds")
            return
        }
        for key in binds.keys.sorted() {
            print(.out, "  \(key) -> \(binds[key] ?? "")")
        }
    }

    private func account(in model: AppModel) -> AccountProfile {
        if let slot = model.newUISlot {
            return model.account(for: slot)
        }
        return model.home.activeAccount
    }

    private func go(_ name: String, model: AppModel) {
        switch name {
        case "home":
            model.openNewUIPage(.home)
        case "discover":
            model.openNewUIPage(.discover)
        default:
            if let url = Self.routes[name] {
                model.openNewUISite(url)
            } else {
                print(.err, "no menu \(name)")
                return
            }
        }
        close()
    }

    private func openPath(_ path: String, model: AppModel) {
        if path.hasPrefix("http"), let url = URL(string: path) {
            model.openNewUISite(url)
            return
        }
        let trimmed = path.hasPrefix("/") ? path : "/\(path)"
        if let url = URL(string: "https://www.roblox.com\(trimmed)") {
            model.openNewUISite(url)
        }
    }

    private func boot() {
        lines = [
            Line(kind: .out, text: "quick-mode"),
            Line(kind: .out, text: "help  ·  \(openKey) menu  ·  q leaves  ·  binds")
        ]
    }

    private static let routes: [String: URL] = [
        "charts": URL(string: "https://www.roblox.com/charts")!,
        "avatar": URL(string: "https://www.roblox.com/my/avatar")!,
        "inventory": URL(string: "https://www.roblox.com/users/inventory")!,
        "friends": URL(string: "https://www.roblox.com/users/friends")!,
        "messages": URL(string: "https://www.roblox.com/my/messages")!,
        "groups": URL(string: "https://www.roblox.com/communities")!,
        "profile": URL(string: "https://www.roblox.com/users/profile")!,
        "catalog": URL(string: "https://www.roblox.com/catalog")!,
        "creator": URL(string: "https://create.roblox.com")!,
        "settings": URL(string: "https://www.roblox.com/my/account")!,
        "premium": URL(string: "https://www.roblox.com/premium/membership")!
    ]

    private func print(_ kind: Line.Kind, _ text: String) {
        for chunk in text.split(separator: "\n", omittingEmptySubsequences: false) {
            lines.append(Line(kind: kind, text: String(chunk)))
        }
        if lines.count > 400 {
            lines.removeFirst(lines.count - 400)
        }
    }

    private func applyDefaults() {
        for (key, command) in Self.defaultBinds {
            if binds[key] != nil { continue }
            if binds.contains(where: { $0.value.split(separator: " ").first.map(String.init) == command }) {
                continue
            }
            binds[key] = command
        }
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
        UserDefaults.standard.set(openKey, forKey: Self.openKeyKey)
        if let data = try? JSONEncoder().encode(binds) {
            UserDefaults.standard.set(data, forKey: Self.bindsKey)
        }
    }

    static let defaultBinds: [String: String] = [
        "h": "home",
        "d": "discover",
        "c": "charts",
        "s": "search",
        "a": "avatar",
        "i": "inventory",
        "f": "friends",
        "m": "messages",
        "u": "groups",
        "p": "profile",
        "b": "catalog",
        "e": "creator",
        ",": "settings",
        "v": "premium",
        "q": "quick"
    ]

    static func normalize(_ event: NSEvent) -> String {
        if event.keyCode == 53 { return "esc" }
        if event.keyCode == 36 || event.keyCode == 76 { return "return" }
        if event.keyCode == 48 { return "tab" }
        if event.keyCode == 49 { return "space" }
        let chars = event.charactersIgnoringModifiers ?? ""
        if chars == ";" { return ";" }
        if chars.count == 1, let scalar = chars.lowercased().first {
            var key = String(scalar)
            if event.modifierFlags.contains(.shift), scalar.isLetter {
                key = "shift+\(key)"
            }
            return key
        }
        return chars.lowercased()
    }

    static func isEditingText() -> Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        if responder is NSTextView || responder is NSTextField {
            return true
        }
        var walk = responder as? NSView
        while let current = walk {
            if current is NSTextField || current is NSTextView {
                return true
            }
            walk = current.superview
        }
        return false
    }

    static func isWebViewFirstResponder() -> Bool {
        var walk = NSApp.keyWindow?.firstResponder as? NSView
        while let current = walk {
            let name = NSStringFromClass(type(of: current))
            if name.contains("WKWeb") || name.contains("WKContent") {
                return true
            }
            walk = current.superview
        }
        return false
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
