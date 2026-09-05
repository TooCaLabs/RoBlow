# Forking RoBlow

MIT. Fork it, change it, ship it. Keep the [LICENSE](LICENSE) copyright notice.

Upstream: [https://github.com/TooCaLabs/RoBlow](https://github.com/TooCaLabs/RoBlow)

## Fork and clone

1. Hit **Fork** on GitHub
2. Clone yours:

```bash
git clone git@github.com:<you>/RoBlow.git
cd RoBlow
```

HTTPS works too:

```bash
git clone https://github.com/<you>/RoBlow.git
```

Stay current with us:

```bash
git remote add upstream git@github.com:TooCaLabs/RoBlow.git
git fetch upstream
git merge upstream/main
```

## What you need

- macOS 15+
- Xcode (full app, not just Command Line Tools)
- Official Roblox at `/Applications/Roblox.app`

This repo is source. The Release `.app` is a different download. Forks build from Xcode.

## Build

Open `RoBlow.xcodeproj` and run the **RoBlow** scheme (Debug is fine).

Or:

```bash
xcodebuild -project RoBlow.xcodeproj -scheme RoBlow -configuration Debug \
  -derivedDataPath build/DerivedData
```

The app lands at:

`build/DerivedData/Build/Products/Debug/RoBlow.app`

Quit any older RoBlow before you open the new one.

The Xcode project is a **file-system synchronized** group: any file you add under `RoBlow/` is picked up. You do not edit `project.pbxproj` for new Swift files.

App sandbox is **off**. That is required to launch Roblox and write its settings. Do not turn sandbox on unless you know you are replacing that.

Signing is “Sign to Run Locally” (`CODE_SIGN_IDENTITY = "-"`). For a Release you give other people, you need your own Developer ID and notarization. Gatekeeper will block an unsigned copy on someone else’s Mac.

## Layout

```
RoBlow.xcodeproj      Xcode project
RoBlow/               App source (synced into the target)
  NewUI/              New UI browser + sealed Contents.idx
  WebMods/            Chrome extension install + host
NewUISource/          Edit New UI CSS/JS here
Tools/seal-newui.swift
```

| Area | Start here |
| --- | --- |
| App / window | `RoBlow/RoBlowApp.swift`, `GlassWindowView.swift` |
| Sidebar / home | `SidebarView.swift`, `HomeScreenView.swift`, `HomeModels.swift` |
| Instances / launch | `MainInstance.swift`, `MainInstanceView.swift`, `AppModel.swift` |
| Accounts | `RobloxAccounts.swift` |
| FastFlags | `ClientMods.swift` |
| New UI browser | `NewUI/NewUIBrowser.swift` |
| New UI look | `NewUISource/theme.css`, `NewUISource/inject.js` |
| Quick-mode | `QuickTerm.swift` — see [Quick_mode.md](Quick_mode.md) |
| Web mods | `WebMods/ChromeExtension.swift`, `ExtensionRuntime.swift` |

## Rules that will save you pain

**Do not patch `/Applications/Roblox.app`.** Launch the stock binary:

`/Applications/Roblox.app/Contents/MacOS/RobloxPlayer`

Client settings go to:

`~/Library/Application Support/Roblox/ClientSettings/ClientAppSettings.json`

New UI is **our** WKWebView on roblox.com, not the player’s UI.

Play from New UI should start the official player once. Do not also open a `roblox-player:` ticket if you already spawned `RobloxPlayer`.

## New UI source

Edit files in `NewUISource/`. Every build runs:

```bash
swift Tools/seal-newui.swift NewUISource RoBlow/NewUI/Contents.idx
```

That writes `RoBlow/NewUI/Contents.idx`. The app unpacks it at runtime (`NewUI/ExtensionVault.swift`).

The sealer and the vault both key off the bundle id `com.goldknow.RoBlow`. If you change `PRODUCT_BUNDLE_IDENTIFIER` in the Xcode target, change the same string in `Tools/seal-newui.swift` (and the matching material in `ExtensionVault.swift`) or New UI CSS/JS will not load.

## Bundle id and data on disk

Current bundle id: `com.goldknow.RoBlow`

User data is **not** in git:

| What | Where |
| --- | --- |
| Web mods | `~/Library/Application Support/RoBlow/Extensions/` |
| Instance files | `~/Library/Application Support/RoBlow/instances/` |
| Session files | `~/Library/Application Support/RoBlow/secrets/` |
| Roblox FastFlags | `~/Library/Application Support/Roblox/ClientSettings/` |
| Cookies | Keychain / those session files |

Do not commit `RoBlow.app`, `build/`, cookies, or `.p12` keys. `.gitignore` already covers the usual junk.

## Web mods

New UI hosts Chrome extensions in WebKit (`ExtensionRuntime.swift`). It is not Chrome.

What a fork can expect to work: content scripts, CSS, `chrome.storage`, messaging, `getURL`.

What will not: real `declarativeNetRequest`, request blocking, a full MV3 service worker.

Install flow is the Chrome Web Store wrapper in-app, CRX download, unpack under the Extensions folder above. Each instance has its own enable list (`webMods` on the instance).

## Quick-mode

`;` opens the overlay when Quick-mode is on. Commands and default binds: [Quick_mode.md](Quick_mode.md).

Binds must not fire while the user is typing (`QuickTerm` already skips text fields and a focused WKWebView).

## Versions

`vA.BC` then a channel. A is major, B is minor, C is patch. `v1.10` means minor 1, patch 0.

- `-Robbed` — beta
- `-Roblox` — full release

This tree is `v1.00-Robbed`. Change `MARKETING_VERSION` in the Xcode target and `RoBlowVersion.mark` in `RoBlow/Version.swift` together.

## License when you ship a fork

[MIT](LICENSE). Keep `Copyright (c) 2026 TooCaLabs` in the license text. Add your own copyright line above or below it if you want.

The README tagline can stay or go. That is your fork.

## Sending work back

PRs against [TooCaLabs/RoBlow](https://github.com/TooCaLabs/RoBlow) are fine. Keep them small. Do not include DerivedData, a built `.app`, or anyone’s cookies.
