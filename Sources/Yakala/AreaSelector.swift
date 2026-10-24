import AppKit
import Carbon.HIToolbox

/// Ekranın "dondurulmuş" görüntüsünün üzerinde fareyle alan seçtirir.
/// Önce ekran yakalanır, sonra her ekrana o görüntüyü gösteren bir katman açılır;
/// böylece seçim sırasında açılır menüler ve fare üzerindeki görünümler kaybolmaz.
@MainActor
final class AreaSelector {
    private var panels: [SelectionPanel] = []
    private var continuation: CheckedContinuation<Capture?, Never>?
    private var previousApp: NSRunningApplication?

    /// Seçilen bölgenin görüntüsünü döner. Esc veya sağ tıkla vazgeçilirse nil.
    /// Sürüklemeden tek tıklanırsa o ekranın tamamı döner.
    func selectArea(from shots: [ScreenShot]) async -> Capture? {
        previousApp = NSWorkspace.shared.frontmostApplication
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            panels = shots.map { shot in
                SelectionPanel(shot: shot) { [weak self] capture in self?.finish(with: capture) }
            }
            NSApp.activate()
            panels.forEach { $0.orderFrontRegardless() }
            let underMouse = NSScreen.underMouse
            (panels.first { $0.screenOfShot == underMouse } ?? panels.first)?.makeKey()
            NSCursor.crosshair.set()
        }
    }

    private func finish(with capture: Capture?) {
        panels.forEach { $0.close() }
        panels = []
        NSCursor.arrow.set()
        // Vazgeçildiyse odağı kullanıcının önceki uygulamasına geri ver.
        if capture == nil {
            previousApp?.activate()
        }
        previousApp = nil
        continuation?.resume(returning: capture)
        continuation = nil
    }
}

/// Tek bir ekranı kaplayan seçim katmanı.
/// Odak çalmayan (non-activating) panel olduğu için uygulama öne gelmese de Esc tuşunu alır.
private final class SelectionPanel: NSPanel {
    let screenOfShot: NSScreen

    init(shot: ScreenShot, onFinish: @escaping (Capture?) -> Void) {
        screenOfShot = shot.screen
        super.init(
            contentRect: shot.screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver // menü çubuğu ve Dock'un da üstünde
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        isReleasedWhenClosed = false
        hasShadow = false
        backgroundColor = .black
        setFrame(shot.screen.frame, display: false)

        let background = FrozenScreenView(image: shot.capture.image)
        let selection = SelectionView(capture: shot.capture, onFinish: onFinish)
        selection.frame = background.bounds
        selection.autoresizingMask = [.width, .height]
        background.addSubview(selection)
        contentView = background
        makeFirstResponder(selection)
    }

    override var canBecomeKey: Bool { true }
}

/// Dondurulmuş ekran görüntüsünü katman içeriği olarak gösterir (her karede yeniden çizilmez).
private final class FrozenScreenView: NSView {
    private let image: CGImage

    init(image: CGImage) {
        self.image = image
        super.init(frame: .zero)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) kullanılmıyor")
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.contents = image
        layer?.contentsGravity = .resize
    }
}

/// Karartma, seçim çerçevesi ve ölçü etiketini çizer; fare ve klavyeyi dinler.
private final class SelectionView: NSView {
    private let capture: Capture
    private let onFinish: (Capture?) -> Void
    private var dragStart: NSPoint?
    private var selection: NSRect?

    private static let labelAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
        .foregroundColor: NSColor.white,
    ]

    init(capture: Capture, onFinish: @escaping (Capture?) -> Void) {
        self.capture = capture
        self.onFinish = onFinish
        super.init(frame: .zero)
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .cursorUpdate, .mouseEnteredAndExited, .mouseMoved],
            owner: self
        ))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) kullanılmıyor")
    }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: - İmleç ve klavye

    override func cursorUpdate(with event: NSEvent) { NSCursor.crosshair.set() }
    override func mouseMoved(with event: NSEvent) { NSCursor.crosshair.set() }

    override func mouseEntered(with event: NSEvent) {
        // Birden fazla ekran varsa Esc'nin çalışması için fare hangi ekrandaysa o katman odak alır.
        window?.makeKey()
        NSCursor.crosshair.set()
    }

    override func keyDown(with event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape {
            onFinish(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onFinish(nil)
    }

    // MARK: - Seçim

    override func mouseDown(with event: NSEvent) {
        dragStart = clampedLocation(of: event)
        selection = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStart else { return }
        let point = clampedLocation(of: event)
        selection = NSRect(
            x: min(dragStart.x, point.x),
            y: min(dragStart.y, point.y),
            width: abs(point.x - dragStart.x),
            height: abs(point.y - dragStart.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard dragStart != nil else { return }
        dragStart = nil

        // Sürüklemeden tıklandıysa ekranın tamamı alınır.
        guard let selection, selection.width >= 4, selection.height >= 4 else {
            onFinish(capture)
            return
        }
        // AppKit'te orijin sol alttadır, görüntüde sol üstte: dikey ekseni çevir.
        let topLeftRect = CGRect(
            x: selection.minX,
            y: bounds.height - selection.maxY,
            width: selection.width,
            height: selection.height
        )
        onFinish(capture.cropped(to: topLeftRect))
    }

    private func clampedLocation(of event: NSEvent) -> NSPoint {
        let point = convert(event.locationInWindow, from: nil)
        return NSPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }

    // MARK: - Çizim

    override func draw(_ dirtyRect: NSRect) {
        let dim = NSBezierPath(rect: bounds)
        if let selection {
            dim.append(NSBezierPath(rect: selection))
            dim.windingRule = .evenOdd // seçili alanın içi karartılmaz
        }
        NSColor.black.withAlphaComponent(0.35).setFill()
        dim.fill()

        guard let selection else {
            drawPill("Alan seçmek için sürükle  ·  Tüm ekran için tıkla  ·  Vazgeçmek için Esc") { size in
                NSPoint(x: bounds.midX - size.width / 2, y: bounds.maxY - 90)
            }
            return
        }

        NSColor.white.setStroke()
        let border = NSBezierPath(rect: selection.insetBy(dx: -0.5, dy: -0.5))
        border.lineWidth = 1
        border.stroke()

        let width = Int((selection.width * capture.scale).rounded())
        let height = Int((selection.height * capture.scale).rounded())
        drawPill("\(width) × \(height)") { size in
            // Seçimin sağ altına; ekranın altına taşıyorsa seçimin içine.
            var origin = NSPoint(x: selection.maxX - size.width, y: selection.minY - size.height - 6)
            if origin.y < bounds.minY + 4 { origin.y = selection.minY + 6 }
            origin.x = max(origin.x, bounds.minX + 4)
            return origin
        }
    }

    /// Yarı saydam siyah, yuvarlak köşeli bir etiket çizer. `origin` etiketin boyutuna göre konumunu verir.
    private func drawPill(_ text: String, origin: (NSSize) -> NSPoint) {
        let string = NSAttributedString(string: text, attributes: Self.labelAttributes)
        let textSize = string.size()
        let size = NSSize(width: ceil(textSize.width) + 16, height: ceil(textSize.height) + 8)
        let rect = NSRect(origin: origin(size), size: size)

        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()
        string.draw(at: NSPoint(x: rect.minX + 8, y: rect.minY + 4))
    }
}
