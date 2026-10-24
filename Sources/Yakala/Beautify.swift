import AppKit

/// Güzelleştir: ekran görüntüsünü renkli bir arka planın ortasına; boşluk, yuvarlak köşe,
/// gölge ve isteğe bağlı pencere çerçevesiyle yerleştirir.
struct BeautifySettings: Codable, Equatable {
    var background: BeautifyBackground = .yakala
    /// Görüntünün çevresindeki boşluk (nokta).
    var padding: CGFloat = 64
    var cornerRadius: CGFloat = 12
    /// 0 gölgesiz, 1 en koyu.
    var shadow: CGFloat = 0.5
    var ratio: BeautifyRatio = .automatic
    /// Görüntünün üstüne macOS penceresi gibi ●●● başlık çubuğu ekler.
    var windowFrame = false

    static let paddingRange: ClosedRange<CGFloat> = 16...160
    static let cornerRange: ClosedRange<CGFloat> = 0...32
}

enum BeautifyBackground: String, Codable, CaseIterable, Identifiable {
    case yakala, sunset, ocean, mint, peach, night, gray, transparent

    var id: Self { self }

    var title: String {
        switch self {
        case .yakala: "Yakala"
        case .sunset: "Gün batımı"
        case .ocean: "Okyanus"
        case .mint: "Nane"
        case .peach: "Şeftali"
        case .night: "Gece"
        case .gray: "Açık gri"
        case .transparent: "Saydam"
        }
    }

    /// Sol üstten sağ alta renk geçişi; düz renklerde iki renk aynı, saydamda boş.
    var colors: [NSColor] {
        func srgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: 1) }
        switch self {
        case .yakala: return [srgb(0.45, 0.30, 0.97), srgb(0.02, 0.66, 0.98)]
        case .sunset: return [srgb(1.00, 0.62, 0.35), srgb(0.91, 0.26, 0.55)]
        case .ocean: return [srgb(0.00, 0.40, 0.75), srgb(0.20, 0.85, 0.85)]
        case .mint: return [srgb(0.62, 0.96, 0.78), srgb(0.18, 0.70, 0.58)]
        case .peach: return [srgb(1.00, 0.88, 0.72), srgb(0.98, 0.58, 0.60)]
        case .night: return [srgb(0.10, 0.11, 0.24), srgb(0.36, 0.20, 0.48)]
        case .gray: return [srgb(0.93, 0.93, 0.95), srgb(0.93, 0.93, 0.95)]
        case .transparent: return []
        }
    }
}

enum BeautifyRatio: String, Codable, CaseIterable, Identifiable {
    case automatic, wide, standard, square

    var id: Self { self }

    var title: String {
        switch self {
        case .automatic: "Otomatik"
        case .wide: "16:9"
        case .standard: "4:3"
        case .square: "1:1"
        }
    }

    /// Genişlik / yükseklik; otomatikte nil (boşluk her yönde eşit).
    var value: CGFloat? {
        switch self {
        case .automatic: nil
        case .wide: 16.0 / 9.0
        case .standard: 4.0 / 3.0
        case .square: 1
        }
    }
}

/// Güzelleştirilmiş görüntünün yerleşimi; tüm değerler görüntünün nokta ölçeğinde, orijin sol üstte.
struct BeautifyLayout: Equatable {
    static let frameBarHeight: CGFloat = 28

    /// Ortaya çıkan görüntünün tamamı.
    let canvasSize: CGSize
    /// Ekran görüntüsünün kendisi (çizimler bu alanın koordinatlarında).
    let imageRect: CGRect
    /// Görüntü ile pencere çerçevesi birlikte (köşe ve gölge buna uygulanır).
    let contentRect: CGRect
    let hasFrameBar: Bool

    /// Pencere yakalamada görüntünün kendi şekli (saydam köşeleri) kullanıldığı için çerçeve eklenmez.
    init(imageSize: CGSize, settings: BeautifySettings, isWindowCapture: Bool) {
        hasFrameBar = settings.windowFrame && !isWindowCapture
        let bar = hasFrameBar ? Self.frameBarHeight : 0
        let content = CGSize(width: imageSize.width, height: imageSize.height + bar)
        var canvas = CGSize(width: content.width + settings.padding * 2, height: content.height + settings.padding * 2)
        if let ratio = settings.ratio.value {
            // Oran tutsun diye kısa kenar uzatılır; görüntü ortada kalır.
            if canvas.width / canvas.height < ratio {
                canvas.width = canvas.height * ratio
            } else {
                canvas.height = canvas.width / ratio
            }
        }
        canvasSize = CGSize(width: canvas.width.rounded(), height: canvas.height.rounded())
        let origin = CGPoint(x: ((canvasSize.width - content.width) / 2).rounded(),
                             y: ((canvasSize.height - content.height) / 2).rounded())
        contentRect = CGRect(origin: origin, size: content)
        imageRect = CGRect(x: origin.x, y: origin.y + bar, width: imageSize.width, height: imageSize.height)
    }
}
