import AppKit
import SwiftUI
import WebKit

enum NewUIPage: String, CaseIterable, Identifiable {
    case home
    case discover
    case search

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .discover: "Discover"
        case .search: "Search"
        }
    }

    var siteURL: URL? {
        switch self {
        case .home: URL(string: "https://www.roblox.com/home")
        case .discover: URL(string: "https://www.roblox.com/discover")
        case .search: URL(string: "https://www.roblox.com/home")
        }
    }
}

struct NewUIBrowserView: View {
    @Environment(AppModel.self) private var model
    var slot: GameInstance

    var body: some View {
        VStack(spacing: 0) {
            chrome
            ZStack {
                RobloxWebCanvas(
                    cookie: RobloxSecrets.cookie(for: model.account(for: slot).userID),
                    destination: model.newUIDestination,
                    stealKeys: model.term.stealKeys,
                    quickMode: model.term.isEnabled,
                    extensionIDs: slot.webMods.filter(\.isEnabled).map(\.id),
                    onPlayerLink: { url in
                        model.handleRobloxWebPlay(url)
                    },
                    onQuickKey: { key in
                        model.term.consumeKey(key, model: model)
                    },
                    onQuickTyping: { typing in
                        model.term.webIsTyping = typing
                    }
                )
                .id(model.webViewEpoch)
                .opacity(model.newUIPage == .search ? 0 : 1)
                .allowsHitTesting(model.newUIPage != .search && !model.term.isOpen)

                if model.newUIPage == .search {
                    SearchView()
                }

                if model.term.isOpen {
                    ZStack {
                        if !model.term.isEnabled {
                            Color.black.opacity(0.32)
                                .onTapGesture { model.term.close() }
                        } else {
                            Color.black.opacity(0.32)
                        }
                        QuickTermView()
                    }
                }
            }
            .background(QuickTermMonitor())
        }
        .background(Color.white.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var chrome: some View {
        HStack(spacing: 8) {
            Text("New UI")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.newUI)

            if !model.term.isEnabled {
                ForEach(NewUIPage.allCases) { page in
                    Button {
                        model.openNewUIPage(page)
                    } label: {
                        Text(page.title)
                            .font(.system(size: 13, weight: model.newUIPage == page ? .semibold : .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background {
                                Capsule().fill(model.newUIPage == page ? Theme.newUI.opacity(0.18) : .clear)
                            }
                            .foregroundStyle(model.newUIPage == page ? Theme.newUI : Theme.controlInk.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("\(model.term.openKey) menu")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.controlInk.opacity(0.4))
            }

            Spacer()

            Toggle("Quick-mode", isOn: Binding(
                get: { model.term.isEnabled },
                set: { model.term.setEnabled($0) }
            ))
            .toggleStyle(.switch)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(model.term.isEnabled ? Theme.termGreen : Theme.controlInk.opacity(0.7))
            .tint(Theme.termGreen)

            Text(slot.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.controlInk.opacity(0.4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct RobloxWebCanvas: NSViewRepresentable {
    var cookie: String?
    var destination: URL?
    var stealKeys: [String] = []
    var quickMode = false
    var extensionIDs: [String] = []
    var onPlayerLink: (URL) -> Void
    var onQuickKey: (String) -> Void
    var onQuickTyping: (Bool) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPlayerLink: onPlayerLink, onQuickKey: onQuickKey, onQuickTyping: onQuickTyping)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.setURLSchemeHandler(context.coordinator.bus.assets, forURLScheme: "rbxext")
        config.userContentController.add(context.coordinator, name: "quick")
        config.userContentController.addUserScript(WKUserScript(
            source: Coordinator.keyStealer,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        config.userContentController.addUserScript(WKUserScript(
            source: Coordinator.quickHider,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        ExtensionRuntime.install(ids: extensionIDs, into: config, bus: context.coordinator.bus)
        NewUIVault.install(into: config)
        let view = WKWebView(frame: .zero, configuration: config)
        view.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        context.coordinator.webView = view
        context.coordinator.onPlayerLink = onPlayerLink
        context.coordinator.onQuickKey = onQuickKey
        context.coordinator.onQuickTyping = onQuickTyping
        context.coordinator.lastExtensionIDs = extensionIDs
        context.coordinator.bus.attach(page: view, ids: extensionIDs)
        context.coordinator.syncSteal(stealKeys)
        context.coordinator.syncQuick(quickMode)
        context.coordinator.apply(cookie: cookie) {
            context.coordinator.load(destination ?? URL(string: "https://www.roblox.com/home"))
        }
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.onPlayerLink = onPlayerLink
        context.coordinator.onQuickKey = onQuickKey
        context.coordinator.onQuickTyping = onQuickTyping
        context.coordinator.syncSteal(stealKeys)
        context.coordinator.syncQuick(quickMode)
        context.coordinator.lastExtensionIDs = extensionIDs
        context.coordinator.apply(cookie: cookie) {
            context.coordinator.load(destination)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var webView: WKWebView?
        var onPlayerLink: (URL) -> Void
        var onQuickKey: (String) -> Void
        var onQuickTyping: (Bool) -> Void
        private var lastCookie: String?
        private var lastURL: URL?
        private var lastSteal: [String] = []
        private var lastQuick = false
        var lastExtensionIDs: [String] = []
        let bus = ExtensionBus()

        init(
            onPlayerLink: @escaping (URL) -> Void,
            onQuickKey: @escaping (String) -> Void,
            onQuickTyping: @escaping (Bool) -> Void
        ) {
            self.onPlayerLink = onPlayerLink
            self.onQuickKey = onQuickKey
            self.onQuickTyping = onQuickTyping
        }

        func syncSteal(_ keys: [String]) {
            guard keys != lastSteal else { return }
            lastSteal = keys
            let payload = (try? JSONSerialization.data(withJSONObject: keys)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            webView?.evaluateJavaScript("window.__rbSteal = \(payload);", completionHandler: nil)
        }

        func syncQuick(_ on: Bool) {
            lastQuick = on
            let js = "window.__rbQuickWanted=\(on);window.__rbSetQuick&&window.__rbSetQuick(\(on));"
            webView?.evaluateJavaScript(js) { [weak self] _, error in
                if error != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        self?.webView?.evaluateJavaScript(js, completionHandler: nil)
                    }
                }
            }
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "quick",
                  let body = message.body as? [String: Any] else { return }
            DispatchQueue.main.async { [onQuickKey, onQuickTyping] in
                if let typing = body["typing"] as? Bool {
                    onQuickTyping(typing)
                }
                if let key = body["key"] as? String {
                    onQuickKey(key)
                }
            }
        }

        static let quickHider = #"""
        (() => {
          if (window.__rbQuickHider) return;
          window.__rbQuickHider = true;
          window.__rbQuickWanted = window.__rbQuickWanted || false;

          const hide = (el) => {
            if (!el || el === document.body || el === document.documentElement) return;
            if (el.getAttribute("data-rb-hidden") === "1") return;
            el.setAttribute("data-rb-hidden", "1");
            el.style.setProperty("display", "none", "important");
            el.style.setProperty("visibility", "hidden", "important");
            el.style.setProperty("pointer-events", "none", "important");
          };

          const showAll = () => {
            document.querySelectorAll("[data-rb-hidden]").forEach((el) => {
              el.removeAttribute("data-rb-hidden");
              el.style.removeProperty("display");
              el.style.removeProperty("visibility");
              el.style.removeProperty("pointer-events");
            });
          };

          const navPath = (href) => {
            try { return new URL(href, location.origin).pathname.toLowerCase().replace(/\/$/, "") || "/"; }
            catch (_) { return ""; }
          };

          const navs = ["/home","/discover","/charts","/my/avatar","/users/inventory","/users/friends","/my/messages","/communities","/users/profile","/catalog","/my/account","/premium","/premium/membership","/develop"];
          const isNav = (href) => {
            const p = navPath(href);
            if (/\/games\/\d+/.test(p) || /\/catalog\/\d+/.test(p)) return false;
            if ((href || "").toLowerCase().includes("create.roblox.com")) return true;
            return navs.some((n) => p === n || p.startsWith(n + "/"));
          };

          const isPlay = (el) => {
            const t = (el.getAttribute("aria-label") || el.textContent || "").replace(/\s+/g, " ").trim().toLowerCase();
            return t === "play" || t === "play now" || t === "join" || t === "play game";
          };

          const hideRails = () => {
            const w = window.innerWidth || 1200;
            const h = window.innerHeight || 800;
            document.querySelectorAll("header, nav, [role='banner'], [role='navigation'], #header, .rbx-header, #navigation, #navigation-container, .rbx-left-col").forEach(hide);
            document.querySelectorAll("body *").forEach((el) => {
              if (el.childElementCount > 120) return;
              const s = getComputedStyle(el);
              if (s.position !== "fixed" && s.position !== "sticky") return;
              const r = el.getBoundingClientRect();
              if (r.width < 12 || r.height < 12) return;
              if (r.width * r.height > w * h * 0.55) return;
              if (r.top <= 20 && r.height <= 140 && r.width >= w * 0.35) hide(el);
              if (r.left <= 20 && r.width <= 300 && r.height >= h * 0.3) hide(el);
            });
            document.querySelectorAll("a[href], button, [role='button']").forEach((el) => {
              const href = el.getAttribute("href") || "";
              if (isNav(href) || isPlay(el)) hide(el.closest("li, [role='menuitem']") || el);
            });
          };

          window.__rbSetQuick = (on) => {
            window.__rbQuickWanted = !!on;
            document.documentElement.classList.toggle("rb-quick", !!on);
            if (on) hideRails();
            else showAll();
          };

          new MutationObserver(() => {
            if (window.__rbQuickWanted) hideRails();
          }).observe(document.documentElement, { childList: true, subtree: true });

          setInterval(() => {
            if (window.__rbQuickWanted) hideRails();
          }, 800);

          if (window.__rbQuickWanted) window.__rbSetQuick(true);
        })();
        """#

        static let keyStealer = """
        (() => {
          window.__rbSteal = window.__rbSteal || [];
          function typingNode(el) {
            if (!el || el === document || el === window) return false;
            if (el.nodeType !== 1) el = el.parentElement;
            if (!el) return false;
            if (el.isContentEditable) return true;
            const tag = (el.tagName || "").toLowerCase();
            if (tag === "textarea" || tag === "select") return true;
            if (tag === "input") {
              const type = (el.type || "text").toLowerCase();
              return ["button","submit","reset","checkbox","radio","file","image","range","color","hidden"].indexOf(type) < 0;
            }
            const role = (el.getAttribute && (el.getAttribute("role") || "")) || "";
            if (/^(textbox|searchbox|combobox)$/.test(role)) return true;
            return !!(el.closest && el.closest("input, textarea, select, [contenteditable='true'], [contenteditable=''], [role='textbox'], [role='searchbox'], [role='combobox']"));
          }
          function isTyping(e) {
            return typingNode((e && e.target) || document.activeElement);
          }
          function report(on) {
            try { webkit.messageHandlers.quick.postMessage({ typing: !!on }); } catch (_) {}
          }
          window.addEventListener("pointerdown", (e) => { report(isTyping(e)); }, true);
          window.addEventListener("focusin", () => { report(isTyping()); }, true);
          window.addEventListener("focusout", () => {
            setTimeout(() => { report(isTyping()); }, 0);
          }, true);
          window.addEventListener("keydown", (e) => {
            if (isTyping(e)) {
              report(true);
              return;
            }
            report(false);
            let k = e.key;
            if (k === "Escape") k = "esc";
            else if (k === " ") k = "space";
            else if (k.length === 1) {
              k = k.toLowerCase();
              if (e.shiftKey && /[a-z]/.test(k)) k = "shift+" + k;
            } else {
              k = k.toLowerCase();
            }
            if (!(window.__rbSteal || []).includes(k)) return;
            e.preventDefault();
            e.stopImmediatePropagation();
            try { webkit.messageHandlers.quick.postMessage({ key: k }); } catch (_) {}
          }, true);
        })();
        """

        func apply(cookie: String?, then done: @escaping () -> Void) {
            guard let view = webView else {
                done()
                return
            }
            if cookie == lastCookie {
                done()
                return
            }
            lastCookie = cookie
            guard let cookie, let parsed = Self.robloxCookie(cookie) else {
                done()
                return
            }
            view.configuration.websiteDataStore.httpCookieStore.setCookie(parsed, completionHandler: done)
        }

        func load(_ url: URL?) {
            guard let url, url != lastURL else { return }
            lastURL = url
            webView?.load(URLRequest(url: url))
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let keys = lastSteal
            lastSteal = []
            syncSteal(keys)
            syncQuick(lastQuick)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url, Self.isPlayerLink(url) {
                decisionHandler(.cancel)
                onPlayerLink(url)
                return
            }
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                decisionHandler(.cancel)
                if Self.isPlayerLink(url) {
                    onPlayerLink(url)
                } else {
                    load(url)
                }
                return
            }
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url {
                if Self.isPlayerLink(url) {
                    onPlayerLink(url)
                } else {
                    load(url)
                }
            }
            return nil
        }

        private static func isPlayerLink(_ url: URL) -> Bool {
            let scheme = url.scheme?.lowercased() ?? ""
            if scheme.hasPrefix("roblox") { return true }
            let text = (url.absoluteString.removingPercentEncoding ?? url.absoluteString).lowercased()
            if text.contains("/games/start") { return true }
            if text.contains("request=requestgame") { return true }
            return false
        }

        private static func robloxCookie(_ value: String) -> HTTPCookie? {
            HTTPCookie(properties: [
                .name: ".ROBLOSECURITY",
                .value: value,
                .domain: ".roblox.com",
                .path: "/",
                .secure: true
            ])
        }
    }
}
