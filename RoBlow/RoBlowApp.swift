import AppKit
import SwiftUI

@main
struct RoBlowApp: App {
    @State private var model = AppModel()

    init() {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        Window("RoBlow", id: "main") {
            ContentView()
                .environment(model)
                .containerBackground(.clear, for: .window)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .defaultSize(width: 1280, height: 820)
        .defaultLaunchBehavior(.presented)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Instance") {
                    model.createInstance()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .sidebar) {
                Button(model.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar") {
                    model.toggleSidebar()
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
            }
        }
    }
}
