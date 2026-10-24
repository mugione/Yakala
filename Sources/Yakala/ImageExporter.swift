import AppKit
import UniformTypeIdentifiers

/// Panoya kopyalama ve diske kaydetme.
@MainActor
enum ImageExporter {
    static func copyToPasteboard(_ capture: Capture) {
        let rep = bitmap(for: capture)
        let item = NSPasteboardItem()
        // PNG çoğu uygulama (tarayıcı, Slack, Figma) için, TIFF eski AppKit uygulamaları için.
        if let png = rep.representation(using: .png, properties: [:]) {
            item.setData(png, forType: .png)
        }
        if let tiff = rep.tiffRepresentation {
            item.setData(tiff, forType: .tiff)
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([item])
    }

    /// PNG olarak yazar. Klasör yoksa oluşturur, aynı adlı dosyanın üzerine yazar.
    static func write(_ capture: Capture, to url: URL) throws {
        guard let png = bitmap(for: capture).representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let folder = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        do {
            try png.write(to: url, options: .atomic)
        } catch {
            // Sandbox'ta kaydetme penceresiyle yalnızca dosyanın kendisine izin verilir; atomik yazma
            // aynı klasöre geçici dosya açamayabilir. O durumda doğrudan dosyanın üzerine yazılır.
            try png.write(to: url)
        }
    }

    /// Klasörde henüz olmayan bir dosya adı. Aynı saniyede iki görüntü alınırsa sonuna (2), (3)… eklenir.
    static func newFileURL(in folder: URL, for date: Date) -> URL {
        let baseName = defaultBaseName(for: date)
        var url = folder.appendingPathComponent(baseName).appendingPathExtension("png")
        var number = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(baseName) (\(number))").appendingPathExtension("png")
            number += 1
        }
        return url
    }

    /// Kaydetme penceresini açar. Kaydedilen dosyanın adresini döner, vazgeçilirse nil.
    @discardableResult
    static func saveWithPanel(_ capture: Capture, startingIn folder: URL? = nil) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Ekran Görüntüsünü Kaydet"
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(defaultBaseName(for: capture.date)).png"
        if let folder, FileManager.default.fileExists(atPath: folder.path) {
            panel.directoryURL = folder
        }

        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        do {
            try write(capture, to: url)
            return url
        } catch {
            NSAlert(error: error).runModal()
            return nil
        }
    }

    private static func bitmap(for capture: Capture) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(cgImage: capture.image)
        // Nokta boyutunu ayarlamak Retina görüntülerin yapıştırıldığında iki kat büyük görünmesini engeller.
        rep.size = capture.pointSize
        return rep
    }

    private static func defaultBaseName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'saat' HH.mm.ss"
        return "Ekran Görüntüsü \(formatter.string(from: date))"
    }
}
