import AppKit
import Foundation
import WebKit
import SwiftUI

enum RobloxAuthError: LocalizedError {
    case invalidCookie
    case ticketDenied
    case network

    var errorDescription: String? {
        switch self {
        case .invalidCookie: "That Roblox session expired. Add the account again."
        case .ticketDenied: "Roblox refused the login ticket."
        case .network: "Could not reach Roblox."
        }
    }
}

enum RobloxSecrets {
    private static let service = "com.goldknow.RoBlow.account"

    static func cookie(for userID: Int) -> String? {
        if let keychain = keychainCookie(for: userID), !keychain.isEmpty {
            return keychain
        }
        return fileCookie(for: userID)
    }

    static func setCookie(_ cookie: String, for userID: Int) {
        setKeychainCookie(cookie, for: userID)
        setFileCookie(cookie, for: userID)
    }

    static func deleteCookie(for userID: Int) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: String(userID)
        ]
        SecItemDelete(query as CFDictionary)
        try? FileManager.default.removeItem(at: fileURL(for: userID))
    }

    static func cookieFromPlayerInstall() -> String? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/HTTPStorages/com.roblox.RobloxPlayer.binarycookies")
        guard let data = try? Data(contentsOf: url),
              let blob = String(data: data, encoding: .isoLatin1) ?? String(data: data, encoding: .ascii)
        else { return nil }

        let pattern = #"_\|WARNING:-DO-NOT-SHARE-THIS\.[^|]*\|_[A-Za-z0-9]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: blob, range: NSRange(blob.startIndex..., in: blob)),
              let range = Range(match.range, in: blob)
        else { return nil }
        return String(blob[range])
    }

    private static func keychainCookie(for userID: Int) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: String(userID),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let cookie = String(data: data, encoding: .utf8)
        else { return nil }
        return cookie
    }

    private static func setKeychainCookie(_ cookie: String, for userID: Int) {
        let account = String(userID)
        let data = Data(cookie.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func fileCookie(for userID: Int) -> String? {
        guard let data = try? Data(contentsOf: fileURL(for: userID)),
              let cookie = String(data: data, encoding: .utf8),
              !cookie.isEmpty
        else { return nil }
        return cookie
    }

    private static func setFileCookie(_ cookie: String, for userID: Int) {
        let url = fileURL(for: userID)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data(cookie.utf8).write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private static func fileURL(for userID: Int) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/RoBlow/secrets/\(userID).session")
    }
}

enum RobloxAuth {
    static func profile(from cookie: String) async throws -> AccountProfile {
        var request = URLRequest(url: URL(string: "https://users.roblox.com/v1/users/authenticated")!)
        apply(cookie: cookie, to: &request)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let userID = json["id"] as? Int,
              let username = json["name"] as? String
        else { throw RobloxAuthError.invalidCookie }

        let display = (json["displayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (display?.isEmpty == false ? display : username) ?? username
        let avatar = await avatarURL(for: userID)
        return AccountProfile(
            userID: userID,
            displayName: name,
            username: username,
            initials: initials(from: name),
            hue: Double(userID % 360) / 360,
            avatarURL: avatar
        )
    }

    static func authenticationTicket(cookie: String) async throws -> String {
        let csrf = try await csrfToken(cookie: cookie)
        var request = URLRequest(url: URL(string: "https://auth.roblox.com/v1/authentication-ticket")!)
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        apply(cookie: cookie, to: &request)
        request.setValue(csrf, forHTTPHeaderField: "X-CSRF-TOKEN")
        request.setValue("https://www.roblox.com/develop", forHTTPHeaderField: "Referer")
        request.setValue("https://www.roblox.com", forHTTPHeaderField: "Origin")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              let ticket = http.value(forHTTPHeaderField: "rbx-authentication-ticket"),
              !ticket.isEmpty
        else { throw RobloxAuthError.ticketDenied }
        return ticket
    }

    static func playerLaunchURL(ticket: String, placeID: String? = nil, linkCode: String? = nil) -> URL? {
        let time = Int(Date().timeIntervalSince1970 * 1000)
        let tracker = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        var spec = "roblox-player:1+launchmode:play+gameinfo:\(ticket)+launchtime:\(time)+browsertrackerid:\(tracker)+robloxLocale:en_us+gameLocale:en_us"
        if let placeID {
            var launcher = "https://assetgame.roblox.com/game/PlaceLauncher.ashx?request=RequestGame&placeId=\(placeID)&isPlayTogetherGame=false"
            if let linkCode, !linkCode.isEmpty {
                launcher = "https://assetgame.roblox.com/game/PlaceLauncher.ashx?request=RequestPrivateGame&placeId=\(placeID)&linkCode=\(linkCode)"
            }
            let encoded = launcher.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? launcher
            spec += "+placelauncherurl:\(encoded)"
        }
        return URL(string: spec)
    }

    private static func csrfToken(cookie: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://auth.roblox.com/v1/authentication-ticket")!)
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        apply(cookie: cookie, to: &request)
        request.setValue("https://www.roblox.com", forHTTPHeaderField: "Referer")
        request.setValue("https://www.roblox.com", forHTTPHeaderField: "Origin")
        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse,
           let token = http.value(forHTTPHeaderField: "x-csrf-token"),
           !token.isEmpty {
            return token
        }
        throw RobloxAuthError.ticketDenied
    }

    private static func avatarURL(for userID: Int) async -> String? {
        guard let url = URL(string: "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=\(userID)&size=150x150&format=Png") else {
            return nil
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["data"] as? [[String: Any]]
        else { return nil }
        return list.first?["imageUrl"] as? String
    }

    static func apply(cookie: String, to request: inout URLRequest) {
        request.httpShouldHandleCookies = false
        request.setValue(".ROBLOSECURITY=\(cookie)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
    }

    private static func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(1)).uppercased()
    }
}

struct RobloxLoginSheet: View {
    var onSignedIn: (AccountProfile, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var status = "Sign in to add this account to RoBlow."
    @State private var isFinishing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Add Roblox account")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.controlInk)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
            }

            Text(status)
                .font(.system(size: 12))
                .foregroundStyle(Theme.controlInk.opacity(0.55))

            RobloxLoginWebView(isFinishing: $isFinishing) { cookie in
                Task { await finish(cookie: cookie) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .frame(width: 760, height: 620)
        .background(GlassSurface(style: .panel, cornerRadius: 22))
    }

    @MainActor
    private func finish(cookie: String) async {
        guard !isFinishing else { return }
        isFinishing = true
        status = "Saving account…"
        do {
            let profile = try await RobloxAuth.profile(from: cookie)
            onSignedIn(profile, cookie)
            dismiss()
        } catch {
            isFinishing = false
            status = error.localizedDescription
        }
    }
}

struct RobloxLoginWebView: NSViewRepresentable {
    @Binding var isFinishing: Bool
    var onCookie: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isFinishing: $isFinishing, onCookie: onCookie)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
        view.navigationDelegate = context.coordinator
        context.coordinator.webView = view
        view.configuration.websiteDataStore.httpCookieStore.add(context.coordinator)
        if let url = URL(string: "https://www.roblox.com/login") {
            view.load(URLRequest(url: url))
        }
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.onCookie = onCookie
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKHTTPCookieStoreObserver {
        var webView: WKWebView?
        var onCookie: (String) -> Void
        var isFinishing: Binding<Bool>
        private var captured = false

        init(isFinishing: Binding<Bool>, onCookie: @escaping (String) -> Void) {
            self.isFinishing = isFinishing
            self.onCookie = onCookie
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            inspectCookies()
        }

        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            inspectCookies()
        }

        private func inspectCookies() {
            guard !captured, !isFinishing.wrappedValue else { return }
            webView?.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self, !self.captured else { return }
                guard let cookie = cookies.first(where: { $0.name == ".ROBLOSECURITY" })?.value,
                      cookie.contains("WARNING:-DO-NOT-SHARE-THIS")
                else { return }
                self.captured = true
                DispatchQueue.main.async {
                    self.onCookie(cookie)
                }
            }
        }
    }
}
