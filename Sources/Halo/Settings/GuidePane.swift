import HaloKit
import SwiftUI

/// How to set up and use Halo, inside the app so it's always one click away.
struct GuidePane: View {
    @ObservedObject var model: AppModel
    @ObservedObject var selection: PaneSelection
    @State private var accessibility = Permissions.accessibility
    @State private var claudeLoggedIn: Bool?
    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        PaneScroll(pane: .guide) {
            Card(title: "Setup", footer: "After every rebuild of Halo, macOS forgets Accessibility. Turn Halo off and on again there.") {
                Step(done: claudeLoggedIn, title: "Sign in to Claude Code",
                     detail: "Claude actions run on your Claude plan. Run `claude` in a terminal once and log in.") {
                    Button("Check Again") { checkClaude() }
                }
                Divided()
                Step(done: accessibility, title: "Allow Accessibility",
                     detail: "Lets Halo read highlighted text, paste results and press app shortcuts.") {
                    if !accessibility {
                        Button("Open Settings") {
                            Permissions.requestAccessibility()
                            Permissions.openAccessibilitySettings()
                        }
                    }
                }
                Divided()
                Step(done: nil, title: "Allow Finder",
                     detail: "Select a file in Finder and open the ring. When macOS asks if Halo can control Finder, click OK.") {
                    Button("Automation Settings") { Permissions.openAutomationSettings() }
                }
                Divided()
                Step(done: model.launchAtLogin, title: "Open at login",
                     detail: "So the ring is always there.") {
                    Toggle("", isOn: Binding(get: { model.launchAtLogin }, set: { model.launchAtLogin = $0 }))
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }

            Card(title: "Using the ring") {
                Tip(symbol: "hand.point.up.left.fill", title: "Hold, move, release",
                    detail: "Hold \(model.settings.shortcut.display), move toward an action and let go. Let go in the middle to cancel.")
                Divided()
                Tip(symbol: "cursorarrow.click.2", title: "Or tap, then click",
                    detail: "A quick tap keeps the ring open. Click an action; Esc closes.")
                Divided()
                Tip(symbol: "ellipsis.circle.fill", title: "Sub-rings",
                    detail: "Slices with a ⋯ badge, like Convert and Text Tools, open more choices. Click the middle or press Esc to go back.")
                Divided()
                Tip(symbol: "square.stack.3d.up.fill", title: "The ring follows what you point at",
                    detail: "Highlighted text gets the Text ring, Finder files get the Files ring, apps like Ghostty and Cursor get their own, and anywhere else gets Everywhere.")
                Divided()
                Tip(symbol: "doc.on.clipboard.fill", title: "Where answers go",
                    detail: "Rewrites replace your selection. Explain, Study Notes, Flashcards, Commit Msg and Review Code are copied to the clipboard.")
            }

            Card(title: "Studying") {
                Tip(symbol: "note.text", tint: ActionCategory.ai.color, title: "Study Notes",
                    detail: "On highlighted text: copies Markdown notes. On a lecture PDF: saves “<name> notes.md” next to it, ready for Obsidian.")
                Divided()
                Tip(symbol: "rectangle.on.rectangle.angled", tint: ActionCategory.ai.color, title: "Flashcards → Anki",
                    detail: "Saves “<name> flashcards.txt”. In Anki choose File → Import, pick the file, separator Tab, note type Basic.")
                Divided()
                Tip(symbol: "text.viewfinder", tint: .green, title: "Grab Text",
                    detail: "From the Everywhere ring: drag over any part of the screen, like a slide in a recorded lecture, and its text is copied.")
                Divided()
                Tip(symbol: "cup.and.saucer.fill", tint: .gray, title: "Keep Awake",
                    detail: "Stops the Mac sleeping during a long lecture or download. Choose it again, or use the menu bar, to stop.")
            }

            Card(title: "Coding") {
                Tip(symbol: "arrow.triangle.branch", tint: ActionCategory.ai.color, title: "Commit Msg",
                    detail: "Highlight a diff (lazygit, git diff) and get a message: imperative, under 72 characters, no trailing period.")
                Divided()
                Tip(symbol: "doc.on.clipboard.fill", tint: .brown, title: "Copy for AI",
                    detail: "Select code files in Finder; they're copied as Markdown code blocks to paste into Claude.")
                Divided()
                Tip(symbol: "apple.terminal.fill", tint: .cyan, title: "Ghostty ring",
                    detail: "Ghostty's default shortcuts (splits, Zoom Split, prompt jumps) plus Claude Code, which types claude and runs it. Rebound a key? Update the slot in Ring Editor.")
                Divided()
                Tip(symbol: "cursorarrow.rays", tint: .brown, title: "Open in Cursor or VS Code",
                    detail: "Select a project folder or code file in Finder.")
            }

            Card(title: "AI") {
                Tip(symbol: "wand.and.rays", tint: ActionCategory.ai.color, title: "Better Prompt",
                    detail: "Highlight a rough request and it's rewritten in place as a clear prompt.")
                Divided()
                Tip(symbol: "sparkles", tint: .mint, title: "Your own prompts",
                    detail: "Custom Actions → Claude Prompt, then drag it onto the Text ring in Ring Editor.")
            }

            Card(title: "Make it yours") {
                Tip(symbol: "circle.dashed.inset.filled", title: "Ring Editor",
                    detail: "Drag a tool onto a slot to replace it, onto + to add, between slots to swap, back to the library to remove. Double-click to add.") {
                    Button("Open") { selection.pane = .rings }
                }
                Divided()
                Tip(symbol: "square.grid.2x2.fill", title: "App Rings",
                    detail: "Turn presets on or off, or give any other app a ring.") {
                    Button("Open") { selection.pane = .apps }
                }
                Divided()
                Tip(symbol: "doc.on.doc.fill", title: "Files",
                    detail: "Where conversions are saved, image quality, resize size and GIF settings.") {
                    Button("Open") { selection.pane = .files }
                }
            }

            Card(title: "If something's off") {
                Tip(symbol: "exclamationmark.triangle.fill", tint: .orange, title: "“Allow Halo in Accessibility settings first”",
                    detail: "Turn Halo off and on in Accessibility. Always needed after a rebuild.")
                Divided()
                Tip(symbol: "folder.badge.questionmark", tint: .orange, title: "Files ring says “No actions”",
                    detail: "Allow Halo to control Finder in Privacy & Security → Automation.")
                Divided()
                Tip(symbol: "sparkles", tint: .orange, title: "Claude actions fail",
                    detail: "Check the Setup step above, then try Claude → Make Professional to see the exact error.")
                Divided()
                Tip(symbol: "keyboard", tint: .orange, title: "The shortcut does nothing",
                    detail: "Another app (BetterTouchTool, Claude's quick entry) may use \(model.settings.shortcut.display). Pick another in General.")
            }
        }
        .onReceive(poll) { _ in accessibility = Permissions.accessibility }
        .task { checkClaude() }
    }

    private func checkClaude() {
        claudeLoggedIn = nil
        Task {
            guard let cli = ClaudeClient.findCLI(),
                  let result = try? await Shell.run(cli, ["auth", "status"]),
                  let json = try? JSONSerialization.jsonObject(with: Data(result.stdout.utf8)) as? [String: Any]
            else {
                claudeLoggedIn = false
                return
            }
            claudeLoggedIn = json["loggedIn"] as? Bool ?? false
        }
    }
}

/// A setup step with a live tick, a cross, or a spinner while it's unknown.
private struct Step<Accessory: View>: View {
    let done: Bool?
    let title: String
    let detail: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(spacing: 12) {
            Group {
                switch done {
                case true?: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                case false?: Image(systemName: "circle.dashed").foregroundStyle(.orange)
                case nil: Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 20))
            .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).strikethrough(done == true, color: .secondary)
                Text(.init(detail)).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            accessory.controlSize(.small)
        }
        .padding(.vertical, 7)
    }
}

private struct Tip<Accessory: View>: View {
    let symbol: String
    var tint: Color = .accentColor
    let title: String
    let detail: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        Row(symbol: symbol, tint: tint, title: title, detail: detail) { accessory.controlSize(.small) }
    }
}

extension Tip where Accessory == EmptyView {
    init(symbol: String, tint: Color = .accentColor, title: String, detail: String) {
        self.init(symbol: symbol, tint: tint, title: title, detail: detail) { EmptyView() }
    }
}
