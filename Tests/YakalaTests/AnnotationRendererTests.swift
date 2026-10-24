import AppKit
import Carbon.HIToolbox
import Testing
@testable import Yakala

/// Ekrandaki tuval ile kaydedilen görüntü aynı çizim kodundan çıkıyor.
/// Bu testler kaydedilen görüntünün doğru yönde, doğru yerde ve tam çözünürlükte çizildiğini doğrular.
@MainActor
struct AnnotationRendererTests {
    @Test func withoutAnnotationsTheOriginalImageIsKept() throws {
        let capture = makeStripedCapture()
        let output = try #require(AnnotationRenderer(capture: capture).renderFlattened([]))
        #expect(output.image === capture.image)
    }

    @Test func rectangleIsDrawnFromTheTopLeftAtFullResolution() throws {
        let capture = makeStripedCapture()
        let rectangle = Annotation(shape: .rectangle(CGRect(x: 20, y: 10, width: 60, height: 30)),
                                   color: .red, lineWidth: .medium)
        let output = try #require(AnnotationRenderer(capture: capture).renderFlattened([rectangle]))
        let pixels = Pixels(output.image)

        #expect(output.image.width == 400 && output.image.height == 200)
        // Üst kenar: y = 10 nokta = 20 piksel.
        #expect(pixels[100, 20].isRed)
        // Görüntünün alt kısmına bir şey çizilmemeli.
        #expect(!pixels[100, 180].isRed)
        // Sol üstteki yeşil işaret yerinde: görüntü ters dönmemiş.
        #expect(pixels[5, 5].isGreen)
    }

    @Test func blurChangesOnlyItsRegion() throws {
        let capture = makeStripedCapture()
        let blur = Annotation(shape: .blur(CGRect(x: 100, y: 0, width: 50, height: 100)), color: .red, lineWidth: .medium)
        let pixels = Pixels(try #require(AnnotationRenderer(capture: capture).renderFlattened([blur])).image)

        // Bölgenin içi: beyaz şerit grileşmiş olmalı.
        #expect((60...200).contains(pixels[250, 100].r))
        // Bölgenin dışı: siyah şerit olduğu gibi.
        #expect(pixels[50, 100].r < 30)
    }

    @Test func pixelateMakesNeighbouringPixelsEqual() throws {
        let capture = makeStripedCapture()
        let original = Pixels(capture.image)
        #expect(original[2, 100].r != original[12, 100].r) // biri siyah, biri beyaz şerit

        let pixelate = Annotation(shape: .pixelate(CGRect(x: 0, y: 40, width: 30, height: 20)), color: .red, lineWidth: .medium)
        let pixels = Pixels(try #require(AnnotationRenderer(capture: capture).renderFlattened([pixelate])).image)
        #expect(pixels[2, 100].r == pixels[12, 100].r) // aynı blokta: aynı renk
    }

    @Test func textIsDrawnUpright() throws {
        let capture = makeStripedCapture(fill: .white)
        let text = Annotation(shape: .text("T", origin: CGPoint(x: 100, y: 20)), color: .red, lineWidth: .thick)
        let pixels = Pixels(try #require(AnnotationRenderer(capture: capture).renderFlattened([text])).image)

        // "T" harfinin yatay çizgisi üstte olmalı: kırmızı pikselin en çok olduğu satır harfin üst yarısında.
        let redCountByRow = (0..<pixels.height).map { y in (0..<pixels.width).count { x in pixels[x, y].isRed } }
        let rows = redCountByRow.indices.filter { redCountByRow[$0] > 0 }
        let top = try #require(rows.first)
        let bottom = try #require(rows.last)
        let widestRow = try #require(redCountByRow.indices.max { redCountByRow[$0] < redCountByRow[$1] })
        #expect(widestRow < (top + bottom) / 2)
    }

    @Test func hitTestingFollowsTheShapes() {
        let arrow = Annotation(shape: .arrow(from: .zero, to: CGPoint(x: 100, y: 0)), color: .red, lineWidth: .medium)
        #expect(arrow.contains(CGPoint(x: 50, y: 3), tolerance: 4))
        #expect(!arrow.contains(CGPoint(x: 50, y: 30), tolerance: 4))

        let rectangle = Annotation(shape: .rectangle(CGRect(x: 0, y: 0, width: 100, height: 100)),
                                   color: .red, lineWidth: .medium)
        #expect(rectangle.contains(CGPoint(x: 0, y: 50), tolerance: 4)) // çerçeve
        #expect(!rectangle.contains(CGPoint(x: 50, y: 50), tolerance: 4)) // içi boş

        let ellipse = Annotation(shape: .ellipse(CGRect(x: 0, y: 0, width: 100, height: 60)),
                                 color: .red, lineWidth: .medium)
        #expect(ellipse.contains(CGPoint(x: 50, y: 1), tolerance: 4)) // çizginin üstü
        #expect(!ellipse.contains(CGPoint(x: 50, y: 30), tolerance: 4)) // merkez
        #expect(!ellipse.contains(CGPoint(x: 2, y: 2), tolerance: 4)) // çevreleyen karenin köşesi
    }

    @Test func ellipseIsDrawnAsARing() throws {
        let capture = makeStripedCapture(fill: .white)
        let ellipse = Annotation(shape: .ellipse(CGRect(x: 50, y: 20, width: 100, height: 60)),
                                 color: .red, lineWidth: .medium)
        let pixels = Pixels(try #require(AnnotationRenderer(capture: capture).renderFlattened([ellipse])).image)

        #expect(pixels[200, 40].isRed) // üst orta nokta: (100, 20) nokta
        #expect(!pixels[200, 100].isRed) // merkez boş
        #expect(!pixels[104, 44].isRed) // çevreleyen karenin köşesi elipsin dışında
    }

    @Test func cropUsesTheTopLeftOrigin() throws {
        let capture = makeStripedCapture()
        let cropped = try #require(capture.cropped(to: CGRect(x: 0, y: 0, width: 10, height: 5)))
        #expect(cropped.image.width == 20 && cropped.image.height == 10)
        #expect(Pixels(cropped.image)[5, 5].isGreen)
    }

    @Test func undoAndRedoRestoreTheShapes() {
        let model = EditorModel(capture: makeStripedCapture())
        let arrow = Annotation(shape: .arrow(from: .zero, to: CGPoint(x: 50, y: 50)), color: .red, lineWidth: .medium)
        model.add(arrow)
        model.select(arrow.id)
        model.moveSelected(by: CGSize(width: 10, height: 0), recordingUndo: true)
        model.moveSelected(by: CGSize(width: 10, height: 0), recordingUndo: false) // aynı sürükleme

        model.undo()
        #expect(model.annotations == [arrow]) // tek geri alma tüm sürüklemeyi geri alır
        model.undo()
        #expect(model.annotations.isEmpty)
        model.redo()
        #expect(model.annotations == [arrow])
    }

    /// Gözle kontrol için tüm araçların çizildiği örnek bir PNG yazar.
    /// Çalıştırmak için: YAKALA_SAMPLE_PNG=/yol/ornek.png swift test
    @Test func counterIsAFilledNumberedCircle() throws {
        let capture = makeStripedCapture(fill: .white)
        let counter = Annotation(shape: .counter(7, center: CGPoint(x: 100, y: 50)), color: .red, lineWidth: .thick)
        let pixels = Pixels(try #require(AnnotationRenderer(capture: capture).renderFlattened([counter])).image)

        // Yarıçap 27 nokta: dairenin içi (rakamın dışında kalan sol kenar) kırmızı, dışı beyaz.
        #expect(pixels[2 * 78, 100].isRed)
        #expect(!pixels[2 * 130, 100].isRed)
        // Rakam beyazla yazılır: dairenin ortasında kırmızı olmayan pikseller vardır.
        let centerRow = (2 * 90..<2 * 110).map { pixels[$0, 100] }
        #expect(centerRow.contains { $0.r > 200 && $0.g > 200 && $0.b > 200 })
    }

    @Test func nextCounterNumberFollowsTheHighestNumber() {
        let model = EditorModel(capture: makeStripedCapture())
        #expect(model.nextCounterNumber == 1)
        model.add(Annotation(shape: .counter(1, center: .zero), color: .red, lineWidth: .medium))
        model.add(Annotation(shape: .counter(2, center: .zero), color: .red, lineWidth: .medium))
        #expect(model.nextCounterNumber == 3)
        model.undo()
        #expect(model.nextCounterNumber == 2)
    }

    @Test func highlightIsTranslucentAndStaysBelowOtherShapes() throws {
        let capture = makeStripedCapture(fill: .white)
        // Önce ok, sonra vurgu eklenir; vurgu yine de okun altında çizilmeli.
        let arrow = Annotation(shape: .arrow(from: CGPoint(x: 20, y: 50), to: CGPoint(x: 180, y: 50)),
                               color: .red, lineWidth: .thick)
        let highlight = Annotation(shape: .highlight([CGPoint(x: 20, y: 50), CGPoint(x: 180, y: 50)]),
                                   color: .yellow, lineWidth: .thick)
        let pixels = Pixels(try #require(AnnotationRenderer(capture: capture).renderFlattened([arrow, highlight])).image)

        // Okun çizgisi (y = 50 nokta) kırmızı kalır.
        #expect(pixels[2 * 100, 2 * 50].isRed)
        // Okun dışında, vurgunun içinde (y = 60 nokta): beyazın üstünde açık sarı, opak sarı değil.
        let tinted = pixels[2 * 100, 2 * 60]
        #expect(tinted.r > 240 && tinted.g > 200 && (120...230).contains(tinted.b))
    }

    @Test func windowCaptureKeepsTransparentCorners() throws {
        // Sol üst köşesi saydam, geri kalanı beyaz 50×50 noktalık "pencere".
        let context = CGContext(data: nil, width: 100, height: 100, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        context.clear(CGRect(x: 0, y: 80, width: 20, height: 20))
        let capture = Capture(image: context.makeImage()!, scale: 2, date: .now, hasTransparency: true)

        let arrow = Annotation(shape: .arrow(from: CGPoint(x: 30, y: 40), to: CGPoint(x: 45, y: 40)),
                               color: .red, lineWidth: .medium)
        let output = try #require(AnnotationRenderer(capture: capture).renderFlattened([arrow]))
        #expect(output.hasTransparency)
        #expect(Pixels(output.image)[5, 5].a == 0)
        #expect(Pixels(output.image)[50, 50].a == 255)
    }

    @Test func labelIsAColoredBoxWithReadableText() throws {
        let capture = makeStripedCapture(fill: .white)
        let label = Annotation(shape: .text("Not", origin: CGPoint(x: 60, y: 40)), color: .red, lineWidth: .thick,
                               hasBackground: true)
        let pixels = Pixels(try #require(AnnotationRenderer(capture: capture).renderFlattened([label])).image)

        // Kutunun metnin solundaki boşluğu kırmızı; kutunun dışı beyaz.
        #expect(pixels[2 * 56, 2 * 50].isRed)
        #expect(!pixels[2 * 40, 2 * 50].isRed)
        // Metin kırmızı kutunun içinde beyazla yazılır.
        let box = label.bounds
        let row = Int(box.midY * 2)
        let whiteInside = (Int(box.minX * 2) + 10..<Int(box.maxX * 2) - 10).contains { x in
            let pixel = pixels[x, row]
            return pixel.r > 220 && pixel.g > 220 && pixel.b > 220
        }
        #expect(whiteInside)
    }

    @Test func magnifierEnlargesTheImage() throws {
        let capture = makeStripedCapture()
        let magnifier = Annotation(shape: .magnifier(center: CGPoint(x: 100, y: 50), radius: 30),
                                   color: .blue, lineWidth: .medium)
        let pixels = Pixels(try #require(AnnotationRenderer(capture: capture).renderFlattened([magnifier])).image)
        // (110, 50) noktası normalde beyaz şeritte (220 px); 2 kat büyütmede (105, 50)'deki siyah şerit görünür.
        #expect(Pixels(capture.image)[220, 100].r > 200)
        #expect(pixels[220, 100].r < 40)
    }

    @Test func magnifierDoesNotRevealBlurredContent() throws {
        let capture = makeStripedCapture()
        let blur = Annotation(shape: .blur(CGRect(x: 60, y: 10, width: 80, height: 80)), color: .red, lineWidth: .medium)
        let magnifier = Annotation(shape: .magnifier(center: CGPoint(x: 100, y: 50), radius: 30),
                                   color: .blue, lineWidth: .medium)
        let pixels = Pixels(try #require(AnnotationRenderer(capture: capture).renderFlattened([blur, magnifier])).image)
        // Büyütülen bölge de bulanık: şeritlerin keskin siyahı ya da beyazı görünmez.
        #expect((50...205).contains(pixels[220, 100].r))
        #expect((50...205).contains(pixels[200, 100].r))
    }

    @Test func stampShowsItsMarkInAColoredCircle() throws {
        let capture = makeStripedCapture(fill: .white)
        let stamp = Annotation(shape: .stamp(.check, center: CGPoint(x: 100, y: 50)), color: .green, lineWidth: .thick)
        let pixels = Pixels(try #require(AnnotationRenderer(capture: capture).renderFlattened([stamp])).image)

        let edge = pixels[2 * 77, 100] // yarıçap 27: dairenin sol kenarına yakın
        #expect(edge.g > 150 && edge.r < 100)
        let centerRow = (2 * 88..<2 * 112).map { pixels[$0, 100] }
        #expect(centerRow.contains { $0.r > 220 && $0.g > 220 && $0.b > 220 }) // beyaz ✓
    }

    @Test func shortcutIsReadFromAKeyPress() throws {
        func press(_ keyCode: Int, _ flags: NSEvent.ModifierFlags, _ characters: String) -> NSEvent? {
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
                             context: nil, characters: characters, charactersIgnoringModifiers: characters,
                             isARepeat: false, keyCode: UInt16(keyCode))
        }
        let areaPress = try #require(press(kVK_ANSI_2, [.command, .shift], "2"))
        let area = try #require(Shortcut(event: areaPress))
        #expect(area == Shortcut.defaultArea)
        #expect(area.display == "⇧⌘2")

        let spacePress = try #require(press(kVK_Space, [.control, .option], " "))
        let space = try #require(Shortcut(event: spacePress))
        #expect(space.display == "⌃⌥Boşluk")
        #expect(space.menuKeyEquivalent.isEmpty)

        // Yalnızca Shift ile kısayol olmaz: her yerde yazı yazmayı engellerdi.
        let shiftOnly = try #require(press(kVK_ANSI_A, [.shift], "A"))
        #expect(Shortcut(event: shiftOnly) == nil)
    }

    @Test func beautifyLayoutAddsPaddingAndKeepsTheRatio() {
        var settings = BeautifySettings()
        settings.padding = 50
        let free = BeautifyLayout(imageSize: CGSize(width: 200, height: 100), settings: settings, isWindowCapture: false)
        #expect(free.canvasSize == CGSize(width: 300, height: 200))
        #expect(free.imageRect == CGRect(x: 50, y: 50, width: 200, height: 100))

        settings.ratio = .square
        settings.windowFrame = true
        let square = BeautifyLayout(imageSize: CGSize(width: 200, height: 100), settings: settings, isWindowCapture: false)
        #expect(square.canvasSize.width == square.canvasSize.height)
        #expect(square.imageRect.minY == square.contentRect.minY + BeautifyLayout.frameBarHeight)

        // Pencere yakalamada çerçeve eklenmez.
        let window = BeautifyLayout(imageSize: CGSize(width: 200, height: 100), settings: settings, isWindowCapture: true)
        #expect(!window.hasFrameBar)
    }

    @Test func beautifiedImageHasBackgroundAndTheScreenshotInTheMiddle() throws {
        let capture = makeStripedCapture()
        var settings = BeautifySettings()
        settings.padding = 40
        let renderer = AnnotationRenderer(capture: capture)
        let layout = renderer.beautifyLayout(settings)
        let output = try #require(renderer.renderFlattened([], beautify: settings))
        let pixels = Pixels(output.image)

        #expect(output.image.width == Int(layout.canvasSize.width * 2))
        // Sol üst köşe: Yakala renk geçişinin mor ucu.
        let corner = pixels[2, 2]
        #expect(corner.b > 200 && corner.r > 80 && corner.g < 120)
        // Görüntünün sol üstündeki yeşil işaret, boşluk kadar içeride.
        #expect(pixels[Int(layout.imageRect.minX * 2) + 38, Int(layout.imageRect.minY * 2) + 18].isGreen)
    }

    @Test func transparentBackgroundAndWindowFrame() throws {
        let capture = makeStripedCapture()
        var settings = BeautifySettings()
        settings.background = .transparent
        settings.windowFrame = true
        let renderer = AnnotationRenderer(capture: capture)
        let layout = renderer.beautifyLayout(settings)
        let output = try #require(renderer.renderFlattened([], beautify: settings))
        let pixels = Pixels(output.image)

        #expect(output.hasTransparency)
        #expect(pixels[2, 2].a == 0)
        // Çerçeve çubuğu: görüntünün hemen üstünde açık gri.
        let bar = pixels[Int(layout.contentRect.midX * 2), Int((layout.contentRect.minY + 4) * 2)]
        #expect(bar.r > 220 && bar.g > 220 && bar.b > 220 && bar.a == 255)
    }

    @Test func writesSampleForVisualCheck() throws {
        guard let path = ProcessInfo.processInfo.environment["YAKALA_SAMPLE_PNG"] else { return }
        let capture = makeStripedCapture()
        let annotations = [
            Annotation(shape: .blur(CGRect(x: 110, y: 10, width: 40, height: 35)), color: .red, lineWidth: .medium),
            Annotation(shape: .pixelate(CGRect(x: 155, y: 10, width: 40, height: 35)), color: .red, lineWidth: .medium),
            Annotation(shape: .rectangle(CGRect(x: 10, y: 30, width: 80, height: 50)), color: .blue, lineWidth: .medium),
            Annotation(shape: .ellipse(CGRect(x: 20, y: 5, width: 60, height: 20)), color: .orange, lineWidth: .medium),
            Annotation(shape: .arrow(from: CGPoint(x: 120, y: 90), to: CGPoint(x: 60, y: 55)), color: .red, lineWidth: .medium),
            Annotation(shape: .pen([CGPoint(x: 110, y: 60), CGPoint(x: 130, y: 70), CGPoint(x: 150, y: 58),
                                    CGPoint(x: 170, y: 75), CGPoint(x: 190, y: 62)]), color: .green, lineWidth: .thin),
            Annotation(shape: .text("Yakala ✓", origin: CGPoint(x: 112, y: 72)), color: .yellow, lineWidth: .thin),
            Annotation(shape: .highlight([CGPoint(x: 15, y: 92), CGPoint(x: 95, y: 92)]), color: .yellow, lineWidth: .medium),
            Annotation(shape: .counter(1, center: CGPoint(x: 100, y: 30)), color: .red, lineWidth: .medium),
            Annotation(shape: .counter(2, center: CGPoint(x: 180, y: 92)), color: .yellow, lineWidth: .thin),
            Annotation(shape: .text("Etiket", origin: CGPoint(x: 140, y: 52)), color: .blue, lineWidth: .thin,
                       hasBackground: true),
            Annotation(shape: .stamp(.check, center: CGPoint(x: 20, y: 70)), color: .green, lineWidth: .thin),
            Annotation(shape: .stamp(.cross, center: CGPoint(x: 50, y: 70)), color: .red, lineWidth: .thin),
            Annotation(shape: .magnifier(center: CGPoint(x: 60, y: 30), radius: 22), color: .blue, lineWidth: .thin),
        ]
        let output = try #require(AnnotationRenderer(capture: capture).renderFlattened(annotations))
        let png = try #require(NSBitmapImageRep(cgImage: output.image).representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: path))
    }
}

// MARK: - Yardımcılar

/// 200×100 noktalık Retina (2x) test görüntüsü: siyah-beyaz dikey şeritler,
/// sol üst köşede yönü belli eden yeşil bir işaret.
private func makeStripedCapture(fill: NSColor? = nil) -> Capture {
    let width = 400
    let height = 200
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    if fill == nil {
        context.setFillColor(NSColor.black.cgColor)
        for x in stride(from: 0, to: width, by: 16) {
            context.fill(CGRect(x: x, y: 0, width: 8, height: height))
        }
    }
    // CGContext'te orijin sol alttadır: sol üst köşe = y'nin en büyük olduğu yer.
    context.setFillColor(CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: height - 20, width: 40, height: 20))
    return Capture(image: context.makeImage()!, scale: 2, date: .now)
}

/// Görüntünün piksellerine sol üst orijinle erişim.
private struct Pixels {
    struct Color {
        let r: Int, g: Int, b: Int, a: Int
        var isRed: Bool { r > 200 && g < 120 && b < 120 }
        var isGreen: Bool { g > 200 && r < 60 && b < 60 }
    }

    let width: Int
    let height: Int
    private var data: [UInt8]

    init(_ image: CGImage) {
        width = image.width
        height = image.height
        data = [UInt8](repeating: 0, count: width * height * 4)
        data.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                    bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    /// Bellekteki ilk satır görüntünün en üst satırıdır.
    subscript(x: Int, y: Int) -> Color {
        let i = (y * width + x) * 4
        return Color(r: Int(data[i]), g: Int(data[i + 1]), b: Int(data[i + 2]), a: Int(data[i + 3]))
    }
}
