import AppKit
import ScreenCaptureKit

/// Alınmış bir ekran görüntüsü. `scale` Retina ekranlarda 2'dir.
struct Capture {
    let image: CGImage
    let scale: CGFloat
    let date: Date
    /// Pencere yakalamada köşeler saydamdır; düzenleyici arkasına siyah zemin koymaz.
    var hasTransparency = false

    /// Görüntünün ekrandaki (nokta cinsinden) boyutu.
    var pointSize: CGSize {
        CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
    }

    /// Görüntünün bir bölümünü keser. `rect` nokta cinsindendir ve orijini sol üst köşededir.
    func cropped(to rect: CGRect) -> Capture? {
        let pixelRect = CGRect(
            x: rect.minX * scale,
            y: rect.minY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
        .integral
        .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))

        guard !pixelRect.isEmpty, let cropped = image.cropping(to: pixelRect) else { return nil }
        return Capture(image: cropped, scale: scale, date: date)
    }
}

/// Bir ekranın görüntüsü ve o ekran.
struct ScreenShot {
    let screen: NSScreen
    let capture: Capture
}

/// Ekranda görünen bir uygulama penceresi (pencere yakalamada seçilebilir).
struct WindowInfo {
    let id: CGWindowID
    /// Cocoa koordinatlarında (ana ekranın sol altı orijin) pencerenin çerçevesi.
    let frame: CGRect
}

enum CaptureError: LocalizedError {
    case permissionDenied
    case displayNotFound
    case windowNotFound

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Ekran kaydı izni verilmemiş."
        case .displayNotFound: "Yakalanacak ekran bulunamadı."
        case .windowNotFound: "Seçilen pencere artık ekranda değil."
        }
    }
}

@MainActor
enum ScreenCapturer {
    /// Bağlı tüm ekranları yakalar (alan seçimi için).
    static func captureAllScreens() async throws -> [ScreenShot] {
        try await capture(NSScreen.screens)
    }

    /// Fare imlecinin bulunduğu ekranın tamamını yakalar.
    static func captureScreenUnderMouse() async throws -> Capture {
        guard let screen = NSScreen.underMouse,
              let shot = try await capture([screen]).first else {
            throw CaptureError.displayNotFound
        }
        return shot.capture
    }

    /// Tek bir pencereyi, arkasındaki her şeyden bağımsız olarak yakalar.
    /// Pencerenin yuvarlak köşeleri saydam kalır; gölge eklenmez.
    static func captureWindow(_ id: CGWindowID) async throws -> Capture {
        let content = try await shareableContent()
        guard let window = content.windows.first(where: { $0.windowID == id }) else {
            throw CaptureError.windowNotFound
        }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let scale = CGFloat(filter.pointPixelScale)
        let config = SCStreamConfiguration()
        config.width = Int(filter.contentRect.width * scale)
        config.height = Int(filter.contentRect.height * scale)
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true
        config.shouldBeOpaque = false

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return Capture(image: image, scale: scale, date: .now, hasTransparency: true)
    }

    /// Ekrandaki normal uygulama pencereleri, öndekinden arkadakine doğru.
    /// Menü çubuğu, Dock, masaüstü ve Yakala'nın kendi pencereleri dahil değildir.
    static func visibleWindows() -> [WindowInfo] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] else { return [] }
        // CGWindowList ana ekranın sol üstünü orijin alır; AppKit sol altını.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0

        return list.compactMap { info in
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  (info[kCGWindowOwnerPID as String] as? pid_t) != getpid(),
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0.01,
                  let id = info[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds),
                  rect.width >= 40, rect.height >= 40
            else { return nil }
            return WindowInfo(
                id: id,
                frame: CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
            )
        }
    }

    /// İzni denetler ve ekrandaki içeriğin listesini alır.
    private static func shareableContent() async throws -> SCShareableContent {
        guard CGPreflightScreenCaptureAccess() else {
            // Uygulamayı Sistem Ayarları'ndaki listeye ekler; ilk seferde sistem uyarısını da gösterir.
            CGRequestScreenCaptureAccess()
            throw CaptureError.permissionDenied
        }
        do {
            return try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch let error as SCStreamError where error.code == .userDeclined {
            throw CaptureError.permissionDenied
        }
    }

    /// Yakala'nın kendi pencereleri (önizleme, menü) görüntüye girmez.
    private static func capture(_ screens: [NSScreen]) async throws -> [ScreenShot] {
        let content = try await shareableContent()
        let ownApp = content.applications.filter { $0.processID == getpid() }
        var shots: [ScreenShot] = []

        for screen in screens {
            guard let display = content.displays.first(where: { $0.displayID == screen.displayID }) else { continue }
            let filter = SCContentFilter(display: display, excludingApplications: ownApp, exceptingWindows: [])

            let scale = CGFloat(filter.pointPixelScale)
            let config = SCStreamConfiguration()
            config.width = Int(filter.contentRect.width * scale)
            config.height = Int(filter.contentRect.height * scale)
            config.showsCursor = false

            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            shots.append(ScreenShot(screen: screen, capture: Capture(image: image, scale: scale, date: .now)))
        }

        guard !shots.isEmpty else { throw CaptureError.displayNotFound }
        return shots
    }
}

extension NSScreen {
    /// Fare imlecinin şu an üzerinde bulunduğu ekran.
    static var underMouse: NSScreen? {
        let mouse = NSEvent.mouseLocation
        return screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? main
    }

    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
