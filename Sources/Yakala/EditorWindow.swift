import AppKit
import SwiftUI

/// Yüzen çubukların yerleri. Tuval, görüntüyü bu çubukların arasına sığdırır.
struct EditorLayout {
    let titlebarHeight: CGFloat
    let barHeight: CGFloat = 44
    let margin: CGFloat = 14

    var canvasInsets: NSEdgeInsets {
        NSEdgeInsets(top: titlebarHeight + barHeight + margin, left: 28, bottom: barHeight + margin * 2, right: 28)
    }
}

/// Yakalanan görüntüyü düzenleme penceresi: görüntü tüm pencereyi kaplar,
/// araçlar üstte, Kopyala / Kaydet altta yüzen çubuklardadır.
final class EditorWindowController: NSWindowController, NSWindowDelegate {
    let model: EditorModel
    /// Yakalamadan önce öndeki uygulama. Pencere kapanınca ona dönülür; kopyalanan görüntü hemen yapıştırılabilir.
    var previousApp: NSRunningApplication?

    init(capture: Capture) {
        model = EditorModel(capture: capture)
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Yakala"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 820, height: 460) // araç çubuğu 10 araçla bu genişliğe sığar
        super.init(window: window)
        window.delegate = self

        let standardTitlebar = NSWindow.frameRect(forContentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                                                  styleMask: [.titled]).height - 100
        let layout = EditorLayout(titlebarHeight: standardTitlebar)
        window.contentView = NSHostingView(rootView: EditorView(
            model: model,
            layout: layout,
            onCopy: { [weak self] in self?.copyAndClose() },
            onSave: { [weak self] asNewFile in self?.saveAndClose(asNewFile: asNewFile) }
        ))
        window.setContentSize(Self.contentSize(for: capture, layout: layout))
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) kullanılmıyor")
    }

    func present() {
        NSApp.activate()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Kopyalar, pencereyi kapatır ve kısa bir bildirim gösterir.
    func copyAndClose() {
        model.copy()
        close()
        Toast.show("Panoya kopyalandı")
    }

    /// Kaydeder; başarılıysa pencereyi kapatır ve bildirim gösterir.
    /// Kaydetme penceresinde vazgeçilirse düzenleyici açık kalır.
    func saveAndClose(asNewFile: Bool = false) {
        let saved = asNewFile ? model.saveAs() : model.save()
        guard saved else { return }
        close()
        Toast.show("Kaydedildi")
    }

    func windowWillClose(_ notification: Notification) {
        previousApp?.activate()
    }

    /// Görüntüyü ekranın en fazla %75'ini kaplayacak şekilde sığdırır.
    private static func contentSize(for capture: Capture, layout: EditorLayout) -> NSSize {
        let visible = NSScreen.underMouse?.visibleFrame.size ?? NSSize(width: 1280, height: 800)
        let insets = layout.canvasInsets
        let chrome = NSSize(width: insets.left + insets.right, height: insets.top + insets.bottom)
        let image = capture.pointSize
        let ratio = min(
            1,
            (visible.width * 0.75 - chrome.width) / image.width,
            (visible.height * 0.75 - chrome.height) / image.height
        )
        return NSSize(
            width: max(820, image.width * ratio + chrome.width),
            height: max(460, image.height * ratio + chrome.height)
        )
    }
}

private struct EditorView: View {
    let model: EditorModel
    let layout: EditorLayout
    let onCopy: () -> Void
    /// Parametre: yeni bir dosyaya mı kaydedilecek (Farklı Kaydet).
    let onSave: (Bool) -> Void

    var body: some View {
        EditorCanvas(model: model, insets: layout.canvasInsets)
            .background(Color(nsColor: .underPageBackgroundColor))
            .overlay(alignment: .top) {
                toolbar.padding(.top, layout.titlebarHeight)
            }
            .overlay(alignment: .bottom) {
                bottomBar
                    .padding(.horizontal, layout.margin)
                    .padding(.bottom, layout.margin)
            }
            .ignoresSafeArea()
    }

    // MARK: - Araçlar

    private var toolbar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                ForEach(Tool.allCases) { tool in
                    BarButton(isSelected: model.tool == tool,
                              help: "\(tool.title) (\(tool.shortcut.uppercased()))") {
                        model.selectTool(tool)
                    } label: {
                        Image(systemName: tool.symbol)
                            .font(.system(size: 14, weight: .medium))
                    }
                }
            }

            BarDivider()

            HStack(spacing: 0) {
                ForEach(AnnotationColor.allCases) { color in
                    ColorSwatch(color: color, isSelected: model.color == color) {
                        model.setColor(color)
                    }
                }
            }

            BarDivider()

            HStack(spacing: 2) {
                ForEach(LineWidth.allCases) { width in
                    BarButton(isSelected: model.lineWidth == width, help: width.title) {
                        model.setLineWidth(width)
                    } label: {
                        Circle().frame(width: 2 + width.value * 1.1, height: 2 + width.value * 1.1)
                    }
                }
            }

            BarDivider()

            HStack(spacing: 2) {
                BarButton(isSelected: false, help: "Geri Al (⌘Z)") {
                    model.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .keyboardShortcut("z")
                .disabled(!model.canUndo)

                BarButton(isSelected: false, help: "Yinele (⇧⌘Z)") {
                    model.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!model.canRedo)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: layout.barHeight)
        .floatingBar()
    }

    // MARK: - Alt çubuk

    private var bottomBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(verbatim: "\(model.capture.image.width) × \(model.capture.image.height)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                if let savedURL = model.savedURL {
                    Button {
                        model.revealInFinder()
                    } label: {
                        Label(savedURL.lastPathComponent, systemImage: "folder")
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .help("Finder'da göster: \(savedURL.path)")
                }
            }
            .font(.callout)
            .padding(.horizontal, 16)
            .frame(height: layout.barHeight)
            .floatingBar()

            Spacer(minLength: 12)

            if model.savedURL != nil {
                Button("Farklı Kaydet…") {
                    onSave(true)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .floatingButton(prominent: false)
                .help("Yeni bir dosyaya kaydet ve pencereyi kapat (⇧⌘S)")
            }

            Button(action: onCopy) {
                Label("Kopyala", systemImage: "doc.on.doc")
            }
            .keyboardShortcut("c")
            .floatingButton(prominent: false)
            .help("Panoya kopyala ve pencereyi kapat (⌘C)")

            Button {
                onSave(false)
            } label: {
                // Henüz kaydedilmediyse pencere açılacağını "…" belirtir.
                Label(model.savedURL == nil ? "Kaydet…" : "Kaydet", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("s")
            .floatingButton(prominent: true)
            .help("Kaydet ve pencereyi kapat (⌘S)")
        }
        .controlSize(.large)
    }
}

/// Yüzen çubuktaki kare düğme: seçiliyse vurgu rengiyle dolar, üzerine gelince hafifçe belirir.
private struct BarButton<Label: View>: View {
    let isSelected: Bool
    let help: String
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            label()
                .frame(width: 30, height: 30)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color.primary.opacity(isHovered && isEnabled ? 0.08 : 0))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.35)
        .onHover { isHovered = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct ColorSwatch: View {
    let color: AnnotationColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(nsColor: color.nsColor))
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: 1))
                .frame(width: 18, height: 18)
                .padding(3)
                .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 2).opacity(isSelected ? 1 : 0))
                .frame(width: 26, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(color.title)
        .accessibilityLabel(color.title)
    }
}

private struct BarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.15))
            .frame(width: 1, height: 20)
    }
}
