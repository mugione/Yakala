import AppKit
import ScreenCaptureKit

/// Alınmış bir ekran görüntüsü. `scale` Retina ekranlarda 2'dir.
struct Capture {
    let image: CGImage
    let scale: CGFloat
    let date: Date

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

enum CaptureError: LocalizedError {
    case permissionDenied
    case displayNotFound

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Ekran kaydı izni verilmemiş."
        case .displayNotFound: "Yakalanacak ekran bulunamadı."
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

    /// Yakala'nın kendi pencereleri (önizleme, menü) görüntüye girmez.
    private static func capture(_ screens: [NSScreen]) async throws -> [ScreenShot] {
        guard CGPreflightScreenCaptureAccess() else {
            // Uygulamayı Sistem Ayarları'ndaki listeye ekler; ilk seferde sistem uyarısını da gösterir.
            CGRequestScreenCaptureAccess()
            throw CaptureError.permissionDenied
        }

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch let error as SCStreamError where error.code == .userDeclined {
            throw CaptureError.permissionDenied
        }

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
