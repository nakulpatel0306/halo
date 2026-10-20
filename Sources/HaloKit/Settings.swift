import Foundation

public enum RingKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case text, files, general
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .text: "Text"
        case .files: "Files"
        case .general: "Everywhere"
        }
    }

    public var subtitle: String {
        switch self {
        case .text: "When text is highlighted"
        case .files: "When files are selected in Finder"
        case .general: "When nothing is selected"
        }
    }
}

public enum Accent: String, Codable, CaseIterable, Identifiable, Sendable {
    case blue, purple, pink, red, orange, yellow, green, graphite
    public var id: String { rawValue }
}

public enum RingStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case glass, solid
    public var id: String { rawValue }
    public var title: String { self == .glass ? "Glass" : "Solid" }
}

public enum RingTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case system, light, dark
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public struct Appearance: Codable, Hashable, Sendable {
    public var accent: Accent = .blue
    public var style: RingStyle = .glass
    public var theme: RingTheme = .system
    public var diameter: Double = 300
    public var showLabels: Bool = true
    /// Multiplies label and icon size.
    public var labelScale: Double = 1
    /// Icons tinted by category instead of all one colour.
    public var colorfulIcons: Bool = true
    /// The file name or word count in the middle of the ring.
    public var showCaption: Bool = true
    /// How opaque the solid style and the glass tint are.
    public var opacity: Double = 1
    /// 0 is instant, 1 is relaxed.
    public var motion: Double = 0.5

    public init() {}
}

public struct Behavior: Codable, Hashable, Sendable {
    /// Releasing sooner than this counts as a tap, which keeps the ring open.
    public var tapThreshold: Double = 0.28
    public var haptics: Bool = true
    /// Fraction of the ring's radius in the middle where nothing is selected.
    public var deadZone: Double = 0.2
    /// Seconds a success message stays up.
    public var hudDuration: Double = 1.6
    /// Browsers and Electron apps don't expose selected text, so Halo can press
    /// ⌘C to find out. Off means those apps only get the Everywhere ring.
    public var copyToReadSelection: Bool = true
    /// Per-app rings from `profiles`.
    public var appRings: Bool = true

    public init() {}
}

public enum OutputLocation: String, Codable, CaseIterable, Identifiable, Sendable {
    case nextToOriginal, subfolder, downloads
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .nextToOriginal: "Next to original"
        case .subfolder: "“Converted” folder"
        case .downloads: "Downloads"
        }
    }
}

public enum VideoQuality: String, Codable, CaseIterable, Identifiable, Sendable {
    case original, p1080, p720, small
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .original: "Original"
        case .p1080: "1080p"
        case .p720: "720p"
        case .small: "Small"
        }
    }
}

/// How file actions write their results, like Filee's presets.
public struct FileOptions: Codable, Hashable, Sendable {
    /// 0...1 for JPG, HEIC, AVIF and other lossy formats.
    public var imageQuality: Double = 0.85
    /// Longest side for the Resize action, in pixels.
    public var resizeLongestSide: Double = 1600
    /// Drop camera, location and date details from converted images.
    public var stripMetadata: Bool = false
    public var output: OutputLocation = .nextToOriginal
    /// Select the result in Finder when an action finishes.
    public var revealResult: Bool = false
    public var videoQuality: VideoQuality = .original
    public var gifFPS: Double = 12
    public var gifWidth: Double = 480
    /// Longest GIF, in seconds.
    public var gifMaxSeconds: Double = 15

    public init() {}
}

public enum Shortcut: String, Codable, CaseIterable, Identifiable, Sendable {
    case optionSpace, controlOptionSpace, commandShiftSpace, optionBacktick
    public var id: String { rawValue }

    public var display: String {
        switch self {
        case .optionSpace: "⌥ Space"
        case .controlOptionSpace: "⌃⌥ Space"
        case .commandShiftSpace: "⇧⌘ Space"
        case .optionBacktick: "⌥ `"
        }
    }
}

public enum AIProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case claudeCode, anthropicAPI
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .claudeCode: "Claude Subscription"
        case .anthropicAPI: "API Key"
        }
    }
}

public enum ClaudeModel: String, Codable, CaseIterable, Identifiable, Sendable {
    case opus = "claude-opus-5-5"
    case sonnet = "claude-sonnet-5-5"
    case haiku = "claude-haiku-5-5"
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .opus: "Opus 5.5"
        case .sonnet: "Sonnet 5.5"
        case .haiku: "Haiku 5.5"
        }
    }

    public var detail: String {
        switch self {
        case .opus: "Best writing"
        case .sonnet: "Balanced"
        case .haiku: "Fastest"
        }
    }

    /// The alias the `claude` CLI accepts for `--model`.
    public var cliAlias: String {
        switch self {
        case .opus: "opus"
        case .sonnet: "sonnet"
        case .haiku: "haiku"
        }
    }
}

public struct AISettings: Codable, Hashable, Sendable {
    public var provider: AIProvider = .claudeCode
    // Sonnet keeps quick actions fast and goes easy on subscription usage limits.
    public var model: ClaudeModel = .sonnet
    /// Free-form notes about how the user writes, added to every rewrite.
    public var voice: String = ""
    public var translateTo: String = "English"

    public init() {}
}

/// A ring that replaces the Everywhere ring while a given app is in front, like
/// Logitech's per-app Actions Ring.
public struct RingProfile: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var symbol: String
    /// Bundle identifiers of the apps it applies to.
    public var apps: [String]
    public var enabled: Bool
    public var ring: [String]

    public init(id: String = UUID().uuidString, name: String, symbol: String, apps: [String] = [], enabled: Bool = true, ring: [String]) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.apps = apps
        self.enabled = enabled
        self.ring = ring
    }
}

/// Which ring is being shown or edited.
public enum RingTarget: Hashable, Sendable {
    case kind(RingKind)
    case profile(String)
}

public struct HaloSettings: Codable, Hashable, Sendable {
    /// Beyond this the slices get too thin to aim at.
    public static let maxSlots = 10

    public var shortcut: Shortcut = .optionSpace
    public var appearance = Appearance()
    public var behavior = Behavior()
    public var files = FileOptions()
    public var ai = AISettings()
    public var textRing: [String] = ActionCatalog.defaultRing(.text)
    public var fileRing: [String] = ActionCatalog.defaultRing(.files)
    public var generalRing: [String] = ActionCatalog.defaultRing(.general)
    public var profiles: [RingProfile] = ProfilePresets.defaults
    public var customActions: [CustomAction] = []

    public init() {}

    public func ring(_ target: RingTarget) -> [String] {
        switch target {
        case .kind(.text): textRing
        case .kind(.files): fileRing
        case .kind(.general): generalRing
        case let .profile(id): profiles.first { $0.id == id }?.ring ?? []
        }
    }

    public mutating func setRing(_ ids: [String], for target: RingTarget) {
        let ids = Array(ids.prefix(Self.maxSlots))
        switch target {
        case .kind(.text): textRing = ids
        case .kind(.files): fileRing = ids
        case .kind(.general): generalRing = ids
        case let .profile(id):
            if let index = profiles.firstIndex(where: { $0.id == id }) { profiles[index].ring = ids }
        }
    }

    /// Every action, built-in and custom.
    public var allActions: [ActionInfo] {
        ActionCatalog.all + customActions.map(\.info)
    }

    public func info(_ id: String) -> ActionInfo? {
        ActionCatalog.info(id) ?? customActions.first { $0.actionID == id }?.info
    }

    /// Actions that can go in a ring: its own kind plus anything that works everywhere.
    public func library(for target: RingTarget) -> [ActionInfo] {
        let kind: RingKind = if case let .kind(kind) = target { kind } else { .general }
        return allActions.filter { $0.ring == kind || $0.ring == .general }
    }

    /// The enabled profile for the app in front.
    public func profile(app: String?) -> RingProfile? {
        guard behavior.appRings, let app else { return nil }
        return profiles.first { $0.enabled && $0.apps.contains(app) }
    }

    /// Drops actions that no longer exist, e.g. a deleted custom action.
    public mutating func reconcile() {
        let known = Set(allActions.map(\.id))
        textRing.removeAll { !known.contains($0) }
        fileRing.removeAll { !known.contains($0) }
        generalRing.removeAll { !known.contains($0) }
        for i in profiles.indices { profiles[i].ring.removeAll { !known.contains($0) } }
    }
}

/// Persists settings as JSON in UserDefaults.
public struct SettingsStore {
    let key = "settings.v2"
    let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Saved values are laid over fresh defaults, so settings saved by an older
    /// version pick up new options instead of failing to load.
    public func load() -> HaloSettings {
        guard let data = defaults.data(forKey: key),
              let saved = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fresh = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(HaloSettings())) as? [String: Any],
              let merged = try? JSONSerialization.data(withJSONObject: Self.merge(saved, over: fresh)),
              var settings = try? JSONDecoder().decode(HaloSettings.self, from: merged)
        else { return HaloSettings() }
        settings.reconcile()
        return settings
    }

    static func merge(_ saved: [String: Any], over base: [String: Any]) -> [String: Any] {
        var out = base
        for (key, value) in saved {
            if let nested = value as? [String: Any], let baseNested = base[key] as? [String: Any] {
                out[key] = merge(nested, over: baseNested)
            } else {
                out[key] = value
            }
        }
        return out
    }

    public func save(_ settings: HaloSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: key)
        }
    }
}
