import AppKit
import Carbon.HIToolbox

/// Menü çubuğu simgesini ve global kısayolları yönetir.
/// Sol tık veya ⇧⌘2: alan seç. ⇧⌘1: pencere seç. Sağ tık (veya Control + tık): menüyü aç.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum CaptureMode {
        case area
        case window
        case fullScreen
    }

    private var statusItem: NSStatusItem!
    private var hotKey: GlobalHotKey?
    private var windowHotKey: GlobalHotKey?
    private let areaSelector = AreaSelector()
    /// Son görüntünün düzenleyicisi. Pencere kapansa da tutulur; menüden yeniden açılınca çizimler kaybolmaz.
    private var editorController: EditorWindowController?
    private var settingsController: SettingsWindowController?
    private var isCapturing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let icon = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Yakala")
            icon?.isTemplate = true
            button.image = icon
            button.toolTip = "Tıkla veya ⇧⌘2: alan seç\n⇧⌘1: pencere seç\nSağ tık: menü"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        hotKey = GlobalHotKey(keyCode: kVK_ANSI_2, modifiers: cmdKey | shiftKey) { [weak self] in
            self?.startCapture(.area, delay: .zero)
        }
        if hotKey == nil {
            NSLog("Yakala: ⇧⌘2 kısayolu kaydedilemedi, başka bir uygulama kullanıyor olabilir.")
        }
        windowHotKey = GlobalHotKey(keyCode: kVK_ANSI_1, modifiers: cmdKey | shiftKey) { [weak self] in
            self?.startCapture(.window, delay: .zero)
        }
        if windowHotKey == nil {
            NSLog("Yakala: ⇧⌘1 kısayolu kaydedilemedi, başka bir uygulama kullanıyor olabilir.")
        }
    }

    /// Yakala çalışırken yeniden açılırsa (Finder, Spotlight, `open`) ayarlar penceresi gelir.
    /// Çentikli MacBook'larda menü çubuğu doluysa simge çentiğin arkasında kalabilir; bu, uygulamaya
    /// simge olmadan ulaşmanın yolu.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            startCapture(.area)
        }
    }

    // MARK: - Menü

    private func showMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let hasCapture = editorController != nil

        let areaItem = addItem(to: menu, title: "Alan Seç", action: #selector(captureArea))
        areaItem.keyEquivalent = "2"
        areaItem.keyEquivalentModifierMask = [.command, .shift]
        let windowItem = addItem(to: menu, title: "Pencere Seç", action: #selector(captureWindow))
        windowItem.keyEquivalent = "1"
        windowItem.keyEquivalentModifierMask = [.command, .shift]
        addItem(to: menu, title: "Tüm Ekranı Al", action: #selector(captureFullScreen))
        menu.addItem(.separator())
        addItem(to: menu, title: "Son Görüntüyü Göster", action: #selector(showLastCapture), enabled: hasCapture)
        addItem(to: menu, title: "Kopyala", action: #selector(copyLastCapture), enabled: hasCapture)
        addItem(to: menu, title: "Kaydet", action: #selector(saveLastCapture), enabled: hasCapture)
        menu.addItem(.separator())
        addItem(to: menu, title: "Yakala Hakkında", action: #selector(showAbout))
        addItem(to: menu, title: "Ayarlar…", action: #selector(showSettings)).keyEquivalent = ","
        menu.addItem(withTitle: "Yakala'dan Çık", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // Menüyü simgenin altında açmanın standart yolu: geçici olarak bağla, tıkla, çöz.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @discardableResult
    private func addItem(to menu: NSMenu, title: String, action: Selector, enabled: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = enabled
        menu.addItem(item)
        return item
    }

    // MARK: - Eylemler

    @objc private func captureArea() {
        startCapture(.area)
    }

    @objc private func captureWindow() {
        startCapture(.window)
    }

    @objc private func captureFullScreen() {
        startCapture(.fullScreen)
    }

    /// - Parameter delay: Menünün ve simge vurgusunun ekrandan kaybolması için bekleme.
    ///   Kısayolla tetiklendiğinde beklemeye gerek yok.
    private func startCapture(_ mode: CaptureMode, delay: Duration = .milliseconds(200)) {
        guard !isCapturing else { return }
        isCapturing = true
        // Düzenleyici kapanınca bu uygulamaya dönülür (ör. kopyaladıktan sonra hemen yapıştırmak için).
        let previousApp = NSWorkspace.shared.frontmostApplication.flatMap { $0 == .current ? nil : $0 }
        Task {
            defer { isCapturing = false }
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            do {
                let capture: Capture?
                switch mode {
                case .area, .window:
                    // Pencere listesi seçim katmanı açılmadan alınır; katmanın kendisi listeye girmesin.
                    let windows = ScreenCapturer.visibleWindows()
                    let shots = try await ScreenCapturer.captureAllScreens()
                    switch await areaSelector.select(from: shots, windows: windows,
                                                     startingIn: mode == .window ? .window : .area) {
                    case let .area(image): capture = image
                    case let .window(id): capture = try await ScreenCapturer.captureWindow(id)
                    case nil: capture = nil
                    }
                case .fullScreen:
                    capture = try await ScreenCapturer.captureScreenUnderMouse()
                }
                guard let capture else { return } // Esc ile vazgeçildi
                showEditor(for: capture, returningTo: previousApp)
            } catch {
                presentError(error)
            }
        }
    }

    @objc private func showLastCapture() {
        editorController?.present()
    }

    @objc private func copyLastCapture() {
        editorController?.copyAndClose()
    }

    @objc private func saveLastCapture() {
        editorController?.saveAndClose()
    }

    private func showEditor(for capture: Capture, returningTo previousApp: NSRunningApplication?) {
        // Eski pencere kapanırken önceki uygulamaya dönmesin; yeni pencere hemen açılacak.
        editorController?.previousApp = nil
        editorController?.close()
        let controller = EditorWindowController(capture: capture)
        controller.previousApp = previousApp
        editorController = controller

        let settings = AppSettings.shared
        var autoSaveError: Error?
        if settings.autoSave {
            do {
                try controller.model.autoSave(to: settings.saveFolder)
            } catch {
                autoSaveError = error
            }
        }

        controller.present()
        if let autoSaveError {
            let alert = NSAlert(error: autoSaveError)
            alert.messageText = "Otomatik kayıt yapılamadı"
            alert.runModal()
        }
    }

    @objc private func showAbout() {
        About.showPanel()
    }

    @objc private func showSettings() {
        let controller = settingsController ?? SettingsWindowController()
        settingsController = controller
        controller.present()
    }

    private func presentError(_ error: Error) {
        NSApp.activate()
        let alert = NSAlert()
        if case CaptureError.permissionDenied = error {
            alert.messageText = "Ekran kaydı izni gerekiyor"
            alert.informativeText = """
                Sistem Ayarları › Gizlilik ve Güvenlik › Ekran Kaydı bölümünden Yakala'ya izin ver, \
                sonra Yakala'yı kapatıp yeniden aç.
                """
            alert.addButton(withTitle: "Sistem Ayarlarını Aç")
            alert.addButton(withTitle: "Vazgeç")
            if alert.runModal() == .alertFirstButtonReturn,
               let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        } else {
            alert.messageText = "Ekran görüntüsü alınamadı"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
