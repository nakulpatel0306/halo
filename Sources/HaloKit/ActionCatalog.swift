import Foundation

public enum ActionCatalog {
    static let claude: [ActionInfo] = [
        ActionInfo("text.professional", "Professional", "briefcase.fill", .text, .ai, "Polished, clear and confident"),
        ActionInfo("text.fix", "Fix Grammar", "checkmark.seal.fill", .text, .ai, "Spelling, grammar and punctuation only"),
        ActionInfo("text.friendly", "Friendlier", "face.smiling.inverse", .text, .ai, "Warmer and more casual"),
        ActionInfo("text.flirty", "Flirty", "heart.fill", .text, .ai, "Playful and a little teasing"),
        ActionInfo("text.serious", "Serious", "exclamationmark.bubble.fill", .text, .ai, "Sincere and direct, no jokes"),
        ActionInfo("text.funny", "Funnier", "theatermasks.fill", .text, .ai, "Same point with some wit"),
        ActionInfo("text.concise", "Shorter", "scissors", .text, .ai, "Same message in fewer words"),
        ActionInfo("text.bullets", "Bullets", "list.bullet.rectangle.fill", .text, .ai, "Restructure as a scannable list"),
        ActionInfo("text.translate", "Translate", "character.bubble.fill", .text, .ai, "Into your language from AI settings"),
        ActionInfo("text.summarize", "Summarize", "text.badge.star", .text, .ai, "Copies a short summary"),
        ActionInfo("text.explain", "Explain", "questionmark.bubble.fill", .text, .ai, "Copies a plain-language explanation"),
        ActionInfo("text.reply", "Reply", "arrowshape.turn.up.left.fill", .text, .ai, "Copies a reply to this message"),
        ActionInfo("text.notes", "Study Notes", "note.text", .text, .ai, "Copies Markdown study notes, ready for Obsidian or Notion"),
        ActionInfo("text.flashcards", "Flashcards", "rectangle.on.rectangle.angled", .text, .ai, "Copies Anki-ready flashcards (question, tab, answer)"),
        ActionInfo("text.promptPolish", "Better Prompt", "wand.and.rays", .text, .ai, "Rewrites a rough request into a clear prompt for an AI"),
        ActionInfo("text.commitMsg", "Commit Msg", "arrow.triangle.branch", .text, .ai, "Copies a commit message for a selected diff"),
        ActionInfo("text.review", "Review Code", "ladybug.fill", .text, .ai, "Copies a short list of real problems in the code"),
    ]

    static let textTools: [ActionInfo] = [
        ActionInfo("text.tools", "Text Tools", "textformat", .text, .text, "Opens case, sorting, JSON and encoding tools"),
        ActionInfo("text.upper", "UPPERCASE", "textformat.size.larger", .text, .text, "Make every letter a capital"),
        ActionInfo("text.lower", "lowercase", "textformat.size.smaller", .text, .text, "Make every letter small"),
        ActionInfo("text.titleCase", "Title Case", "textformat", .text, .text, "Capitalize Each Word"),
        ActionInfo("text.sentenceCase", "Sentence", "textformat.abc", .text, .text, "Capitalize the first word of each sentence"),
        ActionInfo("text.sortLines", "Sort Lines", "arrow.up.arrow.down", .text, .text, "A to Z, numbers in order"),
        ActionInfo("text.dedupe", "Dedupe", "line.3.horizontal.decrease", .text, .text, "Remove repeated lines"),
        ActionInfo("text.cleanSpaces", "Clean Up", "eraser.fill", .text, .text, "Trim stray spaces and blank lines"),
        ActionInfo("text.json", "Format JSON", "curlybraces", .text, .text, "Pretty-print JSON"),
        ActionInfo("text.urlEncode", "URL Encode", "percent", .text, .text, "Percent-encode for a link"),
        ActionInfo("text.urlDecode", "URL Decode", "link", .text, .text, "Turn %20 back into spaces"),
        ActionInfo("text.base64", "Base64", "lock.square.fill", .text, .text, "Encode as Base64"),
        ActionInfo("text.base64Decode", "Decode 64", "lock.open.fill", .text, .text, "Decode Base64"),
        ActionInfo("text.slug", "Slugify", "minus.rectangle.fill", .text, .text, "turn-this-into-a-slug"),
        ActionInfo("text.count", "Count", "number.square.fill", .text, .text, "Words, characters and lines"),
        ActionInfo("text.search", "Search Web", "magnifyingglass", .text, .text, "Search the selection in your browser"),
        ActionInfo("text.define", "Define", "book.closed.fill", .text, .text, "Look it up in Dictionary"),
        ActionInfo("text.openLink", "Open Link", "safari.fill", .text, .text, "Open the selected address"),
    ]

    static let general: [ActionInfo] = [
        ActionInfo("general.screenshot", "Screenshot", "camera.viewfinder", .general, .capture, "Capture an area to the clipboard"),
        ActionInfo("general.screenshotWindow", "Window Shot", "macwindow.badge.plus", .general, .capture, "Capture a window to the clipboard"),
        ActionInfo("general.screenText", "Grab Text", "text.viewfinder", .general, .capture, "Select an area and copy the text in it"),
        ActionInfo("general.colorPicker", "Pick Color", "eyedropper.halffull", .general, .capture, "Copy any pixel's hex color"),
        ActionInfo("general.polishClipboard", "Polish Copy", "wand.and.stars", .general, .ai, "Make copied text professional"),
        ActionInfo("general.pastePlain", "Paste Plain", "doc.plaintext.fill", .general, .text, "Paste without formatting"),
        ActionInfo("general.keepAwake", "Keep Awake", "cup.and.saucer.fill", .general, .system, "Stop the Mac sleeping until you turn it off"),
        ActionInfo("general.displaySleep", "Display Off", "moon.fill", .general, .system, "Turn the screen off now"),
        ActionInfo("general.downloads", "Downloads", "arrow.down.circle.fill", .general, .system, "Open your Downloads folder"),
        ActionInfo("general.claude", "Claude", "sparkle", .general, .ai, "Open the Claude app"),
        ActionInfo("general.settings", "Settings", "gearshape.fill", .general, .system, "Open Halo settings"),
    ]

    public static let all: [ActionInfo] = claude + textTools + general + FileActions.all + ProfilePresets.shortcuts

    private static let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    public static func info(_ id: String) -> ActionInfo? {
        byID[id]
    }

    /// Actions that open a sub-ring.
    static let folders: Set = ["text.tools", "file.convert"]

    /// What a folder opens, already narrowed to what fits the selection.
    public static func children(of id: String, context: RingContext) -> [ActionInfo] {
        switch id {
        case "text.tools":
            let ids = ["text.upper", "text.lower", "text.titleCase", "text.sortLines", "text.cleanSpaces", "text.json", "text.count", "text.search"]
            return ids.compactMap(info)
        case "file.convert":
            guard case let .files(files) = context else { return [] }
            return FileActions.convertTargets(for: files).compactMap(info)
        default:
            return []
        }
    }

    public static func defaultRing(_ kind: RingKind) -> [String] {
        switch kind {
        case .text:
            ["text.professional", "text.fix", "text.concise", "text.explain", "text.notes",
             "text.flashcards", "text.promptPolish", "text.reply", "text.commitMsg", "text.tools"]
        case .files:
            ["file.convert", "file.compress", "file.copyText", "file.copyForAI", "file.aiSummarize",
             "file.aiNotes", "file.aiFlashcards", "file.openCursor", "file.pdfMerge", "file.archive"]
        case .general:
            ["general.screenshot", "general.screenText", "general.colorPicker", "general.polishClipboard",
             "general.pastePlain", "general.keepAwake", "general.claude", "general.settings"]
        }
    }

    /// Whether an action makes sense for what's selected. The Files ring only
    /// shows actions that do, the same way Filee only offers formats that fit.
    public static func applies(_ id: String, to context: RingContext) -> Bool {
        guard case let .files(files) = context, id.hasPrefix("file.") || id.hasPrefix("convert.") else { return true }
        return FileActions.applies(id, to: files)
    }
}
