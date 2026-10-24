import AppKit

/// Giriş noktası. Uygulama Dock'ta görünmez, sadece menü çubuğunda bir simge olarak yaşar.
@main
@MainActor
enum YakalaApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        // NSApplication.delegate zayıf (weak) referanstır; run() bitene kadar delegate'i canlı tut.
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
