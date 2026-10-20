import AppKit
import UniformTypeIdentifiers

/// The Files ring: what each action is called, when it applies, and the
/// formats a selection can be converted to.
public enum FileActions {
    enum Kind { case image, pdf, document, audio, video }

    /// One format a file can be converted to.
    struct Target {
        let ext: String
        let title: String
        let symbol: String
        let detail: String

        init(_ ext: String, _ title: String, _ symbol: String, _ detail: String) {
            self.ext = ext
            self.title = title
            self.symbol = symbol
            self.detail = detail
        }

        var id: String { "convert.\(ext)" }
    }

    /// In the order they appear in the Convert ring, most useful first.
    static let targets: [Kind: [Target]] = [
        .image: [
            Target("jpg", "JPG", "photo.fill", "Small, works everywhere"),
            Target("png", "PNG", "photo.on.rectangle", "Lossless, keeps transparency"),
            Target("heic", "HEIC", "photo.stack.fill", "Apple's compact photo format"),
            Target("avif", "AVIF", "sparkles.rectangle.stack.fill", "Newest, smallest web format"),
            Target("pdf", "PDF", "doc.richtext.fill", "One PDF per image"),
            Target("gif", "GIF", "photo.badge.arrow.down.fill", "Still GIF"),
            Target("tiff", "TIFF", "photo.artframe", "Lossless for print"),
            Target("ico", "ICO", "app.fill", "Windows and favicon icon"),
            Target("icns", "ICNS", "app.badge.fill", "macOS app icon"),
        ],
        .pdf: [
            Target("png", "PNG", "photo.on.rectangle", "Each page as an image"),
            Target("jpg", "JPG", "photo.fill", "Each page as a smaller image"),
            Target("txt", "Text", "text.alignleft", "The PDF's text as .txt"),
        ],
        .document: [
            Target("pdf", "PDF", "doc.richtext.fill", "Print-ready PDF"),
            Target("docx", "Word", "doc.text.fill", "Microsoft Word .docx"),
            Target("txt", "Text", "text.alignleft", "Plain text"),
            Target("rtf", "RTF", "doc.plaintext.fill", "Rich text for any editor"),
            Target("html", "HTML", "chevron.left.forwardslash.chevron.right", "Web page"),
            Target("odt", "ODT", "doc.fill", "OpenDocument for LibreOffice"),
        ],
        .audio: [
            Target("m4a", "M4A", "music.note.list", "AAC, small and good quality"),
            Target("wav", "WAV", "waveform", "Uncompressed"),
            Target("flac", "FLAC", "waveform.circle.fill", "Lossless and compact"),
            Target("aiff", "AIFF", "waveform.path", "Uncompressed, Apple"),
        ],
        .video: [
            Target("mp4", "MP4", "film.fill", "Plays anywhere"),
            Target("mov", "MOV", "film.stack.fill", "QuickTime movie"),
            Target("gif", "GIF", "photo.on.rectangle.angled", "Animated GIF"),
            Target("m4a", "Audio", "waveform", "Just the sound, as M4A"),
        ],
    ]

    static let actions: [ActionInfo] = [
        ActionInfo("file.convert", "Convert", "arrow.triangle.2.circlepath", .files, .convert, "Opens every format the selection can become"),
        ActionInfo("file.compress", "Compress", "arrow.down.right.and.arrow.up.left", .files, .convert, "Smaller images, PDFs and videos"),
        ActionInfo("file.resize", "Resize", "arrow.up.left.and.down.right.magnifyingglass", .files, .image, "Scale images to the size in File settings"),
        ActionInfo("file.resizeHalf", "Half Size", "square.resize.down", .files, .image, "Scale images to 50%"),
        ActionInfo("file.removeBackground", "Remove BG", "person.and.background.dotted", .files, .image, "Cut out the subject as a PNG"),
        ActionInfo("file.autoCrop", "Auto Crop", "crop", .files, .image, "Trim empty borders around an image"),
        ActionInfo("file.rotate", "Rotate", "rotate.right.fill", .files, .image, "Turn images or PDF pages 90° clockwise"),
        ActionInfo("file.grayscale", "Grayscale", "circle.lefthalf.striped.horizontal", .files, .image, "Black-and-white copy of images"),
        ActionInfo("file.stripMetadata", "Strip Info", "location.slash.fill", .files, .image, "Remove location, camera and date details"),
        ActionInfo("file.copyText", "Copy Text", "text.viewfinder", .files, .image, "Copy the text in images or PDFs, read on your Mac"),
        ActionInfo("file.toPDF", "Make PDF", "doc.on.doc.fill", .files, .document, "Combine images into one PDF"),
        ActionInfo("file.pdfMerge", "Merge", "rectangle.stack.fill.badge.plus", .files, .document, "Join selected PDFs into one"),
        ActionInfo("file.pdfSplit", "Split", "rectangle.split.3x1.fill", .files, .document, "Each page as its own PDF"),
        ActionInfo("file.videoGIF", "GIF", "photo.on.rectangle.angled", .files, .media, "Animated GIF, settings in Files"),
        ActionInfo("file.archive", "Zip", "archivebox.fill", .files, .files, "Zip files, or unzip archives"),
        ActionInfo("file.copyPath", "Copy Path", "link", .files, .files, "Copy the full path"),
        ActionInfo("file.copyForAI", "Copy for AI", "doc.on.clipboard.fill", .files, .files, "Copy code and text files as Markdown to paste into Claude"),
        ActionInfo("file.openCursor", "Cursor", "cursorarrow.rays", .files, .files, "Open in Cursor"),
        ActionInfo("file.openVSCode", "VS Code", "chevron.left.forwardslash.chevron.right", .files, .files, "Open in Visual Studio Code"),
        ActionInfo("file.aiSummarize", "Summarize", "text.badge.star", .files, .ai, "Claude reads the files and copies a summary"),
        ActionInfo("file.aiNotes", "Study Notes", "note.text", .files, .ai, "Claude turns lecture slides or readings into Markdown notes"),
        ActionInfo("file.aiFlashcards", "Flashcards", "rectangle.on.rectangle.angled", .files, .ai, "Claude writes Anki-ready flashcards from the files"),
        ActionInfo("file.aiRename", "Rename", "character.cursor.ibeam", .files, .ai, "Claude names files after what's in them"),
    ]

    /// Every convert target once, for the settings library.
    static let convertActions: [ActionInfo] = {
        var seen = Set<String>()
        return [Kind.image, .document, .audio, .video, .pdf].flatMap { targets[$0] ?? [] }.compactMap { target in
            guard seen.insert(target.id).inserted else { return nil }
            return ActionInfo(target.id, target.title, target.symbol, .files, .convert, "Convert to \(target.title)")
        }
    }()

    public static let all = actions + convertActions

    // MARK: Kinds

    static func type(of url: URL) -> UTType {
        UTType(filenameExtension: url.pathExtension.lowercased()) ?? .data
    }

    static func kind(of url: URL) -> Kind? {
        let type = type(of: url)
        if type.conforms(to: .pdf) { return .pdf }
        if type.conforms(to: .image) { return type == .svg ? nil : .image }
        if type.conforms(to: .movie) { return .video }
        if type.conforms(to: .audio) { return .audio }
        if Documents.readable.contains(url.pathExtension.lowercased()) { return .document }
        return nil
    }

    /// Folders and text or code files: what makes sense to open in an editor.
    static func isCode(_ url: URL) -> Bool {
        url.hasDirectoryPath || (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true || type(of: url).conforms(to: .text)
    }

    /// The one kind every file shares, or nil for a mixed selection.
    static func sharedKind(_ files: [URL]) -> Kind? {
        let kinds = Set(files.map { kind(of: $0) })
        guard kinds.count == 1, let only = kinds.first else { return nil }
        return only
    }

    /// Extension we'd write for a file, so `.jpeg` and `.JPG` both count as JPG.
    static func normalizedExtension(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpeg", "jpe": "jpg"
        case "tif": "tiff"
        case "aif": "aiff"
        case "htm": "html"
        case "markdown": "md"
        case let ext: ext
        }
    }

    public static func convertTargets(for files: [URL]) -> [String] {
        guard !files.isEmpty, let kind = sharedKind(files) else { return [] }
        let current = Set(files.map(normalizedExtension))
        return (targets[kind] ?? []).filter { target in
            !(current.count == 1 && current.contains(target.ext))
                && (kind != .image || target.ext == "pdf" || FileOps.canWrite(target.ext))
        }.map(\.id)
    }

    public static func applies(_ id: String, to files: [URL]) -> Bool {
        guard !files.isEmpty else { return false }
        let kind = sharedKind(files)
        switch id {
        case "file.convert": return !convertTargets(for: files).isEmpty
        case _ where id.hasPrefix("convert."): return convertTargets(for: files).contains(id)
        case "file.compress": return [.image, .pdf, .video].contains(kind)
        case "file.resize", "file.resizeHalf", "file.removeBackground", "file.autoCrop", "file.grayscale",
             "file.stripMetadata", "file.toPDF":
            return kind == .image
        case "file.rotate": return kind == .image || kind == .pdf
        case "file.copyText": return kind == .image || kind == .pdf
        case "file.pdfMerge": return files.count > 1 && kind == .pdf
        case "file.pdfSplit": return kind == .pdf
        case "file.videoGIF": return kind == .video
        case "file.archive", "file.copyPath": return true
        case "file.copyForAI": return files.count <= 50 && files.allSatisfy { type(of: $0).conforms(to: .text) }
        case "file.openCursor": return Apps.installed(Apps.cursor) && files.allSatisfy(isCode)
        case "file.openVSCode": return Apps.installed(Apps.vscode) && files.allSatisfy(isCode)
        case "file.aiSummarize", "file.aiNotes", "file.aiFlashcards", "file.aiRename": return FileAI.applies(to: files)
        default: return false
        }
    }
}

/// Apps Halo can hand files to, by bundle identifier.
public enum Apps {
    public static let cursor = "com.todesktop.230313mzl4w4u92"
    public static let vscode = "com.microsoft.VSCode"
    public static let claude = "com.anthropic.claudefordesktop"

    public static func url(_ bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    public static func installed(_ bundleID: String) -> Bool {
        url(bundleID) != nil
    }
}
