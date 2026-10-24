import AppKit
import Carbon.HIToolbox

/// Seçimin sonucu: seçilen alanın görüntüsü ya da tıklanan pencere.
enum SelectionResult {
    case area(Capture)
    case window(CGWindowID)
}

/// Ekranın "dondurulmuş" görüntüsünün üzerinde fareyle alan ya da pencere seçtirir.
/// Önce ekran yakalanır, sonra her ekrana o görüntüyü gösteren bir katman açılır;
/// böylece seçim sırasında açılır menüler ve fare üzerindeki görünümler kaybolmaz.
@MainActor
final class AreaSelector {
    enum Mode {
        /// Sürükleyerek alan seç; tek tık tüm ekranı alır.
        case area
        /// Fare altındaki pencere vurgulanır; tıklanan pencere alınır.
        case window
    }

    private(set) var mode: Mode = .area
    /// Fare altındaki pencere (pencere modunda vurgulanır).
    private(set) var hoveredWindow: WindowInfo?

    private var windows: [WindowInfo] = []
    private var panels: [SelectionPanel] = []
    private var continuation: CheckedContinuation<SelectionResult?, Never>?
    private var previousApp: NSRunningApplication?

    /// Esc veya sağ tıkla vazgeçilirse nil döner. Seçim ekranında Boşluk tuşu iki mod arasında geçiş yapar.
    /// - Parameter windows: Seçilebilecek pencereler, öndekinden arkadakine.
    func select(from shots: [ScreenShot], windows: [WindowInfo], startingIn mode: Mode) async -> SelectionResult? {
        previousApp = NSWorkspace.shared.frontmostApplication
        self.mode = mode
        self.windows = windows
        hoveredWindow = nil
        updateHover()

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            panels = shots.map { SelectionPanel(shot: $0, selector: self) }
            NSApp.activate()
            panels.forEach { $0.orderFrontRegardless() }
            let underMouse = NSScreen.underMouse
            (panels.first { $0.screenOfShot == underMouse } ?? panels.first)?.makeKey()
            cursor.set()
        }
    }

    var cursor: NSCursor { mode == .window ? .pointingHand : .crosshair }

    func toggleMode() {
        mode = mode == .area ? .window : .area
        updateHover()
        cursor.set()
        redraw()
    }

    /// Fare konumuna göre vurgulanan pencereyi günceller.
    func updateHover() {
        let mouse = NSEvent.mouseLocation
        let hovered = mode == .window ? windows.first { $0.frame.contains(mouse) } : nil
        guard hovered?.id != hoveredWindow?.id else { return }
        hoveredWindow = hovered
        redraw()
    }

    func finish(with result: SelectionResult?) {
        panels.forEach { $0.close() }
        panels = []
        NSCursor.arrow.set()
        // Vazgeçildiyse odağı kullanıcının önceki uygulamasına geri ver.
        if result == nil {
            previousApp?.activate()
        }
        previousApp = nil
        continuation?.resume(returning: result)
        continuation = nil
    }

    private func redraw() {
        panels.forEach { $0.selectionView.needsDisplay = true }
    }
}

/// Tek bir ekranı kaplayan seçim katmanı.
/// Odak çalmayan (non-activating) panel olduğu için uygulama öne gelmese de Esc tuşunu alır.
private final class SelectionPanel: NSPanel {
    let screenOfShot: NSScreen
    let selectionView: SelectionView

    init(shot: ScreenShot, selector: AreaSelector) {
        screenOfShot = shot.screen
        selectionView = SelectionView(capture: shot.capture, selector: selector)
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
        selectionView.frame = background.bounds
        selectionView.autoresizingMask = [.width, .height]
        background.addSubview(selectionView)
        contentView = background
        makeFirstResponder(selectionView)
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

/// Karartma, seçim çerçevesi, pencere vurgusu ve etiketleri çizer; fare ve klavyeyi dinler.
private final class SelectionView: NSView {
    private let capture: Capture
    private weak var selector: AreaSelector?
    private var dragStart: NSPoint?
    private var selection: NSRect?

    private static let labelAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
        .foregroundColor: NSColor.white,
    ]

    init(capture: Capture, selector: AreaSelector) {
        self.capture = capture
        self.selector = selector
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

    private var isWindowMode: Bool { selector?.mode == .window }

    // MARK: - İmleç ve klavye

    override func cursorUpdate(with event: NSEvent) {
        selector?.cursor.set()
    }

    override func mouseMoved(with event: NSEvent) {
        selector?.updateHover()
        selector?.cursor.set()
    }

    override func mouseEntered(with event: NSEvent) {
        // Birden fazla ekran varsa Esc'nin çalışması için fare hangi ekrandaysa o katman odak alır.
        window?.makeKey()
        selector?.cursor.set()
    }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Escape:
            selector?.finish(with: nil)
        case kVK_Space where dragStart == nil:
            // macOS'taki gibi: Boşluk alan ve pencere seçimi arasında geçiş yapar.
            selection = nil
            selector?.toggleMode()
        default:
            super.keyDown(with: event)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        selector?.finish(with: nil)
    }

    // MARK: - Seçim

    override func mouseDown(with event: NSEvent) {
        if isWindowMode {
            if let window = selector?.hoveredWindow {
                selector?.finish(with: .window(window.id))
            }
            return
        }
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
            selector?.finish(with: .area(capture))
            return
        }
        // AppKit'te orijin sol alttadır, görüntüde sol üstte: dikey ekseni çevir.
        let topLeftRect = CGRect(
            x: selection.minX,
            y: bounds.height - selection.maxY,
            width: selection.width,
            height: selection.height
        )
        selector?.finish(with: capture.cropped(to: topLeftRect).map(SelectionResult.area))
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
        if isWindowMode {
            drawWindowMode()
        } else {
            drawAreaMode()
        }
    }

    private func drawAreaMode() {
        let dim = NSBezierPath(rect: bounds)
        if let selection {
            dim.append(NSBezierPath(rect: selection))
            dim.windingRule = .evenOdd // seçili alanın içi karartılmaz
        }
        NSColor.black.withAlphaComponent(0.35).setFill()
        dim.fill()

        guard let selection else {
            drawHint("Alan seçmek için sürükle  ·  Tüm ekran için tıkla  ·  Pencere için Boşluk  ·  Vazgeçmek için Esc")
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

    /// Fare altındaki pencere aydınlık ve mavi çerçeveli kalır, geri kalan kararır.
    private func drawWindowMode() {
        let screenOrigin = window?.frame.origin ?? .zero
        let hovered = selector?.hoveredWindow.map {
            $0.frame.offsetBy(dx: -screenOrigin.x, dy: -screenOrigin.y)
        }

        let dim = NSBezierPath(rect: bounds)
        if let hovered {
            dim.append(NSBezierPath(rect: hovered))
            dim.windingRule = .evenOdd
        }
        NSColor.black.withAlphaComponent(0.35).setFill()
        dim.fill()

        if let hovered {
            NSColor.controlAccentColor.withAlphaComponent(0.15).setFill()
            hovered.fill()
            NSColor.controlAccentColor.setStroke()
            let border = NSBezierPath(rect: hovered.insetBy(dx: 1.5, dy: 1.5))
            border.lineWidth = 3
            border.stroke()
        }

        drawHint("Pencereye tıkla  ·  Alan seçimi için Boşluk  ·  Vazgeçmek için Esc")
    }

    private func drawHint(_ text: String) {
        drawPill(text) { size in
            NSPoint(x: bounds.midX - size.width / 2, y: bounds.maxY - 90)
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
