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

    private init() {
        let defaults = UserDefaults.standard
        autoSave = defaults.bool(forKey: Keys.autoSave)
        saveFolder = Self.restoreBookmarkedFolder() ?? Self.defaultSaveFolder
        refreshLaunchAtLogin()
    }

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
