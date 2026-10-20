import AppKit
import ApplicationServices
import HaloKit

/// Reads the conversation open in Messages through Accessibility. Messages
/// labels each bubble "Sender, text, time", or "Your iMessage, text, time".
@MainActor
enum MessagesReader {
    /// Enough recent history for context without sending the whole thread.
    static let historyLimit = 60

    /// The messages loaded for the open chat, oldest first.
    static func transcript() -> [String] {
        guard let window = window(), let list = find("TranscriptCollectionView", in: window) else { return [] }
        let lines = children(list).compactMap { string($0, kAXDescriptionAttribute) }.filter { !$0.isEmpty }
        return Array(lines.suffix(historyLimit))
    }

    /// Selects everything in the message being typed, so pasting replaces it,
    /// and returns it. `nil` when there's nothing typed.
    static func selectDraft() -> String? {
        guard let window = window(), let field = find("messageBodyField", in: window),
              let text = string(field, kAXValueAttribute), !text.isEmpty
        else { return nil }
        var range = CFRange(location: 0, length: (text as NSString).length)
        guard let value = AXValueCreate(.cfRange, &range) else { return nil }
        AXUIElementSetAttributeValue(field, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(field, kAXSelectedTextRangeAttribute as CFString, value)
        return text
    }

    private static func window() -> AXUIElement? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: Apps.messages).first else { return nil }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var window: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &window) == .success else { return nil }
        return (window as! AXUIElement)
    }

    private static func find(_ identifier: String, in element: AXUIElement) -> AXUIElement? {
        if string(element, kAXIdentifierAttribute) == identifier { return element }
        for child in children(element) {
            if let found = find(identifier, in: child) { return found }
        }
        return nil
    }

    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        return value as? [AXUIElement] ?? []
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return value as? String
    }
}
