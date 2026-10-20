// Draws the Halo app icon at every size macOS wants and writes an .iconset.
// Usage: swift scripts/make-icon.swift <output.iconset>
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func draw(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = size / 1024

    // macOS icon grid: an 824pt rounded square centred in 1024.
    let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = 20 * s
    shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
    shadow.set()
    NSColor.white.setFill()
    tilePath.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGradient(colors: [NSColor(white: 0.17, alpha: 1), NSColor(white: 0.06, alpha: 1)])!.draw(in: tilePath, angle: -90)

    // A soft blue glow behind the lit slice, like the ring when an action is hovered.
    NSGraphicsContext.current?.saveGraphicsState()
    tilePath.addClip()
    let glow = NSGradient(colors: [NSColor(red: 0.1, green: 0.5, blue: 1, alpha: 0.35), .clear])!
    glow.draw(fromCenter: NSPoint(x: tile.midX, y: tile.midY + 220 * s), radius: 0,
              toCenter: NSPoint(x: tile.midX, y: tile.midY + 220 * s), radius: 420 * s, options: [])
    NSGraphicsContext.current?.restoreGraphicsState()

    // Eight slices around a centre disc, the same shape as the ring itself.
    let center = NSPoint(x: tile.midX, y: tile.midY)
    let outer: CGFloat = 318 * s, inner: CGFloat = 158 * s, gap: CGFloat = 26 * s

    func slice(_ index: Int) -> NSBezierPath {
        // AppKit angles run counter-clockwise from 3 o'clock; slice 0 sits at 12.
        let mid = 90 - CGFloat(index) * 45
        let trimOuter = gap / 2 / outer * 180 / .pi, trimInner = gap / 2 / inner * 180 / .pi
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: outer, startAngle: mid - 22.5 + trimOuter, endAngle: mid + 22.5 - trimOuter)
        path.appendArc(withCenter: center, radius: inner, startAngle: mid + 22.5 - trimInner, endAngle: mid - 22.5 + trimInner, clockwise: true)
        path.close()
        return path
    }

    for i in 1..<8 {
        NSColor.white.withAlphaComponent(0.14).setFill()
        slice(i).fill()
    }

    NSGraphicsContext.current?.saveGraphicsState()
    let shine = NSShadow()
    shine.shadowColor = NSColor(red: 0.2, green: 0.6, blue: 1, alpha: 0.9)
    shine.shadowBlurRadius = 40 * s
    shine.set()
    let lit = slice(0)
    NSColor(red: 0.04, green: 0.52, blue: 1, alpha: 1).setFill()
    lit.fill()
    NSGraphicsContext.current?.restoreGraphicsState()
    NSGradient(colors: [NSColor(red: 0.42, green: 0.76, blue: 1, alpha: 1), NSColor(red: 0.04, green: 0.5, blue: 1, alpha: 1)])!
        .draw(in: lit, angle: -90)

    let disc = NSBezierPath(ovalIn: NSRect(x: center.x - 122 * s, y: center.y - 122 * s, width: 244 * s, height: 244 * s))
    NSColor.white.withAlphaComponent(0.06).setFill()
    disc.fill()
    NSColor.white.withAlphaComponent(0.28).setStroke()
    disc.lineWidth = 7 * s
    disc.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        let png = draw(size: CGFloat(base * scale)).representation(using: .png, properties: [:])!
        try! png.write(to: output.appendingPathComponent(name))
    }
}
