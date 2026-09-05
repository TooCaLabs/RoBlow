import AppKit
import SwiftUI

struct BoardPointerOverlay: NSViewRepresentable {
    var cellSize: CGFloat
    var spacing: CGFloat
    var onDown: (CGPoint) -> Void
    var onDrag: (CGPoint) -> Void
    var onUp: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> BoardPointerNSView {
        let view = BoardPointerNSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        context.coordinator.view = view
        context.coordinator.bind(onDown: onDown, onDrag: onDrag, onUp: onUp)
        return view
    }

    func updateNSView(_ nsView: BoardPointerNSView, context: Context) {
        context.coordinator.bind(onDown: onDown, onDrag: onDrag, onUp: onUp)
        nsView.onDown = context.coordinator.onDown
        nsView.onDrag = context.coordinator.onDrag
        nsView.onUp = context.coordinator.onUp
    }

    final class Coordinator {
        var view: BoardPointerNSView?
        var onDown: (CGPoint) -> Void = { _ in }
        var onDrag: (CGPoint) -> Void = { _ in }
        var onUp: () -> Void = {}

        func bind(
            onDown: @escaping (CGPoint) -> Void,
            onDrag: @escaping (CGPoint) -> Void,
            onUp: @escaping () -> Void
        ) {
            self.onDown = onDown
            self.onDrag = onDrag
            self.onUp = onUp
            view?.onDown = onDown
            view?.onDrag = onDrag
            view?.onUp = onUp
        }
    }
}

final class BoardPointerNSView: NSView {
    var onDown: ((CGPoint) -> Void)?
    var onDrag: ((CGPoint) -> Void)?
    var onUp: (() -> Void)?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onDown?(convert(event.locationInWindow, from: nil))
    }

    override func mouseDragged(with event: NSEvent) {
        onDrag?(convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        onUp?()
    }

    override func scrollWheel(with event: NSEvent) {
        enclosingScrollView?.scrollWheel(with: event)
    }
}
