import SwiftUI

enum GlassStyle {
    case window
    case sidebar
    case bar
    case panel

    var material: NSVisualEffectView.Material {
        switch self {
        case .window: .fullScreenUI
        case .sidebar: .popover
        case .bar: .popover
        case .panel: .menu
        }
    }

    var wash: Color {
        switch self {
        case .window: Color.white.opacity(0.22)
        case .sidebar: Color.white.opacity(0.58)
        case .bar: Color.white.opacity(0.52)
        case .panel: Color.white.opacity(0.48)
        }
    }
}

final class PassthroughVisualEffectView: NSVisualEffectView {
    var cornerRadius: CGFloat = 0 {
        didSet {
            if oldValue != cornerRadius {
                updateCornerMask()
            }
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func layout() {
        super.layout()
        updateCornerMask()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateCornerMask()
    }

    func updateCornerMask() {
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.clear.cgColor

        let mask = CAShapeLayer()
        mask.frame = bounds
        let path = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
        mask.path = path.cgPath
        layer?.mask = mask
    }
}

struct FrostedGlass: NSViewRepresentable {
    var style: GlassStyle = .window
    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> PassthroughVisualEffectView {
        let view = PassthroughVisualEffectView()
        view.cornerRadius = cornerRadius
        apply(style, to: view)
        return view
    }

    func updateNSView(_ nsView: PassthroughVisualEffectView, context: Context) {
        nsView.cornerRadius = cornerRadius
        apply(style, to: nsView)
        nsView.updateCornerMask()
    }

    private func apply(_ style: GlassStyle, to view: PassthroughVisualEffectView) {
        view.material = style.material
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = true
        view.appearance = NSAppearance(named: .vibrantLight)
        view.wantsLayer = true
    }
}

struct GlassSurface: View {
    var style: GlassStyle
    var cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            FrostedGlass(style: style, cornerRadius: cornerRadius)

            shape.fill(style.wash)

            if style == .window {
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.38),
                            Color.white.opacity(0.06),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
            }
        }
        .clipShape(shape)
        .compositingGroup()
    }
}

struct GlassStroke: View {
    var cornerRadius: CGFloat
    var lineWidth: CGFloat = 1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.78),
                        Color.white.opacity(0.28),
                        Color.white.opacity(0.42)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: lineWidth
            )
    }
}
