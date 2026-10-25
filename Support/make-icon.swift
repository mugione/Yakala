// Yakala'nın uygulama simgesini üretir: Support/AppIcon.icns ve README için docs/icon.png.
// Kullanım, proje klasöründen: swift Support/make-icon.swift
// Tasarım: açık cam zemin üstünde eğik bir pencere kartı (ekran görüntüsü) ve turuncu işaret oku.
import AppKit

let icnsPath = CommandLine.arguments.dropFirst().first ?? "Support/AppIcon.icns"
let previewPath = "docs/icon.png"
let space = CGColorSpace(name: CGColorSpace.displayP3)!

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [red, green, blue, alpha])!
}

func linear(_ context: CGContext, _ colors: [CGColor], from: CGPoint, to: CGPoint) {
    let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
    context.drawLinearGradient(gradient, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

/// macOS simge biçimi: 1024'lük tuvalde 824'lük süperelips ("squircle"), kenarlardan 100 boşluk.
func squircle(_ rect: CGRect, exponent: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    for step in 0...720 {
        let angle = CGFloat(step) / 720 * 2 * .pi
        let cosine = cos(angle), sine = sin(angle)
        let point = CGPoint(x: rect.midX + rect.width / 2 * (cosine < 0 ? -1 : 1) * pow(abs(cosine), 2 / exponent),
                            y: rect.midY + rect.height / 2 * (sine < 0 ? -1 : 1) * pow(abs(sine), 2 / exponent))
        step == 0 ? path.move(to: point) : path.addLine(to: point)
    }
    path.closeSubpath()
    return path
}

/// Simgeyi verilen piksel boyutunda çizer. Tüm ölçüler 1024'lük tuvale göre, orijin sol altta.
/// Küçük boyutlarda (≤ 64 px) kartın içindeki ayrıntılar çizilmez, ok kalınlaşır; simge bulanıklaşmaz.
func drawIcon(pixels: Int) -> CGImage {
    let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let scale = CGFloat(pixels) / 1024
    context.scaleBy(x: scale, y: scale)
    /// Gölgeler çizim ölçeğinden etkilenmez; elle ölçeklenir, yoksa küçük boyutlarda tuvalden taşar.
    func shadow(y: CGFloat, blur: CGFloat, _ shade: CGColor) {
        context.setShadow(offset: CGSize(width: 0, height: y * scale), blur: blur * scale, color: shade)
    }
    let small = pixels <= 64
    let body = squircle(CGRect(x: 100, y: 100, width: 824, height: 824))

    // Gövde: gölge, beyazdan serin griye zemin, üstte cam parlaması, kenarda ince ışık.
    context.saveGState()
    shadow(y: -12, blur: 30, color(0.05, 0.08, 0.2, 0.32))
    context.addPath(body)
    context.setFillColor(color(1, 1, 1))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(body)
    context.clip()
    linear(context, [color(1, 1, 1), color(0.86, 0.89, 0.96)], from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 100))
    linear(context, [color(1, 1, 1, 0.6), color(1, 1, 1, 0)], from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 640))
    context.restoreGState()

    context.saveGState()
    context.addPath(body)
    context.setLineWidth(6)
    context.replacePathWithStrokedPath()
    context.clip()
    linear(context, [color(1, 1, 1, 1), color(0.62, 0.68, 0.82, 0.5)], from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 100))
    context.restoreGState()

    // Pencere kartı (ekran görüntüsü), hafifçe eğik.
    context.saveGState()
    context.translateBy(x: 512, y: 512)
    context.rotate(by: 0.09)
    context.translateBy(x: -512, y: -512)
    let cardRect = CGRect(x: 232, y: 318, width: 560, height: 410)
    let card = CGPath(roundedRect: cardRect, cornerWidth: 48, cornerHeight: 48, transform: nil)

    context.saveGState()
    shadow(y: -20, blur: 44, color(0.12, 0.16, 0.45, 0.38))
    context.addPath(card)
    context.setFillColor(color(1, 1, 1))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(card)
    context.clip()
    // Yakala'nın marka degradesi: mavi → mor.
    linear(context, [color(0.16, 0.60, 1.0), color(0.47, 0.30, 0.98)],
           from: CGPoint(x: cardRect.minX, y: cardRect.maxY), to: CGPoint(x: cardRect.maxX, y: cardRect.minY))
    // Başlık çubuğu.
    context.setFillColor(color(1, 1, 1, 0.94))
    context.fill(CGRect(x: cardRect.minX, y: cardRect.maxY - 76, width: cardRect.width, height: 76))
    for (index, dot) in [color(1, 0.37, 0.34), color(1, 0.74, 0.18), color(0.18, 0.80, 0.36)].enumerated() {
        let size: CGFloat = small ? 38 : 30
        context.addEllipse(in: CGRect(x: cardRect.minX + 38 + CGFloat(index) * (size + 16),
                                      y: cardRect.maxY - 38 - size / 2, width: size, height: size))
        context.setFillColor(dot)
        context.fillPath()
    }
    if !small {
        // İçerik çizgileri.
        for (index, width) in [CGFloat(300), 390, 230].enumerated() {
            let line = CGRect(x: cardRect.minX + 56, y: cardRect.maxY - 150 - CGFloat(index) * 72, width: width, height: 32)
            context.addPath(CGPath(roundedRect: line, cornerWidth: 16, cornerHeight: 16, transform: nil))
            context.setFillColor(color(1, 1, 1, 0.5))
            context.fillPath()
        }
    }
    // Kartın üst yarısında cam yansıması.
    linear(context, [color(1, 1, 1, 0.22), color(1, 1, 1, 0)],
           from: CGPoint(x: cardRect.midX, y: cardRect.maxY - 76), to: CGPoint(x: cardRect.midX, y: cardRect.midY))
    context.restoreGState()

    context.addPath(card)
    context.setStrokeColor(color(1, 1, 1, 0.95))
    context.setLineWidth(10)
    context.strokePath()
    context.restoreGState()

    // İşaret oku: sol alttan sağ üste, kartın üzerinden taşar.
    let tail = CGPoint(x: 322, y: 246), tip = CGPoint(x: 752, y: 676)
    let length = hypot(tip.x - tail.x, tip.y - tail.y)
    let ux = (tip.x - tail.x) / length, uy = (tip.y - tail.y) / length
    let headLength: CGFloat = small ? 230 : 210, headHalfWidth: CGFloat = small ? 140 : 124
    let base = CGPoint(x: tip.x - ux * headLength, y: tip.y - uy * headLength)
    let shaft = CGMutablePath()
    shaft.move(to: tail)
    shaft.addLine(to: CGPoint(x: base.x + ux * 20, y: base.y + uy * 20))
    let head = CGMutablePath()
    head.move(to: tip)
    head.addLine(to: CGPoint(x: base.x - uy * headHalfWidth, y: base.y + ux * headHalfWidth))
    head.addLine(to: CGPoint(x: base.x + uy * headHalfWidth, y: base.y - ux * headHalfWidth))
    head.closeSubpath()
    let pieces = [shaft.copy(strokingWithWidth: small ? 96 : 78, lineCap: .round, lineJoin: .round, miterLimit: 10),
                  head.copy(strokingWithWidth: 34, lineCap: .round, lineJoin: .round, miterLimit: 10), head]

    // Ok tek katman olarak çizilir; gölge bütüne bir kez düşer, degrade parçaların üstüne uygulanır.
    context.saveGState()
    shadow(y: -14, blur: 28, color(0.55, 0.18, 0.0, 0.45))
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    context.setFillColor(color(1, 0.5, 0.1))
    for piece in pieces {
        context.addPath(piece)
        context.fillPath()
    }
    context.setBlendMode(.sourceAtop)
    linear(context, [color(1.0, 0.80, 0.26), color(1.0, 0.33, 0.10)], from: tip, to: tail)
    // Üst kenarda ince parlaklık: ok yuvarlak ve parlak görünür.
    linear(context, [color(1, 1, 1, 0.35), color(1, 1, 1, 0)],
           from: CGPoint(x: 400, y: 640), to: CGPoint(x: 560, y: 480))
    context.setBlendMode(.normal)
    context.endTransparencyLayer()
    context.restoreGState()

    return context.makeImage()!
}

func png(_ image: CGImage) -> Data {
    NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("Yakala-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }

for points in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let name = factor == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try png(drawIcon(pixels: points * factor)).write(to: iconset.appendingPathComponent(name))
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", icnsPath]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    print("iconutil başarısız oldu")
    exit(1)
}
try png(drawIcon(pixels: 256)).write(to: URL(fileURLWithPath: previewPath))
print("Simge yazıldı: \(icnsPath) ve \(previewPath)")
