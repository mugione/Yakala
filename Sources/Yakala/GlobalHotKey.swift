import AppKit
import Carbon.HIToolbox

/// Uygulama arka plandayken de çalışan, sistem genelinde bir klavye kısayolu.
/// Carbon'un RegisterEventHotKey API'si eski ama Erişilebilirlik izni istemeyen tek yol bu.
@MainActor
final class GlobalHotKey {
    private static var nextID: UInt32 = 1

    private let id: UInt32
    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// - Parameters:
    ///   - keyCode: Fiziksel tuş kodu, ör. `kVK_ANSI_2`.
    ///   - modifiers: Carbon değiştirici tuşları, ör. `cmdKey | shiftKey`.
    /// - Returns: Kısayol başka bir uygulama tarafından kullanılıyorsa nil.
    init?(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        id = Self.nextID
        Self.nextID += 1
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var pressedID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &pressedID
                )
                let pressed = pressedID.id
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                // Carbon olayları ana iş parçacığında gelir.
                return MainActor.assumeIsolated {
                    guard pressed == hotKey.id else { return OSStatus(eventNotHandledErr) }
                    hotKey.action()
                    return noErr
                }
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        guard installStatus == noErr else { return nil }

        let hotKeyID = EventHotKeyID(signature: OSType(0x594B_4C41), id: id) // 'YKLA'
        let registerStatus = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            RemoveEventHandler(handlerRef)
            return nil
        }
    }
}
