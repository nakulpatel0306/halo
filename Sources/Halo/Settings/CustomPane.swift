import AppKit
import HaloKit
import SwiftUI
import UniformTypeIdentifiers

/// The user's own actions. Once made, they show up in the Ring Editor library.
struct CustomPane: View {
    @ObservedObject var model: AppModel
    @State private var editing: CustomAction?

    var body: some View {
        PaneScroll(pane: .custom) {
            Card(title: "New", footer: "New actions appear in the Ring Editor library under Custom. Drag them onto any ring.") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                    ForEach(Template.all) { template in
                        Button {
                            editing = template.make()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: template.symbol)
                                    .foregroundStyle(template.tint)
                                    .frame(width: 26, height: 26)
                                    .background(template.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(template.title).font(.system(size: 12.5, weight: .semibold))
                                    Text(template.detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(8)
                            .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }

            if !model.settings.customActions.isEmpty {
                Card(title: "Yours") {
                    ForEach(Array(model.settings.customActions.enumerated()), id: \.element.id) { index, action in
                        if index > 0 { Divided() }
                        Row(symbol: action.symbol, tint: ActionCategory.custom.color, title: action.title,
                            detail: "\(action.kind.title) · \(action.info.detail)") {
                            Button("Edit") { editing = action }
                                .controlSize(.small)
                        }
                    }
                }
            }
        }
        .sheet(item: $editing) { action in
            CustomEditor(action: action, isNew: !model.settings.customActions.contains { $0.id == action.id }) {
                model.save($0)
            } onDelete: {
                model.delete(action)
            }
        }
    }
}

private struct Template: Identifiable {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let kind: CustomAction.Kind

    var id: String { title }

    func make() -> CustomAction {
        CustomAction(title: "", symbol: symbol, kind: kind)
    }

    static let all = [
        Template(title: "Claude Prompt", detail: "Your own rewrite", symbol: "sparkles", tint: ActionCategory.ai.color, kind: .prompt("")),
        Template(title: "Keyboard Shortcut", detail: "Press keys in any app", symbol: "command", tint: .cyan, kind: .keys(KeyCombo(0, .command))),
        Template(title: "Open Link", detail: "A website or deep link", symbol: "link", tint: .blue, kind: .url("")),
        Template(title: "Run Shortcut", detail: "From the Shortcuts app", symbol: "square.2.layers.3d.fill", tint: .pink, kind: .shortcut("")),
        Template(title: "Shell Command", detail: "Gets $HALO_TEXT/FILES", symbol: "terminal.fill", tint: .gray, kind: .shell("")),
        Template(title: "Open App", detail: "Launch or switch to it", symbol: "app.fill", tint: .orange, kind: .openApp("")),
    ]
}

private struct CustomEditor: View {
    @State var action: CustomAction
    let isNew: Bool
    let onSave: (CustomAction) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var shortcuts: [String] = []

    private let symbols = [
        "sparkles", "wand.and.stars", "globe", "envelope.fill", "bubble.left.fill", "hand.thumbsup.fill", "graduationcap.fill",
        "lightbulb.fill", "pencil", "quote.bubble.fill", "heart.fill", "bolt.fill", "star.fill", "flag.fill", "bookmark.fill",
        "command", "link", "terminal.fill", "app.fill", "folder.fill", "music.note", "camera.fill", "cart.fill", "calendar",
        "clock.fill", "map.fill", "house.fill", "gamecontroller.fill", "cup.and.saucer.fill", "paperplane.fill",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isNew ? "New \(action.kind.title)" : "Edit \(action.kind.title)")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            TextField("Name (short, it goes in a slice)", text: $action.title)
                .textFieldStyle(.roundedBorder)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 6), count: 15), spacing: 6) {
                ForEach(symbols, id: \.self) { symbol in
                    Image(systemName: symbol)
                        .frame(width: 30, height: 30)
                        .foregroundStyle(action.symbol == symbol ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                        .background(action.symbol == symbol ? AnyShapeStyle(Color.accentColor.gradient) : AnyShapeStyle(.primary.opacity(0.05)),
                                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .contentShape(Rectangle())
                        .onTapGesture { action.symbol = symbol }
                }
            }

            kindEditor

            HStack {
                if !isNew {
                    Button("Delete", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isNew ? "Add" : "Save") {
                    onSave(action)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(22)
        .frame(width: 560)
    }

    @ViewBuilder private var kindEditor: some View {
        switch action.kind {
        case let .prompt(text):
            VStack(alignment: .leading, spacing: 6) {
                Text("Instruction for Claude").font(.callout.weight(.semibold))
                TextEditor(text: Binding(get: { text }, set: { action.kind = .prompt($0) }))
                    .font(.body)
                    .frame(minHeight: 90)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text("E.g. “Translate to Spanish” or “Reply politely declining”. Runs on highlighted text.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case let .keys(combo):
            HStack {
                Text("Shortcut").font(.callout.weight(.semibold))
                KeyRecorder(combo: Binding(get: { combo }, set: { action.kind = .keys($0) }))
            }
        case let .url(url):
            TextField("https://…", text: Binding(get: { url }, set: { action.kind = .url($0) }))
                .textFieldStyle(.roundedBorder)
        case let .shortcut(name):
            HStack {
                Picker("Shortcut", selection: Binding(get: { name }, set: { action.kind = .shortcut($0) })) {
                    Text("Choose…").tag("")
                    ForEach(shortcuts, id: \.self) { Text($0).tag($0) }
                }
            }
            .task { shortcuts = await Self.loadShortcuts() }
        case let .shell(command):
            VStack(alignment: .leading, spacing: 6) {
                TextField("open -a Ghostty ~/dev-workspace", text: Binding(get: { command }, set: { action.kind = .shell($0) }))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Text("Runs in zsh. The selection is in $HALO_TEXT, or $HALO_FILES (one path per line). The first line of output shows in the message.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case let .openApp(path):
            HStack {
                Text(path.isEmpty ? "No app chosen" : URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)
                    .foregroundStyle(path.isEmpty ? .secondary : .primary)
                Spacer()
                Button("Choose App…") { chooseApp() }
            }
        }
    }

    private var isValid: Bool {
        guard !action.title.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        switch action.kind {
        case let .prompt(text), let .url(text), let .shortcut(text), let .shell(text), let .openApp(text):
            return !text.trimmingCharacters(in: .whitespaces).isEmpty
        case let .keys(combo):
            return combo.keyCode != 0 || !combo.modifiers.isEmpty
        }
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        action.kind = .openApp(url.path)
        if action.title.isEmpty { action.title = url.deletingPathExtension().lastPathComponent }
    }

    static func loadShortcuts() async -> [String] {
        let result = try? await Shell.run("/usr/bin/shortcuts", ["list"])
        return result?.stdout.split(separator: "\n").map(String.init).sorted() ?? []
    }
}

/// Click, then press the shortcut to record it.
private struct KeyRecorder: View {
    @Binding var combo: KeyCombo
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            Text(recording ? "Press a shortcut…" : combo.display)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .frame(minWidth: 140)
        }
        .buttonStyle(.bordered)
        .tint(recording ? .accentColor : nil)
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags
            var modifiers: KeyCombo.Modifiers = []
            if flags.contains(.command) { modifiers.insert(.command) }
            if flags.contains(.shift) { modifiers.insert(.shift) }
            if flags.contains(.option) { modifiers.insert(.option) }
            if flags.contains(.control) { modifiers.insert(.control) }
            combo = KeyCombo(Int(event.keyCode), modifiers)
            stop()
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
