import SwiftUI

struct WindowBridge: NSViewRepresentable {
    var allowsBackgroundMove: Bool
    var onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.identifier = NSUserInterfaceItemIdentifier("RoBlowWindowBridge")
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            configure(window)
            onResolve(window)
        }
    }

    private func configure(_ window: NSWindow) {
        window.isRestorable = false
        window.tabbingMode = .disallowed
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = allowsBackgroundMove
        window.styleMask.insert(.fullSizeContentView)
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        round(window.contentView)
        round(window.contentView?.superview)
        window.invalidateShadow()
    }

    private func round(_ view: NSView?) {
        guard let view else { return }
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.layer?.isOpaque = false
        view.layer?.cornerRadius = Theme.windowCorner
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
    }
}
