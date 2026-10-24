import AppKit
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
        let r: Int, g: Int, b: Int
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
        return Color(r: Int(data[i]), g: Int(data[i + 1]), b: Int(data[i + 2]))
    }
}
