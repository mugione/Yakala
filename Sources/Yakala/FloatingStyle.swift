import SwiftUI

/// Düzenleyicideki yüzen çubuklar ve bildirimler için ortak görünüm.
/// macOS 26 ve sonrasında Liquid Glass, öncesinde buzlu cam (material) kullanılır.
extension View {
    @ViewBuilder
    func floatingBar() -> some View {
        if #available(macOS 26.0, *) {
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
        if #available(macOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.08)))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        }
    }

    @ViewBuilder
    func floatingButton(prominent: Bool) -> some View {
        if #available(macOS 26.0, *) {
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
