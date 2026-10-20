import AppKit
import Combine
import HaloKit
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: HaloSettings {
        didSet {
            store.save(settings)
            if settings.shortcut != oldValue.shortcut { registerShortcut() }
        }
    }

    /// Set while Keep Awake holds the Mac awake.
    @Published var keepingAwake = false

    private let store = SettingsStore()
    private var hotKey: HotKey?
    private(set) var shortcutFailed = false
    lazy var ring = RingController(model: self)
    lazy var runner = ActionRunner(model: self)
    lazy var settingsWindow = SettingsWindowController(model: self)

    init() {
        settings = store.load()
        registerShortcut()
    }

    func registerShortcut() {
        hotKey = nil
        hotKey = HotKey(settings.shortcut)
        shortcutFailed = hotKey == nil
        hotKey?.onPress = { [weak self] in self?.ring.press() }
        hotKey?.onRelease = { [weak self] in self?.ring.release() }
    }

    /// The ring for what's selected; with nothing selected, the front app's
    /// own ring if it has one.
    func target(for context: RingContext, profile: RingProfile?) -> RingTarget {
        if case .none = context, let profile { return .profile(profile.id) }
        return .kind(context.ring)
    }

    /// The ring's actions in the user's order, minus any that don't fit the selection.
    func items(for context: RingContext, target: RingTarget) -> [RingItem] {
        settings.ring(target).compactMap(settings.info).filter { ActionCatalog.applies($0.id, to: context) }.map(RingItem.init)
    }

    func children(of id: String, context: RingContext) -> [RingItem] {
        ActionCatalog.children(of: id, context: context).prefix(HaloSettings.maxSlots).map(RingItem.init)
    }

    // MARK: Custom actions

    func save(_ action: CustomAction) {
        if let index = settings.customActions.firstIndex(where: { $0.id == action.id }) {
            settings.customActions[index] = action
        } else {
            settings.customActions.append(action)
        }
    }

    func delete(_ action: CustomAction) {
        settings.customActions.removeAll { $0.id == action.id }
        settings.reconcile()
    }

    // MARK: Profiles

    func addProfile(forApp url: URL) -> RingProfile? {
        guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return nil }
        if let existing = settings.profiles.first(where: { $0.apps.contains(id) }) { return existing }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        let profile = RingProfile(name: name, symbol: "app.fill", apps: [id], ring: settings.generalRing)
        settings.profiles.append(profile)
        return profile
    }

    /// Puts back any built-in presets that were deleted.
    func restorePresets() {
        let missing = ProfilePresets.all.filter { preset in !settings.profiles.contains { $0.id == preset.id } }
        settings.profiles.append(contentsOf: missing)
    }

    func resetRing(_ target: RingTarget) {
        switch target {
        case let .kind(kind): settings.setRing(ActionCatalog.defaultRing(kind), for: target)
        case let .profile(id):
            if let preset = ProfilePresets.all.first(where: { $0.id == id }) { settings.setRing(preset.ring, for: target) }
        }
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            if newValue { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
        }
    }

    func openSettings(_ pane: SettingsPane? = nil, editing target: RingTarget? = nil) {
        settingsWindow.show(pane, editing: target)
    }
}
