// Renders the app icon PNGs into an .iconset folder: swift make-icon.swift <out.iconset>
import AppKit

let out = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let tile = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    NSGradient(colors: [NSColor(calibratedRed: 0.16, green: 0.2, blue: 0.45, alpha: 1),
                        NSColor(calibratedRed: 0.04, green: 0.05, blue: 0.14, alpha: 1)])!
        .draw(in: NSBezierPath(roundedRect: tile, xRadius: s * 0.18, yRadius: s * 0.18), angle: -90)
    let config = NSImage.SymbolConfiguration(pointSize: s * 0.4, weight: .semibold)
        .applying(.init(paletteColors: [NSColor(calibratedRed: 1, green: 0.85, blue: 0.45, alpha: 1)]))
    let moon = NSImage(systemSymbolName: "moon.fill", accessibilityDescription: nil)!.withSymbolConfiguration(config)!
    moon.draw(in: NSRect(x: (s - moon.size.width) / 2, y: (s - moon.size.height) / 2,
                         width: moon.size.width, height: moon.size.height))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try render(size).write(to: URL(fileURLWithPath: "\(out)/icon_\(size)x\(size).png"))
    try render(size * 2).write(to: URL(fileURLWithPath: "\(out)/icon_\(size)x\(size)@2x.png"))
}
