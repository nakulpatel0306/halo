import AppKit
import CoreText
import Foundation

/// Word, RTF, HTML, ODT and text conversions through macOS's own `textutil`,
/// plus PDF output drawn with Core Text.
enum Documents {
    static let readable: Set = ["txt", "text", "rtf", "html", "htm", "doc", "docx", "odt", "md", "markdown", "wordml", "webarchive"]

    static func convert(_ url: URL, to ext: String, options: FileOptions) async throws -> URL {
        let out = try FileOps.destination(for: url, ext: ext, options: options)
        guard ext == "pdf" else {
            try await textutil(url, to: ext, out: out)
            return out
        }
        // textutil can't write PDF, so go through RTF, which keeps fonts and styles.
        let rtf = FileManager.default.temporaryDirectory.appendingPathComponent("halo-\(UUID().uuidString).rtf")
        defer { try? FileManager.default.removeItem(at: rtf) }
        try await textutil(url, to: "rtf", out: rtf)
        let text = try NSAttributedString(url: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        try renderPDF(text, to: out)
        return out
    }

    static func textutil(_ url: URL, to format: String, out: URL) async throws {
        var args = ["-convert", format, "-output", out.path]
        // textutil doesn't know Markdown; reading it as plain text keeps every character.
        if ["md", "markdown"].contains(url.pathExtension.lowercased()) { args += ["-format", "txt"] }
        let result = try await Shell.run("/usr/bin/textutil", args + [url.path])
        guard result.status == 0, FileManager.default.fileExists(atPath: out.path) else {
            throw FileOpError.failed("Couldn't convert \(url.lastPathComponent): \(result.stderr)")
        }
    }

    /// US Letter pages with ¾" margins, as many as the text needs.
    static func renderPDF(_ text: NSAttributedString, to url: URL) throws {
        var page = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let ctx = CGContext(url as CFURL, mediaBox: &page, nil) else {
            throw FileOpError.failed("Couldn't create \(url.lastPathComponent).")
        }
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        let path = CGPath(rect: page.insetBy(dx: 54, dy: 54), transform: nil)
        var start = 0
        repeat {
            ctx.beginPDFPage(nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: start, length: 0), path, nil)
            CTFrameDraw(frame, ctx)
            ctx.endPDFPage()
            let visible = CTFrameGetVisibleStringRange(frame).length
            guard visible > 0 else { break }
            start += visible
        } while start < text.length
        ctx.closePDF()
    }
}

/// Audio conversions through macOS's own `afconvert`.
enum Audio {
    static let formats: [String: [String]] = [
        "m4a": ["-f", "m4af", "-d", "aac", "-b", "256000"],
        "wav": ["-f", "WAVE", "-d", "LEI16"],
        "aiff": ["-f", "AIFF", "-d", "BEI16"],
        "flac": ["-f", "flac", "-d", "flac"],
        "caf": ["-f", "caff", "-d", "LEI16"],
    ]

    static func convert(_ url: URL, to ext: String, options: FileOptions) async throws -> URL {
        guard let format = formats[ext] else { throw FileOpError.failed("Can't write \(ext.uppercased()) audio.") }
        let out = try FileOps.destination(for: url, ext: ext, options: options)
        let result = try await Shell.run("/usr/bin/afconvert", format + [url.path, out.path])
        guard result.status == 0 else {
            try? FileManager.default.removeItem(at: out)
            throw FileOpError.failed("Couldn't convert \(url.lastPathComponent): \(result.stderr.isEmpty ? result.stdout : result.stderr)")
        }
        return out
    }
}
