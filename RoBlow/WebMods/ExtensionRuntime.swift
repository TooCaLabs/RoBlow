import Foundation
import WebKit

enum ExtensionRuntime {
    static func install(ids: [String], into config: WKWebViewConfiguration, bus: ExtensionBus) {
        config.userContentController.add(bus, name: "extbus")
        config.userContentController.addUserScript(WKUserScript(
            source: matchHelper,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false,
            in: .page
        ))
        for id in ids {
            for script in preparedScripts(for: id) {
                config.userContentController.addUserScript(script)
            }
        }
    }

    static func preparedScripts(for id: String) -> [WKUserScript] {
        guard let loaded = LoadedExtension.load(id: id) else { return [] }
        var scripts: [WKUserScript] = []
        var needsIsolatedAPI = false

        for group in loaded.groups {
            if group.worldName != "MAIN" { needsIsolatedAPI = true }
            let time: WKUserScriptInjectionTime = group.runAt == .end ? .atDocumentEnd : .atDocumentStart
            for css in group.css {
                scripts.append(WKUserScript(
                    source: cssInjector(css, matches: group.matches, excluded: group.excluded),
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: !group.allFrames,
                    in: group.world
                ))
            }
            if !group.js.isEmpty {
                scripts.append(WKUserScript(
                    source: guardedScript(group.js, matches: group.matches, excluded: group.excluded),
                    injectionTime: time,
                    forMainFrameOnly: !group.allFrames,
                    in: group.world
                ))
            }
        }

        var prefixed: [WKUserScript] = []
        if needsIsolatedAPI {
            prefixed.append(WKUserScript(
                source: matchHelper + "\n" + chromeAPI(loaded, isBackground: false),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false,
                in: WKContentWorld.world(name: "ext-\(id)-ISOLATED")
            ))
        }
        return prefixed + scripts
    }

    static func backgroundScripts(for id: String) -> [WKUserScript] {
        guard let loaded = LoadedExtension.load(id: id) else { return [] }
        let files = loaded.backgroundFiles
        guard !files.isEmpty else { return [] }
        var scripts = [
            WKUserScript(
                source: chromeAPI(loaded, isBackground: true),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        ]
        for file in files {
            scripts.append(WKUserScript(source: file, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        return scripts
    }

    private static func cssInjector(_ css: String, matches: [String], excluded: [String]) -> String {
        """
        (() => {
          if (!globalThis.__rbExtShould(\(jsonValue(matches)), \(jsonValue(excluded)))) return;
          const style = document.createElement("style");
          style.textContent = \(jsonValue(css));
          const add = () => {
            const host = document.documentElement || document.head || document.body;
            if (host) host.appendChild(style);
          };
          if (document.documentElement || document.head) add();
          else document.addEventListener("DOMContentLoaded", add, { once: true });
        })();
        """
    }

    private static func guardedScript(_ js: String, matches: [String], excluded: [String]) -> String {
        """
        if (globalThis.__rbExtShould(\(jsonValue(matches)), \(jsonValue(excluded)))) {
        \(js)
        }
        """
    }

    static let matchHelper = #"""
    (() => {
      if (globalThis.__rbExtShould) return;
      function matchPattern(pattern, href) {
        if (pattern === "<all_urls>") return true;
        let url;
        try { url = new URL(href); } catch (_) { return false; }
        const split = pattern.indexOf("://");
        if (split < 0) return false;
        const scheme = pattern.slice(0, split);
        const rest = pattern.slice(split + 3);
        const slash = rest.indexOf("/");
        const host = slash >= 0 ? rest.slice(0, slash) : rest;
        const path = slash >= 0 ? rest.slice(slash) : "/";
        const urlScheme = url.protocol.replace(":", "");
        if (scheme !== "*" && scheme !== urlScheme) return false;
        const urlHost = (url.hostname || "").toLowerCase();
        if (host === "*") {
        } else if (host.startsWith("*.")) {
          const suffix = host.slice(2).toLowerCase();
          if (urlHost !== suffix && !urlHost.endsWith("." + suffix)) return false;
        } else if (host.toLowerCase() !== urlHost) {
          return false;
        }
        const escaped = path.replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*");
        const re = new RegExp("^" + escaped + "$");
        const urlPath = url.pathname || "/";
        return re.test(urlPath) || re.test(urlPath.endsWith("/") ? urlPath : urlPath + "/");
      }
      globalThis.__rbExtShould = function(matches, excluded) {
        const href = location.href;
        if ((excluded || []).some((p) => matchPattern(p, href))) return false;
        if (!matches || !matches.length) return true;
        return matches.some((p) => matchPattern(p, href));
      };
    })();
    """#

    private static func chromeAPI(_ ext: LoadedExtension, isBackground: Bool) -> String {
        let token = ext.id.replacingOccurrences(of: "-", with: "_")
        let files = isBackground ? ext.files : ext.pageFiles
        return """
        (() => {
          if (globalThis.__rbChrome_\(token)) return;
          globalThis.__rbChrome_\(token) = true;
          const ID = \(jsonValue(ext.id));
          const IS_BG = \(isBackground ? "true" : "false");
          const MANIFEST = \(jsonValue(ext.manifest));
          const FILES = \(jsonValue(files));
          const MESSAGES = \(jsonValue(ext.messages));
          try {
            if (typeof document !== "undefined" && document.contentType !== "text/html") {
              Object.defineProperty(document, "contentType", { configurable: true, value: "text/html" });
            }
          } catch (_) {}
          const empty = { addListener() {}, removeListener() {}, hasListener() { return false; } };
          const onMessage = [];
          const onConnect = [];
          const onInstalled = [];
          const onStartup = [];
          const pending = {};
          let mid = 1;
          let pid = 1;
          const ports = {};
          function post(body) {
            try { webkit.messageHandlers.extbus.postMessage(Object.assign({ ext: ID, bg: IS_BG }, body)); } catch (_) {}
          }
          function storageArea() {
            return {
              get(keys, cb) {
                return new Promise((resolve) => {
                  const id = mid++;
                  pending[id] = (value) => { if (cb) cb(value); resolve(value); };
                  post({ kind: "storage-get", mid: id, keys });
                });
              },
              set(items, cb) {
                return new Promise((resolve) => {
                  const id = mid++;
                  pending[id] = () => { if (cb) cb(); resolve(); };
                  post({ kind: "storage-set", mid: id, items: items || {} });
                });
              },
              remove(keys, cb) {
                return new Promise((resolve) => {
                  const id = mid++;
                  pending[id] = () => { if (cb) cb(); resolve(); };
                  post({ kind: "storage-remove", mid: id, keys });
                });
              },
              clear(cb) {
                return new Promise((resolve) => {
                  const id = mid++;
                  pending[id] = () => { if (cb) cb(); resolve(); };
                  post({ kind: "storage-clear", mid: id });
                });
              }
            };
          }
          globalThis.importScripts = function() {
            for (let i = 0; i < arguments.length; i++) {
              let path = String(arguments[i] || "").replace(/^.*:\\/\\/[^/]+\\//, "").replace(/^\\//, "");
              const text = FILES[path];
              if (text && text.indexOf("data:") !== 0) {
                (0, eval)(text);
              }
            }
          };
          globalThis.chrome = globalThis.chrome || {};
          chrome.runtime = {
            id: ID,
            lastError: null,
            getManifest() { return MANIFEST; },
            getURL(path) {
              const clean = String(path || "").replace(/^\\//, "").split("?")[0];
              if (Object.prototype.hasOwnProperty.call(FILES, clean)) {
                const value = FILES[clean];
                if (typeof value === "string" && value.indexOf("data:") === 0) return value;
                const mime = /\\.css$/i.test(clean) ? "text/css" : (/\\.js$/i.test(clean) ? "text/javascript" : "text/plain");
                return "data:" + mime + ";charset=utf-8," + encodeURIComponent(value);
              }
              return "rbxext://" + ID + "/" + clean;
            },
            sendMessage(a, b, c) {
              const cb = typeof c === "function" ? c : (typeof b === "function" ? b : (typeof a === "function" ? a : null));
              const payload = typeof a === "string" && a.length === 32 ? b : (typeof a === "function" ? undefined : a);
              return new Promise((resolve) => {
                const id = mid++;
                pending[id] = (value) => { if (cb) cb(value); resolve(value); };
                post({ kind: "send", mid: id, message: payload });
              });
            },
            connect(a, b) {
              const id = pid++;
              const listeners = [];
              ports[id] = listeners;
              post({ kind: "connect", pid: id });
              return {
                name: (b && b.name) || (a && a.name) || "",
                sender: { id: ID },
                onMessage: { addListener(fn) { listeners.push(fn); }, removeListener() {}, hasListener() { return false; } },
                onDisconnect: empty,
                disconnect() { post({ kind: "disconnect", pid: id }); },
                postMessage(data) { post({ kind: "port", pid: id, data }); }
              };
            },
            onMessage: {
              addListener(fn) { onMessage.push(fn); },
              removeListener(fn) { const i = onMessage.indexOf(fn); if (i >= 0) onMessage.splice(i, 1); },
              hasListener() { return onMessage.length > 0; }
            },
            onConnect: {
              addListener(fn) { onConnect.push(fn); },
              removeListener() {},
              hasListener() { return false; }
            },
            onInstalled: { addListener(fn) { onInstalled.push(fn); }, removeListener() {}, hasListener() { return false; } },
            onStartup: { addListener(fn) { onStartup.push(fn); }, removeListener() {}, hasListener() { return false; } },
            onMessageExternal: empty
          };
          chrome.extension = {
            getBackgroundPage() { return IS_BG ? globalThis : null; },
            getURL: chrome.runtime.getURL,
            inIncognitoContext: false
          };
          chrome.storage = { local: storageArea(), sync: storageArea(), onChanged: empty };
          chrome.permissions = {
            contains(p, cb) { if (cb) cb(true); return Promise.resolve(true); },
            request(p, cb) { if (cb) cb(true); return Promise.resolve(true); },
            getAll(cb) { const all = { origins: ["<all_urls>"], permissions: ["storage"] }; if (cb) cb(all); return Promise.resolve(all); },
            onAdded: empty,
            onRemoved: empty
          };
          chrome.declarativeNetRequest = {
            updateDynamicRules() { return Promise.resolve(); },
            getDynamicRules() { return Promise.resolve([]); }
          };
          chrome.i18n = {
            getMessage(name, subs) {
              const entry = MESSAGES[name];
              if (!entry) return "";
              let text = entry.message || "";
              const values = subs == null ? [] : (Array.isArray(subs) ? subs : [subs]);
              values.forEach((value, index) => { text = text.replace("$" + (index + 1), String(value)); });
              return text;
            },
            getUILanguage() { return "en"; }
          };
          chrome.tabs = {
            query(info, cb) {
              const href = (typeof location !== "undefined" && location.href) || "";
              const tabs = [{ id: 1, url: href, active: true, windowId: 1 }];
              if (cb) cb(tabs);
              return Promise.resolve(tabs);
            },
            sendMessage(tabId, msg, cb) { return chrome.runtime.sendMessage(msg, cb); },
            create(info, cb) { if (cb) cb({ id: 2 }); return Promise.resolve({ id: 2 }); },
            get(id, cb) { if (cb) cb({ id: 1, url: (typeof location !== "undefined" && location.href) || "" }); return Promise.resolve({ id: 1 }); },
            update() { return Promise.resolve({ id: 1 }); },
            onUpdated: empty,
            onActivated: empty,
            onRemoved: empty
          };
          chrome.windows = { getCurrent(cb) { if (cb) cb({ id: 1 }); return Promise.resolve({ id: 1 }); }, onFocusChanged: empty };
          chrome.action = { onClicked: empty, setIcon() {}, setBadgeText() {}, setTitle() {}, setBadgeBackgroundColor() {} };
          chrome.browserAction = chrome.action;
          chrome.scripting = { executeScript() { return Promise.resolve([]); }, insertCSS() { return Promise.resolve(); } };
          chrome.contextMenus = { create() {}, update() {}, remove() {}, removeAll() {}, onClicked: empty };
          chrome.alarms = { create() {}, clear() { return Promise.resolve(true); }, clearAll() { return Promise.resolve(true); }, getAll(cb) { if (cb) cb([]); return Promise.resolve([]); }, onAlarm: empty };
          chrome.notifications = { create() {}, clear() {}, onClicked: empty };
          chrome.webRequest = { onBeforeRequest: empty, onBeforeSendHeaders: empty, onHeadersReceived: empty, onCompleted: empty };
          chrome.webNavigation = { onCommitted: empty, onCompleted: empty, onDOMContentLoaded: empty };
          chrome.cookies = { get() { return Promise.resolve(null); }, getAll() { return Promise.resolve([]); }, set() { return Promise.resolve(null); } };
          chrome.management = { getSelf(cb) { const info = { id: ID, enabled: true, installType: "normal" }; if (cb) cb(info); return Promise.resolve(info); } };
          globalThis.browser = chrome;
          globalThis.__rbExtDeliver = function(kind, payload) {
            if (kind === "reply") {
              const fn = pending[payload.mid];
              delete pending[payload.mid];
              if (fn) fn(payload.data);
              return;
            }
            if (kind === "message") {
              const sender = { id: ID, url: payload.url || "", tab: { id: 1, url: payload.url || "" } };
              for (const fn of onMessage) {
                try {
                  const result = fn(payload.message, sender, (response) => {
                    post({ kind: "reply", mid: payload.mid, data: response });
                  });
                  if (result && typeof result.then === "function") {
                    result.then((value) => post({ kind: "reply", mid: payload.mid, data: value }));
                  } else if (result !== undefined && result !== true) {
                    post({ kind: "reply", mid: payload.mid, data: result });
                  }
                } catch (err) { console.warn("rb ext message", err); }
              }
              return;
            }
            if (kind === "port-in") {
              (ports[payload.pid] || []).forEach((fn) => { try { fn(payload.data); } catch (_) {} });
              return;
            }
            if (kind === "connect-in") {
              const listeners = [];
              ports[payload.pid] = listeners;
              const port = {
                name: "",
                sender: { id: ID, tab: { id: 1 } },
                onMessage: { addListener(fn) { listeners.push(fn); }, removeListener() {}, hasListener() { return false; } },
                onDisconnect: empty,
                disconnect() {},
                postMessage(data) { post({ kind: "port", pid: payload.pid, data }); }
              };
              onConnect.forEach((fn) => { try { fn(port); } catch (_) {} });
            }
          };
        })();
        """
    }

    static func jsonValue(_ value: Any) -> String {
        if JSONSerialization.isValidJSONObject(value) {
            let data = (try? JSONSerialization.data(withJSONObject: value)) ?? Data("{}".utf8)
            return String(data: data, encoding: .utf8) ?? "{}"
        }
        if let data = try? JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed) {
            return String(data: data, encoding: .utf8) ?? "null"
        }
        return "null"
    }
}

struct LoadedExtension {
    var id: String
    var manifest: [String: Any]
    var files: [String: String]
    var messages: [String: [String: String]]
    var groups: [Group]
    var backgroundFiles: [String]

    var pageFiles: [String: String] {
        let keep: Set<String> = ["css", "html", "svg", "json", "txt", "xml", "png", "jpg", "jpeg", "gif", "webp", "woff", "woff2"]
        return files.filter { keep.contains(($0.key as NSString).pathExtension.lowercased()) }
    }

    struct Group {
        var js: String
        var css: [String]
        var matches: [String]
        var excluded: [String]
        var runAt: RunAt
        var allFrames: Bool
        var worldName: String
        var world: WKContentWorld

        enum RunAt { case start, end }
    }

    static func load(id: String) -> LoadedExtension? {
        let root = WebModLibrary.shared.folder(for: id)
        let manifestURL = root.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let files = assetFiles(in: root)
        let locale = (manifest["default_locale"] as? String) ?? "en"
        let messages = loadMessages(root: root, locale: locale)
        let groups = contentGroups(id: id, manifest: manifest, root: root)
        let background = backgroundSources(manifest: manifest, root: root)
        return LoadedExtension(
            id: id,
            manifest: manifest,
            files: files,
            messages: messages,
            groups: groups,
            backgroundFiles: background
        )
    }

    private static func contentGroups(id: String, manifest: [String: Any], root: URL) -> [Group] {
        let raw = (manifest["content_scripts"] as? [[String: Any]]) ?? []
        var groups: [Group] = []
        for item in raw {
            let matches = (item["matches"] as? [String]) ?? ["<all_urls>"]
            let excluded = (item["exclude_matches"] as? [String]) ?? []
            guard matches.contains(where: ChromeMatch.isRelevant) else { continue }
            let worldName = ((item["world"] as? String) ?? "ISOLATED").uppercased()
            let world: WKContentWorld = worldName == "MAIN"
                ? .page
                : .world(name: "ext-\(id)-ISOLATED")
            let runAt: Group.RunAt = {
                switch (item["run_at"] as? String) ?? "document_idle" {
                case "document_start": return .start
                default: return .end
                }
            }()
            var jsParts: [String] = []
            for file in (item["js"] as? [String]) ?? [] {
                if let text = read(root: root, relative: file) {
                    jsParts.append(text)
                }
            }
            var css: [String] = []
            for file in (item["css"] as? [String]) ?? [] {
                if let text = read(root: root, relative: file) {
                    css.append(text)
                }
            }
            if jsParts.isEmpty && css.isEmpty { continue }
            groups.append(Group(
                js: jsParts.joined(separator: "\n;\n"),
                css: css,
                matches: matches,
                excluded: excluded,
                runAt: runAt,
                allFrames: (item["all_frames"] as? Bool) ?? false,
                worldName: worldName == "MAIN" ? "MAIN" : "ISOLATED",
                world: world
            ))
        }
        return groups
    }

    private static func backgroundSources(manifest: [String: Any], root: URL) -> [String] {
        let background = manifest["background"]
        if let dict = background as? [String: Any] {
            if let scripts = dict["scripts"] as? [String] {
                return scripts.compactMap { read(root: root, relative: $0) }
            }
            if let worker = dict["service_worker"] as? String {
                if (dict["type"] as? String) == "module" {
                    let flat = ESModuleFlat.flatten(entry: worker, root: root)
                    return flat.isEmpty ? [] : [flat]
                }
                if let text = read(root: root, relative: worker) {
                    return [text]
                }
            }
        } else if let scripts = background as? [String] {
            return scripts.compactMap { read(root: root, relative: $0) }
        }
        return []
    }

    private static func assetFiles(in root: URL) -> [String: String] {
        var files: [String: String] = [:]
        let textExt: Set<String> = ["css", "js", "svg", "json", "html", "txt", "xml"]
        let binaryExt: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "woff", "woff2"]
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return files
        }
        for case let file as URL in walker {
            let ext = file.pathExtension.lowercased()
            let relative = file.path.replacingOccurrences(of: root.path + "/", with: "")
            if relative.hasPrefix("_metadata") || relative.hasPrefix(".") { continue }
            if textExt.contains(ext) {
                if let text = read(root: root, relative: relative) {
                    files[relative] = text
                }
            } else if binaryExt.contains(ext), let data = try? Data(contentsOf: file), data.count < 1_500_000 {
                files[relative] = "data:\(mime(for: ext));base64,\(data.base64EncodedString())"
            }
        }
        return files
    }

    private static func mime(for ext: String) -> String {
        switch ext {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        default: return "application/octet-stream"
        }
    }

    private static func loadMessages(root: URL, locale: String) -> [String: [String: String]] {
        var messages: [String: [String: String]] = [:]
        for folder in [locale, "en", "en_US"] {
            let url = root.appendingPathComponent("_locales/\(folder)/messages.json")
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            for (key, raw) in json {
                if let entry = raw as? [String: Any], let message = entry["message"] as? String {
                    messages[key] = ["message": message]
                }
            }
            if !messages.isEmpty { break }
        }
        return messages
    }

    static func read(root: URL, relative: String) -> String? {
        let clean = relative.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let url = root.appendingPathComponent(clean).standardizedFileURL
        guard url.path.hasPrefix(root.standardizedFileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: url), data.count < 8_000_000 else { return nil }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
    }
}

enum ESModuleFlat {
    static func flatten(entry: String, root: URL) -> String {
        var seen = Set<String>()
        var parts: [String] = []
        walk(entry, from: "", root: root, seen: &seen, parts: &parts)
        return parts.joined(separator: "\n;\n")
    }

    private static func walk(_ spec: String, from: String, root: URL, seen: inout Set<String>, parts: inout [String]) {
        let path = resolve(from: from, spec: spec)
        guard seen.insert(path).inserted else { return }
        guard let text = LoadedExtension.read(root: root, relative: path) else { return }
        for next in imports(in: text) {
            walk(next, from: path, root: root, seen: &seen, parts: &parts)
        }
        parts.append(stripModuleSyntax(text))
    }

    private static func imports(in text: String) -> [String] {
        let patterns = [
            #"import\s+(?:type\s+)?(?:[\s\S]*?from\s+)?['"]([^'"]+)['"]"#,
            #"export\s+(?:\*|{[\s\S]*?})\s+from\s+['"]([^'"]+)['"]"#
        ]
        var found: [String] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                if let inner = Range(match.range(at: 1), in: text) {
                    found.append(String(text[inner]))
                }
            }
        }
        return found
    }

    private static func stripModuleSyntax(_ text: String) -> String {
        var result = text
        let removals = [
            #"import\s+(?:type\s+)?(?:[\s\S]*?from\s+)?['"][^'"]+['"]\s*;?"#,
            #"export\s+(?:\*|{[\s\S]*?})\s+from\s+['"][^'"]+['"]\s*;?"#,
            #"export\s+\{[\s\S]*?\}\s*;?"#
        ]
        for pattern in removals {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
            }
        }
        result = result.replacingOccurrences(of: "export async function", with: "async function")
        result = result.replacingOccurrences(of: "export function", with: "function")
        result = result.replacingOccurrences(of: "export class", with: "class")
        result = result.replacingOccurrences(of: "export const ", with: "const ")
        result = result.replacingOccurrences(of: "export let ", with: "let ")
        result = result.replacingOccurrences(of: "export var ", with: "var ")
        result = result.replacingOccurrences(of: "export default ", with: "")
        return result
    }

    private static func resolve(from file: String, spec: String) -> String {
        var clean = spec.trimmingCharacters(in: .whitespacesAndNewlines)
        if let q = clean.firstIndex(of: "?") { clean = String(clean[..<q]) }
        if clean.hasPrefix("/") {
            return String(clean.drop(while: { $0 == "/" }))
        }
        var parts = file.split(separator: "/").map(String.init)
        if !parts.isEmpty { parts.removeLast() }
        for part in clean.split(separator: "/") {
            if part == "." { continue }
            if part == ".." {
                if !parts.isEmpty { parts.removeLast() }
                continue
            }
            parts.append(String(part))
        }
        return parts.joined(separator: "/")
    }
}

enum ChromeMatch {
    nonisolated static func isRelevant(_ pattern: String) -> Bool {
        let p = pattern.lowercased()
        if p == "<all_urls>" || p == "*://*/*" || p == "http://*/*" || p == "https://*/*" { return true }
        return p.contains("roblox.com")
    }

    static func appliesToRobloxUI(_ pattern: String) -> Bool {
        isRelevant(pattern)
    }

    static func matches(_ pattern: String, url: URL) -> Bool {
        if pattern == "<all_urls>" { return true }
        let parts = pattern.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, parts[1].hasPrefix("//") else { return false }
        let scheme = parts[0]
        let rest = String(parts[1].dropFirst(2))
        let slash = rest.firstIndex(of: "/")
        let host = slash.map { String(rest[..<$0]) } ?? rest
        let path = slash.map { String(rest[$0...]) } ?? "/"
        let urlScheme = url.scheme ?? ""
        if scheme != "*" && scheme != urlScheme { return false }
        let urlHost = (url.host ?? "").lowercased()
        if host == "*" {
        } else if host.hasPrefix("*.") {
            let suffix = String(host.dropFirst(2)).lowercased()
            if urlHost != suffix && !urlHost.hasSuffix("." + suffix) { return false }
        } else if host.lowercased() != urlHost {
            return false
        }
        var escaped = NSRegularExpression.escapedPattern(for: path)
        escaped = escaped.replacingOccurrences(of: "\\*", with: ".*")
        let urlPath = url.path.isEmpty ? "/" : url.path
        let candidates = [urlPath, urlPath.hasSuffix("/") ? urlPath : urlPath + "/"]
        guard let regex = try? NSRegularExpression(pattern: "^\(escaped)$") else { return true }
        return candidates.contains { text in
            regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
        }
    }
}

@MainActor
final class ExtensionBus: NSObject, WKScriptMessageHandler {
    let assets = ExtSchemeHandler()
    private var backgrounds: [String: WKWebView] = [:]
    private var storage: [String: [String: Any]] = [:]
    private weak var page: WKWebView?

    func attach(page: WKWebView, ids: [String]) {
        self.page = page
        for id in ids {
            startBackground(id)
        }
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "extbus", let body = message.body as? [String: Any] else { return }
        let ext = body["ext"] as? String ?? ""
        let kind = body["kind"] as? String ?? ""
        let fromBackground = body["bg"] as? Bool ?? false
        switch kind {
        case "storage-get":
            reply(ext: ext, mid: body["mid"], data: storageGet(ext: ext, keys: body["keys"]), toBackground: fromBackground)
        case "storage-set":
            if let items = body["items"] as? [String: Any] {
                var bucket = storage[ext] ?? load(ext)
                for (key, value) in items { bucket[key] = value }
                storage[ext] = bucket
                persist(ext)
            }
            reply(ext: ext, mid: body["mid"], data: nil, toBackground: fromBackground)
        case "storage-remove":
            var bucket = storage[ext] ?? load(ext)
            let keys = body["keys"]
            if let key = keys as? String { bucket.removeValue(forKey: key) }
            if let list = keys as? [String] { list.forEach { bucket.removeValue(forKey: $0) } }
            storage[ext] = bucket
            persist(ext)
            reply(ext: ext, mid: body["mid"], data: nil, toBackground: fromBackground)
        case "storage-clear":
            storage[ext] = [:]
            persist(ext)
            reply(ext: ext, mid: body["mid"], data: nil, toBackground: fromBackground)
        case "send":
            deliverMessage(ext: ext, fromBackground: fromBackground, body: body)
        case "connect":
            let pid = body["pid"]
            deliver(ext: ext, toBackground: !fromBackground, kind: "connect-in", payload: ["pid": pid ?? 0])
        case "port":
            let pid = body["pid"]
            deliver(ext: ext, toBackground: !fromBackground, kind: "port-in", payload: ["pid": pid ?? 0, "data": body["data"] ?? [:]])
        case "reply":
            reply(ext: ext, mid: body["mid"], data: body["data"], toBackground: !fromBackground)
        default:
            break
        }
    }

    private func deliverMessage(ext: String, fromBackground: Bool, body: [String: Any]) {
        let payload: [String: Any] = [
            "mid": body["mid"] ?? 0,
            "message": body["message"] ?? [:],
            "url": page?.url?.absoluteString ?? ""
        ]
        deliver(ext: ext, toBackground: !fromBackground, kind: "message", payload: payload)
    }

    private func reply(ext: String, mid: Any?, data: Any?, toBackground: Bool) {
        var payload: [String: Any] = ["mid": mid ?? 0]
        if let data { payload["data"] = data }
        deliver(ext: ext, toBackground: toBackground, kind: "reply", payload: payload)
    }

    private func deliver(ext: String, toBackground: Bool, kind: String, payload: [String: Any]) {
        let json = ExtensionRuntime.jsonValue(payload)
        let js = "globalThis.__rbExtDeliver&&globalThis.__rbExtDeliver(\(ExtensionRuntime.jsonValue(kind)),\(json));"
        if toBackground {
            backgrounds[ext]?.evaluateJavaScript(js, completionHandler: nil)
        } else {
            page?.evaluateJavaScript(js, in: nil, in: WKContentWorld.world(name: "ext-\(ext)-ISOLATED"))
            page?.evaluateJavaScript(js, in: nil, in: .page)
        }
    }

    private func storageGet(ext: String, keys: Any?) -> [String: Any] {
        let bucket = storage[ext] ?? load(ext)
        storage[ext] = bucket
        if keys == nil { return bucket }
        if let key = keys as? String {
            if let value = bucket[key] { return [key: value] }
            return [:]
        }
        if let list = keys as? [String] {
            var out: [String: Any] = [:]
            for key in list { if let value = bucket[key] { out[key] = value } }
            return out
        }
        if let dict = keys as? [String: Any] {
            var out = dict
            for (key, _) in dict { if let value = bucket[key] { out[key] = value } }
            return out
        }
        return bucket
    }

    private func persist(_ ext: String) {
        let url = WebModLibrary.shared.folder(for: ext).appendingPathComponent(".rb-storage.json")
        if let data = try? JSONSerialization.data(withJSONObject: storage[ext] ?? [:]) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func load(_ ext: String) -> [String: Any] {
        let url = WebModLibrary.shared.folder(for: ext).appendingPathComponent(".rb-storage.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return json
    }

    private func startBackground(_ id: String) {
        guard backgrounds[id] == nil else { return }
        let scripts = ExtensionRuntime.backgroundScripts(for: id)
        guard !scripts.isEmpty else { return }
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.setURLSchemeHandler(ExtSchemeHandler(), forURLScheme: "rbxext")
        config.userContentController.add(self, name: "extbus")
        for script in scripts {
            config.userContentController.addUserScript(script)
        }
        let view = WKWebView(frame: .zero, configuration: config)
        backgrounds[id] = view
        view.loadHTMLString("<!doctype html><title>ext</title>", baseURL: URL(string: "rbxext://\(id)/"))
    }
}
