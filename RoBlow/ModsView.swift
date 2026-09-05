import SwiftUI

struct ModsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let slot = editingSlot

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(slot)

                Text("Each instance keeps its own mix. These write FastFlags when that instance launches. Nothing is patched inside Roblox.app.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.controlInk.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)

                if let slot {
                    NewUICard(slot: slot)
                    WebModListView(slot: slot)

                    ForEach(ModCategory.allCases) { category in
                        section(category, slot: slot)
                    }
                    customCard(slot)
                } else {
                    Text("Create an instance first, then set its mods.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.controlInk.opacity(0.5))
                }
            }
            .padding(22)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if model.instances.editingModInstanceID == nil {
                model.instances.editingModInstanceID = model.selectedInstance?.id ?? model.instances.slots.first?.id
            }
        }
    }

    private var editingSlot: GameInstance? {
        if let id = model.instances.editingModInstanceID {
            return model.instances.instance(for: id)
        }
        return model.instances.slots.first
    }

    private func header(_ slot: GameInstance?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mods")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Theme.controlInk)
                    Text(slot.map { $0.activeModCount == 0 ? "No mods on \($0.name)." : "\($0.activeModCount) active on \($0.name)" } ?? "No instances")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.controlInk.opacity(0.58))
                }

                Spacer()

                if let slot {
                    Button("Apply now") {
                        model.publishClientSettings(for: slot)
                        model.setStatus("Wrote ClientSettings for \(slot.name)")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background {
                        Capsule().fill(Theme.menuBlue.opacity(0.86))
                    }
                    .foregroundStyle(.white)
                }
            }

            HStack(spacing: 8) {
                ForEach(model.instances.slots) { candidate in
                    Button {
                        model.instances.editingModInstanceID = candidate.id
                    } label: {
                        Text(candidate.name)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background {
                                Capsule().fill(
                                    candidate.id == slot?.id ? Theme.menuBlue.opacity(0.86) : Color.white.opacity(0.36)
                                )
                            }
                            .foregroundStyle(candidate.id == slot?.id ? Color.white : Theme.controlInk)
                    }
                    .buttonStyle(.plain)
                }

                if let slot, model.instances.slots.count > 1 {
                    Menu("Copy from") {
                        ForEach(model.instances.slots.filter { $0.id != slot.id }) { source in
                            Button(source.name) {
                                slot.copyMods(from: source)
                                model.instances.persist()
                                model.setStatus("Copied mods from \(source.name)")
                            }
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.menuBlue)
                }
            }
        }
    }

    private func section(_ category: ModCategory, slot: GameInstance) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(category.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.controlInk.opacity(0.48))

            VStack(spacing: 1) {
                ForEach(ClientModCatalog.mods(in: category)) { mod in
                    toggleRow(mod, slot: slot)
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

    private func toggleRow(_ mod: ClientMod, slot: GameInstance) -> some View {
        Toggle(isOn: Binding(
            get: { slot.isModEnabled(mod.id) },
            set: { on in
                slot.setModEnabled(mod.id, on)
                model.instances.persist()
                model.setStatus(on ? "Enabled \(mod.title) on \(slot.name)" : "Disabled \(mod.title) on \(slot.name)")
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(mod.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.controlInk)
                Text(mod.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.controlInk.opacity(0.5))
            }
        }
        .toggleStyle(.switch)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func customCard(_ slot: GameInstance) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Custom FastFlags")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.controlInk.opacity(0.48))

            VStack(alignment: .leading, spacing: 10) {
                Text("Paste a JSON object for this instance. These override the toggles above.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.controlInk.opacity(0.5))

                TextEditor(text: Binding(
                    get: { slot.customModJSON },
                    set: { slot.customModJSON = $0 }
                ))
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .foregroundStyle(Theme.controlInk)
                .frame(minHeight: 140)
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.35))
                }

                HStack {
                    if let error = slot.customModError {
                        Text(error)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.terminateRed)
                    }
                    Spacer()
                    Button("Save custom flags") {
                        if slot.saveCustomMods() {
                            model.instances.persist()
                            model.setStatus("Saved custom FastFlags for \(slot.name)")
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.menuBlue)
                }
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.28))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.6)
            }
        }
    }
}
