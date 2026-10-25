import Foundation

/// A request to transform some text, built from a ring action.
public struct RewriteRequest: Sendable, Equatable {
    public let instruction: String
    public let text: String
    public let voice: String
    /// Whether the result goes to the clipboard instead of over the selection.
    public let copiesResult: Bool

    public init(instruction: String, text: String, voice: String = "", copiesResult: Bool = false) {
        self.instruction = instruction
        self.text = text
        self.voice = voice
        self.copiesResult = copiesResult
    }

    /// Actions whose answer is about the text rather than a new version of it.
    static let copying: Set = ["text.summarize", "text.explain", "text.reply", "text.notes", "text.flashcards", "text.commitMsg", "text.review"]

    public static func forAction(_ id: String, text: String, settings: HaloSettings) -> RewriteRequest? {
        let instruction: String
        switch id {
        case "text.professional", "general.polishClipboard":
            instruction = "Make this professional: clear, confident and polished, the way a capable person would write it at work. Fix spelling, grammar and sentence structure. Match the register the writer was going for: keep a serious message serious, and keep a light or playful one light, just cleaned up rather than turned stiff or formal. Keep the writer's intent, facts, level of detail and personality."
        case "text.fix":
            instruction = "Fix spelling, grammar and punctuation only. Keep the wording, tone and structure otherwise unchanged."
        case "text.friendly":
            instruction = "Make this warmer and more friendly while staying appropriate to send. Fix any spelling and grammar."
        case "text.flirty":
            instruction = "Make this flirty: playful, warm and a little teasing, confident without being cheesy or over the top. Keep it sounding like a real text from the writer, about the same length. Fix any spelling."
        case "text.serious":
            instruction = "Make this serious and sincere: calm, direct and respectful, with no jokes, emoji or filler. Keep everything the writer is saying."
        case "text.funny":
            instruction = "Make this funnier: add some wit or a light joke that fits, without changing the point or making it much longer. Keep it sounding like the writer."
        case "text.concise":
            instruction = "Say the same thing in noticeably fewer words. Keep every point that matters."
        case "text.bullets":
            instruction = "Restructure this as a short, scannable bulleted list. Use \"- \" for bullets."
        case "text.translate":
            instruction = "Translate this into \(settings.ai.translateTo), keeping its tone and formatting."
        case "text.summarize":
            instruction = "Summarize this in two or three sentences."
        case "text.explain":
            instruction = "Explain what this means in plain language, briefly. Define any jargon, code or acronyms it relies on."
        case "text.notes":
            instruction = "Turn this into study notes for a student: short Markdown bullets grouped under headings, key terms in **bold** with one-line definitions."
        case "text.flashcards":
            instruction = FileAI.flashcardSystem + "\n\nMake flashcards from this text."
        case "text.promptPolish":
            instruction = "Rewrite this rough request into a clear, effective prompt for an AI assistant like Claude: state the goal, the context it needs, constraints, and the shape of the answer wanted. Keep every detail the writer gave and don't invent new requirements. Write it in first person, as the writer would send it."
        case "text.commitMsg":
            instruction = "This is a git diff or a description of a change. Write the commit message: a subject line in imperative mood, under 72 characters, no trailing period; then, only if the change needs it, a blank line and a short body explaining why. Reply with the message only."
        case "text.review":
            instruction = "Review this code like a careful senior engineer. List only real problems, most serious first: bugs, edge cases that will actually happen, security issues, then anything confusing. One short bullet each with the fix. If it's fine, say so in one line."
        case "text.reply":
            instruction = "This is a message someone sent me. Draft my reply: short, natural and ready to send. Put anything only I would know in [brackets]."
        default:
            guard case let .prompt(custom)? = settings.customActions.first(where: { $0.actionID == id })?.kind else { return nil }
            instruction = custom
        }
        return RewriteRequest(instruction: instruction, text: text, voice: settings.ai.voice, copiesResult: copying.contains(id))
    }

    public var systemPrompt: String {
        var prompt = copiesResult
            ? """
            You help with text someone highlighted in another app, such as an email, a message or a document. \
            Your answer is copied to their clipboard, so reply with the answer only: \
            no preamble, no surrounding quotes, no markdown code fences. \
            Write in the same language as the original unless the task says otherwise.
            """
            : """
            You edit text that someone highlighted in another app, such as an email, a message or a document. \
            The edited text is pasted straight back over their selection, so reply with the edited text only: \
            no preamble, no explanation, no surrounding quotes, no markdown code fences. \
            Write in the same language as the original unless the task says otherwise. Keep line breaks, greetings and sign-offs unless the task says otherwise. \
            Never add facts, promises or details the writer didn't include. If the text contains placeholders or names, keep them exactly.
            """
        let voice = voice.trimmingCharacters(in: .whitespacesAndNewlines)
        if !voice.isEmpty {
            prompt += "\n\nAbout the writer and how they like to sound:\n\(voice)"
        }
        return prompt
    }

    public var userMessage: String {
        "\(instruction)\n\n<text>\n\(text)\n</text>"
    }

    public var claude: ClaudeRequest {
        ClaudeRequest(system: systemPrompt, message: userMessage)
    }
}

public enum RewriteError: LocalizedError, Equatable {
    case missingAPIKey
    case claudeCodeNotFound
    case timedOut
    case refused
    case empty
    case http(Int, String)
    case process(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey: "Add your Anthropic API key in Halo Settings → Claude, or switch to your Claude subscription."
        case .claudeCodeNotFound: "Couldn't find the claude command. Install Claude Code and sign in with your Claude account."
        case .timedOut: "Claude didn't answer within 3 minutes. Run claude in Terminal to check it's signed in, then try again."
        case .refused: "Claude declined this request."
        case .empty: "Claude returned an empty response."
        case let .http(status, message): "Claude API error \(status): \(message)"
        case let .process(message): "Claude Code failed: \(message)"
        }
    }
}
