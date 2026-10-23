import Foundation

/// Text actions that run instantly on the Mac, no Claude involved.
public enum TextTools {
    public enum Output: Equatable {
        /// Pasted over the selection.
        case replace(String)
        /// Shown in the HUD.
        case message(String)
        /// Opened in the default app.
        case open(URL)
    }

    public static func run(_ id: String, on text: String) throws -> Output {
        switch id {
        case "text.upper": return .replace(text.uppercased())
        case "text.lower": return .replace(text.lowercased())
        case "text.titleCase": return .replace(titleCase(text))
        case "text.sentenceCase": return .replace(sentenceCase(text))
        case "text.sortLines": return .replace(editLines(text) { $0.sorted { $0.localizedStandardCompare($1) == .orderedAscending } })
        case "text.dedupe":
            var seen = Set<String>()
            return .replace(editLines(text) { $0.filter { seen.insert($0).inserted } })
        case "text.cleanSpaces": return .replace(cleanSpaces(text))
        case "text.json": return .replace(try prettyJSON(text))
        case "text.urlEncode":
            return .replace(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+?#"))) ?? text)
        case "text.urlDecode": return .replace(text.removingPercentEncoding ?? text)
        case "text.base64": return .replace(Data(text.utf8).base64EncodedString())
        case "text.base64Decode":
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = Data(base64Encoded: trimmed), let decoded = String(data: data, encoding: .utf8) else {
                throw TextToolError("That isn't Base64 text.")
            }
            return .replace(decoded)
        case "text.slug": return .replace(slug(text))
        case "text.count": return .message(count(text))
        case "text.search":
            let query = text.trimmingCharacters(in: .whitespacesAndNewlines).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return .open(URL(string: "https://www.google.com/search?q=\(query)")!)
        case "text.define":
            let word = text.trimmingCharacters(in: .whitespacesAndNewlines).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
            return .open(URL(string: "dict://\(word)")!)
        case "text.openLink":
            guard let url = link(in: text) else { throw TextToolError("The selection isn't a link.") }
            return .open(url)
        default:
            throw TextToolError("Unknown text tool \(id).")
        }
    }

    static func lines(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
    }

    /// Whole lines selected in an editor end with a newline; peeling it off
    /// first keeps sorting from moving it to the top, and keeping CRLF intact
    /// stops each line ending from being read as a blank line of its own.
    static func editLines(_ text: String, _ transform: ([String]) -> [String]) -> String {
        let separator = text.contains("\r\n") ? "\r\n" : "\n"
        var lines = text.components(separatedBy: separator)
        let trailing = lines.count > 1 && lines.last == ""
        if trailing { lines.removeLast() }
        return transform(lines).joined(separator: separator) + (trailing ? separator : "")
    }

    /// Small words stay lowercase unless they start the title.
    static func titleCase(_ text: String) -> String {
        let small: Set = ["a", "an", "and", "as", "at", "but", "by", "for", "in", "of", "on", "or", "the", "to", "via", "vs"]
        var first = true
        return text.components(separatedBy: " ").map { word in
            defer { if !word.isEmpty { first = false } }
            let lower = word.lowercased()
            if !first && small.contains(lower) { return lower }
            return lower.prefix(1).uppercased() + lower.dropFirst()
        }.joined(separator: " ")
    }

    static func sentenceCase(_ text: String) -> String {
        var out = ""
        var capitalize = true
        for char in text.lowercased() {
            if capitalize, char.isLetter {
                out += char.uppercased()
                capitalize = false
            } else {
                out.append(char)
            }
            if ".!?".contains(char) || char.isNewline { capitalize = true }
        }
        return out
    }

    static func cleanSpaces(_ text: String) -> String {
        let collapsed = lines(text).map { line in
            line.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        }
        var out: [String] = []
        for line in collapsed where !(line.isEmpty && (out.last?.isEmpty ?? true)) { out.append(line) }
        return out.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func prettyJSON(_ text: String) throws -> String {
        guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8), options: .fragmentsAllowed),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        else { throw TextToolError("That isn't valid JSON.") }
        return String(decoding: data, as: UTF8.self)
    }

    static func slug(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
        return folded.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "-")
    }

    static func count(_ text: String) -> String {
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let lines = lines(text).count
        let f = NumberFormatter()
        f.numberStyle = .decimal
        let n = { (value: Int) -> String in f.string(from: NSNumber(value: value)) ?? String(value) }
        return "\(n(words)) words · \(n(text.count)) characters · \(n(lines)) \(lines == 1 ? "line" : "lines")"
    }

    /// A URL from a selection like "github.com/foo" or "https://…".
    static func link(in text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil, url.host != nil { return url }
        guard trimmed.contains("."), let url = URL(string: "https://\(trimmed)"), url.host?.contains(".") == true else { return nil }
        return url
    }
}

public struct TextToolError: LocalizedError, Equatable {
    let message: String
    init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}
