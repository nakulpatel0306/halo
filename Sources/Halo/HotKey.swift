import Carbon.HIToolbox
import HaloKit

/// A system-wide shortcut that reports both press and release, which is what
/// lets the ring work as hold-move-release. Carbon hotkeys need no Accessibility
/// permission, unlike an event tap.
final class HotKey {
    private static var handlers: [UInt32: HotKey] = [:]
    private static var nextID: UInt32 = 1
    private static var eventHandler: EventHandlerRef?

    private let id: UInt32
    private var ref: EventHotKeyRef?
    var onPress: () -> Void = {}
    var onRelease: () -> Void = {}

    init?(keyCode: Int, modifiers: Int) {
        Self.installHandlerIfNeeded()
        id = Self.nextID
        Self.nextID += 1
        let hotKeyID = EventHotKeyID(signature: OSType(0x48414C4F), id: id) // 'HALO'
        guard RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &ref) == noErr else {
            return nil
        }
        Self.handlers[id] = self
    }

    convenience init?(_ shortcut: Shortcut) {
        switch shortcut {
        case .optionSpace: self.init(keyCode: kVK_Space, modifiers: optionKey)
        case .controlOptionSpace: self.init(keyCode: kVK_Space, modifiers: controlKey | optionKey)
        case .commandShiftSpace: self.init(keyCode: kVK_Space, modifiers: cmdKey | shiftKey)
        case .optionBacktick: self.init(keyCode: kVK_ANSI_Grave, modifiers: optionKey)
        }
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        Self.handlers[id] = nil
    }

    private static func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        let types = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard let hotKey = HotKey.handlers[hotKeyID.id] else { return OSStatus(eventNotHandledErr) }
            if GetEventKind(event) == UInt32(kEventHotKeyPressed) {
                hotKey.onPress()
            } else {
                hotKey.onRelease()
            }
            return noErr
        }, types.count, types, nil, &eventHandler)
    }
}
