import AppKit
import Testing
@testable import Yakala

/// Pencerelerin görünümünü gözle kontrol etmek için PNG anlık görüntüleri yazar.
/// Sadece ortam değişkeniyle çalışır, ör.: YAKALA_SNAPSHOT_DIR=/tmp/yakala swift test
@MainActor
struct SnapshotTests {
    @Test func editorAndSettingsSnapshots() async throws {
        guard let folder = ProcessInfo.processInfo.environment["YAKALA_SNAPSHOT_DIR"] else { return }
        _ = NSApplication.shared

        let editor = EditorWindowController(capture: makeGradientCapture())
        editor.model.add(Annotation(shape: .ellipse(CGRect(x: 120, y: 80, width: 220, height: 120)),
                                    color: .red, lineWidth: .medium))
        editor.model.add(Annotation(shape: .arrow(from: CGPoint(x: 520, y: 330), to: CGPoint(x: 350, y: 180)),
                                    color: .yellow, lineWidth: .medium))
        editor.model.selectTool(.ellipse)
        try await snapshot(editor.window, to: "\(folder)/duzenleyici.png")

        let settings = SettingsWindowController()
        try await snapshot(settings.window, to: "\(folder)/ayarlar.png")
    }

    /// Pencereyi görünmez (saydam) olarak açar, başlık çubuğu dahil çizer ve kapatır.
    private func snapshot(_ window: NSWindow?, to path: String) async throws {
        let window = try #require(window)
        window.alphaValue = 0
        window.orderFront(nil)
        try await Task.sleep(for: .seconds(1))
        let frameView = try #require(window.contentView?.superview)
        frameView.layoutSubtreeIfNeeded()
        let rep = try #require(frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds))
        frameView.cacheDisplay(in: frameView.bounds, to: rep)
        try #require(rep.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
        window.close()
    }
}

/// 800×450 noktalık, renk geçişli örnek "ekran görüntüsü".
private func makeGradientCapture() -> Capture {
    let width = 1600, height = 900
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: [CGColor(srgbRed: 0.85, green: 0.9, blue: 1, alpha: 1),
                                       CGColor(srgbRed: 0.98, green: 0.92, blue: 0.85, alpha: 1)] as CFArray,
                              locations: [0, 1])!
    context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 160, y: 160, width: 1280, height: 580))
    return Capture(image: context.makeImage()!, scale: 2, date: .now)
}
