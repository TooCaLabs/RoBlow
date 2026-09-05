import SwiftUI

struct MainStageView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            switch model.selectedSidebarItem {
            case .home:
                HomeScreenView()
            case .mods:
                ModsView()
            case .instance(let id):
                if let slot = model.instances.instance(for: id) {
                    MainInstanceView(slot: slot)
                }
            case .newUI(let id):
                if let slot = model.instances.instance(for: id) {
                    NewUIBrowserView(slot: slot)
                }
            case .document:
                if let document = model.selectedDocumentBinding {
                    DocumentEditor(document: document)
                }
            }

            if model.showWebModStore {
                WebModStoreView()
                    .padding(8)
            }

            if let status = model.statusMessage {
                Text(status)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background {
                        Capsule().fill(.white.opacity(0.32))
                    }
                    .padding(12)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: model.statusMessage)
    }
}

private struct StagePlaceholder: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.controlInk)
            Text(detail)
                .font(.system(size: 15))
                .foregroundStyle(Theme.controlInk.opacity(0.62))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(22)
    }
}

private struct DocumentEditor: View {
    @Binding var document: AppDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Title", text: $document.title)
                .textFieldStyle(.plain)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.controlInk)

            TextEditor(text: $document.body)
                .font(.system(size: 16))
                .scrollContentBackground(.hidden)
                .foregroundStyle(Theme.controlInk.opacity(0.86))
        }
        .padding(22)
    }
}

struct SettingsPanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button {
                    model.dismissOverlays()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
            }

            Toggle("Show sidebar", isOn: Binding(
                get: { model.isSidebarVisible },
                set: { newValue in
                    if newValue != model.isSidebarVisible {
                        model.toggleSidebar()
                    }
                }
            ))

            Toggle("Expanded window", isOn: Binding(
                get: { model.isGlassExpanded },
                set: { _ in model.toggleGlassExpanded() }
            ))

            Text("These controls mirror the chrome and menus in the glass window.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .toggleStyle(.switch)
    }
}

struct AboutPanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("About RoBlow")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button {
                    model.dismissOverlays()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
            }

            Text("A SwiftUI remake of the frosted desktop window: custom chrome, a split menu bar, and a hideable sidebar.")
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
