import AppKit
import Foundation
import WebKit

struct InstanceWebMod: Codable, Equatable, Identifiable {
    var id: String
    var isEnabled: Bool
}

struct WebModRecord: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var version: String
    var detail: String
    var iconName: String?
}

struct WebModPack: Equatable {
    var id: String
    var source: String
}

@MainActor
@Observable
final class WebModLibrary {
    static let shared = WebModLibrary()

    var records: [WebModRecord] = []
    var installingID: String?
    var lastError: String?

    @ObservationIgnored private var cachedPacks: [String: WebModPack] = [:]

    private static var root: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/RoBlow/Extensions", isDirectory: true)
    }

    private static var indexURL: URL {
        root.appendingPathComponent("index.json")
    }

    init() {
        loadIndex()
    }

    func record(for id: String) -> WebModRecord? {
        records.first(where: { $0.id == id })
    }

    func icon(for id: String) -> NSImage? {
        guard let record = record(for: id), let name = record.iconName else { return nil }
        let url = Self.root.appendingPathComponent(id, isDirectory: true).appendingPathComponent(name)
        return NSImage(contentsOf: url)
    }

    func folder(for id: String) -> URL {
        Self.root.appendingPathComponent(id, isDirectory: true)
    }

    func packs(for mods: [InstanceWebMod], matching url: URL?) -> [WebModPack] {
        mods.compactMap { mod in
            guard mod.isEnabled else { return nil }
            return pack(for: mod.id, matching: url)
        }
    }

    func pack(for id: String, matching url: URL?) -> WebModPack? {
        if let cached = cachedPacks[id] { return cached }
        guard let built = buildPack(id: id, matching: url) else { return nil }
        cachedPacks[id] = built
        return built
    }

    func install(id: String) async throws -> WebModRecord {
        let clean = ChromeStore.normalizeID(id)
        guard ChromeStore.isExtensionID(clean) else {
            throw WebModError.badID
        }
        installingID = clean
        lastError = nil
        defer { installingID = nil }
        do {
            let crx = try await ChromeStore.downloadCRX(id: clean)
            let zip = try CRXFile.zipPayload(from: crx)
            let dest = folder(for: clean)
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
            try CRXFile.unzip(zip, to: dest)
            let record = try readRecord(id: clean)
            cachedPacks[clean] = nil
            upsert(record)
            persistIndex()
            return record
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    func removeFromLibrary(_ id: String) {
        records.removeAll { $0.id == id }
        cachedPacks[id] = nil
        try? FileManager.default.removeItem(at: folder(for: id))
        persistIndex()
    }

    private func upsert(_ record: WebModRecord) {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else {
            records.append(record)
        }
    }

    private func loadIndex() {
        guard let data = try? Data(contentsOf: Self.indexURL),
              let saved = try? JSONDecoder().decode([WebModRecord].self, from: data)
        else { return }
        records = saved
    }

    private func persistIndex() {
        try? FileManager.default.createDirectory(at: Self.root, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: Self.indexURL, options: .atomic)
        }
    }

    private func readRecord(id: String) throws -> WebModRecord {
        let root = folder(for: id)
        let manifestURL = root.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw WebModError.badManifest
        }
        let locale = (json["default_locale"] as? String) ?? "en"
        var name = json["name"] as? String ?? id
        var detail = json["description"] as? String ?? "Chrome extension"
        name = localize(name, locale: locale, root: root)
        detail = localize(detail, locale: locale, root: root)
        let version = json["version"] as? String ?? ""
        let iconName = pickIcon(json["icons"], root: root)
        return WebModRecord(id: id, name: name, version: version, detail: detail, iconName: iconName)
    }

    private func localize(_ value: String, locale: String, root: URL) -> String {
        guard value.hasPrefix("__MSG_"), value.hasSuffix("__") else { return value }
        let key = String(value.dropFirst(6).dropLast(2))
        for folder in [locale, "en", "en_US"] {
            let url = root.appendingPathComponent("_locales/\(folder)/messages.json")
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let entry = json[key] as? [String: Any],
                  let message = entry["message"] as? String
            else { continue }
            return message
        }
        return value
    }

    private func pickIcon(_ raw: Any?, root: URL) -> String? {
        guard let icons = raw as? [String: Any] else { return nil }
        let keys = icons.keys.compactMap(Int.init).sorted(by: >)
        for key in keys {
            if let path = icons["\(key)"] as? String, FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path) {
                return path
            }
        }
        if let path = icons.values.compactMap({ $0 as? String }).first,
           FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path) {
            return path
        }
        return nil
    }

    private func buildPack(id: String, matching url: URL?) -> WebModPack? {
        let root = folder(for: id)
        let manifestURL = root.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let scripts = (json["content_scripts"] as? [[String: Any]]) ?? []
        let page = url ?? URL(string: "https://www.roblox.com/home")!
        var files: [String] = []
        var seen = Set<String>()

        let groups = scripts.isEmpty ? [[String: Any]()] : scripts
        for script in groups {
            let matches = (script["matches"] as? [String]) ?? ["<all_urls>"]
            let hits = matches.contains(where: {
                $0 == "<all_urls>" || $0.contains("roblox.com") || ChromeStore.matches($0, url: page)
            })
            if !hits && !scripts.isEmpty { continue }
            for file in (script["js"] as? [String]) ?? [] {
                if seen.insert(file).inserted, let text = readText(root: root, relative: file) {
                    files.append(text)
                }
            }
        }

        if files.isEmpty {
            for script in scripts {
                for file in (script["js"] as? [String]) ?? [] {
                    if seen.insert(file).inserted, let text = readText(root: root, relative: file) {
                        files.append(text)
                    }
                }
            }
        }

        guard !files.isEmpty else { return nil }
        let assets = collectTextAssets(root: root)
        let source = WebModInject.host(id: id, manifest: json, files: assets) + "\n;\n" + files.joined(separator: "\n;\n")
        return WebModPack(id: id, source: source)
    }

    private func collectTextAssets(root: URL) -> [String: String] {
        var assets: [String: String] = [:]
        let allowed: Set<String> = ["css", "svg", "json", "html", "txt", "xml"]
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return assets
        }
        for case let file as URL in walker {
            guard allowed.contains(file.pathExtension.lowercased()) else { continue }
            let relative = file.path.replacingOccurrences(of: root.path + "/", with: "")
            if relative.hasPrefix("_metadata") { continue }
            if let text = readText(root: root, relative: relative) {
                assets[relative] = text
            }
        }
        return assets
    }

    private func readText(root: URL, relative: String) -> String? {
        let url = root.appendingPathComponent(relative).standardizedFileURL
        guard url.path.hasPrefix(root.standardizedFileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: url), data.count < 6_000_000 else { return nil }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
    }
}

enum WebModError: LocalizedError {
    case badID
    case badManifest
    case download
    case unpack
    case store

    var errorDescription: String? {
        switch self {
        case .badID: "That is not a Chrome extension page."
        case .badManifest: "The extension had no readable manifest."
        case .download: "Could not download this extension."
        case .unpack: "Could not unpack this extension."
        case .store: "Could not load the Chrome Web Store catalog."
        }
    }
}

struct StoreListing: Identifiable, Hashable {
    var id: String
    var name: String
    var detail: String
    var iconURL: String?
    var rating: Double?
    var ratings: Int?
}

enum ChromeStore {
    static let home = URL(string: "https://chromewebstore.google.com/category/extensions?hl=en")!
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.6778.86 Safari/537.36"

    static let lanes: [(id: String, title: String, url: URL)] = [
        ("featured", "Featured", URL(string: "https://chromewebstore.google.com/category/extensions?hl=en")!),
        ("tools", "Tools", URL(string: "https://chromewebstore.google.com/category/extensions/productivity/tools?hl=en")!),
        ("workflow", "Workflow", URL(string: "https://chromewebstore.google.com/category/extensions/productivity/workflow?hl=en")!),
        ("developer", "Developer", URL(string: "https://chromewebstore.google.com/category/extensions/productivity/developer?hl=en")!),
        ("fun", "Fun", URL(string: "https://chromewebstore.google.com/category/extensions/lifestyle/fun?hl=en")!),
        ("roblox", "Roblox", URL(string: "https://chromewebstore.google.com/search/roblox?hl=en")!)
    ]

    static func searchURL(_ query: String) -> URL {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if isExtensionID(normalizeID(trimmed)) {
            return detailURL(id: normalizeID(trimmed))
        }
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://chromewebstore.google.com/search/\(encoded)?hl=en")
        else { return home }
        return url
    }

    static func loadListings(from url: URL) async throws -> [StoreListing] {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<400).contains(code), let html = String(data: data, encoding: .utf8) else {
            throw WebModError.store
        }
        let items = listings(from: html)
        if items.isEmpty { throw WebModError.store }
        return items
    }

    static func listings(from html: String) -> [StoreListing] {
        var found: [StoreListing] = []
        var seen = Set<String>()
        var searchStart = html.startIndex
        while let marker = html.range(of: "AF_initDataCallback(", range: searchStart..<html.endIndex) {
            if let dataStart = html.range(of: "data:", range: marker.upperBound..<html.endIndex),
               let side = html.range(of: ", sideChannel", range: dataStart.upperBound..<html.endIndex) {
                let blob = String(html[dataStart.upperBound..<side.lowerBound])
                if let raw = blob.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: raw) {
                    collect(json, into: &found, seen: &seen)
                }
            }
            searchStart = marker.upperBound
        }
        if found.isEmpty {
            collectIDs(html, into: &found, seen: &seen)
        }
        return found
    }

    private static func collect(_ node: Any, into found: inout [StoreListing], seen: inout Set<String>) {
        guard let array = node as? [Any] else { return }
        if array.count >= 3,
           let id = array[0] as? String, isExtensionID(id),
           let name = array[2] as? String, !name.isEmpty, seen.insert(id).inserted {
            let icon = array.count > 1 ? array[1] as? String : nil
            let detail: String = {
                if array.count > 6, let text = array[6] as? String, !text.isEmpty { return text }
                return name
            }()
            let rating = (array[safe: 3] as? Double) ?? (array[safe: 3] as? NSNumber)?.doubleValue
            let ratings = (array[safe: 4] as? Int) ?? (array[safe: 4] as? NSNumber)?.intValue
            found.append(StoreListing(
                id: id,
                name: name,
                detail: detail,
                iconURL: icon?.hasPrefix("http") == true ? icon : nil,
                rating: rating,
                ratings: ratings
            ))
        }
        for child in array {
            collect(child, into: &found, seen: &seen)
        }
    }

    private static func collectIDs(_ html: String, into found: inout [StoreListing], seen: inout Set<String>) {
        guard let regex = try? NSRegularExpression(pattern: #"(?<![a-z])([a-p]{32})(?![a-z])"#) else { return }
        let ns = html as NSString
        for match in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let id = ns.substring(with: match.range(at: 1))
            if seen.insert(id).inserted {
                found.append(StoreListing(id: id, name: id, detail: "Chrome extension", iconURL: nil, rating: nil, ratings: nil))
            }
        }
    }

    static func detailURL(id: String) -> URL {
        URL(string: "https://chromewebstore.google.com/detail/\(id)") ?? home
    }

    static func isExtensionID(_ value: String) -> Bool {
        value.count == 32 && value.unicodeScalars.allSatisfy { CharacterSet.lowercaseLetters.contains($0) }
    }

    static func normalizeID(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func extensionID(in url: URL?) -> String? {
        guard let url else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        for part in parts.reversed() {
            let id = normalizeID(part)
            if isExtensionID(id) { return id }
        }
        if let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            for item in items where item.name == "id" {
                if let value = item.value, isExtensionID(normalizeID(value)) {
                    return normalizeID(value)
                }
            }
        }
        return nil
    }

    static func matches(_ pattern: String, url: URL) -> Bool {
        ChromeMatch.matches(pattern, url: url)
    }

    static func downloadCRX(id: String) async throws -> Data {
        let templates = [
            "https://clients2.google.com/service/update2/crx?response=redirect&prodversion=130.0.0.0&acceptformat=crx2,crx3&x=id%3D\(id)%26uc",
            "https://clients2.google.com/service/update2/crx?response=redirect&os=win&arch=x64&os_arch=x86_64&nacl_arch=x86-64&prod=chromecrx&prodchannel=unknown&prodversion=130.0.0.0&acceptformat=crx2,crx3&x=id%3D\(id)%26uc",
            "https://clients2.google.com/service/update2/crx?response=redirect&os=mac&arch=x64&os_arch=x86_64&nacl_arch=x86-64&prod=chromecrx&prodchannel=unknown&prodversion=131.0.6778.86&acceptformat=crx2,crx3&x=id%3D\(id)%26installsource%3Dondemand%26uc"
        ]
        for template in templates {
            guard let url = URL(string: template) else { continue }
            var request = URLRequest(url: url)
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("application/x-chrome-extension,*/*", forHTTPHeaderField: "Accept")
            guard let (data, response) = try? await URLSession.shared.data(for: request) else { continue }
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200..<400).contains(code), data.count > 16, data.starts(with: Data("Cr24".utf8)) {
                return data
            }
        }
        throw WebModError.download
    }
}

enum CRXFile {
    static func zipPayload(from crx: Data) throws -> Data {
        guard crx.count > 16, crx.starts(with: Data("Cr24".utf8)) else {
            throw WebModError.unpack
        }
        let version = u32(crx, 4)
        if version == 2 {
            let offset = 16 + Int(u32(crx, 8)) + Int(u32(crx, 12))
            guard offset < crx.count else { throw WebModError.unpack }
            return crx.subdata(in: offset..<crx.count)
        }
        if version == 3 {
            let offset = 12 + Int(u32(crx, 8))
            guard offset < crx.count else { throw WebModError.unpack }
            return crx.subdata(in: offset..<crx.count)
        }
        throw WebModError.unpack
    }

    static func unzip(_ zip: Data, to dest: URL) throws {
        let temp = dest.appendingPathExtension("zip")
        try zip.write(to: temp, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temp) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", temp.path, dest.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw WebModError.unpack }
        if !FileManager.default.fileExists(atPath: dest.appendingPathComponent("manifest.json").path) {
            try flatten(dest)
        }
        guard FileManager.default.fileExists(atPath: dest.appendingPathComponent("manifest.json").path) else {
            throw WebModError.badManifest
        }
    }

    private static func u32(_ data: Data, _ offset: Int) -> UInt32 {
        data.subdata(in: offset..<(offset + 4)).withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian
    }

    private static func flatten(_ dest: URL) throws {
        let children = (try? FileManager.default.contentsOfDirectory(at: dest, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        guard let nested = children.first(where: {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                && FileManager.default.fileExists(atPath: $0.appendingPathComponent("manifest.json").path)
        }) else { return }
        let files = try FileManager.default.contentsOfDirectory(at: nested, includingPropertiesForKeys: nil)
        for file in files {
            let target = dest.appendingPathComponent(file.lastPathComponent)
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.moveItem(at: file, to: target)
        }
        try? FileManager.default.removeItem(at: nested)
    }
}

enum WebModInject {
    static func host(id: String, manifest: [String: Any], files: [String: String]) -> String {
        let manifestJSON = jsonValue(manifest)
        let filesJSON = jsonValue(files)
        return """
        "use strict";
        (() => {
          try {
            if (document.contentType !== "text/html") {
              Object.defineProperty(document, "contentType", { configurable: true, value: "text/html" });
            }
          } catch (_) {}
          const ID = \(jsonValue(id));
          const MANIFEST = \(manifestJSON);
          const FILES = \(filesJSON);
          const empty = { addListener() {}, removeListener() {}, hasListener() { return false; } };
          const mem = {};
          const replyHandlers = [];
          function reply(info, data) {
            if (info == null || info.id == null) return;
            queueMicrotask(() => {
              replyHandlers.forEach((fn) => fn({ id: info.id, data, final: true }));
            });
          }
          window.chrome = window.chrome || {};
          chrome.runtime = {
            id: ID,
            lastError: null,
            getManifest() { return MANIFEST; },
            getURL(path) {
              const clean = String(path || "").replace(/^\\//, "").split("?")[0];
              if (Object.prototype.hasOwnProperty.call(FILES, clean)) {
                const mime = /\\.css$/i.test(clean) ? "text/css" : "text/plain";
                return "data:" + mime + ";charset=utf-8," + encodeURIComponent(FILES[clean]);
              }
              return "rbxext://" + ID + "/" + clean;
            },
            sendMessage(a, b, c) {
              const cb = typeof c === "function" ? c : (typeof b === "function" ? b : null);
              if (cb) cb();
              return Promise.resolve();
            },
            connect() {
              return {
                onMessage: {
                  addListener(fn) { replyHandlers.push(fn); },
                  removeListener() {},
                  hasListener() { return false; }
                },
                onDisconnect: empty,
                disconnect() {},
                postMessage(info) {
                  const name = info && info.name;
                  if (name === "checkPermissions" || name === "requestPermissions") reply(info, true);
                  else if (name === "getSharedData") reply(info, { version: 1, settings: { _version: 2 } });
                  else reply(info);
                }
              };
            },
            onMessage: empty,
            onInstalled: empty,
            onStartup: empty,
            onConnect: empty
          };
          chrome.extension = { getBackgroundPage() { return null; }, getURL: chrome.runtime.getURL };
          const area = {
            get(keys, cb) {
              let out = {};
              if (keys == null) out = Object.assign({}, mem);
              else if (typeof keys === "string") out[keys] = mem[keys];
              else if (Array.isArray(keys)) keys.forEach((k) => { out[k] = mem[k]; });
              else if (typeof keys === "object") Object.keys(keys).forEach((k) => { out[k] = mem[k] ?? keys[k]; });
              if (cb) cb(out);
              return Promise.resolve(out);
            },
            set(items, cb) { Object.assign(mem, items || {}); if (cb) cb(); return Promise.resolve(); },
            remove(keys, cb) { (Array.isArray(keys) ? keys : [keys]).forEach((k) => { delete mem[k]; }); if (cb) cb(); return Promise.resolve(); },
            clear(cb) { Object.keys(mem).forEach((k) => { delete mem[k]; }); if (cb) cb(); return Promise.resolve(); }
          };
          chrome.storage = { local: area, sync: area, onChanged: empty };
          chrome.permissions = {
            contains(p, cb) { if (cb) cb(true); return Promise.resolve(true); },
            request(p, cb) { if (cb) cb(true); return Promise.resolve(true); },
            onAdded: empty,
            onRemoved: empty
          };
          chrome.declarativeNetRequest = { updateDynamicRules() { return Promise.resolve(); } };
          chrome.i18n = { getMessage(name) { return name || ""; } };
          chrome.tabs = { query(info, cb) { if (cb) cb([]); return Promise.resolve([]); }, sendMessage() {}, create() {} };
          chrome.action = { onClicked: empty };
          chrome.browserAction = chrome.action;
          chrome.scripting = { executeScript() { return Promise.resolve([]); } };
          chrome.contextMenus = { create() {}, update() {}, remove() {}, removeAll() {}, onClicked: empty };
        })();
        """
    }

    private static func jsonValue(_ value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(value) || value is String || value is NSNumber || value is NSNull else {
            return "{}"
        }
        let data = (try? JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)) ?? Data("{}".utf8)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

final class ExtSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        let id = url.host ?? ""
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let root = WebModLibrary.shared.folder(for: id).standardizedFileURL
        let file = root.appendingPathComponent(path).standardizedFileURL
        guard file.path.hasPrefix(root.path), let data = try? Data(contentsOf: file) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let mime: String
        switch file.pathExtension.lowercased() {
        case "css": mime = "text/css"
        case "js": mime = "text/javascript"
        case "png": mime = "image/png"
        case "jpg", "jpeg": mime = "image/jpeg"
        case "svg": mime = "image/svg+xml"
        case "json": mime = "application/json"
        case "html": mime = "text/html"
        case "woff2": mime = "font/woff2"
        default: mime = "application/octet-stream"
        }
        let response = URLResponse(url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: "utf-8")
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
