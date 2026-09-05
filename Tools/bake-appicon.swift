import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let layerURL = root.appendingPathComponent("RoBlow/Assets.xcassets/AppIcon.icon/Assets/image (4).png")
let setURL = root.appendingPathComponent("RoBlow/Assets.xcassets/AppIcon.appiconset")
guard let source = NSImage(contentsOf: layerURL)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fatalError("missing layer")
}

let w = source.width
let h = source.height
let ctx = CGContext(
    data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
ctx.draw(source, in: CGRect(x: 0, y: 0, width: w, height: h))
let data = ctx.data!.assumingMemoryBound(to: UInt8.self)
var minX = w, minY = h, maxX = 0, maxY = 0
for y in 0..<h {
    for x in 0..<w {
        let i = (y * ctx.bytesPerRow) + x * 4
        let r = data[i], a = data[i + 3]
        if a < 20 || r < 90 { continue }
        minX = min(minX, x); minY = min(minY, y)
        maxX = max(maxX, x); maxY = max(maxY, y)
    }
}
for y in 0..<h {
    for x in 0..<w {
        let i = (y * ctx.bytesPerRow) + x * 4
        if data[i + 3] < 20 || data[i] < 70 {
            data[i] = 0; data[i + 1] = 0; data[i + 2] = 0; data[i + 3] = 0
        }
    }
}
let pad = 8
minX = max(0, minX - pad); minY = max(0, minY - pad)
maxX = min(w - 1, maxX + pad); maxY = min(h - 1, maxY + pad)
let punched = ctx.makeImage()!
let cropped = punched.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))!
let mark = NSImage(cgImage: cropped, size: .zero)
if let tiff = mark.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    try png.write(to: layerURL)
}

let canvas = 1024
let fill: CGFloat = 0.74
let composed = NSImage(size: NSSize(width: canvas, height: canvas), flipped: false) { rect in
    let colors = [
        NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1).cgColor,
        NSColor(srgbRed: 0.75140, green: 0.72365, blue: 1, alpha: 1).cgColor
    ]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
    let cg = NSGraphicsContext.current!.cgContext
    cg.drawLinearGradient(
        gradient,
        start: CGPoint(x: rect.midX, y: rect.maxY),
        end: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.7),
        options: [.drawsAfterEndLocation, .drawsBeforeStartLocation]
    )
    let side = CGFloat(canvas) * fill
    mark.draw(in: NSRect(x: (CGFloat(canvas) - side) / 2, y: (CGFloat(canvas) - side) / 2, width: side, height: side))
    return true
}

func write(_ size: Int, name: String) throws {
    let target = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        composed.draw(in: rect)
        return true
    }
    let tiff = target.tiffRepresentation!
    let rep = NSBitmapImageRep(data: tiff)!
    try rep.representation(using: .png, properties: [:])!.write(to: setURL.appendingPathComponent(name))
}

try write(16, name: "icon_16.png")
try write(32, name: "icon_16@2x.png")
try write(32, name: "icon_32.png")
try write(64, name: "icon_32@2x.png")
try write(128, name: "icon_128.png")
try write(256, name: "icon_128@2x.png")
try write(256, name: "icon_256.png")
try write(512, name: "icon_256@2x.png")
try write(512, name: "icon_512.png")
try write(1024, name: "icon_512@2x.png")
print("baked \(maxX - minX)x\(maxY - minY)")
