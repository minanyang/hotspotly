// Draws the Hotspotly logo (a router with two antennas, a Wi-Fi signal and two status lights) and
// writes every icon the app and README use. Run `make icons` after changing it; the outputs are
// committed so a normal build does not need this script.
//
//   Resources/AppIcon.icns            app icon
//   Resources/MenuBarIcon.pdf         menu bar, any network (template image)
//   Resources/MenuBarIconFilled.pdf   menu bar, on a hotspot (template image)
//   docs/icon.png                     README header
import AppKit

/// The glyph on a 24-point grid, y up.
enum Glyph {
    static let body = NSRect(x: 3, y: 3.5, width: 18, height: 6.5)
    static let lights = [NSPoint(x: 7.5, y: 6.75), NSPoint(x: 11, y: 6.75)]
    static let signalCenter = NSPoint(x: 12, y: 13.04)

    /// Body, antennas and signal as lines; `filled` makes the body solid with the lights cut out.
    static func draw(in rect: NSRect, color: NSColor, filled: Bool = false, lights lightColor: NSColor? = nil) {
        let s = rect.width / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        func line(_ width: CGFloat) -> NSBezierPath {
            let path = NSBezierPath()
            path.lineWidth = width * s
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            return path
        }
        color.set()

        let bodyRect = NSRect(origin: p(body.minX, body.minY), size: NSSize(width: body.width * s, height: body.height * s))
        let outline = NSBezierPath(roundedRect: bodyRect, xRadius: 2.5 * s, yRadius: 2.5 * s)
        outline.lineWidth = 2 * s
        outline.stroke()
        if filled {
            // Even-odd: the light dots become holes in the solid body.
            let solid = NSBezierPath(roundedRect: bodyRect, xRadius: 2.5 * s, yRadius: 2.5 * s)
            for light in lights { solid.appendOval(in: circle(p(light.x, light.y), 1 * s)) }
            solid.windingRule = .evenOdd
            solid.fill()
        }

        let antennas = line(2)
        antennas.move(to: p(6.5, 10)); antennas.line(to: p(5.4, 18))
        antennas.move(to: p(17.5, 10)); antennas.line(to: p(18.6, 18))
        antennas.stroke()

        NSBezierPath(ovalIn: circle(p(12, 13), 1.2 * s)).fill()
        let c = p(signalCenter.x, signalCenter.y)
        for (radius, angle) in [(3.4, 48.6), (6.8, 54.9)] as [(CGFloat, CGFloat)] {
            let arc = line(1.5)
            arc.appendArc(withCenter: c, radius: radius * s, startAngle: angle, endAngle: 180 - angle)
            arc.stroke()
        }

        if !filled {
            (lightColor ?? color).set()
            let r = (lightColor == nil ? 1 : 1.25) * s
            for light in lights { NSBezierPath(ovalIn: circle(p(light.x, light.y), r)).fill() }
        }
    }

    static func circle(_ center: NSPoint, _ r: CGFloat) -> NSRect {
        NSRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
    }
}

/// macOS app icon: a rounded square inset in the 1024 grid, teal to blue, white router, green lights.
func drawAppIcon(side: CGFloat) {
    let body = NSRect(x: 0, y: 0, width: side, height: side).insetBy(dx: side * 100 / 1024, dy: side * 100 / 1024)
    let radius = body.width * 0.225
    NSGradient(starting: NSColor(srgbRed: 0.16, green: 0.71, blue: 0.69, alpha: 1),
               ending: NSColor(srgbRed: 0.05, green: 0.33, blue: 0.62, alpha: 1))!
        .draw(in: NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius), angle: -90)
    let g = body.width * 0.62
    Glyph.draw(in: NSRect(x: body.midX - g / 2, y: body.midY - g / 2, width: g, height: g), color: .white,
               lights: NSColor(srgbRed: 0.20, green: 0.84, blue: 0.29, alpha: 1))
}

func png(side: Int, to url: URL) throws {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawAppIcon(side: CGFloat(side))
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

func pdf(side: CGFloat, filled: Bool, to url: URL) {
    var box = CGRect(x: 0, y: 0, width: side, height: side)
    let context = CGContext(url as CFURL, mediaBox: &box, nil)!
    context.beginPDFPage(nil)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    Glyph.draw(in: box, color: .black, filled: filled)
    NSGraphicsContext.restoreGraphicsState()
    context.endPDFPage()
    context.closePDF()
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let resources = root.appendingPathComponent("Resources")
let fm = FileManager.default

let iconset = fm.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try png(side: size, to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try png(side: size * 2, to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()

pdf(side: 24, filled: false, to: resources.appendingPathComponent("MenuBarIcon.pdf"))
pdf(side: 24, filled: true, to: resources.appendingPathComponent("MenuBarIconFilled.pdf"))

try fm.createDirectory(at: root.appendingPathComponent("docs"), withIntermediateDirectories: true)
try png(side: 256, to: root.appendingPathComponent("docs/icon.png"))
print("wrote AppIcon.icns, MenuBarIcon.pdf, MenuBarIconFilled.pdf, docs/icon.png")
