import AppKit

/// Hakkında panelinde ve ayarlarda gösterilen bilgiler.
enum About {
    static let creatorURL = URL(string: "https://github.com/mugione/")!
    static let creatorTitle = "github.com/mugione"
    static let summary = """
        Yakala, menü çubuğundan ekran görüntüsü alır. Üzerine ok, şekil ve yazı ekleyebilir, \
        gizli bilgileri bulanıklaştırabilir; sonucu tek tıkla kopyalayıp kaydedebilirsin.
        """

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    /// macOS'un standart Hakkında paneli: simge, sürüm, açıklama ve yapımcı bağlantısı.
    @MainActor
    static func showPanel() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    private static var credits: NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph,
        ]
        let text = NSMutableAttributedString(string: "\(summary)\n\nYapımcı: ", attributes: attributes)
        var link = attributes
        link[.link] = creatorURL
        text.append(NSAttributedString(string: creatorTitle, attributes: link))
        return text
    }
}
