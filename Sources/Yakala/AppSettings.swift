import AppKit
import Observation
import ServiceManagement

/// Kullanıcı ayarları. Değerler UserDefaults'ta saklanır; girişte başlatma durumu ise
/// macOS'un Giriş Öğeleri listesinden (SMAppService) okunur.
@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private enum Keys {
        static let autoSave = "autoSave"
        static let saveFolderBookmark = "saveFolderBookmark"
        static let afterCapture = "afterCapture"
        static let areaShortcut = "areaShortcut"
        static let windowShortcut = "windowShortcut"
        static let beautify = "beautify"
    }

    /// Yakalamadan hemen sonra ne olacağı. Kopyala ve Kaydet "hızlı mod"dur: düzenleyici açılmaz.
    enum AfterCapture: String, CaseIterable, Identifiable {
        case editor, copy, save

        var id: Self { self }

        var title: String {
            switch self {
            case .editor: "Düzenleyiciyi aç"
            case .copy: "Hemen panoya kopyala"
            case .save: "Hemen kayıt klasörüne kaydet"
            }
        }
    }

    enum ShortcutAction {
        case area, window
    }

    /// Kullanıcının gerçek ev klasörü. Sandbox'ta FileManager ve NSHomeDirectory uygulamanın
    /// kapsayıcısını (~/Library/Containers/...) gösterdiği için kullanıcı kaydından okunur.
    static let homeFolder: URL = {
        let path = getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        return URL(fileURLWithPath: path, isDirectory: true)
    }()

    /// Masaüstü, Belgeler ve İndirilenler macOS tarafından korunur ve izin ister; Resimler klasörüne ise
    /// Yakala'nın sandbox izni var. Bu yüzden varsayılan orası.
    static let defaultSaveFolder = homeFolder.appendingPathComponent("Pictures/Yakala", isDirectory: true)

    /// Klasör yolunu ev klasörünü "~" ile kısaltarak gösterir.
    static func displayPath(_ url: URL) -> String {
        let home = homeFolder.path
        return url.path.hasPrefix(home) ? "~" + url.path.dropFirst(home.count) : url.path
    }

    /// Her yakalamada görüntü kayıt klasörüne kendiliğinden kaydedilir.
    private(set) var autoSave: Bool
    private(set) var saveFolder: URL
    private(set) var launchAtLoginStatus: SMAppService.Status = .notRegistered
    private(set) var launchAtLoginError: String?
    private(set) var afterCapture: AfterCapture
    private(set) var areaShortcut: Shortcut
    private(set) var windowShortcut: Shortcut
    /// Güzelleştir panelinde son seçilen ayarlar; yeni görüntülerde aynı gelir.
    private(set) var beautify: BeautifySettings
    /// Ayarlarda yeni kısayol kaydedilirken global kısayollar geçici olarak kapatılır.
    private(set) var isRecordingShortcut = false
    /// Kaydedilemeyen kısayolların açıklaması (başka bir uygulama kullanıyorsa).
    private(set) var shortcutError: String?
    /// Kısayollar değişince ya da kayıt başlayıp bitince çağrılır; AppDelegate kısayolları yeniden kaydeder.
    @ObservationIgnored var onHotKeysChanged: (() -> Void)?

    private init() {
        let defaults = UserDefaults.standard
        autoSave = defaults.bool(forKey: Keys.autoSave)
        afterCapture = defaults.string(forKey: Keys.afterCapture).flatMap(AfterCapture.init(rawValue:)) ?? .editor
        areaShortcut = Self.loadShortcut(Keys.areaShortcut) ?? .defaultArea
        windowShortcut = Self.loadShortcut(Keys.windowShortcut) ?? .defaultWindow
        beautify = defaults.data(forKey: Keys.beautify)
            .flatMap { try? JSONDecoder().decode(BeautifySettings.self, from: $0) } ?? BeautifySettings()
        saveFolder = Self.restoreBookmarkedFolder() ?? Self.defaultSaveFolder
        refreshLaunchAtLogin()
    }

    func setAfterCapture(_ value: AfterCapture) {
        afterCapture = value
        UserDefaults.standard.set(value.rawValue, forKey: Keys.afterCapture)
    }

    func setBeautify(_ settings: BeautifySettings) {
        beautify = settings
        UserDefaults.standard.set(try? JSONEncoder().encode(settings), forKey: Keys.beautify)
    }

    // MARK: - Kısayollar

    /// İki işleme aynı kısayol verilemez; o durumda değişiklik yapılmaz ve hata gösterilir.
    func setShortcut(_ shortcut: Shortcut, for action: ShortcutAction) {
        let other = action == .area ? windowShortcut : areaShortcut
        guard shortcut.keyCode != other.keyCode || shortcut.modifiers != other.modifiers else {
            shortcutError = "\(shortcut.display) zaten diğer işlem için kullanılıyor."
            return
        }
        switch action {
        case .area: areaShortcut = shortcut
        case .window: windowShortcut = shortcut
        }
        Self.saveShortcut(shortcut, action == .area ? Keys.areaShortcut : Keys.windowShortcut)
        onHotKeysChanged?()
    }

    func resetShortcuts() {
        areaShortcut = .defaultArea
        windowShortcut = .defaultWindow
        UserDefaults.standard.removeObject(forKey: Keys.areaShortcut)
        UserDefaults.standard.removeObject(forKey: Keys.windowShortcut)
        onHotKeysChanged?()
    }

    func setRecordingShortcut(_ recording: Bool) {
        isRecordingShortcut = recording
        if recording { shortcutError = nil }
        onHotKeysChanged?()
    }

    /// AppDelegate kısayolları kaydettikten sonra başarısız olanları bildirir.
    func reportFailedShortcuts(_ failed: [Shortcut]) {
        shortcutError = failed.isEmpty
            ? nil
            : failed.map(\.display).joined(separator: ", ") + " kaydedilemedi; başka bir uygulama kullanıyor olabilir."
    }

    private static func loadShortcut(_ key: String) -> Shortcut? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
    }

    private static func saveShortcut(_ shortcut: Shortcut, _ key: String) {
        UserDefaults.standard.set(try? JSONEncoder().encode(shortcut), forKey: key)
    }

    // MARK: - Kayıt

    func setAutoSave(_ enabled: Bool) {
        autoSave = enabled
        UserDefaults.standard.set(enabled, forKey: Keys.autoSave)
    }

    /// Sandbox'ta kullanıcının seçtiği klasöre erişim yalnızca o oturum için verilir.
    /// Güvenli yer imi (security-scoped bookmark) bu erişimi sonraki açılışlara taşır.
    func setSaveFolder(_ folder: URL) {
        saveFolder = folder
        if folder.standardizedFileURL == Self.defaultSaveFolder.standardizedFileURL {
            UserDefaults.standard.removeObject(forKey: Keys.saveFolderBookmark)
        } else if let bookmark = try? folder.bookmarkData(options: .withSecurityScope) {
            UserDefaults.standard.set(bookmark, forKey: Keys.saveFolderBookmark)
        }
    }

    private static func restoreBookmarkedFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: Keys.saveFolderBookmark) else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &isStale) else {
            return nil
        }
        // Erişim uygulama açık kaldığı sürece sürer; kayıt klasörü her an kullanılabileceği için bırakılmaz.
        _ = url.startAccessingSecurityScopedResource()
        if isStale, let fresh = try? url.bookmarkData(options: .withSecurityScope) {
            UserDefaults.standard.set(fresh, forKey: Keys.saveFolderBookmark)
        }
        return url
    }

    // MARK: - Girişte başlatma

    /// Onay bekleyen kayıt da açık sayılır; kullanıcı Sistem Ayarları'nda onaylayınca etkinleşir.
    var launchAtLogin: Bool {
        launchAtLoginStatus == .enabled || launchAtLoginStatus == .requiresApproval
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        refreshLaunchAtLogin()
    }

    /// Kullanıcı Sistem Ayarları'ndan değiştirmiş olabilir; ayarlar penceresi her açıldığında okunur.
    func refreshLaunchAtLogin() {
        launchAtLoginStatus = SMAppService.mainApp.status
    }
}
