import AppKit
import Observation

/// Düzenleyicinin durumu: şekiller, seçili araç/renk/kalınlık, geri alma geçmişi.
@MainActor
@Observable
final class EditorModel {
    let capture: Capture
    @ObservationIgnored let renderer: AnnotationRenderer
    /// Dışa aktarmadan önce tuvalin yarım kalan metni kaydetmesi için.
    @ObservationIgnored var beforeExport: (() -> Void)?

    private(set) var annotations: [Annotation] = []
    /// Fareyle çizilmekte olan, henüz eklenmemiş şekil.
    var draft: Annotation?
    private(set) var selectedID: Annotation.ID?
    /// Düzenlenen metin, metin kutusu açıkken tuvalde çizilmez.
    var editingTextID: Annotation.ID?

    private(set) var tool: Tool = .arrow
    private(set) var color: AnnotationColor = .red
    private(set) var lineWidth: LineWidth = .medium
    /// Damga aracının koyacağı işaret.
    private(set) var stampKind: StampKind = .check
    /// Görüntünün kaydedildiği dosya. Bir kez kaydedildikten sonra Kaydet (⌘S) bu dosyayı günceller.
    private(set) var savedURL: URL?
    /// Güzelleştir açıkken kopyalanan ve kaydedilen görüntü arka plan ve çerçeveyle birlikte olur.
    private(set) var isBeautifyOn = false
    private(set) var beautify = AppSettings.shared.beautify

    private var undoStack: [[Annotation]] = []
    private var redoStack: [[Annotation]] = []

    init(capture: Capture) {
        self.capture = capture
        renderer = AnnotationRenderer(capture: capture)
    }

    /// Numara aracının koyacağı sıradaki numara: mevcut en büyük numaranın bir fazlası.
    var nextCounterNumber: Int {
        let numbers = annotations.compactMap { annotation -> Int? in
            if case let .counter(number, _) = annotation.shape { number } else { nil }
        }
        return (numbers.max() ?? 0) + 1
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    var visibleAnnotations: [Annotation] {
        var visible = annotations.filter { $0.id != editingTextID }
        if let draft { visible.append(draft) }
        return visible
    }

    var selectedAnnotation: Annotation? {
        selectedIndex.map { annotations[$0] }
    }

    private var selectedIndex: Int? {
        guard let selectedID else { return nil }
        return annotations.firstIndex { $0.id == selectedID }
    }

    // MARK: - Araç çubuğu

    func selectTool(_ tool: Tool) {
        self.tool = tool
        if tool != .select { selectedID = nil }
    }

    /// Seçili bir şekil varsa yeni renk ona da uygulanır.
    func setColor(_ color: AnnotationColor) {
        self.color = color
        updateSelected { $0.color = color }
    }

    /// Damga türünü seçer, damga aracına geçer ve rengi işarete uygun renge çevirir (✓ yeşil, ✗ kırmızı…).
    func setStampKind(_ kind: StampKind) {
        stampKind = kind
        selectTool(.stamp)
        setColor(kind.defaultColor)
    }

    func setLineWidth(_ lineWidth: LineWidth) {
        self.lineWidth = lineWidth
        updateSelected { $0.lineWidth = lineWidth }
    }

    // MARK: - Güzelleştir

    func setBeautifyOn(_ on: Bool) {
        isBeautifyOn = on
    }

    /// Ayarlar hem bu görüntüye uygulanır hem de sonraki görüntüler için hatırlanır.
    func updateBeautify(_ change: (inout BeautifySettings) -> Void) {
        change(&beautify)
        AppSettings.shared.setBeautify(beautify)
    }

    // MARK: - Şekiller

    func add(_ annotation: Annotation) {
        recordUndo()
        annotations.append(annotation)
    }

    func select(_ id: Annotation.ID?) {
        selectedID = id
    }

    func deleteSelected() {
        guard let index = selectedIndex else { return }
        recordUndo()
        annotations.remove(at: index)
        selectedID = nil
    }

    /// Fareyle sürüklerken her adımda geri alma kaydı tutulmaz; sadece ilk adımda (`recordingUndo`).
    func moveSelected(by delta: CGSize, recordingUndo: Bool) {
        guard let index = selectedIndex else { return }
        if recordingUndo { recordUndo() }
        annotations[index] = annotations[index].moved(by: delta)
    }

    /// Metin kutusu kapanınca çağrılır. Boş metin, düzenlenen şekli siler.
    /// `background`: yeni metin etiket (arka planlı) olarak mı eklensin.
    func commitText(_ string: String, at origin: CGPoint, editing id: Annotation.ID?, background: Bool = false) {
        defer { editingTextID = nil }
        let isEmpty = string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if let id, let index = annotations.firstIndex(where: { $0.id == id }) {
            var updated = annotations[index]
            updated.shape = .text(string, origin: origin)
            guard isEmpty || updated != annotations[index] else { return }
            recordUndo()
            if isEmpty {
                annotations.remove(at: index)
                selectedID = nil
            } else {
                annotations[index] = updated
            }
        } else if !isEmpty {
            add(Annotation(shape: .text(string, origin: origin), color: color, lineWidth: lineWidth,
                           hasBackground: background))
        }
    }

    // MARK: - Geri al / Yinele

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = previous
        selectedID = nil
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = next
        selectedID = nil
    }

    private func recordUndo() {
        undoStack.append(annotations)
        redoStack.removeAll()
    }

    private func updateSelected(_ change: (inout Annotation) -> Void) {
        guard let index = selectedIndex else { return }
        var updated = annotations[index]
        change(&updated)
        guard updated != annotations[index] else { return }
        recordUndo()
        annotations[index] = updated
    }

    // MARK: - Dışa aktarma

    /// Şekillerin işlendiği son görüntü.
    func flattened() -> Capture {
        beforeExport?()
        return renderer.renderFlattened(annotations, beautify: isBeautifyOn ? beautify : nil) ?? capture
    }

    func copy() {
        ImageExporter.copyToPasteboard(flattened())
    }

    /// Daha önce kaydedildiyse aynı dosyayı günceller, kaydedilmediyse kaydetme penceresini açar.
    /// Kaydedildiyse true döner; pencerede vazgeçilirse ya da hata olursa false.
    @discardableResult
    func save() -> Bool {
        guard let savedURL else {
            return saveAs()
        }
        do {
            try ImageExporter.write(flattened(), to: savedURL)
            return true
        } catch {
            NSAlert(error: error).runModal()
            return false
        }
    }

    @discardableResult
    func saveAs() -> Bool {
        guard let url = ImageExporter.saveWithPanel(flattened(), startingIn: AppSettings.shared.saveFolder) else {
            return false
        }
        savedURL = url
        return true
    }

    /// Yakalandığı anda, çizimler olmadan kayıt klasörüne yazar (otomatik kayıt).
    func autoSave(to folder: URL) throws {
        let url = ImageExporter.newFileURL(in: folder, for: capture.date)
        try ImageExporter.write(capture, to: url)
        savedURL = url
    }

    func revealInFinder() {
        guard let savedURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([savedURL])
    }
}
