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
        TabView {
            general.tabItem { Label("Genel", systemImage: "gearshape") }
            shortcuts.tabItem { Label("Kısayollar", systemImage: "command") }
            saving.tabItem { Label("Kaydetme", systemImage: "folder") }
            about.tabItem { Label("Hakkında", systemImage: "info.circle") }
        }
        .tint(Brand.accent)
        // Sekmeler başlık çubuğuna yapışmasın.
        .padding(.top, 12)
        .frame(width: 560, height: 482)
    }

    // MARK: - Genel

    private var general: some View {
        Form {
            Section {
                Toggle("Mac açılınca Yakala'yı başlat", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                if settings.launchAtLoginStatus == .requiresApproval {
                    LabeledContent {
                        Button("Giriş Öğelerini Aç") {
                            SMAppService.openSystemSettingsLoginItems()
                        }
                    } label: {
                        Text("macOS onayı bekleniyor: Sistem Ayarları › Genel › Giriş Öğeleri bölümünden Yakala'yı aç.")
                            .foregroundStyle(.secondary)
                    }
                }
                if let error = settings.launchAtLoginError {
                    Text(error).foregroundStyle(.red)
                }
            }

            Section {
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
            } header: {
                Text("Yakaladıktan sonra")
            } footer: {
                footnote("""
                    Hızlı mod: kopyala ya da kaydet seçiliyse düzenleyici açılmaz. Son görüntüyü yine de menüden açıp \
                    düzenleyebilirsin.
                    """)
            }

            Section {
                LabeledContent("Alan seçmek için", value: settings.areaShortcut.display)
            } header: {
                Text("Menü çubuğu")
            } footer: {
                footnote("""
                    Kısayol, menü çubuğu simgesi görünmese de çalışır. Simge görünmüyorsa menü çubuğu dolu olabilir; ⌘ \
                    tuşunu basılı tutarak başka simgeleri dışarı sürükle ya da Sistem Ayarları › Menü Çubuğu'ndan \
                    gerekmeyenleri kapat. Bu pencereyi Yakala'yı Spotlight'tan yeniden açarak her zaman getirebilirsin.
                    """)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Kısayollar

    private var shortcuts: some View {
        Form {
            Section {
                LabeledContent("Alan seç") {
                    ShortcutRecorder(shortcut: settings.areaShortcut) { settings.setShortcut($0, for: .area) }
                }
                LabeledContent("Pencere seç") {
                    ShortcutRecorder(shortcut: settings.windowShortcut) { settings.setShortcut($0, for: .window) }
                }
                if let error = settings.shortcutError {
                    Text(error).foregroundStyle(.red)
                }
            } footer: {
                footnote("Değiştirmek için kısayola tıkla ve yeni tuşlara bas; en az bir ⌘, ⌥ ya da ⌃ içermeli. Vazgeçmek için Esc.")
            }

            Section {
                LabeledContent("Varsayılan kısayollar: ⇧⌘2 ve ⇧⌘1") {
                    Button("Varsayılana Dön") { settings.resetShortcuts() }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Kaydetme

    private var saving: some View {
        Form {
            Section {
                LabeledContent("Kayıt klasörü") {
                    Label(displayPath(settings.saveFolder), systemImage: "folder.fill")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(settings.saveFolder.path)
                }
                LabeledContent {
                    HStack {
                        Button("Değiştir…", action: chooseFolder)
                        Button("Finder'da Aç", action: openFolder)
                    }
                } label: {
                    EmptyView()
                }
            }

            Section {
                Toggle("Her ekran görüntüsünü bu klasöre otomatik kaydet", isOn: Binding(
                    get: { settings.autoSave },
                    set: { settings.setAutoSave($0) }
                ))
            } footer: {
                footnote("""
                    Açıkken düzenleyicideki Kaydet (⌘S) aynı dosyayı çizimlerle günceller. Kapalıyken Kaydet, bu \
                    klasörde açılan kaydetme penceresini gösterir.
                    """)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Hakkında

    private var about: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            VStack(spacing: 4) {
                Text("Yakala").font(.system(size: 26, weight: .bold, design: .rounded))
                Text("Sürüm \(About.version)").foregroundStyle(.secondary)
            }
            Text(About.summary)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 380)
                .fixedSize(horizontal: false, vertical: true)
            Link(About.creatorTitle, destination: About.creatorURL)
                .font(.callout)
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
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

