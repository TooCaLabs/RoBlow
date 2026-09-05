import SwiftUI

struct NewUICard: View {
    @Environment(AppModel.self) private var model
    var slot: GameInstance

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(NewUIMod.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.controlInk)
                        Text("Special")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background {
                                Capsule().fill(Theme.newUI.opacity(0.22))
                            }
                            .foregroundStyle(Theme.newUI)
                    }
                    Text(NewUIMod.blurb)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.controlInk.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { slot.newUI.isEnabled },
                    set: { on in
                        slot.newUI.isEnabled = on
                        model.instances.persist()
                        model.setStatus(on ? "New UI on \(slot.name)" : "New UI off \(slot.name)")
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }

            if slot.newUI.isEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: Binding(
                        get: { slot.newUI.searchTab },
                        set: { on in
                            slot.newUI.searchTab = on
                            model.instances.persist()
                            model.setStatus(on ? "Search tab on \(slot.name)" : "Search tab off \(slot.name)")
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Search tab")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.controlInk)
                            Text("Google for Roblox, drawn on top of the website when this instance launches.")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.controlInk.opacity(0.5))
                        }
                    }
                    .toggleStyle(.switch)
                    .padding(10)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.28))
                    }

                    ForEach(NewUIVariant.allCases) { variant in
                        Button {
                            slot.newUI.variant = variant
                            model.instances.persist()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(variant.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Theme.controlInk)
                                    Text(variant.detail)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.controlInk.opacity(0.5))
                                }
                                Spacer()
                                if slot.newUI.variant == variant {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.newUI)
                                }
                            }
                            .padding(10)
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(slot.newUI.variant == variant ? 0.45 : 0.18))
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(NewUIMod.stages) { stage in
                            HStack(alignment: .top, spacing: 8) {
                                Text(stage.label)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(stage.state == .now ? Theme.newUI : Theme.controlInk.opacity(0.4))
                                    .frame(width: 40, alignment: .leading)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(stage.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.controlInk.opacity(stage.state == .later ? 0.45 : 0.82))
                                    Text(stage.detail)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.controlInk.opacity(0.45))
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.newUI.opacity(0.10))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.newUI.opacity(0.28), lineWidth: 1)
        }
    }
}
