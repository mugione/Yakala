import AppKit
import Testing
@testable import Yakala

/// Mac App Store görsellerini (2880 × 1800) gerçek Yakala pencerelerinden üretir.
/// Sadece ortam değişkeniyle çalışır: YAKALA_APPSTORE_DIR=docs/appstore/screenshots swift test --filter AppStore
@MainActor
struct AppStoreScreenshots {
    static let size = CGSize(width: 2880, height: 1800)

    @Test func appStoreScreenshots() async throws {
        guard let folder = ProcessInfo.processInfo.environment["YAKALA_APPSTORE_DIR"] else { return }
        _ = NSApplication.shared
        FloatingStyle.solidSurfaces = true
        defer { FloatingStyle.solidSurfaces = false }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        NSApp.applicationIconImage = NSImage(contentsOf: root.appendingPathComponent("Support/AppIcon.icns"))
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)

        // 1. İşaretle
        let annotate = editor()
        let m = annotate.model
        m.add(Annotation(shape: .rectangle(CGRect(x: 262, y: 128, width: 548, height: 118)), color: .red, lineWidth: .medium))
        m.add(Annotation(shape: .arrow(from: CGPoint(x: 640, y: 338), to: CGPoint(x: 560, y: 258)), color: .red, lineWidth: .thick))
        m.add(Annotation(shape: .text("Gelir hedefi aşıldı!", origin: CGPoint(x: 560, y: 340)), color: .red, lineWidth: .thick,
                         hasBackground: true))
        m.add(Annotation(shape: .counter(1, center: CGPoint(x: 262, y: 128)), color: .blue, lineWidth: .medium))
        m.add(Annotation(shape: .counter(2, center: CGPoint(x: 262, y: 300)), color: .blue, lineWidth: .medium))
        m.add(Annotation(shape: .ellipse(CGRect(x: 918, y: 330, width: 160, height: 250)), color: .orange, lineWidth: .medium))
        m.add(Annotation(shape: .stamp(.check, center: CGPoint(x: 1074, y: 344)), color: .green, lineWidth: .medium))
        m.selectTool(.arrow)
        try await compose(window: annotate.window, headline: ("Yakala, ", "işaretle", ", paylaş."),
                          subhead: "Oklar, şekiller, etiketler ve numaralı adımlarla her şeyi tek bakışta anlat.",
                          to: "\(folder)/1-isaretle.png")

        // 2. Gizle
        let redact = editor()
        let r = redact.model
        r.add(Annotation(shape: .pixelate(CGRect(x: 506, y: 710, width: 200, height: 160)), color: .red, lineWidth: .medium))
        r.add(Annotation(shape: .blur(CGRect(x: 280, y: 158, width: 170, height: 46)), color: .red, lineWidth: .medium))
        r.add(Annotation(shape: .text("Müşteri e-postaları gizlendi", origin: CGPoint(x: 760, y: 640)), color: .blue,
                         lineWidth: .thick, hasBackground: true))
        r.add(Annotation(shape: .arrow(from: CGPoint(x: 770, y: 680), to: CGPoint(x: 712, y: 724)), color: .blue, lineWidth: .thick))
        r.selectTool(.pixelate)
        try await compose(window: redact.window, headline: ("Gizli bilgileri ", "saniyede", " gizle."),
                          subhead: "E-postaları, şifreleri, kart numaralarını bulanıklaştır ya da pikselleştir.",
                          to: "\(folder)/2-gizle.png")

        // 3. Güzelleştir
        let beautify = editor()
        let b = beautify.model
        b.add(Annotation(shape: .arrow(from: CGPoint(x: 1010, y: 300), to: CGPoint(x: 830, y: 210)), color: .orange, lineWidth: .thick))
        b.add(Annotation(shape: .rectangle(CGRect(x: 262, y: 128, width: 548, height: 118)), color: .orange, lineWidth: .medium))
        b.setBeautifyOn(true)
        b.updateBeautify {
            $0 = BeautifySettings()
            $0.background = .sunset
            $0.windowFrame = true
            $0.padding = 90
        }
        try await compose(window: beautify.window, headline: ("Tek tıkla ", "güzelleştir", "."),
                          subhead: "8 arka plan, gölge, köşe, oran ve pencere çerçevesi. Sunumlara ve paylaşıma hazır.",
                          to: "\(folder)/3-guzellestir.png")
        b.updateBeautify { $0 = BeautifySettings() }

        // 4. Alan seçimi
        try write(selectionScene(), to: "\(folder)/4-yakala.png")

        // 5. Karşılama ve ayarlar
        let welcome = WelcomeWindowController()
        let welcomeImage = try await snapshot(welcome.window)
        let settings = SettingsWindowController()
        let settingsImage = try await snapshot(settings.window)
        try write(twoWindowScene(back: settingsImage, front: welcomeImage,
                                 headline: ("Menü çubuğunda, ", "her an", " hazır."),
                                 subhead: "Tek kısayol yeter. İnternet yok, veri toplamaz; görüntülerin Mac'inde kalır."),
                  to: "\(folder)/5-hazir.png")
    }

    // MARK: - Pencereler

    private func editor() -> EditorWindowController {
        let controller = EditorWindowController(capture: SampleScreen.capture())
        controller.window?.setContentSize(NSSize(width: 1360, height: 900))
        return controller
    }

    private func snapshot(_ window: NSWindow?) async throws -> CGImage {
        let window = try #require(window)
        window.alphaValue = 0
        window.orderFront(nil)
        try await Task.sleep(for: .seconds(1.2))
        let frameView = try #require(window.contentView?.superview)
        frameView.layoutSubtreeIfNeeded()
        let rep = try #require(frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds))
        frameView.cacheDisplay(in: frameView.bounds, to: rep)
        window.close()
        return try #require(rep.cgImage)
    }

    // MARK: - Kompozisyon

    private func compose(window: NSWindow?, headline: (String, String, String), subhead: String, to path: String) async throws {
        let image = try await snapshot(window)
        try write(scene { context in
            drawBackground(context)
            drawHeadline(headline, subhead: subhead, in: context)
            let height: CGFloat = 1300
            let width = height * CGFloat(image.width) / CGFloat(image.height)
            drawWindow(image, in: CGRect(x: (Self.size.width - width) / 2, y: 445, width: width, height: height), context: context)
        }, to: path)
    }

    private func twoWindowScene(back: CGImage, front: CGImage, headline: (String, String, String), subhead: String) -> CGImage {
        scene { context in
            drawBackground(context)
            drawHeadline(headline, subhead: subhead, in: context)
            // Yan yana, aralarında boşluk; ikisi de tamamen görünür.
            let frontHeight: CGFloat = 1240
            let frontWidth = frontHeight * CGFloat(front.width) / CGFloat(front.height)
            let backWidth: CGFloat = 1260
            let backHeight = backWidth * CGFloat(back.height) / CGFloat(back.width)
            let left = (Self.size.width - backWidth - 110 - frontWidth) / 2
            drawWindow(back, in: CGRect(x: left, y: 470 + (frontHeight - backHeight) / 2, width: backWidth, height: backHeight),
                       context: context)
            drawWindow(front, in: CGRect(x: left + backWidth + 110, y: 470, width: frontWidth, height: frontHeight), context: context)
        }
    }

    /// Alan seçimi sahnesi: masaüstü, menü çubuğu, kararmış ekran ve marka rengi seçim çerçevesi.
    private func selectionScene() -> CGImage {
        scene { context in
            drawBackground(context)
            drawHeadline(("Bir kısayolla ", "yakala", "."), subhead: "⇧⌘2 ile alanı seç, ⇧⌘1 ile pencereyi; tek tık tüm ekranı alır.",
                         in: context)

            let screen = CGRect(x: 290, y: 470, width: 2300, height: 1438)
            let corner: CGFloat = 36
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: 30), blur: 90, color: NSColor.black.withAlphaComponent(0.28).cgColor)
            context.addPath(CGPath(roundedRect: screen, cornerWidth: corner, cornerHeight: corner, transform: nil))
            context.setFillColor(NSColor.black.cgColor)
            context.fillPath()
            context.restoreGState()

            context.saveGState()
            context.addPath(CGPath(roundedRect: screen, cornerWidth: corner, cornerHeight: corner, transform: nil))
            context.clip()
            // Duvar kâğıdı ve üstünde örnek uygulama penceresi.
            let wall = CGGradient(colorsSpace: nil, colors: [Brand.blue.cgColor, Brand.violet.cgColor, Brand.orange.cgColor] as CFArray,
                                  locations: [0, 0.6, 1])!
            context.drawLinearGradient(wall, start: CGPoint(x: screen.minX, y: screen.minY),
                                       end: CGPoint(x: screen.maxX, y: screen.maxY), options: [])
            let app = SampleScreen.capture().image
            let appRect = CGRect(x: screen.minX + 150, y: screen.minY + 120, width: 2000, height: 1250)
            drawWindow(app, in: appRect, context: context, radius: 22)

            // Menü çubuğu.
            let bar = CGRect(x: screen.minX, y: screen.minY, width: screen.width, height: 58)
            context.setFillColor(NSColor.white.withAlphaComponent(0.55).cgColor)
            context.fill(bar)
            drawText("Pusula   Dosya   Düzen   Görünüm", size: 28, weight: .medium, color: .black,
                     at: CGPoint(x: bar.minX + 96, y: bar.minY + 13), context: context)
            drawText("Paz 25 Eki  14:32", size: 28, weight: .medium, color: .black,
                     at: CGPoint(x: bar.maxX - 280, y: bar.minY + 13), context: context)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            let icon = Brand.menuBarIcon
            let tinted = NSImage(size: icon.size, flipped: false) { rect in
                icon.draw(in: rect)
                NSColor.black.set()
                rect.fill(using: .sourceAtop)
                return true
            }
            tinted.draw(in: CGRect(x: bar.maxX - 360, y: bar.minY + 11, width: 36, height: 36), from: .zero, operation: .sourceOver,
                        fraction: 1, respectFlipped: true, hints: nil)
            NSGraphicsContext.restoreGraphicsState()

            // Karartma ve seçim.
            let selection = CGRect(x: appRect.minX + 300, y: appRect.minY + 230, width: 1180, height: 640)
            context.saveGState()
            context.addRect(screen)
            context.addRect(selection)
            context.setFillColor(NSColor.black.withAlphaComponent(0.38).cgColor)
            context.fillPath(using: .evenOdd)
            context.restoreGState()
            context.setStrokeColor(Brand.accentNSColor.cgColor)
            context.setLineWidth(4)
            context.stroke(selection.insetBy(dx: -2, dy: -2))
            let arm: CGFloat = 30
            context.setLineWidth(10)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            for (point, dx, dy) in [(CGPoint(x: selection.minX, y: selection.minY), arm, arm), (CGPoint(x: selection.maxX, y: selection.minY), -arm, arm),
                                    (CGPoint(x: selection.minX, y: selection.maxY), arm, -arm), (CGPoint(x: selection.maxX, y: selection.maxY), -arm, -arm)] {
                context.move(to: CGPoint(x: point.x, y: point.y + dy))
                context.addLine(to: point)
                context.addLine(to: CGPoint(x: point.x + dx, y: point.y))
            }
            context.strokePath()
            let pillText = "2360 × 1280"
            let pill = CGRect(x: selection.maxX - 270, y: selection.maxY + 18, width: 270, height: 62)
            context.saveGState()
            context.addPath(CGPath(roundedRect: pill, cornerWidth: 31, cornerHeight: 31, transform: nil))
            context.clip()
            let pillGradient = CGGradient(colorsSpace: nil, colors: [Brand.blue.cgColor, Brand.violet.cgColor] as CFArray, locations: nil)!
            context.drawLinearGradient(pillGradient, start: CGPoint(x: pill.minX, y: 0), end: CGPoint(x: pill.maxX, y: 0), options: [])
            context.restoreGState()
            drawText(pillText, size: 30, weight: .semibold, color: .white, at: CGPoint(x: pill.minX + 38, y: pill.minY + 13),
                     context: context, monospacedDigits: true)
            context.restoreGState()
        }
    }

    // MARK: - Çizim yardımcıları

    /// Sol üst orijinli (y aşağı) bir tuval açar.
    private func scene(_ draw: (CGContext) -> Void) -> CGImage {
        let context = CGContext(data: nil, width: Int(Self.size.width), height: Int(Self.size.height), bitsPerComponent: 8,
                                bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.displayP3)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.translateBy(x: 0, y: Self.size.height)
        context.scaleBy(x: 1, y: -1)
        draw(context)
        return context.makeImage()!
    }

    /// Açık, yumuşak marka zemini: beyazımsı degrade ve üzerinde bulanık renk lekeleri.
    private func drawBackground(_ context: CGContext) {
        let full = CGRect(origin: .zero, size: Self.size)
        let base = CGGradient(colorsSpace: nil, colors: [NSColor(srgbRed: 0.95, green: 0.96, blue: 1, alpha: 1).cgColor,
                                                         NSColor(srgbRed: 0.98, green: 0.95, blue: 1, alpha: 1).cgColor] as CFArray,
                              locations: nil)!
        context.drawLinearGradient(base, start: .zero, end: CGPoint(x: full.maxX, y: full.maxY), options: [])
        for (center, radius, color) in [(CGPoint(x: 300, y: 250), 900.0, Brand.blue), (CGPoint(x: 2650, y: 300), 850.0, Brand.violet),
                                        (CGPoint(x: 2500, y: 1700), 800.0, Brand.orange), (CGPoint(x: 200, y: 1650), 700.0, Brand.violet)] {
            let blob = CGGradient(colorsSpace: nil, colors: [color.withAlphaComponent(0.28).cgColor, color.withAlphaComponent(0).cgColor] as CFArray,
                                  locations: nil)!
            context.drawRadialGradient(blob, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
        }
    }

    /// Başlık: ortadaki kelime marka degradesinde. Altında açıklama.
    private func drawHeadline(_ parts: (String, String, String), subhead: String, in context: CGContext) {
        let font = Self.font(size: 112, weight: .bold)
        let dark = NSColor(srgbRed: 0.07, green: 0.08, blue: 0.17, alpha: 1)
        let pieces = [parts.0, parts.1, parts.2].map { NSAttributedString(string: $0, attributes: [.font: font, .kern: -1.5]) }
        let widths = pieces.map { $0.size().width }
        var x = (Self.size.width - widths.reduce(0, +)) / 2
        let y: CGFloat = 120
        for (index, piece) in pieces.enumerated() {
            if index == 1 {
                // Degrade yazı: metni maske olarak kullanıp degrade boya.
                let mask = textMask(piece)
                let rect = CGRect(x: x, y: y, width: CGFloat(mask.width) / 2, height: CGFloat(mask.height) / 2)
                context.saveGState()
                context.translateBy(x: 0, y: rect.maxY + rect.minY)
                context.scaleBy(x: 1, y: -1)
                context.clip(to: rect, mask: mask)
                let gradient = CGGradient(colorsSpace: nil, colors: [Brand.blue.cgColor, Brand.violet.cgColor] as CFArray, locations: nil)!
                context.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: 0), end: CGPoint(x: rect.maxX, y: 0), options: [])
                context.restoreGState()
            } else {
                drawAttributed(NSAttributedString(string: piece.string, attributes: [.font: font, .kern: -1.5, .foregroundColor: dark]),
                               at: CGPoint(x: x, y: y), context: context)
            }
            x += widths[index]
        }
        let sub = NSAttributedString(string: subhead, attributes: [
            .font: Self.font(size: 48, weight: .regular),
            .foregroundColor: NSColor(srgbRed: 0.33, green: 0.35, blue: 0.45, alpha: 1),
        ])
        drawAttributed(sub, at: CGPoint(x: (Self.size.width - sub.size().width) / 2, y: 288), context: context)
    }

    private func textMask(_ text: NSAttributedString) -> CGImage {
        let size = text.size()
        let width = Int(ceil(size.width * 2)), height = Int(ceil(size.height * 2))
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: 2, y: 2)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let white = NSMutableAttributedString(attributedString: text)
        white.addAttribute(.foregroundColor, value: NSColor.white, range: NSRange(location: 0, length: white.length))
        white.draw(at: .zero)
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()!
    }

    private func drawAttributed(_ text: NSAttributedString, at point: CGPoint, context: CGContext) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        text.draw(at: point)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawText(_ string: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, at point: CGPoint,
                          context: CGContext, monospacedDigits: Bool = false) {
        let font = monospacedDigits ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
        drawAttributed(NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color]), at: point, context: context)
    }

    /// Pencere görüntüsünü yuvarlak köşeli, büyük yumuşak gölgeli çizer. Görüntü y-aşağı tuvalde dik durur.
    private func drawWindow(_ image: CGImage, in rect: CGRect, context: CGContext, radius: CGFloat = 30) {
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 40), blur: 110, color: NSColor(srgbRed: 0.1, green: 0.1, blue: 0.3, alpha: 0.35).cgColor)
        context.addPath(path)
        context.setFillColor(NSColor.white.cgColor)
        context.fillPath()
        context.restoreGState()
        context.saveGState()
        context.addPath(path)
        context.clip()
        context.translateBy(x: 0, y: rect.maxY + rect.minY)
        context.scaleBy(x: 1, y: -1)
        context.interpolationQuality = .high
        context.draw(image, in: rect)
        context.restoreGState()
        context.addPath(path)
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.08).cgColor)
        context.setLineWidth(2)
        context.strokePath()
    }

    private static func font(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        return NSFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: size) ?? base
    }

    private func write(_ image: CGImage, to path: String) throws {
        // App Store saydamlık kabul etmez: sRGB, alfasız görüntü.
        let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
        try #require(rep.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
    }
}

/// Mağaza görsellerinde "yakalanan ekran" olarak kullanılan örnek uygulama: Pusula adında bir satış paneli.
/// 1440 × 900 nokta, 2x ölçek.
@MainActor
enum SampleScreen {
    static func capture() -> Capture {
        let size = CGSize(width: 1440, height: 900)
        let context = CGContext(data: nil, width: 2880, height: 1800, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // Nokta ölçeğinde, sol üst orijinli çizim.
        context.translateBy(x: 0, y: 1800)
        context.scaleBy(x: 2, y: -2)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        draw(in: size)
        NSGraphicsContext.restoreGraphicsState()
        return Capture(image: context.makeImage()!, scale: 2, date: .now)
    }

    private static func rgb(_ hex: Int, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }

    private static func text(_ string: String, _ point: CGPoint, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = rgb(0x1D2133)) {
        NSAttributedString(string: string, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
            .draw(at: point)
    }

    private static func box(_ rect: CGRect, radius: CGFloat = 14, fill: NSColor = .white, stroke: NSColor? = rgb(0xE6E8F0)) {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        fill.setFill()
        path.fill()
        if let stroke {
            stroke.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    private static func draw(in size: CGSize) {
        rgb(0xF5F6FA).setFill()
        NSRect(origin: .zero, size: size).fill()

        // Kenar çubuğu.
        box(CGRect(x: 0, y: 0, width: 230, height: size.height), radius: 0, stroke: nil)
        rgb(0xE6E8F0).setFill()
        NSRect(x: 229, y: 0, width: 1, height: size.height).fill()
        box(CGRect(x: 24, y: 26, width: 34, height: 34), radius: 10, fill: rgb(0x10B981), stroke: nil)
        text("◎", CGPoint(x: 31, y: 28), size: 22, weight: .bold, color: .white)
        text("Pusula", CGPoint(x: 70, y: 30), size: 21, weight: .bold)
        for (index, item) in ["Genel Bakış", "Siparişler", "Müşteriler", "Ürünler", "Raporlar", "Ayarlar"].enumerated() {
            let y = 104 + CGFloat(index) * 48
            if index == 0 {
                box(CGRect(x: 14, y: y - 9, width: 202, height: 40), radius: 10, fill: rgb(0xECFDF5), stroke: nil)
            }
            text(item, CGPoint(x: 34, y: y), size: 16, weight: index == 0 ? .semibold : .regular,
                 color: index == 0 ? rgb(0x047857) : rgb(0x5B6175))
        }

        // Üst bilgi.
        text("Genel Bakış", CGPoint(x: 262, y: 26), size: 30, weight: .bold)
        text("Ekim 2026 · Tüm mağazalar", CGPoint(x: 262, y: 68), size: 15, color: rgb(0x8A90A2))
        box(CGRect(x: 1080, y: 28, width: 220, height: 40), radius: 20)
        text("Ara…", CGPoint(x: 1104, y: 38), size: 15, color: rgb(0x9AA0B0))
        box(CGRect(x: 1318, y: 26, width: 44, height: 44), radius: 22, fill: rgb(0xFDE68A), stroke: nil)
        text("EK", CGPoint(x: 1328, y: 37), size: 15, weight: .bold, color: rgb(0x92400E))

        // Göstergeler.
        let cards = [("Gelir", "₺482.900", "+%12,4", true), ("Siparişler", "1.284", "+%8,1", true),
                     ("Yeni müşteri", "316", "+%21", true), ("İade oranı", "%1,8", "−%0,3", true)]
        for (index, card) in cards.enumerated() {
            let rect = CGRect(x: 262 + CGFloat(index) * 284, y: 116, width: 268, height: 130)
            box(rect)
            text(card.0, CGPoint(x: rect.minX + 22, y: rect.minY + 20), size: 15, color: rgb(0x8A90A2))
            text(card.1, CGPoint(x: rect.minX + 22, y: rect.minY + 46), size: 32, weight: .bold)
            box(CGRect(x: rect.minX + 22, y: rect.minY + 92, width: 74, height: 24), radius: 12, fill: rgb(0xD1FAE5), stroke: nil)
            text(card.2, CGPoint(x: rect.minX + 32, y: rect.minY + 95), size: 13, weight: .semibold, color: rgb(0x047857))
        }

        // Grafik.
        let chart = CGRect(x: 262, y: 270, width: 836, height: 340)
        box(chart)
        text("Aylık satışlar", CGPoint(x: chart.minX + 24, y: chart.minY + 20), size: 18, weight: .semibold)
        text("Son 12 ay", CGPoint(x: chart.maxX - 100, y: chart.minY + 22), size: 14, color: rgb(0x8A90A2))
        let values: [CGFloat] = [0.42, 0.55, 0.48, 0.62, 0.58, 0.7, 0.66, 0.74, 0.69, 0.81, 0.86, 0.97]
        let months = ["Kas", "Ara", "Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki"]
        for (index, value) in values.enumerated() {
            let barWidth: CGFloat = 40
            let x = chart.minX + 40 + CGFloat(index) * 64
            let height = 220 * value
            let bar = NSBezierPath(roundedRect: CGRect(x: x, y: chart.maxY - 44 - height, width: barWidth, height: height), xRadius: 8, yRadius: 8)
            let gradient = NSGradient(starting: rgb(index == 11 ? 0x10B981 : 0xA7F3D0), ending: rgb(index == 11 ? 0x059669 : 0x6EE7B7))!
            gradient.draw(in: bar, angle: 90)
            text(months[index], CGPoint(x: x + 6, y: chart.maxY - 34), size: 13, color: rgb(0x8A90A2))
        }

        // Hedef.
        let goal = CGRect(x: 1114, y: 270, width: 248, height: 340)
        box(goal)
        text("Aylık hedef", CGPoint(x: goal.minX + 22, y: goal.minY + 20), size: 18, weight: .semibold)
        let center = CGPoint(x: goal.midX, y: goal.minY + 180)
        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: 78, startAngle: 0, endAngle: 360)
        track.lineWidth = 20
        rgb(0xECEFF5).setStroke()
        track.stroke()
        let progress = NSBezierPath()
        progress.appendArc(withCenter: center, radius: 78, startAngle: -90, endAngle: -90 + 360 * 0.84, clockwise: false)
        progress.lineWidth = 20
        progress.lineCapStyle = .round
        rgb(0x10B981).setStroke()
        progress.stroke()
        text("%84", CGPoint(x: center.x - 36, y: center.y - 22), size: 32, weight: .bold)
        text("₺575.000 hedefin", CGPoint(x: goal.minX + 56, y: goal.maxY - 56), size: 14, color: rgb(0x8A90A2))

        // Son siparişler.
        let table = CGRect(x: 262, y: 630, width: 1100, height: 250)
        box(table)
        text("Son siparişler", CGPoint(x: table.minX + 24, y: table.minY + 18), size: 18, weight: .semibold)
        let columns: [CGFloat] = [24, 250, 560, 790, 950]
        for (index, header) in ["Müşteri", "E-posta", "Tarih", "Tutar", "Durum"].enumerated() {
            text(header, CGPoint(x: table.minX + columns[index], y: table.minY + 58), size: 13, weight: .medium, color: rgb(0x8A90A2))
        }
        let rows = [("Ayşe Demir", "ayse.demir@posta.com", "25 Eki", "₺2.480", "Teslim edildi", 0x047857, 0xD1FAE5),
                    ("Mehmet Kaya", "m.kaya@sirket.com.tr", "25 Eki", "₺1.150", "Kargoda", 0x1D4ED8, 0xDBEAFE),
                    ("Zeynep Arslan", "zeynep.a@posta.com", "24 Eki", "₺3.920", "Hazırlanıyor", 0xB45309, 0xFEF3C7),
                    ("Can Yıldız", "canyildiz@eposta.net", "24 Eki", "₺780", "Teslim edildi", 0x047857, 0xD1FAE5)]
        for (index, row) in rows.enumerated() {
            let y = table.minY + 88 + CGFloat(index) * 40
            rgb(0xF0F1F5).setFill()
            NSRect(x: table.minX + 16, y: y - 8, width: table.width - 32, height: 1).fill()
            text(row.0, CGPoint(x: table.minX + columns[0], y: y), size: 15, weight: .medium)
            text(row.1, CGPoint(x: table.minX + columns[1], y: y), size: 15, color: rgb(0x5B6175))
            text(row.2, CGPoint(x: table.minX + columns[2], y: y), size: 15, color: rgb(0x5B6175))
            text(row.3, CGPoint(x: table.minX + columns[3], y: y), size: 15, weight: .semibold)
            box(CGRect(x: table.minX + columns[4], y: y - 3, width: 120, height: 26), radius: 13, fill: rgb(row.6), stroke: nil)
            text(row.4, CGPoint(x: table.minX + columns[4] + 12, y: y), size: 13, weight: .semibold, color: rgb(row.5))
        }
    }
}
