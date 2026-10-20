import AppKit
import HaloKit
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case guide, general, rings, apps, files, appearance, ai, custom, permissions
    var id: String { rawValue }

    var title: String {
        switch self {
        case .guide: "Guide"
        case .general: "General"
        case .rings: "Ring Editor"
        case .apps: "App Rings"
        case .files: "Files"
        case .appearance: "Appearance"
        case .ai: "Claude"
        case .custom: "Custom Actions"
        case .permissions: "Permissions"
        }
    }

    var subtitle: String {
        switch self {
        case .guide: "Setup, tips and fixes, all in one place"
        case .general: "Shortcut, feel and timing"
        case .rings: "Drag tools in and out of each ring"
        case .apps: "A different ring for each app, like VS Code or GitHub"
        case .files: "How conversions are saved, like Filee presets"
        case .appearance: "Color, size, glass and motion"
        case .ai: "Rewrite, explain and summarize with your Claude plan"
        case .custom: "Your own prompts, shortcuts, links and scripts"
        case .permissions: "What Halo needs from macOS"
        }
    }

    var symbol: String {
        switch self {
        case .guide: "book.fill"
        case .general: "gearshape.fill"
        case .rings: "circle.dashed.inset.filled"
        case .apps: "square.grid.2x2.fill"
        case .files: "doc.on.doc.fill"
        case .appearance: "paintpalette.fill"
        case .ai: "sparkles"
        case .custom: "wand.and.stars"
        case .permissions: "hand.raised.fill"
        }
    }

    var tint: Color {
        switch self {
        case .guide: .orange
        case .general: .gray
        case .rings: .blue
        case .apps: .cyan
        case .files: .teal
        case .appearance: .pink
        case .ai: ActionCategory.ai.color
        case .custom: .mint
        case .permissions: .indigo
        }
    }
}

@MainActor
final class SettingsWindowController {
    private unowned let model: AppModel
    private var window: NSWindow?
    private let selection = PaneSelection()

    init(model: AppModel) {
        self.model = model
    }

    func show(_ pane: SettingsPane?, editing target: RingTarget? = nil) {
        if let pane { selection.pane = pane }
        if let target {
            selection.pane = .rings
            selection.ring = target
        }
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 700),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.title = "Halo"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: SettingsView(model: model, selection: selection))
            window.setContentSize(NSSize(width: 980, height: 700))
            window.contentMinSize = NSSize(width: 900, height: 600)
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

@MainActor
final class PaneSelection: ObservableObject {
    @Published var pane: SettingsPane = .guide
    /// Which ring the editor shows.
    @Published var ring: RingTarget = .kind(.text)
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var selection: PaneSelection

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(model: model, selection: selection)
                .frame(width: 216)
            Divider()
            Group {
                switch selection.pane {
                case .guide: GuidePane(model: model, selection: selection)
                case .general: GeneralPane(model: model)
                case .rings: RingsPane(model: model, selection: selection)
                case .apps: AppsPane(model: model, selection: selection)
                case .files: FilesPane(model: model)
                case .appearance: AppearancePane(model: model)
                case .ai: AIPane(model: model)
                case .custom: CustomPane(model: model)
                case .permissions: PermissionsPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .ignoresSafeArea()
        .frame(minWidth: 900, minHeight: 600)
        .tint(model.settings.appearance.accent.color)
    }
}

private struct Sidebar: View {
    @ObservedObject var model: AppModel
    @ObservedObject var selection: PaneSelection

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                HaloMark(accent: model.settings.appearance.accent.color)
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Halo").font(.system(size: 17, weight: .bold, design: .rounded))
                    Text("Hold \(model.settings.shortcut.display)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 44)
            .padding(.bottom, 18)

            ForEach(SettingsPane.allCases) { pane in
                SidebarButton(pane: pane, selected: selection.pane == pane) {
                    withAnimation(.snappy(duration: 0.2)) { selection.pane = pane }
                }
            }
            Spacer()
            Button {
                model.ring.showFromMenu()
            } label: {
                Label("Try the ring", systemImage: "circle.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(10)
        }
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.ultraThinMaterial)
        .background(
            LinearGradient(colors: [model.settings.appearance.accent.color.opacity(0.18), .clear],
                           startPoint: .top, endPoint: .center)
        )
    }
}

private struct SidebarButton: View {
    let pane: SettingsPane
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: pane.symbol)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(pane.tint.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(pane.title)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(selected ? AnyShapeStyle(.primary.opacity(0.1)) : AnyShapeStyle(.primary.opacity(hovering ? 0.05 : 0)))
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .onHover { hovering = $0 }
    }
}

/// Halo's logo, the same shape as the app icon and the ring itself: eight
/// slices around a centre disc, the top one lit.
struct HaloMark: View {
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size.width
            let slice = 2 * Double.pi / 8
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    Sector(inner: size * 0.27, outer: size * 0.48, start: Double(i) * slice - slice / 2,
                           end: Double(i) * slice + slice / 2, gap: size * 0.05)
                        .fill(i == 0 ? AnyShapeStyle(accent.gradient) : AnyShapeStyle(.primary.opacity(0.2)))
                        .shadow(color: i == 0 ? accent.opacity(0.6) : .clear, radius: size * 0.06)
                }
                Circle()
                    .strokeBorder(.primary.opacity(0.25), lineWidth: max(1, size * 0.025))
                    .frame(width: size * 0.4, height: size * 0.4)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// A non-interactive ring for settings previews.
struct RingPreview: View {
    let items: [RingItem]
    let appearance: Appearance
    var caption = "Preview"
    var hovered: Int? = 0

    var body: some View {
        let state = RingState()
        state.items = items
        state.hovered = items.isEmpty ? nil : hovered
        state.caption = caption
        state.visible = true
        let size = RingGeometry.fittingDiameter(count: items.count, preferred: appearance.diameter, labelScale: appearance.labelScale)
        return RingView(state: state, appearance: appearance)
            .frame(width: size, height: size)
            .colorScheme(appearance.theme.colorScheme)
            .allowsHitTesting(false)
    }
}

extension View {
    /// Forces a colour scheme, or leaves the system's in place when `nil`.
    @ViewBuilder func colorScheme(_ scheme: ColorScheme?) -> some View {
        if let scheme { environment(\.colorScheme, scheme) } else { self }
    }
}
