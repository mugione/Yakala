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
        static let saveFolder = "saveFolder"
    }

    /// Masaüstü, Belgeler ve İndirilenler macOS tarafından korunur ve izin ister;
    /// Resimler klasörü istemez, bu yüzden varsayılan orası.
    static let defaultSaveFolder = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Yakala", isDirectory: true)

    /// Her yakalamada görüntü kayıt klasörüne kendiliğinden kaydedilir.
    private(set) var autoSave: Bool
    private(set) var saveFolder: URL
    private(set) var launchAtLoginStatus: SMAppService.Status = .notRegistered
    private(set) var launchAtLoginError: String?

    private init() {
        let defaults = UserDefaults.standard
        autoSave = defaults.bool(forKey: Keys.autoSave)
        saveFolder = defaults.string(forKey: Keys.saveFolder)
            .map { URL(fileURLWithPath: $0, isDirectory: true) } ?? Self.defaultSaveFolder
        refreshLaunchAtLogin()
    }

    func setAutoSave(_ enabled: Bool) {
        autoSave = enabled
        UserDefaults.standard.set(enabled, forKey: Keys.autoSave)
    }

    func setSaveFolder(_ folder: URL) {
        saveFolder = folder
        UserDefaults.standard.set(folder.path, forKey: Keys.saveFolder)
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
