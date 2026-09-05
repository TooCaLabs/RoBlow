import AppKit
import SwiftUI

struct QuickTermView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("roblox menu")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.termGreen)
                Spacer()
                Text("esc")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.28))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(model.term.lines) { line in
                            Text(line.text)
                                .font(.system(size: 12.5, weight: .regular, design: .monospaced))
                                .foregroundStyle(color(for: line.kind))
                                .textSelection(.enabled)
                                .id(line.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                }
                .onChange(of: model.term.lines.count) {
                    if let last = model.term.lines.last?.id {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }

            HStack(alignment: .center, spacing: 8) {
                Text(">")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.termGreen)
                TextField("command", text: Binding(
                    get: { model.term.input },
                    set: { model.term.input = $0 }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.92))
                .focused($focused)
                .onSubmit { model.term.submit(using: model) }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.04))
        }
        .frame(maxWidth: 720)
        .frame(height: 420)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.termBg)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.termGreen.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
        .onAppear { focused = true }
        .onChange(of: model.term.isOpen) { _, open in
            if open { focused = true }
        }
        .background(QuickTermFieldBridge())
        .onKeyPress(.upArrow) {
            model.term.historyUp()
            return .handled
        }
        .onKeyPress(.downArrow) {
            model.term.historyDown()
            return .handled
        }
    }

    private func color(for kind: QuickTerm.Line.Kind) -> Color {
        switch kind {
        case .out: Color.white.opacity(0.78)
        case .err: Color(red: 1, green: 0.42, blue: 0.38)
        case .cmd: Theme.termGreen
        }
    }
}

struct QuickTermMonitor: NSViewRepresentable {
    @Environment(AppModel.self) private var model

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.start()
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.model = model
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        var model: AppModel
        private var monitor: Any?

        init(model: AppModel) {
            self.model = model
        }

        func start() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return self.model.term.handleKey(event, model: self.model)
            }
        }

        func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }
    }
}

private struct QuickTermFieldBridge: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            mark(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            mark(from: nsView)
        }
    }

    private func mark(from view: NSView) {
        var walker: NSView? = view.superview
        while let current = walker {
            if let field = current as? NSTextField {
                field.identifier = NSUserInterfaceItemIdentifier("quick-term-input")
                return
            }
            if let field = current.subviews.compactMap({ $0 as? NSTextField }).first {
                field.identifier = NSUserInterfaceItemIdentifier("quick-term-input")
                return
            }
            walker = current.superview
        }
    }
}
