import AppKit
import CoreGraphics
import SwiftUI

/// İlk açılışta bir kez gösterilen karşılama penceresi: Yakala'nın ne yaptığı, kısayollar ve ekran kaydı izni.
/// Yakala menü çubuğunda sessizce başladığı için bu pencere olmadan yeni kullanıcı uygulamayı bulamayabilir.
final class WelcomeWindowController: NSWindowController {
    private static let shownKey = "didShowWelcome"

    static var shouldShow: Bool {
        !UserDefaults.standard.bool(forKey: shownKey)
    }

    init() {
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.contentView = NSHostingView(rootView: WelcomeView(onStart: { [weak self] in self?.close() }))
        window.setContentSize(window.contentView!.fittingSize)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) kullanılmıyor")
    }

    func present() {
        UserDefaults.standard.set(true, forKey: Self.shownKey)
        NSApp.activate()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct WelcomeView: View {
    let onStart: () -> Void
    private let settings = AppSettings.shared
    @State private var hasPermission = CGPreflightScreenCaptureAccess()

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 104, height: 104)
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                Text("Yakala'ya hoş geldin")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("Ekran görüntüsü al, işaretle, paylaş. Yakala menü çubuğunda bekler.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 14) {
                Step(symbol: "rectangle.dashed", title: "Alan seç",
                     detail: "\(settings.areaShortcut.display) ile alanı sürükleyerek seç; tek tık tüm ekranı alır.")
                Step(symbol: "macwindow", title: "Pencere seç",
                     detail: "\(settings.windowShortcut.display) ile bir pencereye tıkla.")
                Step(symbol: "pencil.and.outline", title: "İşaretle ve kopyala",
                     detail: "Ok, yazı, bulanıklaştırma ekle; ⌘C ile kopyala, hemen yapıştır.")
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            permission

            Button("Başla", action: onStart)
                .buttonStyle(BrandButtonStyle())
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 36)
        .padding(.top, 36)
        .padding(.bottom, 28)
        .frame(width: 480)
        .tint(Brand.accent)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasPermission = CGPreflightScreenCaptureAccess()
        }
    }

    @ViewBuilder
    private var permission: some View {
        if hasPermission {
            Label("Ekran kaydı izni verildi", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            VStack(spacing: 8) {
                Text("Ekranı yakalayabilmek için macOS'un ekran kaydı iznine ihtiyaç var. İzin verdikten sonra Yakala'yı yeniden açman gerekebilir.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Ekran Kaydı İznini Ver") {
                    // İlk seferde macOS izin penceresini açar; daha önce reddedildiyse ayarlar sayfasına götürür.
                    if !CGRequestScreenCaptureAccess(),
                       let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}

private struct Step: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Brand.gradient, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
