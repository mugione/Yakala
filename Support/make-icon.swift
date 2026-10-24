// Yakala'nın uygulama simgesini üretir (Support/AppIcon.icns).
// Kullanım, proje klasöründen: swift Support/make-icon.swift
import AppKit

let outputPath = CommandLine.arguments.dropFirst().first ?? "Support/AppIcon.icns"

func srgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
}

/// Gölgeler çizim ölçeğinden etkilenmez; elle ölçeklenir.
func shadow(color: NSColor, offsetY: CGFloat, blur: CGFloat, scale: CGFloat) -> NSShadow {
    let shadow = NSShadow()
    shadow.shadowColor = color
    shadow.shadowOffset = NSSize(width: 0, height: offsetY * scale)
    shadow.shadowBlurRadius = blur * scale
    return shadow
}

/// Simgeyi verilen piksel boyutunda çizer. Tüm ölçüler 1024'lük tuvale göredir.
func drawIcon(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let scale = CGFloat(pixels) / 1024
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()

    // Apple simge ızgarası: 1024'lük tuvalde 824'lük yuvarlatılmış kare, kenarlardan 100 boşluk.
    let body = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    shadow(color: .black.withAlphaComponent(0.3), offsetY: -10, blur: 22, scale: scale).set()
    srgb(0.2, 0.45, 0.97).setFill()
    body.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Alttan gök mavisi, üste doğru mor; üstte hafif bir parlaklık.
    NSGradient(starting: srgb(0.02, 0.66, 0.98), ending: srgb(0.45, 0.30, 0.97))!.draw(in: body, angle: 90)
    NSGradient(starting: .white.withAlphaComponent(0), ending: .white.withAlphaComponent(0.16))!.draw(in: body, angle: 90)

    // Vizör köşeleri.
    let low: CGFloat = 262, high: CGFloat = 762, arm: CGFloat = 150
    let brackets = NSBezierPath()
    for (corner, horizontal, vertical) in [
        (NSPoint(x: low, y: high), arm, -arm), (NSPoint(x: high, y: high), -arm, -arm),
        (NSPoint(x: high, y: low), -arm, arm), (NSPoint(x: low, y: low), arm, arm),
    ] {
        brackets.move(to: NSPoint(x: corner.x, y: corner.y + vertical))
        brackets.line(to: corner)
        brackets.line(to: NSPoint(x: corner.x + horizontal, y: corner.y))
    }
    brackets.lineWidth = 60
    brackets.lineCapStyle = .round
    brackets.lineJoinStyle = .round
    NSColor.white.setStroke()
    brackets.stroke()

    // İşaretleme oku: sol alttan sağ üste.
    let start = NSPoint(x: 380, y: 380)
    let end = NSPoint(x: 646, y: 646)
    let headLength: CGFloat = 175, headHalfWidth: CGFloat = 108
    let length = hypot(end.x - start.x, end.y - start.y)
    let ux = (end.x - start.x) / length, uy = (end.y - start.y) / length
    let base = NSPoint(x: end.x - ux * headLength, y: end.y - uy * headLength)

    let arrow = NSBezierPath()
    arrow.move(to: start)
    arrow.line(to: base)
    arrow.lineWidth = 62
    arrow.lineCapStyle = .round
    let head = NSBezierPath()
    head.move(to: end)
    head.line(to: NSPoint(x: base.x - uy * headHalfWidth, y: base.y + ux * headHalfWidth))
    head.line(to: NSPoint(x: base.x + uy * headHalfWidth, y: base.y - ux * headHalfWidth))
    head.close()
    head.lineWidth = 22
    head.lineJoinStyle = .round

    // Ok tek bir katman olarak çizilir; gölge her parçaya ayrı ayrı değil, bütüne bir kez düşer.
    NSGraphicsContext.saveGraphicsState()
    shadow(color: .black.withAlphaComponent(0.25), offsetY: -8, blur: 16, scale: scale).set()
    let context = NSGraphicsContext.current!.cgContext
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    let yellow = srgb(1.0, 0.84, 0.04)
    yellow.setStroke()
    yellow.setFill()
    arrow.stroke()
    head.fill()
    head.stroke()
    context.endTransparencyLayer()
    NSGraphicsContext.restoreGraphicsState()

    return rep
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("Yakala-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }

for points in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let name = factor == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        let png = drawIcon(pixels: points * factor).representation(using: .png, properties: [:])!
        try png.write(to: iconset.appendingPathComponent(name))
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", outputPath]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    print("iconutil başarısız oldu")
    exit(1)
}
print("Simge yazıldı: \(outputPath)")
