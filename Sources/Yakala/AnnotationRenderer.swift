import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Görüntüyü ve işaretlemeleri çizer. Ekrandaki tuval de dışa aktarma da bu kodu kullanır;
/// böylece kaydedilen görüntü ekranda görünenle birebir aynı olur.
@MainActor
final class AnnotationRenderer {
    let capture: Capture

    private lazy var ciContext = CIContext()
    /// Bulanık ve pikselli kopyalar ilk ihtiyaçta bir kez hesaplanır;
    /// her bölge bu kopyadan kırpılarak çizilir.
    private lazy var blurred: CGImage = makeBlurred()
    private lazy var pixelated: CGImage = makePixelated()

    init(capture: Capture) {
        self.capture = capture
    }

    /// Görüntüyü ve şekilleri çizer.
    /// `context` y ekseni aşağı bakan (sol üst orijinli) ve görüntünün nokta ölçeğinde olmalı.
    func draw(_ annotations: [Annotation], in context: CGContext) {
        drawImage(capture.image, in: CGRect(origin: .zero, size: capture.pointSize), context: context)
        // Önce gizleme bölgeleri, sonra vurgular, en üstte diğer şekiller (Annotation.drawLayer).
        for layer in 0...2 {
            for annotation in annotations where annotation.drawLayer == layer {
                draw(annotation, among: annotations, in: context)
            }
        }
    }

    /// İşaretlemelerin işlendiği tam çözünürlüklü görüntü. Şekil yoksa orijinal görüntü döner.
    func renderFlattened(_ annotations: [Annotation]) -> Capture? {
        guard !annotations.isEmpty else { return capture }
        let image = capture.image
        let colorSpace = image.colorSpace.flatMap { $0.supportsOutput ? $0 : nil }
            ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        // Orijini sol üste taşı ve nokta ölçeğine geç (Retina'da 1 nokta = 2 piksel).
        context.translateBy(x: 0, y: CGFloat(image.height))
        context.scaleBy(x: capture.scale, y: -capture.scale)
        context.interpolationQuality = .high
        draw(annotations, in: context)

        guard let output = context.makeImage() else { return nil }
        return Capture(image: output, scale: capture.scale, date: capture.date, hasTransparency: capture.hasTransparency)
    }

    // MARK: - Şekiller

    /// `annotations`: tüm şekiller; büyüteç altındaki gizleme bölgelerini de büyütebilsin diye.
    private func draw(_ annotation: Annotation, among annotations: [Annotation], in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }

        let color = annotation.color.nsColor.cgColor
        context.setStrokeColor(color)
        context.setFillColor(color)
        context.setLineWidth(annotation.lineWidth.value)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch annotation.shape {
        case let .arrow(from, to):
            drawArrow(from: from, to: to, headLength: annotation.arrowHeadLength, in: context)
        case let .rectangle(rect):
            context.addRect(rect)
            context.strokePath()
        case let .ellipse(rect):
            context.addEllipse(in: rect)
            context.strokePath()
        case let .pen(points):
            drawStroke(through: points, lineWidth: annotation.lineWidth.value, in: context)
        case let .highlight(points):
            // Tek katman olarak yarı saydam çizilir; çizginin kendi üstüne bindiği yerler koyulaşmaz.
            context.setLineWidth(annotation.highlightWidth)
            context.setAlpha(0.4)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            drawStroke(through: points, lineWidth: annotation.highlightWidth, in: context)
            context.endTransparencyLayer()
        case let .text(string, origin) where annotation.hasBackground:
            // Etiket: yuvarlak köşeli renkli kutu, içinde okunur renkte yazı.
            let box = annotation.bounds
            let radius = min(annotation.fontSize * 0.35, box.height / 2)
            context.addPath(CGPath(roundedRect: box, cornerWidth: radius, cornerHeight: radius, transform: nil))
            context.fillPath()
            drawText(string, at: origin, attributes: annotation.labelAttributes, in: context)
        case let .text(string, origin):
            drawText(string, at: origin, attributes: annotation.textAttributes, in: context)
        case let .counter(number, center):
            drawBadge("\(number)", at: center, annotation: annotation, in: context)
        case let .stamp(kind, center):
            drawBadge(kind.glyph, at: center, annotation: annotation, in: context)
        case let .magnifier(center, radius):
            drawMagnifier(at: center, radius: radius, annotation: annotation, among: annotations, in: context)
        case let .blur(rect):
            context.clip(to: rect)
            drawImage(blurred, in: CGRect(origin: .zero, size: capture.pointSize), context: context)
        case let .pixelate(rect):
            context.clip(to: rect)
            drawImage(pixelated, in: CGRect(origin: .zero, size: capture.pointSize), context: context)
        }
    }

    private func drawArrow(from start: CGPoint, to end: CGPoint, headLength: CGFloat, in context: CGContext) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 0 else { return }

        let head = min(headLength, length)
        let ux = dx / length
        let uy = dy / length
        let base = CGPoint(x: end.x - ux * head, y: end.y - uy * head)
        let halfWidth = head * 0.45

        // Gövde ok başının tabanında biter, uç sivri kalır.
        context.move(to: start)
        context.addLine(to: base)
        context.strokePath()

        context.move(to: end)
        context.addLine(to: CGPoint(x: base.x - uy * halfWidth, y: base.y + ux * halfWidth))
        context.addLine(to: CGPoint(x: base.x + uy * halfWidth, y: base.y - ux * halfWidth))
        context.closePath()
        context.fillPath()
    }

    /// Altındaki görüntüyü iki kat büyüterek gösteren yuvarlak mercek.
    /// Gizleme bölgeleri ve vurgular da büyütülür; büyüteç bulanıklaştırılmış bilgiyi açığa çıkarmaz.
    private func drawMagnifier(at center: CGPoint, radius: CGFloat, annotation: Annotation,
                               among annotations: [Annotation], in context: CGContext) {
        let circle = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)

        context.saveGState()
        context.setShadow(offset: .zero, blur: radius * 0.25, color: NSColor.black.withAlphaComponent(0.35).cgColor)
        context.setFillColor(NSColor.white.cgColor)
        context.fillEllipse(in: circle)
        context.restoreGState()

        context.saveGState()
        context.addEllipse(in: circle)
        context.clip()
        context.translateBy(x: center.x, y: center.y)
        context.scaleBy(x: 2, y: 2)
        context.translateBy(x: -center.x, y: -center.y)
        drawImage(capture.image, in: CGRect(origin: .zero, size: capture.pointSize), context: context)
        for underlying in annotations where underlying.drawLayer < 2 {
            draw(underlying, among: annotations, in: context)
        }
        context.restoreGState()

        let border = max(3, annotation.lineWidth.value)
        context.setStrokeColor(annotation.color.nsColor.cgColor)
        context.setLineWidth(border)
        context.strokeEllipse(in: circle)
    }

    /// İçinde numara ya da işaret olan dolu daire; ince beyaz kenarı koyu arka planlarda da daireyi ayırır.
    private func drawBadge(_ label: String, at center: CGPoint, annotation: Annotation, in context: CGContext) {
        let radius = annotation.counterRadius
        let circle = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fillEllipse(in: circle)
        let border = max(1.5, radius * 0.12)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        context.setLineWidth(border)
        context.strokeEllipse(in: circle.insetBy(dx: -border / 2, dy: -border / 2))

        // Rakamlar taban çizgisinin üstünde durur; büyük harf yüksekliğine göre dikeyde ortalanır.
        let attributes = annotation.counterAttributes
        let text = NSAttributedString(string: label, attributes: attributes)
        let font = attributes[.font] as? NSFont ?? .systemFont(ofSize: radius)
        let origin = CGPoint(x: center.x - text.size().width / 2, y: center.y + font.capHeight / 2 - font.ascender)
        drawText(text.string, at: origin, attributes: attributes, in: context)
    }

    /// Kalem çizgisini noktaların orta noktalarından geçen eğrilerle yumuşatır.
    private func drawStroke(through points: [CGPoint], lineWidth: CGFloat, in context: CGContext) {
        guard let first = points.first, let last = points.last else { return }
        if points.count == 1 {
            context.fillEllipse(in: CGRect(x: first.x - lineWidth / 2, y: first.y - lineWidth / 2,
                                           width: lineWidth, height: lineWidth))
            return
        }
        context.move(to: first)
        for (point, next) in zip(points.dropFirst(), points.dropFirst(2)) {
            let mid = CGPoint(x: (point.x + next.x) / 2, y: (point.y + next.y) / 2)
            context.addQuadCurve(to: mid, control: point)
        }
        context.addLine(to: last)
        context.strokePath()
    }

    private func drawText(_ string: String, at origin: CGPoint, attributes: [NSAttributedString.Key: Any],
                          in context: CGContext) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        NSAttributedString(string: string, attributes: attributes).draw(at: origin)
        NSGraphicsContext.restoreGraphicsState()
    }

    /// CGImage'ı y ekseni aşağı bakan bağlama ters dönmeden çizer.
    private func drawImage(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    // MARK: - Gizleme kopyaları

    private func makeBlurred() -> CGImage {
        let input = CIImage(cgImage: capture.image)
        // Kenarlar kararmasın diye görüntü önce sonsuza uzatılır, sonra eski boyutuna kırpılır.
        let output = input.clampedToExtent()
            .applyingGaussianBlur(sigma: 12 * capture.scale)
            .cropped(to: input.extent)
        return render(output, extent: input.extent)
    }

    private func makePixelated() -> CGImage {
        let input = CIImage(cgImage: capture.image)
        let filter = CIFilter.pixellate()
        filter.inputImage = input.clampedToExtent()
        filter.scale = Float(14 * capture.scale)
        filter.center = .zero
        guard let output = filter.outputImage?.cropped(to: input.extent) else { return capture.image }
        return render(output, extent: input.extent)
    }

    private func render(_ image: CIImage, extent: CGRect) -> CGImage {
        let colorSpace = capture.image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        return ciContext.createCGImage(image, from: extent, format: .RGBA8, colorSpace: colorSpace) ?? capture.image
    }
}
