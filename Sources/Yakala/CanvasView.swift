import AppKit
import Carbon.HIToolbox
import Observation
import SwiftUI

/// AppKit tuvalini SwiftUI düzenleyicisine yerleştirir.
struct EditorCanvas: NSViewRepresentable {
    let model: EditorModel
    /// Yüzen çubukların kapladığı kenarlar; görüntü bunların arasına sığdırılır.
    let insets: NSEdgeInsets

    func makeNSView(context: Context) -> CanvasView {
        CanvasView(model: model, insets: insets)
    }

    func updateNSView(_ nsView: CanvasView, context: Context) {
        // Güzelleştir paneli açılıp kapanınca sağ kenar değişir.
        nsView.insets = insets
    }
}

/// Görüntüyü pencereye sığdırarak gösterir; fareyle şekil çizdirir, şekilleri taşıtır
/// ve metin kutusunu yönetir. Fare ve klavye ayrıntıları AppKit'te daha kolay olduğu için NSView.
final class CanvasView: NSView, NSTextFieldDelegate {
    private let model: EditorModel
    var insets: NSEdgeInsets {
        didSet {
            guard insets.left != oldValue.left || insets.right != oldValue.right
                || insets.top != oldValue.top || insets.bottom != oldValue.bottom else { return }
            needsDisplay = true
            layoutTextField()
            window?.invalidateCursorRects(for: self)
        }
    }

    private var dragStart: CGPoint?
    private var lastDragPoint: CGPoint?
    private var hasMovedSelection = false

    private var textField: NSTextField?
    private var textOrigin: CGPoint = .zero
    private var textHasBackground = false
    private var editingTextID: Annotation.ID?

    init(model: EditorModel, insets: NSEdgeInsets) {
        self.model = model
        self.insets = insets
        super.init(frame: .zero)
        model.beforeExport = { [weak self] in self?.endTextEditing(commit: true) }
        observeTool()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) kullanılmıyor")
    }

    // Orijin sol üstte: görüntü ve şekil koordinatlarıyla aynı yön.
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutTextField()
    }

    // MARK: - Geometri

    private var imageSize: CGSize { model.capture.pointSize }

    /// Güzelleştir açıksa arka plan ve çerçeveyle birlikte bütün kompozisyonun yerleşimi.
    private var beautifyLayout: BeautifyLayout? {
        model.isBeautifyOn ? model.renderer.beautifyLayout(model.beautify) : nil
    }

    /// Görünümde gösterilen şeyin (görüntü ya da güzelleştirilmiş kompozisyon) sığdırıldığı alan.
    /// Küçültülür ama büyütülmez.
    private var compositionRect: CGRect {
        let size = beautifyLayout?.canvasSize ?? imageSize
        let available = CGRect(
            x: insets.left,
            y: insets.top,
            width: bounds.width - insets.left - insets.right,
            height: bounds.height - insets.top - insets.bottom
        )
        let zoom = max(0.01, min(1, available.width / size.width, available.height / size.height))
        let fitted = CGSize(width: size.width * zoom, height: size.height * zoom)
        return CGRect(
            x: (available.midX - fitted.width / 2).rounded(),
            y: (available.midY - fitted.height / 2).rounded(),
            width: fitted.width,
            height: fitted.height
        )
    }

    private var zoom: CGFloat { compositionRect.width / (beautifyLayout?.canvasSize.width ?? imageSize.width) }

    /// Ekran görüntüsünün (çizimlerin koordinat sisteminin) görünümdeki yeri.
    private var imageRect: CGRect {
        let composition = compositionRect
        let zoom = zoom
        let offset = beautifyLayout?.imageRect.origin ?? .zero
        return CGRect(x: composition.minX + offset.x * zoom, y: composition.minY + offset.y * zoom,
                      width: imageSize.width * zoom, height: imageSize.height * zoom)
    }

    /// Fare konumunu görüntü koordinatına çevirir; görüntünün dışına taşmaz.
    private func imagePoint(for event: NSEvent) -> CGPoint {
        let point = convert(event.locationInWindow, from: nil)
        let rect = imageRect
        let x = (point.x - rect.minX) / zoom
        let y = (point.y - rect.minY) / zoom
        return CGPoint(x: min(max(x, 0), imageSize.width), y: min(max(y, 0), imageSize.height))
    }

    private func viewRect(for rect: CGRect) -> CGRect {
        let image = imageRect
        let zoom = zoom
        return CGRect(
            x: image.minX + rect.minX * zoom,
            y: image.minY + rect.minY * zoom,
            width: rect.width * zoom,
            height: rect.height * zoom
        )
    }

    // MARK: - Çizim

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        // Çizim sırasında okunan model alanları değişince tuval kendiliğinden yeniden çizilir.
        withObservationTracking {
            drawContents(in: context)
        } onChange: { [weak self] in
            Task { @MainActor in self?.needsDisplay = true }
        }
    }

    private func drawContents(in context: CGContext) {
        if model.isBeautifyOn {
            let composition = compositionRect
            context.saveGState()
            context.translateBy(x: composition.minX, y: composition.minY)
            context.scaleBy(x: zoom, y: zoom)
            context.interpolationQuality = .high
            model.renderer.drawBeautified(model.visibleAnnotations, settings: model.beautify, in: context)
            context.restoreGState()
            drawSelectionOutline()
            return
        }

        let rect = imageRect
        let shadow = NSColor.black.withAlphaComponent(0.28).cgColor

        context.saveGState()
        if model.capture.hasTransparency {
            // Pencere görüntüsü: köşeleri zaten saydam ve yuvarlak; gölgeyi görüntünün kendi şekli düşürür.
            context.setShadow(offset: .zero, blur: 24, color: shadow)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
        } else {
            // Ekranda köşeler yuvarlatılır; kaydedilen görüntü kare köşeli kalır.
            let radius = min(10, rect.width / 2, rect.height / 2)
            let rounded = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
            context.saveGState()
            context.setShadow(offset: .zero, blur: 24, color: shadow)
            context.addPath(rounded)
            context.setFillColor(NSColor.black.cgColor)
            context.fillPath()
            context.restoreGState()
            context.addPath(rounded)
            context.clip()
        }
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: zoom, y: zoom)
        context.interpolationQuality = .high
        model.renderer.draw(model.visibleAnnotations, in: context)
        if model.capture.hasTransparency {
            context.endTransparencyLayer()
        }
        context.restoreGState()
        drawSelectionOutline()
    }

    private func drawSelectionOutline() {
        if let selected = model.selectedAnnotation, selected.id != model.editingTextID {
            let outline = NSBezierPath(rect: viewRect(for: selected.bounds).insetBy(dx: -4, dy: -4))
            outline.lineWidth = 1
            outline.setLineDash([4, 3], count: 2, phase: 0)
            Brand.accentNSColor.setStroke()
            outline.stroke()
        }
    }

    // MARK: - İmleç

    override func resetCursorRects() {
        let cursor: NSCursor = switch model.tool {
        case .select: .arrow
        case .text, .label: .iBeam
        default: .crosshair
        }
        addCursorRect(imageRect, cursor: cursor)
    }

    /// Araç değişince imleci güncelle ve açık metni kaydet.
    private func observeTool() {
        withObservationTracking {
            _ = model.tool
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                endTextEditing(commit: true)
                window?.invalidateCursorRects(for: self)
                observeTool()
            }
        }
    }

    // MARK: - Fare

    override func mouseDown(with event: NSEvent) {
        if textField != nil {
            // Açık metin kutusunun dışına tıklamak metni kaydeder.
            endTextEditing(commit: true)
            return
        }
        window?.makeFirstResponder(self)
        let point = imagePoint(for: event)

        switch model.tool {
        case .select:
            let hit = annotation(at: point)
            if event.clickCount == 2, let hit, case let .text(_, origin) = hit.shape {
                beginTextEditing(at: origin, editing: hit)
                return
            }
            model.select(hit?.id)
            dragStart = point
            lastDragPoint = point
            hasMovedSelection = false
        case .text, .label:
            if let hit = annotation(at: point), case let .text(_, origin) = hit.shape {
                beginTextEditing(at: origin, editing: hit)
            } else {
                // Tıklanan nokta yazının dikey ortasına denk gelsin.
                let fontSize = Annotation(shape: .text("", origin: point), color: model.color,
                                          lineWidth: model.lineWidth).fontSize
                beginTextEditing(at: CGPoint(x: point.x, y: point.y - fontSize * 0.6), editing: nil)
            }
        default:
            dragStart = point
            model.draft = newAnnotation(from: point, to: point)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        var point = imagePoint(for: event)

        switch model.tool {
        case .select:
            guard model.selectedAnnotation != nil, let last = lastDragPoint else { return }
            model.moveSelected(by: CGSize(width: point.x - last.x, height: point.y - last.y),
                               recordingUndo: !hasMovedSelection)
            hasMovedSelection = true
            lastDragPoint = point
        case .pen:
            guard let draft = model.draft, case .pen(var points) = draft.shape else { return }
            points.append(point)
            model.draft?.shape = .pen(points)
        case .highlighter:
            guard let draft = model.draft, case .highlight(var points) = draft.shape else { return }
            if event.modifierFlags.contains(.shift) {
                // Shift: yazının altını çizer gibi düz çizgi.
                points = [start, CGPoint(x: point.x, y: start.y)]
            } else {
                points.append(point)
            }
            model.draft?.shape = .highlight(points)
        case .counter:
            // Numara bırakılmadan önce sürüklenerek yerine oturtulabilir.
            guard let draft = model.draft, case let .counter(number, _) = draft.shape else { return }
            model.draft?.shape = .counter(number, center: point)
        case .stamp:
            guard let draft = model.draft, case let .stamp(kind, _) = draft.shape else { return }
            model.draft?.shape = .stamp(kind, center: point)
        case .text, .label:
            break
        default:
            if event.modifierFlags.contains(.shift) {
                point = constrained(point, from: start)
            }
            model.draft = newAnnotation(from: start, to: point)
        }
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            dragStart = nil
            lastDragPoint = nil
        }
        guard let draft = model.draft else { return }
        model.draft = nil
        if !draft.isTooSmall {
            model.add(draft)
        }
    }

    private func newAnnotation(from start: CGPoint, to end: CGPoint) -> Annotation? {
        let shape: Annotation.Shape
        switch model.tool {
        case .arrow: shape = .arrow(from: start, to: end)
        case .rectangle: shape = .rectangle(CGRect(corner: start, end))
        case .ellipse: shape = .ellipse(CGRect(corner: start, end))
        case .pen: shape = .pen([start])
        case .highlighter: shape = .highlight([start])
        case .counter: shape = .counter(model.nextCounterNumber, center: end)
        case .stamp: shape = .stamp(model.stampKind, center: end)
        // Büyüteç: tıklanan nokta merkez, sürükleme mesafesi yarıçap.
        case .magnifier: shape = .magnifier(center: start, radius: hypot(end.x - start.x, end.y - start.y))
        case .blur: shape = .blur(CGRect(corner: start, end))
        case .pixelate: shape = .pixelate(CGRect(corner: start, end))
        case .select, .text, .label: return nil
        }
        return Annotation(shape: shape, color: model.color, lineWidth: model.lineWidth)
    }

    /// Shift basılıyken ok 45°'lik açılara kilitlenir; dikdörtgen kare, yuvarlak daire olur.
    private func constrained(_ point: CGPoint, from start: CGPoint) -> CGPoint {
        let dx = point.x - start.x
        let dy = point.y - start.y
        if model.tool == .arrow {
            let step = CGFloat.pi / 4
            let angle = (atan2(dy, dx) / step).rounded() * step
            let length = hypot(dx, dy)
            return CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
        }
        let side = max(abs(dx), abs(dy))
        return CGPoint(x: start.x + (dx < 0 ? -side : side), y: start.y + (dy < 0 ? -side : side))
    }

    /// Tıklanan noktadaki en üstteki şekil. Gizleme bölgeleri diğerlerinin altında çizildiği için en son bakılır.
    private func annotation(at point: CGPoint) -> Annotation? {
        let annotations = model.annotations
        let ordered = annotations.reversed().filter { !$0.isRedaction } + annotations.reversed().filter(\.isRedaction)
        return ordered.first { $0.contains(point, tolerance: 6 / zoom) }
    }

    // MARK: - Klavye

    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else {
            super.keyDown(with: event)
            return
        }
        let step: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1

        switch Int(event.keyCode) {
        case kVK_Delete, kVK_ForwardDelete:
            model.deleteSelected()
        case kVK_Escape:
            if model.selectedAnnotation != nil {
                model.select(nil)
            } else {
                window?.performClose(nil)
            }
        case kVK_LeftArrow:
            model.moveSelected(by: CGSize(width: -step, height: 0), recordingUndo: true)
        case kVK_RightArrow:
            model.moveSelected(by: CGSize(width: step, height: 0), recordingUndo: true)
        case kVK_UpArrow:
            model.moveSelected(by: CGSize(width: 0, height: -step), recordingUndo: true)
        case kVK_DownArrow:
            model.moveSelected(by: CGSize(width: 0, height: step), recordingUndo: true)
        default:
            if let key = event.charactersIgnoringModifiers?.lowercased().first,
               let tool = Tool.allCases.first(where: { $0.shortcut == key }) {
                model.selectTool(tool)
            } else {
                super.keyDown(with: event)
            }
        }
    }

    // MARK: - Metin kutusu

    private func beginTextEditing(at origin: CGPoint, editing existing: Annotation?) {
        endTextEditing(commit: true)
        let style = existing ?? Annotation(shape: .text("", origin: origin), color: model.color,
                                           lineWidth: model.lineWidth, hasBackground: model.tool == .label)

        let field = NSTextField(string: "")
        if case let .text(string, _) = existing?.shape {
            field.stringValue = string
        }
        field.isBordered = false
        field.isBezeled = false
        // Etiket yazılırken de kutusunun renginde görünür.
        field.drawsBackground = style.hasBackground
        field.backgroundColor = style.color.nsColor
        field.focusRingType = .none
        field.font = .systemFont(ofSize: style.fontSize * zoom, weight: .bold)
        field.textColor = style.hasBackground ? style.color.contrastingTextColor : style.color.nsColor
        field.placeholderString = "Metin yaz…"
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.delegate = self

        textField = field
        textOrigin = origin
        textHasBackground = style.hasBackground
        editingTextID = existing?.id
        model.editingTextID = existing?.id

        addSubview(field)
        layoutTextField()
        window?.makeFirstResponder(field)
    }

    private func layoutTextField() {
        guard let field = textField, let font = field.font else { return }
        field.sizeToFit()
        let placeholderWidth = NSAttributedString(string: field.placeholderString ?? "", attributes: [.font: font])
            .size().width
        let origin = viewRect(for: CGRect(origin: textOrigin, size: .zero)).origin
        // NSTextField metni ~2 nokta içeriden başlatır; çizilecek metinle hizalamak için sola kaydır.
        field.frame = CGRect(
            x: origin.x - 2,
            y: origin.y,
            width: max(field.frame.width, placeholderWidth) + 12,
            height: field.frame.height
        )
    }

    func controlTextDidChange(_ notification: Notification) {
        layoutTextField()
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        endTextEditing(commit: true)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            endTextEditing(commit: false)
            return true
        }
        return false
    }

    /// Metin kutusunu kapatır. `commit` false ise (Esc) yazılan metin atılır.
    private func endTextEditing(commit: Bool) {
        guard let field = textField else { return }
        textField = nil
        if commit {
            model.commitText(field.stringValue, at: textOrigin, editing: editingTextID, background: textHasBackground)
        } else {
            model.editingTextID = nil
        }
        editingTextID = nil
        field.removeFromSuperview()
        window?.makeFirstResponder(self)
    }
}
