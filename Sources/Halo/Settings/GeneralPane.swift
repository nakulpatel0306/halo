import HaloKit
import SwiftUI

struct GeneralPane: View {
    @ObservedObject var model: AppModel

    private var behavior: Binding<Behavior> { $model.settings.behavior }

    var body: some View {
        PaneScroll(pane: .general) {
            Card(title: "Shortcut") {
                Row(symbol: "keyboard", title: "Open the ring", detail: "Hold it, move toward an action and let go. Or tap it and click.") {
                    Picker("", selection: $model.settings.shortcut) {
                        ForEach(Shortcut.allCases) { Text($0.display).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                }
                if model.shortcutFailed {
                    Label("Another app is using this shortcut. Pick a different one.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.callout)
                        .padding(.vertical, 6)
                }
                Divided()
                ToggleRow(symbol: "power", tint: .green, title: "Open at login",
                          isOn: Binding(get: { model.launchAtLogin }, set: { model.launchAtLogin = $0 }))
            }

            Card(title: "Feel") {
                SliderRow(symbol: "hand.tap.fill", tint: .orange, title: "Tap or hold",
                          detail: "Let go sooner than this and the ring stays open for a click.",
                          value: behavior.tapThreshold, range: 0.15...0.6, step: 0.01) { "\(Int($0 * 1000)) ms" }
                Divided()
                SliderRow(symbol: "circle.dotted", tint: .purple, title: "Center dead zone",
                          detail: "Letting go in the middle cancels. Bigger is more forgiving.",
                          value: behavior.deadZone, range: 0.1...0.4, step: 0.01) { "\(Int($0 * 100))%" }
                Divided()
                ToggleRow(symbol: "waveform.path", tint: .blue, title: "Haptic ticks",
                          detail: "A trackpad tick as you move between slices.", isOn: behavior.haptics)
            }

            Card(title: "Smarts") {
                ToggleRow(symbol: "square.grid.2x2.fill", tint: .cyan, title: "App rings",
                          detail: "Switch to an app's own ring, like VS Code or GitHub, when nothing is selected.",
                          isOn: behavior.appRings)
                Divided()
                ToggleRow(symbol: "doc.on.clipboard", tint: .teal, title: "Read selections by copying",
                          detail: "Browsers and Electron apps hide selected text. Halo can press ⌘C to find it, then put your clipboard back.",
                          isOn: behavior.copyToReadSelection)
                Divided()
                SliderRow(symbol: "text.bubble.fill", tint: .green, title: "Message time",
                          detail: "How long results like “Saved photo.jpg” stay on screen.",
                          value: behavior.hudDuration, range: 0.8...5, step: 0.1) { String(format: "%.1f s", $0) }
            }

            Card(title: "How it works") {
                HowRow(symbol: "text.cursor", title: "Highlight text", detail: "Rewrite with Claude, translate, or run quick text tools.")
                Divided()
                HowRow(symbol: "folder", title: "Select files in Finder", detail: "Convert, compress, resize and more. Only what fits appears.")
                Divided()
                HowRow(symbol: "square.grid.2x2", title: "In your apps", detail: "VS Code, GitHub, Xcode and others get rings of their own shortcuts.")
            }
        }
    }
}

private struct HowRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        Row(symbol: symbol, title: title, detail: detail) { EmptyView() }
    }
}
