import SwiftUI

struct MainInstanceView: View {
    @Environment(AppModel.self) private var model
    var slot: GameInstance
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        @Bindable var instance = slot

        VStack(alignment: .leading, spacing: 16) {
            header

            actionRow

            accountRow

            configCard

            WebModListView(slot: slot)

            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    finishRename()
                }
        }
        .simultaneousGesture(
            TapGesture().onEnded { finishRename() }
        )
        .onExitCommand {
            finishRename()
        }
        .onAppear {
            model.instances.refresh()
        }
        .onChange(of: nameFieldFocused) { _, focused in
            model.instances.isEditingName = focused
            if !focused {
                model.instances.persist()
            }
        }
        .onReceive(Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()) { _ in
            Task {
                let account = model.account(for: slot)
                if let message = await model.instances.handleCrashWatch(accountFor: slot, fallback: account) {
                    model.setStatus(message)
                } else {
                    model.instances.refresh()
                }
            }
        }
        .popover(isPresented: $instance.showAccountPicker, arrowEdge: .bottom) {
            accountPicker
        }
    }

    private var assignedAccount: AccountProfile {
        model.account(for: slot)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Instance name", text: Bindable(slot).name)
                .textFieldStyle(.plain)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.controlInk)
                .focused($nameFieldFocused)
                .onSubmit { finishRename() }

            Text(statusLine)
                .font(.system(size: 14))
                .foregroundStyle(Theme.controlInk.opacity(0.58))
        }
    }

    private func finishRename() {
        nameFieldFocused = false
        model.instances.isEditingName = false
        model.instances.persist()
        model.hostWindow?.makeFirstResponder(nil)
    }

    private var statusLine: String {
        if !model.instances.isInstalled { return "Roblox Player is not installed." }
        if slot.isBusy { return "Preparing \(slot.name)…" }
        if slot.isRunning { return "\(slot.name) is running." }
        return "\(slot.name) is ready."
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            instanceButton(
                "LAUNCH THIS INSTANCE",
                fill: Theme.launchGreen,
                text: .white,
                enabled: model.instances.isInstalled && !slot.isBusy
            ) {
                Task {
                    await model.launchInstance(slot)
                }
            }

            instanceButton(
                "BRING TO FRONT",
                fill: Color.white.opacity(0.92),
                text: Theme.controlInk,
                enabled: slot.isRunning
            ) {
                model.setStatus(model.instances.bringToFront(slot))
            }
            .frame(width: 168)

            instanceButton(
                "TERMINATE",
                fill: Theme.terminateRed,
                text: .white,
                enabled: slot.isRunning
            ) {
                model.setStatus(model.instances.terminate(slot))
            }
            .frame(width: 128)
        }
    }

    private var accountRow: some View {
        HStack(spacing: 16) {
            sectionLabel("Account Profile")

            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.controlInk.opacity(0.45))
                Text(accountSummary)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.controlInk)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule().fill(Color.white.opacity(0.55))
            }

            Text(tokenSummary)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.controlInk.opacity(0.55))

            Spacer(minLength: 8)

            if model.home.accounts.isEmpty {
                Button("Add Account") {
                    model.home.showAddAccount = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.controlInk)
            } else {
                Button("Switch Account") {
                    slot.showAccountPicker = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.controlInk)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(panelBackground)
    }

    private var configCard: some View {
        HStack(alignment: .top, spacing: 28) {
            sectionLabel("Client Config")
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 12) {
                configRow("Unlock Framerate") {
                    Menu {
                        ForEach(InstanceFPS.allCases) { value in
                            Button(value.title) {
                                slot.fps = value
                                model.home.fpsCap = value == .unlimited ? 999 : value.rawValue
                                model.instances.persist()
                                model.setStatus("FPS cap set to \(value.title)")
                            }
                        }
                    } label: {
                        pill(slot.fps.title)
                    }
                }

                configRow("Graphics Level") {
                    Menu {
                        ForEach(GraphicsLevel.allCases) { level in
                            Button(level.rawValue) {
                                slot.graphics = level
                                model.instances.persist()
                                model.setStatus("Graphics set to \(level.rawValue)")
                            }
                        }
                    } label: {
                        pill(slot.graphics.rawValue)
                    }
                }

                configRow("UI Font Style") {
                    Menu {
                        ForEach(UIFontStyle.allCases) { font in
                            Button(font.rawValue) {
                                slot.fontStyle = font
                                model.instances.persist()
                                model.setStatus("UI font set to \(font.rawValue)")
                            }
                        }
                    } label: {
                        pill(slot.fontStyle.rawValue)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                checkbox("Bypass Singleton Mutex", isOn: Bindable(slot).bypassMutex)
                checkbox("Kill Background Rendering", isOn: Bindable(slot).killBackgroundRendering)
                checkbox("Auto-Reconnect on Crash", isOn: Bindable(slot).autoReconnect)
            }
            .frame(maxWidth: 260, alignment: .leading)
        }
        .padding(18)
        .background(panelBackground)
    }

    private var accountSummary: String {
        let account = assignedAccount
        if account.isSignedIn {
            return "\(account.displayName) (@\(account.username))"
        }
        return "No account added"
    }

    private var tokenSummary: String {
        assignedAccount.isSignedIn ? "Session Token: Valid & Encrypted" : "Session Token: Missing"
    }

    private var accountPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your accounts")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.controlInk.opacity(0.45))
                .padding(.horizontal, 4)

            if model.home.accounts.isEmpty {
                Text("No Roblox accounts yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.controlInk.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }

            ForEach(model.home.accounts) { account in
                HStack {
                    Button {
                        slot.accountID = account.id
                        model.home.selectAccount(account.id)
                        slot.showAccountPicker = false
                        model.instances.persist()
                        model.setStatus("\(slot.name) will use \(account.username)")
                    } label: {
                        HStack {
                            Text("\(account.displayName) (@\(account.username))")
                                .foregroundStyle(Theme.controlInk)
                            Spacer()
                            if assignedAccount.id == account.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.menuBlue)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        model.home.removeAccount(account.id)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(Theme.terminateRed)
                    }
                    .buttonStyle(.plain)
                    .help("Remove account")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }

            Divider()

            Button("Add Roblox account…") {
                slot.showAccountPicker = false
                model.home.showAddAccount = true
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.menuBlue)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .padding(12)
        .frame(width: 300)
    }

    private func instanceButton(
        _ title: String,
        fill: Color,
        text: Color,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .tracking(0.3)
                .foregroundStyle(text)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(fill)
                }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityLabel(title)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(Theme.controlInk)
            .frame(width: 138, alignment: .leading)
    }

    private func configRow<Content: View>(_ title: String, @ViewBuilder value: () -> Content) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.controlInk)
                .frame(width: 140, alignment: .leading)
            value()
        }
    }

    private func pill(_ title: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Theme.controlInk)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            Capsule().fill(Color.white.opacity(0.62))
        }
    }

    private func checkbox(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
            model.instances.persist()
            model.setStatus(isOn.wrappedValue ? "Enabled \(title)" : "Disabled \(title)")
        } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isOn.wrappedValue ? Theme.launchGreen : Color.white.opacity(0.35))
                    .frame(width: 16, height: 16)
                    .overlay {
                        if isOn.wrappedValue {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(Theme.controlInk.opacity(0.22), lineWidth: 1)
                        }
                    }

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.controlInk)
            }
        }
        .buttonStyle(.plain)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.36))
    }
}
