import AppKit

// Reproducible, code-native artwork: a window carrying an F and a pair of switching arrows.
let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let tile = NSBezierPath(
    roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896),
    xRadius: 202,
    yRadius: 202
)
NSGradient(starting: NSColor(srgbRed: 0.10, green: 0.17, blue: 0.28, alpha: 1),
           ending: NSColor(srgbRed: 0.04, green: 0.08, blue: 0.15, alpha: 1))!.draw(in: tile, angle: -90)
func window(_ rect: NSRect, color: NSColor, width: CGFloat) {
    color.setStroke()
    let path = NSBezierPath(roundedRect: rect, xRadius: 40, yRadius: 40)
    path.lineWidth = width
    path.stroke()
}

window(
    NSRect(x: 320, y: 230, width: 455, height: 480),
    color: NSColor.white.withAlphaComponent(0.30),
    width: 22
)
window(NSRect(x: 220, y: 335, width: 455, height: 480), color: .white, width: 25)
let divider = NSBezierPath()
divider.move(to: NSPoint(x: 222, y: 720))
divider.line(to: NSPoint(x: 673, y: 720))
divider.lineWidth = 22
NSColor.white.setStroke()
divider.stroke()
let f = NSBezierPath()
f.move(to: NSPoint(x: 342, y: 410))
f.line(to: NSPoint(x: 342, y: 637))
f.line(to: NSPoint(x: 536, y: 637))
f.move(to: NSPoint(x: 342, y: 534))
f.line(to: NSPoint(x: 502, y: 534))
f.lineWidth = 40
f.lineCapStyle = .round
f.lineJoinStyle = .round
f.stroke()
let arrows = NSBezierPath()
arrows.move(to: NSPoint(x: 532, y: 245))
arrows.line(to: NSPoint(x: 815, y: 245))
arrows.line(to: NSPoint(x: 753, y: 303))
arrows.move(to: NSPoint(x: 815, y: 245))
arrows.line(to: NSPoint(x: 753, y: 187))
arrows.move(to: NSPoint(x: 760, y: 142))
arrows.line(to: NSPoint(x: 477, y: 142))
arrows.line(to: NSPoint(x: 539, y: 200))
arrows.move(to: NSPoint(x: 477, y: 142))
arrows.line(to: NSPoint(x: 539, y: 84))
arrows.lineWidth = 29
arrows.lineCapStyle = .round
arrows.lineJoinStyle = .round
NSColor(srgbRed: 0.29, green: 0.90, blue: 0.80, alpha: 1).setStroke()
arrows.stroke()
NSGraphicsContext.restoreGraphicsState()
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "resources/icons/app/app.png")
try bitmap.representation(using: .png, properties: [:])!.write(to: output)
