import SwiftUI

struct MenuBarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 22) {
            ForEach(AppMenu.allCases.filter(\.isLeading)) { menu in
                MenuItemButton(menu: menu)
            }

            Spacer(minLength: 24)

            ForEach(AppMenu.allCases.filter { !$0.isLeading }) { menu in
                MenuItemButton(menu: menu)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background {
            GlassSurface(style: .bar, cornerRadius: Theme.menuBarCorner)
        }
        .overlay {
            GlassStroke(cornerRadius: Theme.menuBarCorner, lineWidth: 0.7)
        }
    }
}

private struct MenuItemButton: View {
    @Environment(AppModel.self) private var model
    let menu: AppMenu

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) {
                model.toggleMenu(menu)
            }
        } label: {
            VStack(spacing: 5) {
                Text(menu.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.menuBlue)

                Capsule()
                    .fill(Color.white.opacity(model.openMenu == menu ? 0.70 : 0.40))
                    .frame(width: pillWidth, height: 8)
            }
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(menu.title)
    }

    private var pillWidth: CGFloat {
        switch menu {
        case .file: 36
        case .edit: 36
        case .window: 68
        case .view: 40
        case .settings: 68
        case .help: 36
        }
    }
}

struct MenuDropdown: View {
    @Environment(AppModel.self) private var model
    let menu: AppMenu

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(items, id: \.title) { item in
                if item.title == "—" {
                    Rectangle()
                        .fill(.black.opacity(0.08))
                        .frame(height: 1)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                } else {
                    DropdownRow(title: item.title, shortcut: item.shortcut, action: item.action)
                }
            }
        }
        .padding(6)
        .frame(width: 214, alignment: .leading)
        .background {
            GlassSurface(style: .panel, cornerRadius: 14)
        }
        .overlay {
            GlassStroke(cornerRadius: 14, lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.16), radius: 16, y: 8)
    }

    private var items: [(title: String, shortcut: String?, action: () -> Void)] {
        switch menu {
        case .file:
            [
                ("New Instance", "⌘N", { model.createInstance() }),
                ("Open…", "⌘O", { model.setStatus("Open is a local demo action") }),
                ("Save", "⌘S", { model.setStatus(model.selectedDocument == nil ? "Nothing to save" : "Saved \(model.selectedDocument!.title)") }),
                ("—", nil, {}),
                ("Close", "⌘W", { model.closeApp() })
            ]
        case .edit:
            [
                ("Undo", "⌘Z", { model.performEdit("Undo") }),
                ("—", nil, {}),
                ("Cut", "⌘X", { model.performEdit("Cut") }),
                ("Copy", "⌘C", { model.performEdit("Copy") }),
                ("Paste", "⌘V", { model.performEdit("Paste") }),
                ("Select All", "⌘A", { model.performEdit("Select All") })
            ]
        case .window:
            [
                (model.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar", "⌥⌘S", { model.toggleSidebar() }),
                ("Minimize", "⌘M", { model.minimizeApp() }),
                (model.isGlassExpanded ? "Restore" : "Zoom", nil, { model.toggleGlassExpanded() })
            ]
        case .view:
            [
                (model.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar", "⌥⌘S", { model.toggleSidebar() }),
                (model.isGlassExpanded ? "Exit Zoom" : "Enter Zoom", nil, { model.toggleGlassExpanded() })
            ]
        case .settings:
            [
                ("Settings…", "⌘,", { model.openSettings() })
            ]
        case .help:
            [
                ("About RoBlow", nil, { model.openAbout() })
            ]
        }
    }
}

private struct DropdownRow: View {
    let title: String
    let shortcut: String?
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(hovering ? 0.38 : 0.001))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
