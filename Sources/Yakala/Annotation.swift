import AppKit

/// Düzenleyicideki araçlar.
enum Tool: CaseIterable, Identifiable {
    case select, arrow, rectangle, ellipse, pen, highlighter, text, label, counter, stamp, magnifier, blur, pixelate

    var id: Self { self }

    var title: String {
        switch self {
        case .select: "Seç ve Taşı"
        case .arrow: "Ok"
        case .rectangle: "Dikdörtgen"
        case .ellipse: "Yuvarlak"
        case .pen: "Kalem"
        case .highlighter: "Vurgulayıcı"
        case .text: "Metin"
        case .label: "Etiket (arka planlı metin)"
        case .counter: "Numara"
        case .stamp: "Damga"
        case .magnifier: "Büyüteç"
        case .blur: "Bulanıklaştır"
        case .pixelate: "Pikselleştir"
        }
    }

    var symbol: String {
        switch self {
        case .select: "cursorarrow"
        case .arrow: "arrow.up.right"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .pen: "pencil.tip"
        case .highlighter: "highlighter"
        case .text: "textformat"
        case .label: "character.textbox"
        case .counter: "1.circle"
        case .stamp: "checkmark.seal"
        case .magnifier: "plus.magnifyingglass"
        case .blur: "drop.halffull"
        case .pixelate: "square.grid.3x3.fill"
        }
    }

    /// Tuval odaktayken aracı seçen tuş.
    var shortcut: Character {
        switch self {
        case .select: "v"
        case .arrow: "a"
        case .rectangle: "r"
        case .ellipse: "o"
        case .pen: "p"
        case .highlighter: "h"
        case .text: "t"
        case .label: "l"
        case .counter: "n"
        case .stamp: "d"
        case .magnifier: "m"
        case .blur: "b"
        case .pixelate: "x"
        }
    }
}

/// Sabit renkler. Sistem renkleri açık/koyu moda göre değiştiği için kullanılmıyor;
/// kaydedilen görüntü her zaman aynı renkte olmalı.
enum AnnotationColor: CaseIterable, Identifiable {
    case red, orange, yellow, green, blue, white, black

    var id: Self { self }

    var title: String {
        switch self {
        case .red: "Kırmızı"
        case .orange: "Turuncu"
        case .yellow: "Sarı"
        case .green: "Yeşil"
        case .blue: "Mavi"
        case .white: "Beyaz"
        case .black: "Siyah"
        }
    }

    var nsColor: NSColor {
        switch self {
        case .red: NSColor(srgbRed: 1.00, green: 0.23, blue: 0.19, alpha: 1)
        case .orange: NSColor(srgbRed: 1.00, green: 0.58, blue: 0.00, alpha: 1)
        case .yellow: NSColor(srgbRed: 1.00, green: 0.80, blue: 0.00, alpha: 1)
        case .green: NSColor(srgbRed: 0.20, green: 0.78, blue: 0.35, alpha: 1)
        case .blue: NSColor(srgbRed: 0.00, green: 0.48, blue: 1.00, alpha: 1)
        case .white: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        case .black: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        }
    }

    /// Bu rengin üzerine yazılan yazının okunur rengi (numara aracı).
    var contrastingTextColor: NSColor {
        switch self {
        case .yellow, .white: .black
        default: .white
        }
    }
}

/// Damga aracının işaretleri. Seçildiğinde rengi de kendine uygun renge geçer.
enum StampKind: CaseIterable, Identifiable {
    case check, cross, question, exclamation

    var id: Self { self }

    var glyph: String {
        switch self {
        case .check: "✓"
        case .cross: "✗"
        case .question: "?"
        case .exclamation: "!"
        }
    }

    var title: String {
        switch self {
        case .check: "Doğru"
        case .cross: "Yanlış"
        case .question: "Soru"
        case .exclamation: "Dikkat"
        }
    }

    var defaultColor: AnnotationColor {
        switch self {
        case .check: .green
        case .cross: .red
        case .question: .orange
        case .exclamation: .yellow
        }
    }
}

enum LineWidth: CaseIterable, Identifiable {
    case thin, medium, thick

    var id: Self { self }

    var title: String {
        switch self {
        case .thin: "İnce"
        case .medium: "Orta"
        case .thick: "Kalın"
        }
    }

    var value: CGFloat {
        switch self {
        case .thin: 2
        case .medium: 4
        case .thick: 8
        }
    }
}

/// Görüntü üzerine çizilmiş tek bir şekil.
/// Koordinatlar görüntünün nokta ölçeğindedir ve orijin sol üst köşededir.
struct Annotation: Identifiable, Equatable {
    enum Shape: Equatable {
        case arrow(from: CGPoint, to: CGPoint)
        case rectangle(CGRect)
        /// Dikdörtgenin içine çizilen elips (Shift ile daire).
        case ellipse(CGRect)
        case pen([CGPoint])
        /// Yarı saydam, kalın fosforlu kalem çizgisi.
        case highlight([CGPoint])
        /// `origin` metnin sol üst köşesi.
        case text(String, origin: CGPoint)
        /// İçinde sıra numarası olan dolu daire (adım adım anlatım için).
        case counter(Int, center: CGPoint)
        /// ✓ ✗ ? ! gibi hazır işaret.
        case stamp(StampKind, center: CGPoint)
        /// Görüntünün bir kısmını iki kat büyüterek gösteren yuvarlak mercek.
        case magnifier(center: CGPoint, radius: CGFloat)
        case blur(CGRect)
        case pixelate(CGRect)
    }

    let id: UUID
    var shape: Shape
    var color: AnnotationColor
    var lineWidth: LineWidth
    /// Metin renkli bir etiket kutusunun içinde mi (etiket aracı)?
    var hasBackground: Bool

    init(shape: Shape, color: AnnotationColor, lineWidth: LineWidth, hasBackground: Bool = false) {
        id = UUID()
        self.shape = shape
        self.color = color
        self.lineWidth = lineWidth
        self.hasBackground = hasBackground
    }

    var isRedaction: Bool {
        switch shape {
        case .blur, .pixelate: true
        default: false
        }
    }

    /// Çizim sırası: önce gizleme bölgeleri, sonra vurgular, en üstte diğer şekiller.
    /// Böylece oklar ve yazılar hiçbir zaman bulanıklığın ya da vurgunun altında kalmaz.
    var drawLayer: Int {
        switch shape {
        case .blur, .pixelate: 0
        case .highlight: 1
        default: 2
        }
    }

    /// Fareyle yanlışlıkla oluşan, eklenmeye değmeyecek kadar küçük şekiller.
    var isTooSmall: Bool {
        switch shape {
        case let .arrow(from, to): hypot(to.x - from.x, to.y - from.y) < 4
        case let .rectangle(rect), let .ellipse(rect), let .blur(rect), let .pixelate(rect):
            rect.width < 3 || rect.height < 3
        case let .pen(points), let .highlight(points): points.isEmpty
        case let .text(string, _): string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .counter, .stamp: false
        case let .magnifier(_, radius): radius < 10
        }
    }

    var arrowHeadLength: CGFloat { max(12, lineWidth.value * 4) }

    /// Vurgulayıcının kalınlığı: kalemden çok daha geniş.
    var highlightWidth: CGFloat { 10 + lineWidth.value * 3 } // 16 / 22 / 34

    /// Numara ve damga dairesinin yarıçapı.
    var counterRadius: CGFloat { 11 + lineWidth.value * 2 } // 15 / 19 / 27

    // MARK: - Metin

    var fontSize: CGFloat { 10 + lineWidth.value * 3 } // 16 / 22 / 34

    var textAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: color.nsColor,
        ]
    }

    /// Etiketin metin çevresindeki boşluğu.
    var labelPadding: CGSize { CGSize(width: fontSize * 0.4, height: fontSize * 0.18) }

    /// Etiket kutusunun içindeki metin: kutunun renginin üstünde okunur renkte.
    var labelAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: color.contrastingTextColor,
        ]
    }

    var counterAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedDigitSystemFont(ofSize: counterRadius * 1.15, weight: .bold),
            .foregroundColor: color.contrastingTextColor,
        ]
    }

    // MARK: - Geometri

    /// Şeklin kapladığı alan.
    var bounds: CGRect {
        switch shape {
        case let .arrow(from, to):
            CGRect(enclosing: [from, to]).insetBy(dx: -arrowHeadLength / 2, dy: -arrowHeadLength / 2)
        case let .rectangle(rect), let .ellipse(rect), let .blur(rect), let .pixelate(rect):
            rect
        case let .pen(points):
            CGRect(enclosing: points).insetBy(dx: -lineWidth.value / 2, dy: -lineWidth.value / 2)
        case let .highlight(points):
            CGRect(enclosing: points).insetBy(dx: -highlightWidth / 2, dy: -highlightWidth / 2)
        case let .text(string, origin):
            textBounds(string, origin: origin)
        case let .counter(_, center), let .stamp(_, center):
            CGRect(x: center.x - counterRadius, y: center.y - counterRadius, width: counterRadius * 2, height: counterRadius * 2)
        case let .magnifier(center, radius):
            CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        }
    }

    /// Nokta şeklin üzerinde mi? `tolerance` tıklamayı kolaylaştıran pay.
    func contains(_ point: CGPoint, tolerance: CGFloat) -> Bool {
        let reach = tolerance + lineWidth.value / 2
        switch shape {
        case let .arrow(from, to):
            return point.distance(toSegment: from, to) <= reach
        case let .rectangle(rect):
            // Sadece çerçeve tıklanabilir; içi boş olduğu için alttaki şekiller seçilebilsin.
            let outer = rect.insetBy(dx: -reach, dy: -reach)
            let inner = rect.insetBy(dx: reach, dy: reach)
            return outer.contains(point) && !inner.contains(point)
        case let .ellipse(rect):
            // Sadece çizgi tıklanabilir: nokta dış elipsin içinde, iç elipsin dışında olmalı.
            let dx = point.x - rect.midX
            let dy = point.y - rect.midY
            func isInside(radiusX: CGFloat, radiusY: CGFloat) -> Bool {
                radiusX > 0 && radiusY > 0 && (dx * dx) / (radiusX * radiusX) + (dy * dy) / (radiusY * radiusY) <= 1
            }
            return isInside(radiusX: rect.width / 2 + reach, radiusY: rect.height / 2 + reach)
                && !isInside(radiusX: rect.width / 2 - reach, radiusY: rect.height / 2 - reach)
        case let .pen(points):
            return Self.stroke(points, contains: point, reach: reach)
        case let .highlight(points):
            return Self.stroke(points, contains: point, reach: tolerance + highlightWidth / 2)
        case let .counter(_, center), let .stamp(_, center):
            return hypot(point.x - center.x, point.y - center.y) <= counterRadius + tolerance
        case let .magnifier(center, radius):
            return hypot(point.x - center.x, point.y - center.y) <= radius + tolerance
        case .text, .blur, .pixelate:
            return bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        }
    }

    /// Metnin kapladığı alan; etiketse kutunun boşluğu da dahil.
    private func textBounds(_ string: String, origin: CGPoint) -> CGRect {
        let rect = CGRect(origin: origin, size: NSAttributedString(string: string, attributes: textAttributes).size())
        return hasBackground ? rect.insetBy(dx: -labelPadding.width, dy: -labelPadding.height) : rect
    }

    private static func stroke(_ points: [CGPoint], contains point: CGPoint, reach: CGFloat) -> Bool {
        guard let first = points.first else { return false }
        if points.count == 1 { return point.distance(toSegment: first, first) <= reach }
        return zip(points, points.dropFirst()).contains { point.distance(toSegment: $0, $1) <= reach }
    }

    func moved(by delta: CGSize) -> Annotation {
        func move(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x + delta.width, y: point.y + delta.height)
        }
        var copy = self
        switch shape {
        case let .arrow(from, to): copy.shape = .arrow(from: move(from), to: move(to))
        case let .rectangle(rect): copy.shape = .rectangle(rect.offsetBy(dx: delta.width, dy: delta.height))
        case let .ellipse(rect): copy.shape = .ellipse(rect.offsetBy(dx: delta.width, dy: delta.height))
        case let .pen(points): copy.shape = .pen(points.map(move))
        case let .highlight(points): copy.shape = .highlight(points.map(move))
        case let .text(string, origin): copy.shape = .text(string, origin: move(origin))
        case let .counter(number, center): copy.shape = .counter(number, center: move(center))
        case let .stamp(kind, center): copy.shape = .stamp(kind, center: move(center))
        case let .magnifier(center, radius): copy.shape = .magnifier(center: move(center), radius: radius)
        case let .blur(rect): copy.shape = .blur(rect.offsetBy(dx: delta.width, dy: delta.height))
        case let .pixelate(rect): copy.shape = .pixelate(rect.offsetBy(dx: delta.width, dy: delta.height))
        }
        return copy
    }
}

extension CGRect {
    /// İki köşe noktasından dikdörtgen.
    init(corner a: CGPoint, _ b: CGPoint) {
        self.init(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
    }

    init(enclosing points: [CGPoint]) {
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let minX = xs.min() ?? 0
        let minY = ys.min() ?? 0
        self.init(x: minX, y: minY, width: (xs.max() ?? 0) - minX, height: (ys.max() ?? 0) - minY)
    }
}

extension CGPoint {
    func distance(toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(x - a.x, y - a.y) }
        let t = max(0, min(1, ((x - a.x) * dx + (y - a.y) * dy) / lengthSquared))
        return hypot(x - (a.x + t * dx), y - (a.y + t * dy))
    }
}
