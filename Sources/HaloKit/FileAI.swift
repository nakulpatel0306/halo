import AppKit
import Foundation
import UniformTypeIdentifiers

/// File actions where Claude reads the files: summarizing them and naming them
/// after what's inside.
public enum FileAI {
    /// Formats both the CLI's Read tool and the API can take as-is.
    static func readable(_ url: URL) -> Bool {
        let type = UTType(filenameExtension: url.pathExtension) ?? .data
        return type.conforms(to: .pdf) || ClaudeClient.apiImageTypes.contains(type) || type.conforms(to: .text)
    }

    /// Enough for a folder of scans, not so many that one request takes minutes.
    static let maxFiles = 20

    public static func applies(to files: [URL]) -> Bool {
        (1...maxFiles).contains(files.count) && files.allSatisfy(readable)
    }

    public static func request(for id: String, files: [URL], voice: String = "") -> ClaudeRequest? {
        switch id {
        case "file.aiSummarize":
            var system = """
            You summarize files for someone who selected them in Finder. Your answer is copied to their clipboard, \
            so reply with the summary only: no preamble and no markdown headings. Plain "- " bullets are fine.
            """
            if !voice.isEmpty { system += "\n\nAbout the reader:\n\(voice)" }
            let what = files.count == 1 ? "this file" : "these \(files.count) files, one short paragraph each, starting with the file name"
            return ClaudeRequest(system: system, message: "Summarize \(what): what it is and the points that matter.", files: files)
        case "file.aiNotes":
            let system = """
            You turn lecture slides, readings and documents into study notes for a student. \
            Reply with Markdown only, no preamble: a # title, ## sections that follow the material, short bullets, \
            key terms in **bold** with one-line definitions, and a final ## Review section of 3–5 questions worth being able to answer.
            """
            return ClaudeRequest(system: system, message: "Make study notes from \(files.count == 1 ? "this file" : "these files").", files: files)
        case "file.aiFlashcards":
            return ClaudeRequest(system: flashcardSystem, message: "Make flashcards from \(files.count == 1 ? "this file" : "these files").", files: files)
        case "file.aiRename":
            let system = """
            You name files after what's in them. Reply with exactly one name per line, in the order the files are listed, \
            and nothing else: no numbering, no quotes, no file extensions.
            """
            let message = """
            Suggest a clear, specific name for each of these \(files.count) files based on its contents, \
            like "Lease Agreement 2026" or "Chase Statement March". At most 60 characters, words separated by spaces. \
            Include a date only if the contents show one.
            """
            return ClaudeRequest(system: system, message: message, files: files)
        default:
            return nil
        }
    }

    /// Shared with the text Flashcards action so both import into Anki the same way.
    public static let flashcardSystem = """
    You write flashcards for a student studying for exams. Cover the ideas most likely to be tested, \
    one fact per card, in your own concise words. Reply with one card per line and nothing else: \
    the question, a single tab character, then the answer. No numbering, no header, no tabs inside a question or answer.
    """

    public static func run(_ id: String, on files: [URL], client: ClaudeClient, options: FileOptions = FileOptions()) async throws -> FileOpResult {
        guard let request = request(for: id, files: files, voice: client.settings.voice) else {
            throw FileOpError.failed("Unknown action \(id)")
        }
        let reply = try await client.ask(request)
        if id == "file.aiNotes" {
            let out = try write(reply, nextTo: files, suffix: " notes", ext: "md", options: options)
            return FileOpResult(outputs: [out], message: "Saved \(out.lastPathComponent)")
        }
        if id == "file.aiFlashcards" {
            let cards = flashcards(from: reply)
            guard !cards.isEmpty else { throw FileOpError.failed("Claude didn't return any flashcards. Try again.") }
            let out = try write(cards.joined(separator: "\n"), nextTo: files, suffix: " flashcards", ext: "txt", options: options)
            return FileOpResult(outputs: [out], message: "\(cards.count) cards saved. In Anki: File → Import")
        }
        if id == "file.aiRename" {
            let renamed = try rename(files, to: try names(from: reply, count: files.count))
            return FileOpResult(outputs: renamed, message: renamed.count == 1
                ? "Renamed to \(renamed[0].lastPathComponent)" : "Renamed \(renamed.count) files")
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(reply, forType: .string)
        return FileOpResult(outputs: [], message: "Summary copied")
    }

    static func write(_ text: String, nextTo files: [URL], suffix: String, ext: String, options: FileOptions) throws -> URL {
        let first = files[0]
        let out = files.count == 1
            ? try FileOps.destination(for: first, suffix: suffix, ext: ext, options: options)
            : FileOps.uniqueURL(in: try FileOps.folder(for: first, options: options), base: "Study\(suffix)", ext: ext)
        try text.write(to: out, atomically: true, encoding: .utf8)
        return out
    }

    /// Lines shaped "question<TAB>answer", which Anki imports as Basic cards.
    public static func flashcards(from reply: String) -> [String] {
        reply.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count == 2 else { return nil }
            let front = parts[0].trimmingCharacters(in: .whitespaces), back = parts[1].trimmingCharacters(in: .whitespaces)
            return front.isEmpty || back.isEmpty ? nil : "\(front)\t\(back)"
        }
    }

    /// One clean name per file, or an error if Claude's reply doesn't line up.
    static func names(from reply: String, count: Int) throws -> [String] {
        let names = reply.split(whereSeparator: \.isNewline).map(clean).filter { !$0.isEmpty }
        guard names.count == count else {
            throw FileOpError.failed("Claude suggested \(names.count) names for \(count) files. Try again.")
        }
        return names
    }

    static func clean(_ line: Substring) -> String {
        var name = line.trimmingCharacters(in: .whitespaces)
        if let range = name.range(of: #"^(\d+[.)]|-|\*)\s+"#, options: .regularExpression) { name.removeSubrange(range) }
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`").union(.whitespaces))
        // Finder shows ":" as "/" and "/" can't appear in a name at all.
        name = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: " -")
        let ext = (name as NSString).pathExtension
        if !ext.isEmpty, UTType(filenameExtension: ext) != nil, !ext.contains(" ") {
            name = (name as NSString).deletingPathExtension
        }
        return String(name.prefix(60)).trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: ".")))
    }

    static func rename(_ files: [URL], to names: [String]) throws -> [URL] {
        try zip(files, names).map { file, name in
            let ext = file.pathExtension
            guard file.deletingPathExtension().lastPathComponent != name else { return file }
            let target = FileOps.uniqueURL(in: file.deletingLastPathComponent(), base: name, ext: ext)
            try FileManager.default.moveItem(at: file, to: target)
            return target
        }
    }
}
