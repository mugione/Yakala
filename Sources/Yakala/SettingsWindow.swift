import AppKit
import Carbon.HIToolbox
import ServiceManagement
import SwiftUI

/// Ayarlar penceresi. Boyutu içeriğe göre kendiliğinden ayarlanır.
final class SettingsWindowController: NSWindowController {
    init() {
        let hosting = NSHostingController(rootView: SettingsView(settings: .shared))
        hosting.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: hosting)
        window.title = "Yakala Ayarları"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) kullanılmıyor")
    }

    func present() {
        AppSettings.shared.refreshLaunchAtLogin()
        NSApp.activate()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}

/// Tıklanınca bir sonraki tuş bileşimini yeni kısayol olarak kaydeden düğme.
private struct ShortcutRecorder: View {
    let shortcut: Shortcut
    let onRecord: (Shortcut) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            isRecording ? stop() : start()
        } label: {
            Text(isRecording ? "Yeni kısayola bas…" : shortcut.display)
                .monospaced()
                .frame(minWidth: 130)
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        isRecording = true
        AppSettings.shared.setRecordingShortcut(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated {
                if Int(event.keyCode) == kVK_Escape {
                    stop()
                } else if let shortcut = Shortcut(event: event) {
                    onRecord(shortcut)
                    stop()
                } else {
                    NSSound.beep()
                }
            }
            return nil
        }
    }

    private func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        guard isRecording else { return }
        isRecording = false
        AppSettings.shared.setRecordingShortcut(false)
    }
}

private struct SettingsView: View {
    let settings: AppSettings

    var body: some View {
        Form {
            LabeledContent("Genel:") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Mac açılınca Yakala'yı başlat", isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { settings.setLaunchAtLogin($0) }
                    ))
                    if settings.launchAtLoginStatus == .requiresApproval {
                        Text("macOS onayı bekleniyor: Sistem Ayarları › Genel › Giriş Öğeleri bölümünden Yakala'yı aç.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Giriş Öğelerini Aç") {
                            SMAppService.openSystemSettingsLoginItems()
                        }
                    }
                    if let error = settings.launchAtLoginError {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.bottom, 12)

            LabeledContent("Yakaladıktan sonra:") {
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Yakaladıktan sonra", selection: Binding(
                        get: { settings.afterCapture },
                        set: { settings.setAfterCapture($0) }
                    )) {
                        ForEach(AppSettings.AfterCapture.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    Text("Hızlı mod: kopyala ya da kaydet seçiliyse düzenleyici açılmaz. Son görüntüyü yine de menüden açıp düzenleyebilirsin.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, 12)

            LabeledContent("Kısayollar:") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Alan seç").frame(width: 90, alignment: .leading)
                        ShortcutRecorder(shortcut: settings.areaShortcut) { settings.setShortcut($0, for: .area) }
                    }
                    HStack {
                        Text("Pencere seç").frame(width: 90, alignment: .leading)
                        ShortcutRecorder(shortcut: settings.windowShortcut) { settings.setShortcut($0, for: .window) }
                    }
                    if let error = settings.shortcutError {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text("Değiştirmek için kısayola tıkla ve yeni tuşlara bas; en az bir ⌘, ⌥ ya da ⌃ içermeli. Vazgeçmek için Esc.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Varsayılan") { settings.resetShortcuts() }
                            .help("⇧⌘2 ve ⇧⌘1'e dön")
                    }
                }
            }
            .padding(.bottom, 12)

            LabeledContent("Kayıt klasörü:") {
                VStack(alignment: .leading, spacing: 8) {
                    Label(displayPath(settings.saveFolder), systemImage: "folder")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(settings.saveFolder.path)
                    HStack {
                        Button("Değiştir…", action: chooseFolder)
                        Button("Finder'da Aç", action: openFolder)
                    }
                    Toggle("Her ekran görüntüsünü bu klasöre otomatik kaydet", isOn: Binding(
                        get: { settings.autoSave },
                        set: { settings.setAutoSave($0) }
                    ))
                    .padding(.top, 4)
                    Text("""
                        Açıkken düzenleyicideki Kaydet (⌘S) aynı dosyayı çizimlerle günceller. \
                        Kapalıyken Kaydet, bu klasörde açılan kaydetme penceresini gösterir.
                        """)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, 12)

            LabeledContent("Menü çubuğu:") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(settings.areaShortcut.display) ile alan seç: simge görünmese de çalışır.")
                    Text("""
                        Simge görünmüyorsa menü çubuğu dolu olabilir; çentikli MacBook'larda soldaki simgeler \
                        çentiğin arkasında kalır. ⌘ tuşunu basılı tutarak başka simgeleri menü çubuğunun dışına \
                        sürükle ya da Sistem Ayarları › Menü Çubuğu'ndan gerekmeyenleri kapat. \
                        Bu pencereyi Yakala'yı Spotlight'tan veya Finder'dan yeniden açarak her zaman getirebilirsin.
                        """)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, 12)

            LabeledContent("Hakkında:") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Yakala \(About.version)")
                    Text(About.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 4) {
                        Text("Yapımcı:")
                        Link(About.creatorTitle, destination: About.creatorURL)
                    }
                    .font(.callout)
                }
            }
        }
        .formStyle(.columns)
        .padding(24)
        .frame(width: 520)
    }

    private func displayPath(_ url: URL) -> String {
        AppSettings.displayPath(url)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Kayıt Klasörünü Seç"
        panel.prompt = "Seç"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        let folder = settings.saveFolder
        panel.directoryURL = FileManager.default.fileExists(atPath: folder.path)
            ? folder
            : folder.deletingLastPathComponent()

        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.setSaveFolder(url)
    }

    private func openFolder() {
        do {
            try FileManager.default.createDirectory(at: settings.saveFolder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(settings.saveFolder)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
