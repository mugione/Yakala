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
        window.minSize = NSSize(width: Self.minimumWidth, height: 460)
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

    /// Araç çubuğunun (13 araç, stil düğmesi, geri al) ve alt çubuğun sığdığı en küçük genişlik.
    static let minimumWidth: CGFloat = 820

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
            width: max(minimumWidth, image.width * ratio + chrome.width),
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

    /// Güzelleştir paneli açıkken görüntü panelin soluna sığdırılır.
    private var canvasInsets: NSEdgeInsets {
        var insets = layout.canvasInsets
        if model.isBeautifyOn {
            insets.right += BeautifyPanel.width + layout.margin
        }
        return insets
    }

    var body: some View {
        EditorCanvas(model: model, insets: canvasInsets)
            .background(WorkspaceBackground())
            .tint(Brand.accent)
            .overlay(alignment: .top) {
                toolbar.padding(.top, layout.titlebarHeight)
            }
            .overlay(alignment: .topTrailing) {
                if model.isBeautifyOn {
                    BeautifyPanel(model: model)
                        .padding(.top, layout.titlebarHeight + layout.barHeight + layout.margin)
                        .padding(.bottom, layout.barHeight + layout.margin * 2)
                        .padding(.trailing, layout.margin)
                }
            }
            .overlay(alignment: .bottom) {
                bottomBar
                    .padding(.horizontal, layout.margin)
                    .padding(.bottom, layout.margin)
            }
            .ignoresSafeArea()
    }

    // MARK: - Araçlar

    /// Araçlar işlevlerine göre gruplanır: seç | şekiller | yazı | işaretler | gizle.
    private static let toolGroups: [[Tool]] = [
        [.select], [.arrow, .rectangle, .ellipse, .pen, .highlighter], [.text, .label],
        [.counter, .stamp, .magnifier], [.blur, .pixelate],
    ]

    private var toolbar: some View {
        HStack(spacing: 6) {
            ForEach(Array(Self.toolGroups.enumerated()), id: \.offset) { index, group in
                if index > 0 {
                    BarDivider()
                }
                HStack(spacing: 2) {
                    ForEach(group) { tool in
                        toolButton(tool)
                    }
                }
            }

            BarDivider()
            StyleButton(model: model)
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

    @ViewBuilder
    private func toolButton(_ tool: Tool) -> some View {
        BarButton(isSelected: model.tool == tool, help: "\(tool.title) (\(tool.shortcut.uppercased()))") {
            model.selectTool(tool)
        } label: {
            if tool == .stamp {
                // Damga düğmesi seçili işareti gösterir.
                Text(model.stampKind.glyph)
                    .font(.system(size: 16, weight: .bold))
            } else {
                Image(systemName: tool.symbol)
                    .font(.system(size: 14, weight: .medium))
            }
        }
        if tool == .stamp {
            StampMenu(model: model)
        }
    }

    // MARK: - Alt çubuk

    /// Kopyalanacak / kaydedilecek görüntünün piksel boyutu.
    private var outputSizeText: String {
        guard model.isBeautifyOn else {
            return "\(model.capture.image.width) × \(model.capture.image.height)"
        }
        let size = model.renderer.beautifyLayout(model.beautify).canvasSize
        return "\(Int(size.width * model.capture.scale)) × \(Int(size.height * model.capture.scale))"
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(verbatim: outputSizeText)
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
                    .foregroundStyle(Brand.accent)
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

            Button {
                model.setBeautifyOn(!model.isBeautifyOn)
            } label: {
                Label("Güzelleştir", systemImage: model.isBeautifyOn ? "sparkles.rectangle.stack.fill" : "sparkles")
            }
            .floatingButton(prominent: model.isBeautifyOn)
            .help("Arka plan, boşluk, gölge ve çerçeve ekle")

            Button {
                onSave(false)
            } label: {
                // Henüz kaydedilmediyse pencere açılacağını "…" belirtir.
                Label(model.savedURL == nil ? "Kaydet…" : "Kaydet", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("s")
            .floatingButton(prominent: false)
            .help("Kaydet ve pencereyi kapat (⌘S)")

            // Ana eylem en sağda ve marka renginde: çoğu zaman yapılan şey kopyalayıp yapıştırmak.
            Button(action: onCopy) {
                Label("Kopyala", systemImage: "doc.on.doc.fill")
            }
            .keyboardShortcut("c")
            .buttonStyle(BrandButtonStyle())
            .help("Panoya kopyala ve pencereyi kapat (⌘C)")
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
                    let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
                    if isSelected {
                        shape.fill(Brand.gradient)
                            .shadow(color: Color(nsColor: Brand.violet).opacity(0.35), radius: 4, y: 1.5)
                    } else {
                        shape.fill(Color.primary.opacity(isHovered && isEnabled ? 0.08 : 0))
                    }
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

/// Renk ve kalınlık: çubukta tek düğme (seçili renk, halkası kalınlığı gösterir), tıklayınca panel açılır.
private struct StyleButton: View {
    let model: EditorModel
    @State private var isOpen = false
    @State private var isHovered = false

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color(nsColor: model.color.nsColor))
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 1))
                    .frame(width: 18, height: 18)
                Capsule()
                    .fill(Color.primary.opacity(0.75))
                    .frame(width: 14, height: max(1.5, model.lineWidth.value * 0.9))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 7)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(isHovered || isOpen ? 0.08 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Renk ve kalınlık: \(model.color.title), \(model.lineWidth.title)")
        .accessibilityLabel("Renk ve kalınlık")
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Renk").font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 2) {
                    ForEach(AnnotationColor.allCases) { color in
                        ColorSwatch(color: color, isSelected: model.color == color) {
                            model.setColor(color)
                        }
                    }
                }
                Text("Kalınlık").font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(LineWidth.allCases) { width in
                        BarButton(isSelected: model.lineWidth == width, help: width.title) {
                            model.setLineWidth(width)
                        } label: {
                            Capsule().frame(width: 18, height: width.value * 1.1)
                        }
                    }
                }
            }
            .padding(14)
        }
    }
}

/// Düzenleyicinin zemini: görüntünün öne çıktığı, hafif noktalı çalışma alanı (açık ve koyu modda).
private struct WorkspaceBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        Canvas { context, size in
            let spacing: CGFloat = 18
            let dot = Path(ellipseIn: CGRect(x: 0, y: 0, width: 1.6, height: 1.6))
            for x in stride(from: spacing / 2, through: size.width, by: spacing) {
                for y in stride(from: spacing / 2, through: size.height, by: spacing) {
                    context.fill(dot.offsetBy(dx: x, dy: y), with: .color(.primary.opacity(dark ? 0.10 : 0.09)))
                }
            }
        }
        .background(dark ? Color(white: 0.11) : Color(red: 0.94, green: 0.95, blue: 0.97))
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
                .overlay(Circle().strokeBorder(Brand.accent, lineWidth: 2).opacity(isSelected ? 1 : 0))
                .frame(width: 26, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(color.title)
        .accessibilityLabel(color.title)
    }
}

/// Güzelleştir ayarları: arka plan, boşluk, köşe, gölge, oran ve pencere çerçevesi.
private struct BeautifyPanel: View {
    static let width: CGFloat = 270
    let model: EditorModel

    private var isWindowCapture: Bool { model.capture.hasTransparency }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Güzelleştir").font(.headline)

                section("Arka plan") {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(48), spacing: 10), count: 4), spacing: 10) {
                        ForEach(BeautifyBackground.allCases) { background in
                            BackgroundSwatch(background: background, isSelected: model.beautify.background == background) {
                                model.updateBeautify { $0.background = background }
                            }
                        }
                    }
                }

                section("Boşluk") {
                    Slider(value: binding(\.padding), in: BeautifySettings.paddingRange)
                }
                section("Köşe") {
                    Slider(value: binding(\.cornerRadius), in: BeautifySettings.cornerRange)
                        .disabled(isWindowCapture)
                }
                section("Gölge") {
                    Slider(value: binding(\.shadow), in: 0...1)
                }
                section("Oran") {
                    Picker("Oran", selection: binding(\.ratio)) {
                        ForEach(BeautifyRatio.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Toggle("Pencere çerçevesi (●●●)", isOn: binding(\.windowFrame))
                    .disabled(isWindowCapture)
                if isWindowCapture {
                    Text("Pencere yakalamada köşe ve çerçeve pencerenin kendisinden gelir.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18)
        }
        .frame(width: Self.width)
        .floatingPanel()
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<BeautifySettings, Value>) -> Binding<Value> {
        Binding(get: { model.beautify[keyPath: keyPath] },
                set: { value in model.updateBeautify { $0[keyPath: keyPath] = value } })
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            content()
        }
    }
}

private struct BackgroundSwatch: View {
    let background: BeautifyBackground
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(fill)
                .overlay {
                    if background == .transparent {
                        Image(systemName: "square.dashed").foregroundStyle(.secondary)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.15)))
                .frame(width: 44, height: 44)
                .padding(2)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Brand.accent, lineWidth: 2.5).opacity(isSelected ? 1 : 0))
        }
        .buttonStyle(.plain)
        .help(background.title)
        .accessibilityLabel(background.title)
    }

    private var fill: AnyShapeStyle {
        let colors = background.colors.map { Color(nsColor: $0) }
        guard colors.count == 2 else { return AnyShapeStyle(Color.primary.opacity(0.05)) }
        return AnyShapeStyle(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}

/// Damga türünü seçen küçük açılır menü (✓ ✗ ? !).
private struct StampMenu: View {
    let model: EditorModel

    var body: some View {
        Menu {
            ForEach(StampKind.allCases) { kind in
                Button("\(kind.glyph)  \(kind.title)") {
                    model.setStampKind(kind)
                }
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Damga türü")
        .accessibilityLabel("Damga türü")
    }
}

private struct BarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.15))
            .frame(width: 1, height: 20)
    }
}
