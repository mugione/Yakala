import SwiftUI

/// Düzenleyicideki yüzen çubuklar ve bildirimler için ortak görünüm.
/// macOS 26 ve sonrasında Liquid Glass, öncesinde buzlu cam (material) kullanılır.
enum FloatingStyle {
    /// Cam ve buzlu cam, pencere görüntüye çevrilirken (mağaza görselleri, testler) çizilemez;
    /// açıkken yüzeyler aynı biçimde ama düz, yarı saydam beyazla çizilir.
    nonisolated(unsafe) static var solidSurfaces = false
}

private struct SolidSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(colorScheme == .dark ? Color(white: 0.2) : Color.white, in: shape)
            .overlay(shape.strokeBorder(Color.primary.opacity(0.08)))
            .shadow(color: .black.opacity(0.14), radius: 14, y: 5)
    }
}

extension View {
    @ViewBuilder
    func floatingBar() -> some View {
        if FloatingStyle.solidSurfaces {
            modifier(SolidSurface(shape: Capsule()))
        } else if #available(macOS 26.0, *) {
            glassEffect(.regular, in: Capsule())
        } else {
            background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        }
    }

    /// Yüzen çubukla aynı görünümde, köşeleri yuvarlatılmış dikdörtgen panel.
    @ViewBuilder
    func floatingPanel() -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        if FloatingStyle.solidSurfaces {
            modifier(SolidSurface(shape: shape))
        } else if #available(macOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.08)))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        }
    }

    @ViewBuilder
    func floatingButton(prominent: Bool) -> some View {
        if FloatingStyle.solidSurfaces {
            if prominent {
                buttonStyle(.borderedProminent)
            } else {
                buttonStyle(.bordered)
            }
        } else if #available(macOS 26.0, *) {
            if prominent {
                buttonStyle(.glassProminent)
            } else {
                buttonStyle(.glass)
            }
        } else {
            if prominent {
                buttonStyle(.borderedProminent)
            } else {
                buttonStyle(.bordered)
            }
        }
    }
}
