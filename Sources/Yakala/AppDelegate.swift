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
    private var welcomeController: WelcomeWindowController?
    private var isCapturing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Başka bir kopya (ör. DMG'deki ya da derleme klasöründeki) zaten çalışıyorsa ikinci simge açılmasın.
        let me = NSRunningApplication.current
        if let bundleID = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
               .contains(where: { $0.processIdentifier != me.processIdentifier && !$0.isTerminated }) {
            NSApp.terminate(nil)
            return
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = Brand.menuBarIcon
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        AppSettings.shared.onHotKeysChanged = { [weak self] in self?.registerHotKeys() }
        registerHotKeys()

        if WelcomeWindowController.shouldShow {
            welcomeController = WelcomeWindowController()
            welcomeController?.present()
        }
    }

    /// Ayarlardaki kısayolları kaydeder. Ayarlarda yeni kısayol kaydedilirken hiçbirini kaydetmez;
    /// yoksa basılan tuşlar yakalamayı başlatırdı.
    private func registerHotKeys() {
        hotKey?.unregister()
        windowHotKey?.unregister()
        hotKey = nil
        windowHotKey = nil

        let settings = AppSettings.shared
        statusItem.button?.toolTip = "Tıkla veya \(settings.areaShortcut.display): alan seç\n"
            + "\(settings.windowShortcut.display): pencere seç\nSağ tık: menü"
        guard !settings.isRecordingShortcut else { return }

        hotKey = GlobalHotKey(keyCode: settings.areaShortcut.keyCode, modifiers: settings.areaShortcut.modifiers) {
            [weak self] in self?.startCapture(.area, delay: .zero)
        }
        windowHotKey = GlobalHotKey(keyCode: settings.windowShortcut.keyCode, modifiers: settings.windowShortcut.modifiers) {
            [weak self] in self?.startCapture(.window, delay: .zero)
        }
        var failed: [Shortcut] = []
        if hotKey == nil { failed.append(settings.areaShortcut) }
        if windowHotKey == nil { failed.append(settings.windowShortcut) }
        settings.reportFailedShortcuts(failed)
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

        let settings = AppSettings.shared
        let areaItem = addItem(to: menu, title: "Alan Seç", action: #selector(captureArea))
        areaItem.keyEquivalent = settings.areaShortcut.menuKeyEquivalent
        areaItem.keyEquivalentModifierMask = settings.areaShortcut.menuModifierMask
        let windowItem = addItem(to: menu, title: "Pencere Seç", action: #selector(captureWindow))
        windowItem.keyEquivalent = settings.windowShortcut.menuKeyEquivalent
        windowItem.keyEquivalentModifierMask = settings.windowShortcut.menuModifierMask
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
                handle(capture, returningTo: previousApp)
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

    /// Yakalanan görüntüyü ayara göre düzenleyicide açar ya da hızlı modda hemen kopyalar / kaydeder.
    /// Hızlı modda da düzenleyici hazırlanır; menüdeki "Son Görüntüyü Göster" ile sonradan açılabilir.
    private func handle(_ capture: Capture, returningTo previousApp: NSRunningApplication?) {
        // Eski pencere kapanırken önceki uygulamaya dönmesin; yeni pencere hemen açılacak.
        editorController?.previousApp = nil
        editorController?.close()
        let controller = EditorWindowController(capture: capture)
        controller.previousApp = previousApp
        editorController = controller

        let settings = AppSettings.shared
        var saveError: Error?
        if settings.autoSave || settings.afterCapture == .save {
            do {
                try controller.model.autoSave(to: settings.saveFolder)
            } catch {
                saveError = error
            }
        }

        switch settings.afterCapture {
        case .editor:
            controller.present()
        case .copy:
            controller.model.copy()
            previousApp?.activate()
            Toast.show("Panoya kopyalandı")
        case .save:
            previousApp?.activate()
            if saveError == nil {
                Toast.show("Kaydedildi")
            }
        }

        if let saveError {
            let alert = NSAlert(error: saveError)
            alert.messageText = "Kaydedilemedi"
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
