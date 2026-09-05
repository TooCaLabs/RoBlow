import SwiftUI

struct GlassWindowView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WindowControlsRow()
            MenuBarView()

            HStack(alignment: .top, spacing: 16) {
                if model.isSidebarVisible {
                    SidebarView()
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                MainStageView()
            }
            .padding(.top, 2)
        }
        .padding(.top, 16)
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            GlassSurface(style: .window, cornerRadius: Theme.windowCorner)
        }
        .overlay {
            GlassStroke(cornerRadius: Theme.windowCorner)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.windowCorner, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 28, y: 14)
        .overlay(alignment: model.openMenu?.isLeading == false ? .topTrailing : .topLeading) {
            if let menu = model.openMenu {
                MenuDropdown(menu: menu)
                    .padding(.top, 74)
                    .padding(.horizontal, 38)
                    .offset(x: dropdownNudge(for: menu))
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }
        }
        .overlay {
            if model.showSettings {
                OverlayPanel {
                    SettingsPanel()
                }
            } else if model.showAbout {
                OverlayPanel {
                    AboutPanel()
                }
            }
        }
        .sheet(isPresented: Bindable(model.home).showAddAccount) {
            RobloxLoginSheet { profile, cookie in
                model.home.upsertAccount(profile, cookie: cookie)
                model.setStatus("Added \(profile.username)")
            }
        }
    }

    private func dropdownNudge(for menu: AppMenu) -> CGFloat {
        switch menu {
        case .file: 0
        case .edit: 54
        case .window: 112
        case .view: -128
        case .settings: -62
        case .help: 0
        }
    }
}

private struct WindowControlsRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 16) {
            ChromeButton(systemName: "xmark", help: "Close") {
                model.closeApp()
            }
            ChromeButton(systemName: "minus", help: "Minimize") {
                model.minimizeApp()
            }
            ChromeButton(systemName: "square", help: "Zoom") {
                model.toggleGlassExpanded()
            }
            Spacer()
        }
        .padding(.leading, 6)
        .padding(.bottom, 2)
    }
}

private struct ChromeButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.controlInk)
                .frame(width: 22, height: 22)
                .background {
                    Circle()
                        .fill(.white.opacity(hovering ? 0.34 : 0))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .onHover { hovering = $0 }
    }
}

private struct OverlayPanel<Content: View>: View {
    @Environment(AppModel.self) private var model
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.windowCorner, style: .continuous)
                .fill(.black.opacity(0.12))
                .onTapGesture {
                    model.dismissOverlays()
                }

            content
                .frame(width: 380)
                .padding(22)
                .background {
                    GlassSurface(style: .panel, cornerRadius: 22)
                }
                .overlay {
                    GlassStroke(cornerRadius: 22)
                }
                .shadow(color: .black.opacity(0.16), radius: 20, y: 10)
        }
    }
}
