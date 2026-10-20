import Carbon.HIToolbox
import Foundation

/// Ready-made per-app rings, like Logitech's Actions Ring presets, and the app
/// shortcut actions they're built from.
public enum ProfilePresets {
    private typealias K = KeyCombo
    private static let cmd: KeyCombo.Modifiers = .command
    private static let shiftCmd: KeyCombo.Modifiers = [.shift, .command]
    private static let optCmd: KeyCombo.Modifiers = [.option, .command]

    private static func key(_ id: String, _ title: String, _ symbol: String, _ detail: String, _ combo: KeyCombo) -> ActionInfo {
        ActionInfo(id, title, symbol, .general, .app, "\(detail) · \(combo.display)", keys: combo)
    }

    private static func link(_ id: String, _ title: String, _ symbol: String, _ detail: String, _ url: String) -> ActionInfo {
        ActionInfo(id, title, symbol, .general, .app, detail, link: url)
    }

    static let vscode: [ActionInfo] = [
        key("vscode.palette", "Commands", "command", "Command Palette", K(kVK_ANSI_P, shiftCmd)),
        key("vscode.quickOpen", "Go to File", "doc.text.magnifyingglass", "Quick Open", K(kVK_ANSI_P, cmd)),
        key("vscode.terminal", "Terminal", "apple.terminal.fill", "Toggle the terminal", K(kVK_ANSI_Grave, .control)),
        key("vscode.sidebar", "Sidebar", "sidebar.left", "Toggle the sidebar", K(kVK_ANSI_B, cmd)),
        key("vscode.format", "Format", "text.alignleft", "Format Document", K(kVK_ANSI_F, [.shift, .option])),
        key("vscode.comment", "Comment", "chevron.left.forwardslash.chevron.right", "Toggle line comment", K(kVK_ANSI_Slash, cmd)),
        key("vscode.git", "Source Ctrl", "arrow.triangle.branch", "Open Source Control", K(kVK_ANSI_G, [.control, .shift])),
        key("vscode.findAll", "Find in Files", "magnifyingglass", "Search the workspace", K(kVK_ANSI_F, shiftCmd)),
        key("vscode.definition", "Definition", "arrow.right.circle.fill", "Go to Definition", K(kVK_F12)),
        key("vscode.rename", "Rename", "pencil", "Rename Symbol", K(kVK_F2)),
        key("vscode.split", "Split", "rectangle.split.2x1.fill", "Split the editor", K(kVK_ANSI_Backslash, cmd)),
    ]

    /// Cursor is VS Code underneath, plus its AI panels.
    static let cursor: [ActionInfo] = [
        key("cursor.chat", "AI Chat", "bubble.left.and.text.bubble.right.fill", "Open the AI chat", K(kVK_ANSI_L, cmd)),
        key("cursor.edit", "AI Edit", "wand.and.stars", "Edit the selection with AI", K(kVK_ANSI_K, cmd)),
        key("cursor.agent", "Agent", "sparkles", "Open the agent", K(kVK_ANSI_I, cmd)),
    ]

    static let github: [ActionInfo] = [
        link("github.pulls", "My PRs", "arrow.triangle.pull", "Your pull requests", "https://github.com/pulls"),
        link("github.issues", "Issues", "smallcircle.filled.circle", "Your issues", "https://github.com/issues"),
        link("github.notifications", "Inbox", "bell.fill", "GitHub notifications", "https://github.com/notifications"),
        link("github.new", "New Repo", "plus.rectangle.on.folder.fill", "Create a repository", "https://github.com/new"),
    ]

    static let browser: [ActionInfo] = [
        key("browser.newTab", "New Tab", "plus.square.on.square", "Open a new tab", K(kVK_ANSI_T, cmd)),
        key("browser.closeTab", "Close Tab", "xmark.square.fill", "Close this tab", K(kVK_ANSI_W, cmd)),
        key("browser.reopen", "Reopen", "arrow.uturn.backward.square.fill", "Reopen the last closed tab", K(kVK_ANSI_T, shiftCmd)),
        key("browser.reload", "Reload", "arrow.clockwise", "Reload the page", K(kVK_ANSI_R, cmd)),
        key("browser.back", "Back", "chevron.backward", "Previous page", K(kVK_ANSI_LeftBracket, cmd)),
        key("browser.forward", "Forward", "chevron.forward", "Next page", K(kVK_ANSI_RightBracket, cmd)),
        key("browser.devtools", "Dev Tools", "hammer.fill", "Open developer tools", K(kVK_ANSI_I, optCmd)),
        key("browser.bookmark", "Bookmark", "bookmark.fill", "Bookmark this page", K(kVK_ANSI_D, cmd)),
    ]

    /// Matches the keybinds in ~/.config/ghostty/config.
    static let ghostty: [ActionInfo] = [
        key("ghostty.claude", "Claude Code", "sparkles", "Types claude and runs it", K(kVK_ANSI_C, shiftCmd)),
        key("ghostty.newTab", "New Tab", "plus.square.on.square", "New tab", K(kVK_ANSI_T, cmd)),
        key("ghostty.splitRight", "Split Right", "rectangle.split.2x1.fill", "Split right", K(kVK_ANSI_D, cmd)),
        key("ghostty.splitDown", "Split Down", "rectangle.split.1x2.fill", "Split down", K(kVK_ANSI_D, shiftCmd)),
        key("ghostty.zoom", "Zoom Split", "arrow.up.left.and.arrow.down.right", "Zoom the split", K(kVK_Return, shiftCmd)),
        key("ghostty.equalize", "Equalize", "square.split.2x2.fill", "Even out the splits", K(kVK_ANSI_E, shiftCmd)),
        key("ghostty.prevPrompt", "Prev Prompt", "arrow.up.to.line", "Jump to the previous prompt", K(kVK_UpArrow, cmd)),
        key("ghostty.nextPrompt", "Next Prompt", "arrow.down.to.line", "Jump to the next prompt", K(kVK_DownArrow, cmd)),
        key("ghostty.clear", "Clear", "clear.fill", "Clear the screen", K(kVK_ANSI_K, cmd)),
        key("ghostty.close", "Close", "xmark.square.fill", "Close the split or tab", K(kVK_ANSI_W, cmd)),
        key("ghostty.reload", "Reload Config", "arrow.clockwise", "Reload the Ghostty config", K(kVK_ANSI_Comma, shiftCmd)),
    ]

    static let notion: [ActionInfo] = [
        key("notion.search", "Search", "magnifyingglass", "Search", K(kVK_ANSI_P, cmd)),
        key("notion.new", "New Page", "square.and.pencil", "New page", K(kVK_ANSI_N, cmd)),
        key("notion.sidebar", "Sidebar", "sidebar.left", "Toggle the sidebar", K(kVK_ANSI_Backslash, cmd)),
        key("notion.back", "Back", "chevron.backward", "Previous page", K(kVK_ANSI_LeftBracket, cmd)),
        key("notion.forward", "Forward", "chevron.forward", "Next page", K(kVK_ANSI_RightBracket, cmd)),
        key("notion.copyLink", "Copy Link", "link", "Copy a link to this page", K(kVK_ANSI_L, cmd)),
        key("notion.comment", "Comment", "bubble.left.fill", "Comment", K(kVK_ANSI_M, shiftCmd)),
        key("notion.dark", "Dark Mode", "moon.fill", "Toggle dark mode", K(kVK_ANSI_L, shiftCmd)),
    ]

    static let obsidian: [ActionInfo] = [
        key("obsidian.switcher", "Open Note", "doc.text.magnifyingglass", "Quick switcher", K(kVK_ANSI_O, cmd)),
        key("obsidian.palette", "Commands", "command", "Command palette", K(kVK_ANSI_P, cmd)),
        key("obsidian.new", "New Note", "square.and.pencil", "New note", K(kVK_ANSI_N, cmd)),
        key("obsidian.read", "Read/Edit", "book.fill", "Toggle reading view", K(kVK_ANSI_E, cmd)),
        key("obsidian.search", "Search", "magnifyingglass", "Search all notes", K(kVK_ANSI_F, shiftCmd)),
        key("obsidian.graph", "Graph", "point.3.connected.trianglepath.dotted", "Open graph view", K(kVK_ANSI_G, cmd)),
        key("obsidian.back", "Back", "chevron.backward", "Navigate back", K(kVK_LeftArrow, optCmd)),
        key("obsidian.forward", "Forward", "chevron.forward", "Navigate forward", K(kVK_RightArrow, optCmd)),
    ]

    static let zoom: [ActionInfo] = [
        key("zoom.mute", "Mute", "mic.slash.fill", "Mute or unmute", K(kVK_ANSI_A, shiftCmd)),
        key("zoom.video", "Video", "video.slash.fill", "Start or stop video", K(kVK_ANSI_V, shiftCmd)),
        key("zoom.share", "Share", "rectangle.on.rectangle", "Share screen", K(kVK_ANSI_S, shiftCmd)),
        key("zoom.hand", "Raise Hand", "hand.raised.fill", "Raise or lower hand", K(kVK_ANSI_Y, .option)),
        key("zoom.chat", "Chat", "message.fill", "Show chat", K(kVK_ANSI_H, shiftCmd)),
        key("zoom.people", "People", "person.2.fill", "Show participants", K(kVK_ANSI_U, cmd)),
    ]

    public static let shortcuts = vscode + cursor + github + browser + ghostty + notion + obsidian + zoom

    private static func ids(_ actions: [ActionInfo], take: Int = 8) -> [String] {
        actions.prefix(take).map(\.id)
    }

    public static let all: [RingProfile] = [
        RingProfile(id: "preset.cursor", name: "Cursor", symbol: "cursorarrow.rays", apps: [Apps.cursor],
                    ring: ids(cursor) + ["vscode.palette", "vscode.quickOpen", "vscode.terminal", "vscode.git", "vscode.findAll", "vscode.format", "vscode.comment"]),
        RingProfile(id: "preset.vscode", name: "VS Code", symbol: "chevron.left.forwardslash.chevron.right", apps: [Apps.vscode],
                    ring: ids(vscode)),
        RingProfile(id: "preset.ghostty", name: "Ghostty", symbol: "apple.terminal.fill", apps: ["com.mitchellh.ghostty"],
                    ring: ids(ghostty, take: 10)),
        RingProfile(id: "preset.browser", name: "Chrome & Safari", symbol: "safari.fill", apps: ["com.google.Chrome", "com.apple.Safari"],
                    ring: ids(browser, take: 6) + ["github.pulls", "github.notifications", "general.screenText", "general.screenshot"]),
        RingProfile(id: "preset.notion", name: "Notion", symbol: "doc.text.fill", apps: ["notion.id"], ring: ids(notion)),
        RingProfile(id: "preset.obsidian", name: "Obsidian", symbol: "point.3.connected.trianglepath.dotted", apps: ["md.obsidian"], ring: ids(obsidian)),
        RingProfile(id: "preset.zoom", name: "Zoom", symbol: "video.fill", apps: ["us.zoom.xos"], ring: ids(zoom)),
    ]

    public static let defaults = all
}
