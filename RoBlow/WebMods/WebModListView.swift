import SwiftUI

struct WebModListView: View {
    @Environment(AppModel.self) private var model
    var slot: GameInstance

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chrome extensions")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.controlInk.opacity(0.48))
                    Text("Content scripts on this instance’s New UI. Same idea as a Modrinth instance list.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.controlInk.opacity(0.45))
                }
                Spacer()
                Button("Install mods") {
                    model.openWebModStore(for: slot)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background {
                    Capsule().fill(Theme.menuBlue)
                }
            }

            if slot.webMods.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No extensions on \(slot.name).")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.controlInk)
                    Text("Install mods opens the Chrome Web Store. Adding one drops it here with a toggle.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.controlInk.opacity(0.5))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.28))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 0.6)
                }
            } else {
                VStack(spacing: 1) {
                    ForEach(slot.webMods) { mod in
                        row(mod)
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.28))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 0.6)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func row(_ mod: InstanceWebMod) -> some View {
        let record = model.webMods.record(for: mod.id)
        return HStack(spacing: 12) {
            icon(for: mod.id)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(record?.name ?? mod.id)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.controlInk)
                    if let version = record?.version, !version.isEmpty {
                        Text(version)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.controlInk.opacity(0.4))
                    }
                }
                Text(record?.detail ?? "Chrome extension")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.controlInk.opacity(0.5))
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { mod.isEnabled },
                set: { on in
                    slot.setWebModEnabled(mod.id, on)
                    model.instances.persist()
                    model.reloadNewUI()
                    model.setStatus(on ? "Enabled \(record?.name ?? mod.id)" : "Disabled \(record?.name ?? mod.id)")
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()

            Button {
                slot.removeWebMod(mod.id)
                model.instances.persist()
                model.reloadNewUI()
                model.setStatus("Removed \(record?.name ?? mod.id)")
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(Theme.terminateRed.opacity(0.85))
            }
            .buttonStyle(.plain)
            .help("Remove from this instance")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func icon(for id: String) -> some View {
        if let image = model.webMods.icon(for: id) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.menuBlue.opacity(0.16))
                .overlay {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.menuBlue)
                }
        }
    }
}
