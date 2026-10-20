import AppKit
import Carbon.HIToolbox
import HaloKit
import SwiftUI

@MainActor
final class RingState: ObservableObject {
    @Published var items: [RingItem] = []
    @Published var hovered: Int?
    @Published var caption = ""
    @Published var visible = false
    /// Showing a folder's sub-ring, so the middle goes back instead of closing.
    @Published var inFolder = false
}

/// A borderless panel that never takes focus, so the app underneath keeps its
/// selection and cursor while the ring is up.
final class RingPanel: NSPanel {
    init(size: CGFloat) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isMovable = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Opens the ring at the cursor and turns pointer movement into a choice.
///
/// Hold the shortcut, move toward a slice, release: that runs it. Tap the
/// shortcut instead and the ring stays open for a click. Folders like Convert
/// open a sub-ring in place, which then stays open for a click.
@MainActor
final class RingController {
    private unowned let model: AppModel
    private let state = RingState()
    private var panel: RingPanel?
    private var context: RingContext = .none
    private var center: NSPoint = .zero
    private var geometry = RingGeometry(count: 0, deadZone: 0)
    /// Rings opened from folders, so the middle can step back out.
    private var parents: [(items: [RingItem], caption: String)] = []
    private var pressedAt = Date.distantPast
    private var heldDown = false
    private var loading = false
    private var tracker: Timer?
    private var monitors: [Any] = []
    private var escape: HotKey?
    /// Set by `demo` so the highlighted slice stays put for screenshots.
    private var frozen = false

    init(model: AppModel) {
        self.model = model
    }

    var isOpen: Bool { panel != nil }

    func press() {
        guard !heldDown else { return }
        if isOpen {
            close()
            return
        }
        guard !loading else { return }
        heldDown = true
        loading = true
        pressedAt = Date()
        let mouse = NSEvent.mouseLocation
        let settings = model.settings
        let app = ContextReader.frontApp
        Task {
            let profile = settings.profile(app: app)
            // In an app with its own ring, an unreadable selection means "show
            // the app ring", not "press ⌘C and copy the current line". Browsers
            // are the exception: they never expose a selection any other way.
            let canCopy = profile == nil || ContextReader.frontIsBrowser
            let context = await ContextReader.current(copying: settings.behavior.copyToReadSelection && canCopy)
            loading = false
            show(context, target: model.target(for: context, profile: profile), caption: profile?.name, at: mouse)
        }
    }

    func release() {
        heldDown = false
        guard isOpen, !state.inFolder, Date().timeIntervalSince(pressedAt) >= model.settings.behavior.tapThreshold else { return }
        if let index = state.hovered {
            choose(index)
        } else {
            close()
        }
    }

    func showFromMenu() {
        // The menu is still closing; wait so the ring isn't dismissed with it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
            show(.none, target: .kind(.general), caption: nil, at: NSEvent.mouseLocation)
        }
    }

    /// Opens a ring in the middle of the screen with sample content, for
    /// screenshots and for trying out settings. `folder` opens that sub-ring.
    func demo(_ target: RingTarget, folder: String? = nil) {
        let context: RingContext = switch target {
        case .kind(.text): .text("Hey team, quick update on the launch plan for next week")
        case .kind(.files): .files([URL(fileURLWithPath: "/tmp/IMG_2041.heic")])
        default: .none
        }
        let frame = NSScreen.main?.frame ?? .zero
        show(context, target: target, caption: nil, at: NSPoint(x: frame.midX, y: frame.midY))
        if let folder, let index = state.items.firstIndex(where: { $0.id == folder }) { choose(index) }
        frozen = true
        state.hovered = 0
    }

    private func show(_ context: RingContext, target: RingTarget, caption: String?, at point: NSPoint) {
        let items = model.items(for: context, target: target)
        guard !items.isEmpty else {
            model.runner.hud.show(.failure("No actions for this selection"), at: point)
            return
        }
        self.context = context
        parents = []
        state.inFolder = false
        state.caption = caption ?? Self.caption(for: context)
        state.visible = false
        center = point
        layout(items)

        let appearance = model.settings.appearance
        withAnimation(appearance.spring) { state.visible = true }
        startTracking()
    }

    /// Sizes the panel so every label fits, and keeps the whole ring on screen.
    private func layout(_ items: [RingItem]) {
        let appearance = model.settings.appearance
        let size = RingGeometry.fittingDiameter(count: items.count, preferred: appearance.diameter, labelScale: appearance.labelScale)
        geometry = RingGeometry(count: items.count, deadZone: size / 2 * model.settings.behavior.deadZone)
        state.items = items
        state.hovered = nil

        if panel == nil {
            let panel = RingPanel(size: size)
            let view = RingView(state: state, appearance: appearance)
                .colorScheme(appearance.theme.colorScheme)
            panel.contentView = NSHostingView(rootView: view)
            panel.orderFrontRegardless()
            self.panel = panel
        }
        center = clamped(center, size: size)
        panel?.setFrame(NSRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size), display: true)
    }

    private func clamped(_ point: NSPoint, size: CGFloat) -> NSPoint {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main else { return point }
        let f = screen.visibleFrame.insetBy(dx: size / 2, dy: size / 2)
        return NSPoint(x: min(max(point.x, f.minX), f.maxX), y: min(max(point.y, f.minY), f.maxY))
    }

    private static func caption(for context: RingContext) -> String {
        switch context {
        case let .text(text): "\(text.split(whereSeparator: \.isWhitespace).count) words"
        case let .files(files): files.count == 1 ? files[0].lastPathComponent : "\(files.count) files"
        case .none: "Halo"
        }
    }

    private func startTracking() {
        tracker = Timer.scheduledTimer(withTimeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.track() }
        }
        RunLoop.main.add(tracker!, forMode: .common)

        monitors.append(NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            if let index = state.hovered {
                choose(index)
            } else if !parents.isEmpty {
                back()
            } else {
                close()
            }
            return nil
        } as Any)
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        } as Any)

        escape = HotKey(keyCode: kVK_Escape, modifiers: 0)
        escape?.onPress = { [weak self] in
            guard let self else { return }
            if parents.isEmpty { close() } else { back() }
        }
    }

    private func track() {
        guard !frozen else { return }
        let mouse = NSEvent.mouseLocation
        let index = geometry.slice(dx: mouse.x - center.x, dy: mouse.y - center.y)
        if index != state.hovered {
            withAnimation(.easeOut(duration: 0.1)) { state.hovered = index }
            if index != nil, model.settings.behavior.haptics {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
        }
    }

    private func choose(_ index: Int) {
        let item = state.items[index]
        if item.isFolder {
            open(item)
            return
        }
        let context = context
        let point = center
        close()
        model.runner.run(item.id, context: context, at: point)
    }

    private func open(_ folder: RingItem) {
        let children = model.children(of: folder.id, context: context)
        guard !children.isEmpty else {
            model.runner.hud.show(.failure("Nothing in \(folder.title) fits this selection"), at: center)
            return
        }
        parents.append((state.items, state.caption))
        state.caption = folder.title
        state.inFolder = true
        withAnimation(model.settings.appearance.spring) { layout(children) }
    }

    private func back() {
        guard let parent = parents.popLast() else { return }
        state.caption = parent.caption
        state.inFolder = !parents.isEmpty
        withAnimation(model.settings.appearance.spring) { layout(parent.items) }
    }

    func close() {
        tracker?.invalidate()
        tracker = nil
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        escape = nil
        panel?.orderOut(nil)
        panel = nil
        parents = []
        frozen = false
        state.visible = false
        state.inFolder = false
    }
}
