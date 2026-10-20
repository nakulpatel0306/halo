import AppKit
import ApplicationServices
import Carbon.HIToolbox
import HaloKit

/// Works out what the user is pointing at when the ring opens, and puts text
/// back afterwards.
@MainActor
enum ContextReader {
    /// `copying` allows pressing ⌘C to find a selection the app won't expose.
    static func current(copying: Bool) async -> RingContext {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier == "com.apple.finder" {
            let files = finderSelection()
            return files.isEmpty ? .none : .files(files)
        }
        switch accessibilitySelection() {
        case let .some(text):
            return text.isEmpty ? .none : .text(text)
        case .none:
            // The app doesn't expose its selection (common in browsers and
            // Electron apps), so ask it to copy and see if anything arrives.
            guard copying else { return .none }
            if let text = await copySelection(), !text.isEmpty { return .text(text) }
            return .none
        }
    }

    // MARK: Front app

    static var frontApp: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    static let terminals: Set = ["com.mitchellh.ghostty", "com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable"]

    static var frontIsTerminal: Bool {
        frontApp.map(terminals.contains) ?? false
    }

    // MARK: Finder

    private static let finderScript = NSAppleScript(source: """
    tell application "Finder"
        set out to {}
        repeat with f in (selection as alias list)
            set end of out to POSIX path of f
        end repeat
        return out
    end tell
    """)

    /// Read as a list rather than joined text, so a file name containing a
    /// newline can't split into paths that were never selected.
    static func finderSelection() -> [URL] {
        var error: NSDictionary?
        guard let list = finderScript?.executeAndReturnError(&error), list.numberOfItems > 0 else { return [] }
        return (1...list.numberOfItems).compactMap { list.atIndex($0)?.stringValue }.map { URL(fileURLWithPath: $0) }
    }

    // MARK: Text

    /// `nil` when the focused app can't tell us; `""` when it says nothing is selected.
    static func accessibilitySelection() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused
        else { return nil }
        var selected: AnyObject?
        guard AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selected) == .success
        else { return nil }
        return selected as? String
    }

    static func copySelection() async -> String? {
        let board = NSPasteboard.general
        let saved = PasteboardSnapshot(board)
        let before = board.changeCount
        postShortcut(kVK_ANSI_C)
        for _ in 0..<12 where board.changeCount == before {
            try? await Task.sleep(for: .milliseconds(25))
        }
        guard board.changeCount != before else { return nil }
        let text = board.string(forType: .string)
        saved.restore(to: board)
        return text
    }

    /// Replaces the current selection in the frontmost app with `text`, then
    /// puts the user's clipboard back the way it was.
    static func paste(_ text: String) async {
        let board = NSPasteboard.general
        let saved = PasteboardSnapshot(board)
        board.clearContents()
        board.setString(text, forType: .string)
        postShortcut(kVK_ANSI_V)
        // Give the target app time to read the clipboard before restoring it.
        try? await Task.sleep(for: .milliseconds(600))
        saved.restore(to: board)
    }

    static func postShortcut(_ key: Int) {
        press(KeyCombo(key, .command))
    }

    /// Presses a shortcut in the front app. A private event source keeps the keys
    /// still held for the Halo shortcut (⌥ and so on) out of the event.
    static func press(_ combo: KeyCombo) {
        var flags: CGEventFlags = []
        if combo.modifiers.contains(.command) { flags.insert(.maskCommand) }
        if combo.modifiers.contains(.shift) { flags.insert(.maskShift) }
        if combo.modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if combo.modifiers.contains(.control) { flags.insert(.maskControl) }
        let source = CGEventSource(stateID: .privateState)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(combo.keyCode), keyDown: down)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
        }
    }
}

/// Every item and type on the pasteboard, so borrowing it for a copy or paste
/// doesn't lose an image or rich text the user had copied.
struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(_ board: NSPasteboard) {
        items = (board.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in item.data(forType: type).map { (type, $0) } })
        }
    }

    func restore(to board: NSPasteboard) {
        board.clearContents()
        let restored = items.map { entries in
            let item = NSPasteboardItem()
            for (type, data) in entries { item.setData(data, forType: type) }
            return item
        }
        if !restored.isEmpty { board.writeObjects(restored) }
    }
}
