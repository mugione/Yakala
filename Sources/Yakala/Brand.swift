import AppKit
import SwiftUI

/// Yakala'nın marka renkleri; simgedeki kart (mavi → mor) ve ok (sarı → turuncu) ile aynı tonlar.
enum Brand {
    static let blue = NSColor(srgbRed: 0.16, green: 0.60, blue: 1.0, alpha: 1)
    static let violet = NSColor(srgbRed: 0.47, green: 0.30, blue: 0.98, alpha: 1)
    static let amber = NSColor(srgbRed: 1.0, green: 0.80, blue: 0.26, alpha: 1)
    static let orange = NSColor(srgbRed: 1.0, green: 0.42, blue: 0.12, alpha: 1)

    /// Vurgu rengi (seçili araç, açık anahtarlar, seçim çerçeveleri): degradenin orta tonu.
    static let accentNSColor = NSColor(srgbRed: 0.33, green: 0.44, blue: 1.0, alpha: 1)
    static let accent = Color(nsColor: accentNSColor)
    static let gradient = LinearGradient(colors: [Color(nsColor: blue), Color(nsColor: violet)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
    static let warmGradient = LinearGradient(colors: [Color(nsColor: amber), Color(nsColor: orange)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// Ana eylem düğmesi (Kopyala): marka degradeli kapsül, beyaz yazı, hafif gölge.
struct BrandButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(height: 34)
            .background(Brand.gradient, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.25)))
            .shadow(color: Color(nsColor: Brand.violet).opacity(configuration.isPressed ? 0.2 : 0.35), radius: 8, y: 3)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(Capsule())
    }
}

extension Brand {
    /// Menü çubuğu simgesi: logonun tek renkli hâli (eğik pencere kartı ve işaret oku).
    /// Şablon görüntü olduğu için macOS açık / koyu menü çubuğuna göre kendisi renklendirir.
    static let menuBarIcon: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let card = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 4, width: 14, height: 10.5), xRadius: 2.2, yRadius: 2.2)
            let tilt = AffineTransform(rotationByDegrees: 5)
            var centered = AffineTransform(translationByX: -8.5, byY: -9.25)
            centered.append(tilt)
            centered.append(AffineTransform(translationByX: 8.5, byY: 9.25))
            card.transform(using: centered)
            card.lineWidth = 1.5
            NSColor.black.setStroke()
            card.stroke()

            // Okun kartla kesiştiği yer silinir; ok kartın üstünde okunur kalır.
            let tail = NSPoint(x: 4.5, y: 3), tip = NSPoint(x: 15.5, y: 14)
            let shaft = NSBezierPath()
            shaft.move(to: tail)
            shaft.line(to: NSPoint(x: 12, y: 10.5))
            shaft.lineWidth = 2.2
            shaft.lineCapStyle = .round
            let head = NSBezierPath()
            head.move(to: tip)
            head.line(to: NSPoint(x: 9.6, y: 12.6))
            head.line(to: NSPoint(x: 14.1, y: 8.1))
            head.close()
            head.lineJoinStyle = .round
            head.lineWidth = 1.2

            NSGraphicsContext.current?.compositingOperation = .clear
            let gap = NSBezierPath()
            gap.append(shaft)
            gap.lineWidth = 5
            gap.lineCapStyle = .round
            gap.stroke()
            head.lineWidth = 4
            head.stroke()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            head.lineWidth = 1.2
            NSColor.black.setFill()
            shaft.stroke()
            head.fill()
            head.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Yakala"
        return image
    }()
}
