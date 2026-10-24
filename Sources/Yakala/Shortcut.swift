import AppKit
import Carbon.HIToolbox

/// Sistem genelinde çalışan bir klavye kısayolu (ör. ⇧⌘2). Ayarlarda saklanır.
struct Shortcut: Codable, Equatable {
    /// Fiziksel tuş kodu (klavye düzeninden bağımsız).
    var keyCode: Int
    /// Carbon değiştirici tuşları (cmdKey | shiftKey …).
    var modifiers: Int
    /// Tuşun kendisi, ekranda gösterilecek biçimde ("2", "A", "Boşluk", "F5" …).
    var key: String

    static let defaultArea = Shortcut(keyCode: kVK_ANSI_2, modifiers: cmdKey | shiftKey, key: "2")
    static let defaultWindow = Shortcut(keyCode: kVK_ANSI_1, modifiers: cmdKey | shiftKey, key: "1")

    /// Basılan tuştan kısayol oluşturur. En az bir ⌘, ⌥ ya da ⌃ yoksa nil: tek başına harfler
    /// ya da yalnızca Shift ile basılan tuşlar sistem genelinde yazı yazmayı engellerdi.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !flags.intersection([.command, .option, .control]).isEmpty else { return nil }

        var carbon = 0
        if flags.contains(.command) { carbon |= cmdKey }
        if flags.contains(.option) { carbon |= optionKey }
        if flags.contains(.control) { carbon |= controlKey }
        if flags.contains(.shift) { carbon |= shiftKey }

        keyCode = Int(event.keyCode)
        modifiers = carbon
        if let name = Self.specialKeyNames[keyCode] {
            key = name
        } else {
            // Değiştiricisiz karakter: ⇧2 için "@" ya da "'" değil, "2" gösterilsin.
            let plain = event.characters(byApplyingModifiers: []) ?? event.charactersIgnoringModifiers ?? ""
            key = plain.uppercased(with: Locale(identifier: "tr_TR"))
        }
        guard !key.isEmpty else { return nil }
    }

    init(keyCode: Int, modifiers: Int, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }

    /// macOS'un kullandığı sırayla: ⌃⌥⇧⌘ ve tuş.
    var display: String {
        var text = ""
        if modifiers & controlKey != 0 { text += "⌃" }
        if modifiers & optionKey != 0 { text += "⌥" }
        if modifiers & shiftKey != 0 { text += "⇧" }
        if modifiers & cmdKey != 0 { text += "⌘" }
        return text + key
    }

    /// Menüde tuşun yanında gösterilecek eşdeğer; özel tuşlarda boş.
    var menuKeyEquivalent: String {
        key.count == 1 ? key.lowercased(with: Locale(identifier: "tr_TR")) : ""
    }

    var menuModifierMask: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & controlKey != 0 { flags.insert(.control) }
        if modifiers & optionKey != 0 { flags.insert(.option) }
        if modifiers & shiftKey != 0 { flags.insert(.shift) }
        if modifiers & cmdKey != 0 { flags.insert(.command) }
        return flags
    }

    private static let specialKeyNames: [Int: String] = [
        kVK_Space: "Boşluk", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]
}
