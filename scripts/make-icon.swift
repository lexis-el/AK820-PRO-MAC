// Draws the app icon (a small RGB keyboard) and writes assets/AppIcon.icns.
// Run from the repo root: swift scripts/make-icon.swift
import AppKit

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // macOS icon grid: ~10% margin, continuous-corner squircle approximated by a rounded rect.
    let inset = s * 0.1, body = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let bg = CGPath(roundedRect: body, cornerWidth: s * 0.18, cornerHeight: s * 0.18, transform: nil)
    ctx.addPath(bg); ctx.clip()
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [CGColor(red: 0.16, green: 0.17, blue: 0.22, alpha: 1),
                                   CGColor(red: 0.06, green: 0.06, blue: 0.09, alpha: 1)] as CFArray,
                          locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])

    // Screen (top right) and a 4x6 block of keys lit in a rainbow.
    let pad = body.width * 0.12
    let area = body.insetBy(dx: pad, dy: pad)
    let cols = 6, rows = 4
    let gap = area.width * 0.035
    let kw = (area.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
    let kh = (area.height * 0.72 - gap * CGFloat(rows - 1)) / CGFloat(rows)
    for r in 0..<rows {
        for c in 0..<cols {
            if r == 0 && c > 0 && c < 5 { continue }   // space bar row
            let hue = (CGFloat(c) / CGFloat(cols) + CGFloat(r) * 0.06).truncatingRemainder(dividingBy: 1)
            NSColor(hue: hue, saturation: 0.75, brightness: 1, alpha: 1).setFill()
            let x = area.minX + CGFloat(c) * (kw + gap)
            let y = area.minY + CGFloat(r) * (kh + gap)
            NSBezierPath(roundedRect: CGRect(x: x, y: y, width: kw, height: kh), xRadius: kw * 0.18, yRadius: kw * 0.18).fill()
        }
    }
    // space bar
    NSColor(hue: 0.55, saturation: 0.6, brightness: 1, alpha: 1).setFill()
    let sx = area.minX + kw + gap, sy = area.minY
    NSBezierPath(roundedRect: CGRect(x: sx, y: sy, width: 4 * kw + 3 * gap, height: kh), xRadius: kw * 0.18, yRadius: kw * 0.18).fill()
    // screen
    let scr = CGRect(x: area.maxX - kw * 2 - gap, y: area.minY + area.height * 0.78, width: kw * 2 + gap, height: area.height * 0.22)
    NSColor(white: 0.02, alpha: 1).setFill()
    NSBezierPath(roundedRect: scr, xRadius: kw * 0.15, yRadius: kw * 0.15).fill()
    NSColor(hue: 0.08, saturation: 0.8, brightness: 1, alpha: 1).setFill()
    NSBezierPath(ovalIn: scr.insetBy(dx: scr.width * 0.3, dy: scr.height * 0.2)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try render(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", "assets/AppIcon.icns"]
try p.run(); p.waitUntilExit()
print(p.terminationStatus == 0 ? "wrote assets/AppIcon.icns" : "iconutil failed")
