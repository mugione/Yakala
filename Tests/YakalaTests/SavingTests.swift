import AppKit
import Testing
@testable import Yakala

/// Otomatik kayıt ve Kaydet (⌘S) akışı.
@MainActor
struct SavingTests {
    @Test func newFileNamesNeverOverwriteExistingFiles() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let date = Date()
        let first = ImageExporter.newFileURL(in: folder, for: date)
        try Data().write(to: first)
        let second = ImageExporter.newFileURL(in: folder, for: date)

        #expect(second != first)
        #expect(second.lastPathComponent.hasSuffix(" (2).png"))
    }

    @Test func autoSaveCreatesTheFolderAndSaveUpdatesTheSameFile() throws {
        let root = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("Yakala/Alt klasör", isDirectory: true) // henüz yok

        let model = EditorModel(capture: makeSolidCapture())
        try model.autoSave(to: folder)
        let url = try #require(model.savedURL)
        let original = try Data(contentsOf: url)

        model.add(Annotation(shape: .rectangle(CGRect(x: 5, y: 5, width: 20, height: 10)),
                             color: .red, lineWidth: .thick))
        model.save() // kaydetme penceresi açmadan aynı dosyayı günceller

        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).count == 1)
        #expect(try Data(contentsOf: url) != original)
    }
}

/// Sandbox'ta FileManager kapsayıcıyı gösterir; varsayılan klasör gerçek ~/Pictures olmalı.
@MainActor
struct SaveFolderTests {
    @Test func defaultFolderIsTheRealPicturesFolder() {
        let folder = AppSettings.defaultSaveFolder.path
        #expect(folder.hasSuffix("/Pictures/Yakala"))
        #expect(!folder.contains("/Library/Containers/"))
        #expect(AppSettings.displayPath(AppSettings.defaultSaveFolder) == "~/Pictures/Yakala")
        #expect(AppSettings.displayPath(URL(fileURLWithPath: "/Volumes/Disk/Ekran")) == "/Volumes/Disk/Ekran")
    }
}

private func makeTemporaryFolder() throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
}

/// 50×30 noktalık (100×60 piksel) düz gri görüntü.
private func makeSolidCapture() -> Capture {
    let context = CGContext(data: nil, width: 100, height: 60, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(gray: 0.5, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: 100, height: 60))
    return Capture(image: context.makeImage()!, scale: 2, date: .now)
}
