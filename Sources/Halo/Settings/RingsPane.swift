import HaloKit
import SwiftUI
import UniformTypeIdentifiers

/// Drag tools from the library onto the ring, swap slots by dragging between
/// them, and drag a slot off the ring to remove it.
struct RingsPane: View {
    @ObservedObject var model: AppModel
    @ObservedObject var selection: PaneSelection

    private var target: RingTarget { selection.ring }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PaneHeader(pane: .rings)
            RingPicker(model: model, selection: selection)
            HStack(alignment: .top, spacing: 22) {
                VStack(spacing: 12) {
                    EditorRing(model: model, target: target)
                        .frame(width: 360, height: 360)
                    footer
                }
                .frame(width: 360)
                Library(model: model, target: target)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 28)
        .padding(.top, 34)
        .padding(.bottom, 20)
    }

    private var footer: some View {
        let count = model.settings.ring(target).count
        return VStack(spacing: 8) {
            HStack {
                Text("\(count) of \(HaloSettings.maxSlots) slots")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Spacer()
                if count > 0 {
                    Button("Clear") { model.settings.setRing([], for: target) }
                        .buttonStyle(.borderless)
                }
                if target.hasDefault {
                    Button("Reset") { withAnimation { model.resetRing(target) } }
                        .buttonStyle(.borderless)
                }
            }
            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var hint: String {
        let base = "Drag a tool onto a slot to replace it, onto + to add it, or drag a slot away to remove it. Drag between slots to swap."
        return switch target {
        case .kind(.files): base + " Only actions that fit the selected files appear, so this ring can hold more than any one file type uses."
        case .kind(.text): base + " Shows when text is highlighted."
        case .kind(.general): base + " Shows when nothing is selected and the app has no ring of its own."
        case .profile: base + " Shows in this app when nothing is selected."
        }
    }
}

extension RingTarget {
    var hasDefault: Bool {
        if case let .profile(id) = self { return ProfilePresets.all.contains { $0.id == id } }
        return true
    }
}

private struct RingPicker: View {
    @ObservedObject var model: AppModel
    @ObservedObject var selection: PaneSelection

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(RingKind.allCases) { kind in
                    chip(.kind(kind), title: kind.title, symbol: symbol(kind))
                }
                Divider().frame(height: 20).padding(.horizontal, 4)
                ForEach(model.settings.profiles.filter(\.enabled)) { profile in
                    chip(.profile(profile.id), title: profile.name, symbol: profile.symbol)
                }
                Button {
                    selection.pane = .apps
                } label: {
                    Label("Apps…", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderless)
                .padding(.leading, 4)
            }
            .padding(.vertical, 2)
        }
    }

    private func symbol(_ kind: RingKind) -> String {
        switch kind {
        case .text: "text.cursor"
        case .files: "folder.fill"
        case .general: "circle.circle"
        }
    }

    private func chip(_ target: RingTarget, title: String, symbol: String) -> some View {
        let on = selection.ring == target
        return Label(title, systemImage: symbol)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .foregroundStyle(on ? AnyShapeStyle(.white) : AnyShapeStyle(.primary.opacity(0.8)))
            .background(on ? AnyShapeStyle(Color.accentColor.gradient) : AnyShapeStyle(.primary.opacity(0.07)), in: Capsule())
            .contentShape(Capsule())
            .onTapGesture { withAnimation(.snappy(duration: 0.2)) { selection.ring = target } }
    }
}

/// What's being dragged, carried as text so it works with plain drag and drop.
enum DragPayload {
    case action(String)
    case slot(Int)

    var string: String {
        switch self {
        case let .action(id): "halo-action:\(id)"
        case let .slot(index): "halo-slot:\(index)"
        }
    }

    init?(_ string: String) {
        if string.hasPrefix("halo-action:") {
            self = .action(String(string.dropFirst("halo-action:".count)))
        } else if string.hasPrefix("halo-slot:"), let index = Int(string.dropFirst("halo-slot:".count)) {
            self = .slot(index)
        } else {
            return nil
        }
    }

    var provider: NSItemProvider { NSItemProvider(object: string as NSString) }

    static func load(from info: DropInfo, _ completion: @escaping @MainActor (DragPayload) -> Void) {
        guard let provider = info.itemProviders(for: [.text]).first else { return }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let string = object as? String, let payload = DragPayload(string) else { return }
            DispatchQueue.main.async { MainActor.assumeIsolated { completion(payload) } }
        }
    }
}

private struct EditorRing: View {
    @ObservedObject var model: AppModel
    let target: RingTarget
    @State private var dropIndex: Int?
    @State private var hovered: Int?

    private let size = 360.0

    private var ids: [String] { model.settings.ring(target) }
    /// Real slots plus an empty "+" slot while there's room.
    private var slotCount: Int { ids.count < HaloSettings.maxSlots ? ids.count + 1 : ids.count }

    var body: some View {
        let appearance = model.settings.appearance
        let outer = size / 2 - RingGeometry.margin
        let inner = outer * RingGeometry.innerRatio
        let slice = 2 * Double.pi / Double(max(slotCount, 1))
        let labelWidth = RingGeometry.labelWidth(count: slotCount, diameter: size)
        let geometry = RingGeometry(count: slotCount, deadZone: inner)

        ZStack {
            Donut(thickness: outer - inner + 4)
                .fill(appearance.backdrop, style: FillStyle(eoFill: true))
                .overlay(Circle().stroke(.primary.opacity(0.12), lineWidth: 0.5))
                .frame(width: outer * 2, height: outer * 2)
                .shadow(color: .black.opacity(0.15), radius: 16, y: 8)

            ForEach(0..<slotCount, id: \.self) { index in
                let sector = Sector(inner: inner + 6, outer: outer - 6, start: Double(index) * slice - slice / 2,
                                    end: Double(index) * slice + slice / 2, gap: 6)
                let lit = dropIndex == index || hovered == index
                sector
                    .fill(lit ? AnyShapeStyle(appearance.accent.color.opacity(dropIndex == index ? 0.9 : 0.25))
                              : AnyShapeStyle(.primary.opacity(index < ids.count ? 0.04 : 0.015)))
                    .overlay {
                        if index >= ids.count {
                            sector.stroke(.primary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }
                    }
            }

            ForEach(0..<slotCount, id: \.self) { index in
                let angle = Double(index) * slice
                let radius = (inner + outer) / 2
                slotLabel(index, appearance: appearance, width: labelWidth)
                    .position(x: size / 2 + radius * sin(angle), y: size / 2 - radius * cos(angle))
            }

            VStack(spacing: 2) {
                Image(systemName: dropIndex == nil ? "hand.draw.fill" : "arrow.down.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                Text(dropIndex == nil ? "Drag tools here" : "Drop to place")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(width: (inner - 6) * 2, height: (inner - 6) * 2)
            .background(appearance.backdrop, in: Circle())
            .overlay(Circle().stroke(.primary.opacity(0.12), lineWidth: 0.5))
        }
        .frame(width: size, height: size)
        .colorScheme(appearance.theme.colorScheme)
        .onDrop(of: [.text], delegate: RingDrop(geometry: geometry, size: size, dropIndex: $dropIndex) { payload, index in
            place(payload, at: index)
        })
        .animation(.snappy(duration: 0.2), value: ids)
    }

    @ViewBuilder private func slotLabel(_ index: Int, appearance: Appearance, width: Double) -> some View {
        if index < ids.count, let info = model.settings.info(ids[index]) {
            SliceLabel(item: RingItem(info), highlighted: dropIndex == index, appearance: appearance, width: width)
                .padding(6)
                .contentShape(Rectangle())
                .onHover { hovered = $0 ? index : (hovered == index ? nil : hovered) }
                .onDrag { DragPayload.slot(index).provider }
                .help(info.detail)
                .contextMenu {
                    Button("Remove from Ring", role: .destructive) { remove(index) }
                }
                .overlay(alignment: .topTrailing) {
                    if hovered == index {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red)
                            .font(.system(size: 14))
                            .onTapGesture { remove(index) }
                    }
                }
        } else {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func remove(_ index: Int) {
        var ids = ids
        guard ids.indices.contains(index) else { return }
        ids.remove(at: index)
        hovered = nil
        model.settings.setRing(ids, for: target)
    }

    /// Dropping a tool on a slot replaces it (or swaps, if it's already on the
    /// ring); on "+" it's added. Dropping a slot on another swaps them.
    private func place(_ payload: DragPayload, at index: Int) {
        var ids = ids
        switch payload {
        case let .action(id):
            if let existing = ids.firstIndex(of: id) {
                if index < ids.count { ids.swapAt(existing, index) } else { ids.append(ids.remove(at: existing)) }
            } else if index < ids.count {
                ids[index] = id
            } else {
                ids.append(id)
            }
        case let .slot(from):
            guard ids.indices.contains(from), from != index else { return }
            if index < ids.count { ids.swapAt(from, index) } else { ids.append(ids.remove(at: from)) }
        }
        model.settings.setRing(ids, for: target)
    }
}

private struct RingDrop: DropDelegate {
    let geometry: RingGeometry
    let size: Double
    @Binding var dropIndex: Int?
    let onDrop: @MainActor (DragPayload, Int) -> Void

    private func index(_ info: DropInfo) -> Int? {
        // Drop locations have y growing downward; the geometry expects up.
        geometry.slice(dx: info.location.x - size / 2, dy: size / 2 - info.location.y)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        dropIndex = index(info)
        return DropProposal(operation: dropIndex == nil ? .forbidden : .move)
    }

    func dropExited(info: DropInfo) {
        dropIndex = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let index = index(info) else { return false }
        dropIndex = nil
        DragPayload.load(from: info) { onDrop($0, index) }
        return true
    }
}

/// Every tool that can go on this ring, searchable and grouped by category.
private struct Library: View {
    @ObservedObject var model: AppModel
    let target: RingTarget
    @State private var query = ""
    @State private var category: ActionCategory?
    @State private var dropping = false

    private var actions: [ActionInfo] {
        model.settings.library(for: target).filter { info in
            (category == nil || info.category == category)
                && (query.isEmpty || info.title.localizedCaseInsensitiveContains(query) || info.detail.localizedCaseInsensitiveContains(query))
        }
    }

    private var categories: [ActionCategory] {
        let present = Set(model.settings.library(for: target).map(\.category))
        return ActionCategory.allCases.filter(present.contains)
    }

    var body: some View {
        let inRing = Set(model.settings.ring(target))
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Library").font(.system(size: 15, weight: .bold, design: .rounded))
                Text("\(actions.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                TextField("Search tools", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    filter(nil, title: "All", color: .accentColor)
                    ForEach(categories) { filter($0, title: $0.title, color: $0.color) }
                }
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                    ForEach(actions) { info in
                        Tile(info: info, inRing: inRing.contains(info.id), colorful: model.settings.appearance.colorfulIcons)
                            .onDrag { DragPayload.action(info.id).provider }
                            .onTapGesture(count: 2) { add(info.id) }
                    }
                }
                .padding(2)
            }
            .overlay {
                if dropping {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.red.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .overlay(Label("Drop to remove", systemImage: "trash").font(.headline).foregroundStyle(.red))
                        .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .onDrop(of: [.text], delegate: LibraryDrop(dropping: $dropping) { payload in
                guard case let .slot(index) = payload else { return }
                var ids = model.settings.ring(target)
                guard ids.indices.contains(index) else { return }
                ids.remove(at: index)
                model.settings.setRing(ids, for: target)
            })
            Text("Double-click a tool to add it to the next free slot.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func add(_ id: String) {
        var ids = model.settings.ring(target)
        guard !ids.contains(id), ids.count < HaloSettings.maxSlots else { return }
        ids.append(id)
        model.settings.setRing(ids, for: target)
    }

    private func filter(_ value: ActionCategory?, title: String, color: Color) -> some View {
        let on = category == value
        return Text(title)
            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(on ? AnyShapeStyle(.white) : AnyShapeStyle(color))
            .background(on ? AnyShapeStyle(color.gradient) : AnyShapeStyle(color.opacity(0.12)), in: Capsule())
            .contentShape(Capsule())
            .onTapGesture { category = value }
    }
}

private struct LibraryDrop: DropDelegate {
    @Binding var dropping: Bool
    let onDrop: @MainActor (DragPayload) -> Void

    func dropEntered(info: DropInfo) { dropping = true }
    func dropExited(info: DropInfo) { dropping = false }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        dropping = false
        DragPayload.load(from: info, onDrop)
        return true
    }
}

private struct Tile: View {
    let info: ActionInfo
    let inRing: Bool
    let colorful: Bool
    @State private var hovering = false

    var body: some View {
        let tint = colorful ? info.category.color : .accentColor
        VStack(spacing: 6) {
            Image(systemName: info.symbol)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(info.title)
                .font(.system(size: 11, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 28, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .padding(.horizontal, 4)
        .background(.background.opacity(hovering ? 0.95 : 0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.primary.opacity(hovering ? 0.15 : 0.07)))
        .overlay(alignment: .topTrailing) {
            if inRing {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 13))
                    .padding(5)
            }
        }
        .opacity(inRing ? 0.6 : 1)
        .onHover { hovering = $0 }
        .help(info.detail)
    }
}
