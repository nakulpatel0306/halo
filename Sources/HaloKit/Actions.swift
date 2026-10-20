import Carbon.HIToolbox
import Foundation

/// What was under the user's attention when the ring opened.
public enum RingContext: Sendable, Equatable {
    case text(String)
    case files([URL])
    case none

    public var ring: RingKind {
        switch self {
        case .text: .text
        case .files: .files
        case .none: .general
        }
    }
}

/// Groups actions in the library and gives each its icon colour.
public enum ActionCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case ai, text, convert, image, document, media, files, capture, system, app, custom
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .ai: "Claude"
        case .text: "Text Tools"
        case .convert: "Convert"
        case .image: "Image"
        case .document: "PDF & Docs"
        case .media: "Video & Audio"
        case .files: "Files"
        case .capture: "Capture"
        case .system: "System"
        case .app: "App Shortcuts"
        case .custom: "Custom"
        }
    }
}

public struct ActionInfo: Identifiable, Hashable, Sendable {
    public let id: String
    /// Kept short: it has to fit inside a ring slice.
    public let title: String
    public let symbol: String
    /// Which ring the action needs: text actions need a selection, file actions
    /// need files, and general ones work anywhere.
    public let ring: RingKind
    public let category: ActionCategory
    /// Shown in settings under the title.
    public let detail: String
    /// Sent to the frontmost app, for app shortcut actions.
    public let keys: KeyCombo?
    /// Opened in the browser, for app actions that are just a page.
    public let link: URL?
    /// Typed into the front app and run with Return, like a terminal command.
    public let command: String?

    init(_ id: String, _ title: String, _ symbol: String, _ ring: RingKind, _ category: ActionCategory, _ detail: String,
         keys: KeyCombo? = nil, link: String? = nil, command: String? = nil) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.ring = ring
        self.category = category
        self.detail = detail
        self.keys = keys
        self.link = link.flatMap(URL.init(string:))
        self.command = command
    }

    /// Opens a sub-ring of further choices instead of running.
    public var isFolder: Bool { ActionCatalog.folders.contains(id) }
}

/// A keyboard shortcut Halo can press in the frontmost app.
public struct KeyCombo: Codable, Hashable, Sendable {
    public var keyCode: Int
    public var modifiers: Modifiers

    public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let command = Modifiers(rawValue: 1)
        public static let shift = Modifiers(rawValue: 2)
        public static let option = Modifiers(rawValue: 4)
        public static let control = Modifiers(rawValue: 8)
    }

    public init(_ keyCode: Int, _ modifiers: Modifiers = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Mac order: ⌃⌥⇧⌘ then the key.
    public var display: String {
        var out = ""
        if modifiers.contains(.control) { out += "⌃" }
        if modifiers.contains(.option) { out += "⌥" }
        if modifiers.contains(.shift) { out += "⇧" }
        if modifiers.contains(.command) { out += "⌘" }
        return out + Self.keyName(keyCode)
    }

    static let names: [Int: String] = {
        var names: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
            kVK_ANSI_Grave: "`", kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=", kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]",
            kVK_ANSI_Backslash: "\\", kVK_ANSI_Semicolon: ";", kVK_ANSI_Quote: "'", kVK_ANSI_Comma: ",", kVK_ANSI_Period: ".", kVK_ANSI_Slash: "/",
        ]
        let letters: [(Int, String)] = [
            (kVK_ANSI_A, "A"), (kVK_ANSI_B, "B"), (kVK_ANSI_C, "C"), (kVK_ANSI_D, "D"), (kVK_ANSI_E, "E"), (kVK_ANSI_F, "F"),
            (kVK_ANSI_G, "G"), (kVK_ANSI_H, "H"), (kVK_ANSI_I, "I"), (kVK_ANSI_J, "J"), (kVK_ANSI_K, "K"), (kVK_ANSI_L, "L"),
            (kVK_ANSI_M, "M"), (kVK_ANSI_N, "N"), (kVK_ANSI_O, "O"), (kVK_ANSI_P, "P"), (kVK_ANSI_Q, "Q"), (kVK_ANSI_R, "R"),
            (kVK_ANSI_S, "S"), (kVK_ANSI_T, "T"), (kVK_ANSI_U, "U"), (kVK_ANSI_V, "V"), (kVK_ANSI_W, "W"), (kVK_ANSI_X, "X"),
            (kVK_ANSI_Y, "Y"), (kVK_ANSI_Z, "Z"), (kVK_ANSI_0, "0"), (kVK_ANSI_1, "1"), (kVK_ANSI_2, "2"), (kVK_ANSI_3, "3"),
            (kVK_ANSI_4, "4"), (kVK_ANSI_5, "5"), (kVK_ANSI_6, "6"), (kVK_ANSI_7, "7"), (kVK_ANSI_8, "8"), (kVK_ANSI_9, "9"),
            (kVK_F1, "F1"), (kVK_F2, "F2"), (kVK_F3, "F3"), (kVK_F4, "F4"), (kVK_F5, "F5"), (kVK_F6, "F6"),
            (kVK_F7, "F7"), (kVK_F8, "F8"), (kVK_F9, "F9"), (kVK_F10, "F10"), (kVK_F11, "F11"), (kVK_F12, "F12"),
        ]
        for (code, name) in letters { names[code] = name }
        return names
    }()

    public static func keyName(_ code: Int) -> String {
        names[code] ?? "Key \(code)"
    }
}

/// An action the user made: a Claude instruction, a shortcut to press, a link,
/// a macOS Shortcut, a shell command or an app to open.
public struct CustomAction: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: Codable, Hashable, Sendable {
        case prompt(String)
        case keys(KeyCombo)
        case url(String)
        case shortcut(String)
        case shell(String)
        case openApp(String)

        public var title: String {
            switch self {
            case .prompt: "Claude Prompt"
            case .keys: "Keyboard Shortcut"
            case .url: "Open Link"
            case .shortcut: "Run Shortcut"
            case .shell: "Shell Command"
            case .openApp: "Open App"
            }
        }
    }

    public var id: UUID
    public var title: String
    public var symbol: String
    public var kind: Kind

    public init(id: UUID = UUID(), title: String, symbol: String = "sparkles", kind: Kind) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.kind = kind
    }

    public var actionID: String { "custom.\(id.uuidString)" }

    /// Prompts rewrite a selection; everything else works anywhere.
    public var ring: RingKind {
        if case .prompt = kind { .text } else { .general }
    }

    public var info: ActionInfo {
        let detail = switch kind {
        case let .prompt(text): text
        case let .keys(combo): "Presses \(combo.display)"
        case let .url(url): url
        case let .shortcut(name): "Runs “\(name)”"
        case let .shell(command): command
        case let .openApp(path): URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        }
        let keys: KeyCombo? = if case let .keys(combo) = kind { combo } else { nil }
        return ActionInfo(actionID, title, symbol, ring, .custom, detail, keys: keys)
    }
}
