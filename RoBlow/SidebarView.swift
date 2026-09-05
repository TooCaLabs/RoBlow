import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            VStack(alignment: .leading, spacing: 2) {
                SidebarRow(
                    title: "Home",
                    selected: model.selectedSidebarItem == .home
                ) {
                    model.selectSidebarItem(.home)
                }

                SidebarRow(
                    title: "Mods",
                    selected: model.selectedSidebarItem == .mods
                ) {
                    model.selectSidebarItem(.mods)
                }

                SidebarSeparator()
                    .padding(.vertical, 6)

                HStack {
                    Text("Instances")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.controlInk.opacity(0.48))
                    Spacer()
                    Button {
                        model.createInstance()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.controlInk.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("New instance")
                    .accessibilityLabel("New instance")
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 4)

                ForEach(model.instances.slots) { slot in
                    SidebarRow(
                        title: slot.name,
                        selected: model.selectedSidebarItem == .instance(slot.id),
                        running: slot.isRunning
                    ) {
                        model.selectSidebarItem(.instance(slot.id))
                    }
                    .contextMenu {
                        Button("Launch") {
                            Task {
                                await model.launchInstance(slot)
                            }
                        }
                        if !slot.isMain || model.instances.slots.count > 1 {
                            Button("Delete", role: .destructive) {
                                model.deleteInstance(slot.id)
                            }
                        }
                    }

                    if model.openNewUIInstanceIDs.contains(slot.id) {
                        SidebarRow(
                            title: "New UI",
                            selected: model.selectedSidebarItem == .newUI(slot.id),
                            indented: true
                        ) {
                            model.selectSidebarItem(.newUI(slot.id))
                        }
                        .contextMenu {
                            Button("Close") {
                                model.dismissNewUI(for: slot.id)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 0)
        }
        .frame(width: Theme.sidebarWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            GlassSurface(style: .sidebar, cornerRadius: Theme.sidebarCorner)
        }
        .overlay {
            GlassStroke(cornerRadius: Theme.sidebarCorner, lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.sidebarCorner, style: .continuous))
        .onReceive(Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()) { _ in
            model.instances.refresh()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                model.toggleSidebar()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.controlInk)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Hide Sidebar")
            .accessibilityLabel("Hide Sidebar")

            Text("Sidebar")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.controlInk)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Theme.controlInk)
                        .frame(height: 1.1)
                        .padding(.horizontal, -6)
                        .offset(y: 3)
                }
        }
        .padding(.top, 12)
        .padding(.horizontal, 14)
    }
}

private struct SidebarRow: View {
    let title: String
    let selected: Bool
    var running = false
    var indented = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: selected ? .semibold : .medium))
                    .foregroundStyle(Theme.controlInk.opacity(selected ? 0.92 : 0.78))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if running {
                    Circle()
                        .fill(Theme.launchGreen)
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .padding(.leading, indented ? 16 : 0)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(selected ? 0.48 : (hovering ? 0.22 : 0)))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(title)
    }
}

private struct SidebarSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Theme.controlInk.opacity(0.12))
            .frame(height: 1)
            .padding(.horizontal, 6)
    }
}
