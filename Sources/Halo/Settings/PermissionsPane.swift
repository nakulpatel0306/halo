import SwiftUI

struct PermissionsPane: View {
    @State private var accessibility = Permissions.accessibility
    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        PaneScroll(pane: .permissions) {
            Card(footer: "Halo runs on your Mac. Conversions never leave it; Claude only sees text or files when you choose a Claude action like Professional, Summarize or Rename.") {
                PermissionRow(symbol: "accessibility", tint: .blue, title: "Accessibility",
                              detail: "Reads highlighted text, pastes results back and presses app shortcuts.",
                              granted: accessibility) {
                    Permissions.requestAccessibility()
                    Permissions.openAccessibilitySettings()
                }
                Divided()
                PermissionRow(symbol: "folder.fill", tint: .cyan, title: "Finder",
                              detail: "Reads which files are selected. macOS asks the first time you open the ring in Finder.",
                              granted: nil) {
                    Permissions.openAutomationSettings()
                }
            }
        }
        .onReceive(poll) { _ in accessibility = Permissions.accessibility }
    }
}

private struct PermissionRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    /// `nil` when macOS doesn't let apps check ahead of time.
    let granted: Bool?
    let open: () -> Void

    var body: some View {
        Row(symbol: symbol, tint: tint, title: title, detail: detail) {
            if granted == true {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout.weight(.semibold))
            } else {
                Button(granted == false ? "Allow…" : "Open…", action: open)
            }
        }
    }
}
