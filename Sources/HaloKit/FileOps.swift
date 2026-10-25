import AppKit
import AVFoundation
import CoreImage
import ImageIO
import PDFKit
import UniformTypeIdentifiers
import Vision

public struct FileOpResult: Sendable {
    public let outputs: [URL]
    public let message: String
}

public enum FileOpError: LocalizedError {
    case unreadable(String)
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case let .unreadable(name): "Couldn't read \(name)."
        case let .failed(message): message
        }
    }
}

/// File actions. Results are written as new files, never over the originals,
/// in the folder File settings choose.
public enum FileOps {
    public static func run(_ id: String, on files: [URL], options: FileOptions = FileOptions()) async throws -> FileOpResult {
        let o = options
        let outputs: [URL]
        switch id {
        case _ where id.hasPrefix("convert."):
            outputs = try await serial(files) { try await convert($0, to: String(id.dropFirst("convert.".count)), options: o) }
        case "file.compress": return try await compress(files, options: o)
        case "file.resize": outputs = try files.map { try resize($0, longestSide: o.resizeLongestSide, options: o) }
        case "file.resizeHalf": outputs = try files.map { try resize($0, scale: 0.5, options: o) }
        case "file.removeBackground": outputs = try files.map { try removeBackground($0, options: o) }
        case "file.autoCrop": outputs = try files.map { try autoCrop($0, options: o) }
        case "file.rotate": outputs = try files.map { try rotate($0, options: o) }
        case "file.grayscale": outputs = try files.map { try grayscale($0, options: o) }
        case "file.stripMetadata": outputs = try files.map { try stripMetadata($0, options: o) }
        case "file.toPDF": outputs = [try imagesToPDF(files, options: o)]
        case "file.pdfMerge": outputs = [try mergePDFs(files, options: o)]
        case "file.pdfSplit": outputs = try files.map { try splitPDF($0, options: o) }
        case "file.videoGIF": outputs = try await serial(files) { try await videoToGIF($0, options: o) }
        case "file.archive":
            outputs = files.allSatisfy({ FileActions.type(of: $0).conforms(to: .zip) })
                ? try await serial(files) { try await unzip($0, options: o) }
                : [try await zip(files, options: o)]
        case "file.copyText":
            let text = try files.map(text(in:)).filter { !$0.isEmpty }.joined(separator: "\n\n")
            guard !text.isEmpty else { throw FileOpError.failed("No text found.") }
            copy(text)
            return FileOpResult(outputs: [], message: "Text copied")
        case "file.copyForAI":
            copy(try markdown(files))
            return FileOpResult(outputs: [], message: files.count == 1 ? "Copied \(files[0].lastPathComponent) for AI" : "Copied \(files.count) files for AI")
        case "file.copyPath":
            copy(files.map(\.path).joined(separator: "\n"))
            return FileOpResult(outputs: [], message: files.count == 1 ? "Path copied" : "\(files.count) paths copied")
        default:
            throw FileOpError.failed("Unknown action \(id)")
        }
        return FileOpResult(outputs: outputs, message: summary(outputs))
    }

    /// Each file as a fenced block under its name, the shape AI chats read best.
    static func markdown(_ files: [URL]) throws -> String {
        try files.map { url in
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { throw FileOpError.unreadable(url.lastPathComponent) }
            let fence = text.contains("```") ? "````" : "```"
            return "\(url.lastPathComponent)\n\(fence)\(url.pathExtension.lowercased())\n\(text.trimmingCharacters(in: .newlines))\n\(fence)"
        }.joined(separator: "\n\n")
    }

    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    static func summary(_ outputs: [URL]) -> String {
        outputs.count == 1 ? "Saved \(outputs[0].lastPathComponent)" : "Saved \(outputs.count) files"
    }

    static func serial(_ files: [URL], _ work: (URL) async throws -> URL) async throws -> [URL] {
        var results: [URL] = []
        for file in files { results.append(try await work(file)) }
        return results
    }

    // MARK: Where results go

    static func folder(for source: URL, options: FileOptions) throws -> URL {
        switch options.output {
        case .nextToOriginal:
            return source.deletingLastPathComponent()
        case .subfolder:
            let folder = source.deletingLastPathComponent().appendingPathComponent("Converted")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder
        case .downloads:
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        }
    }

    /// `photo.png` → `photo.jpg`, or `photo 2.jpg` if that already exists.
    public static func destination(for source: URL, suffix: String = "", ext: String, options: FileOptions = FileOptions()) throws -> URL {
        let base = source.deletingPathExtension().lastPathComponent + suffix
        return uniqueURL(in: try folder(for: source, options: options), base: base, ext: ext)
    }

    static func uniqueURL(in folder: URL, base: String, ext: String) -> URL {
        let name = { (n: Int) in (n == 1 ? base : "\(base) \(n)") + (ext.isEmpty ? "" : ".\(ext)") }
        var n = 1
        while FileManager.default.fileExists(atPath: folder.appendingPathComponent(name(n)).path) { n += 1 }
        return folder.appendingPathComponent(name(n))
    }

    static func size(of url: URL) -> Int64 {
        ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber)?.int64Value ?? 0
    }

    // MARK: Convert

    public static func convert(_ url: URL, to ext: String, options: FileOptions = FileOptions()) async throws -> URL {
        switch (FileActions.kind(of: url), ext) {
        case (.image, "pdf"): return try imagesToPDF([url], options: options)
        case (.image, _): return try convertImage(url, toExtension: ext, options: options)
        case (.pdf, "png"): return try pdfToImages(url, type: .png, options: options)
        case (.pdf, "jpg"): return try pdfToImages(url, type: .jpeg, options: options)
        case (.pdf, "txt"): return try pdfText(url, options: options)
        case (.document, _): return try await Documents.convert(url, to: ext, options: options)
        case (.audio, _): return try await Audio.convert(url, to: ext, options: options)
        case (.video, "gif"): return try await videoToGIF(url, options: options)
        case (.video, "m4a"): return try await exportVideo(url, preset: AVAssetExportPresetAppleM4A, type: .m4a, suffix: "", options: options)
        case (.video, "mov"): return try await exportVideo(url, preset: options.videoQuality.preset, type: .mov, suffix: "", options: options)
        case (.video, "mp4"): return try await exportVideo(url, preset: options.videoQuality.preset, type: .mp4, suffix: "", options: options)
        default: throw FileOpError.failed("Can't convert \(url.lastPathComponent) to \(ext.uppercased()).")
        }
    }

    // MARK: Images

    static let imageTypes: [String: UTType] = [
        "jpg": .jpeg, "png": .png, "heic": .heic, "avif": UTType("public.avif") ?? .heic, "tiff": .tiff, "gif": .gif,
        "bmp": .bmp, "ico": .ico, "icns": .icns,
    ]

    /// Whether this Mac can write an image format. Some, like AVIF, depend on the
    /// hardware and macOS version, so each is tried once on a tiny image.
    public static func canWrite(_ ext: String) -> Bool {
        writable.contains(ext)
    }

    private static let writable = Set(imageTypes.filter { probe($0.value) }.keys)

    private static func probe(_ type: UTType) -> Bool {
        let side = type == .icns ? 16 : 2
        guard let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let image = ctx.makeImage(),
              let dest = CGImageDestinationCreateWithData(NSMutableData(), type.identifier as CFString, 1, nil)
        else { return false }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest)
    }

    /// `.jpg` rather than UTType's `.jpeg`, which is what people expect to see.
    static func fileExtension(for type: UTType) -> String {
        type == .jpeg ? "jpg" : type.preferredFilenameExtension ?? "png"
    }

    static func loadImage(_ url: URL) throws -> (CGImage, CGImageSource) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw FileOpError.unreadable(url.lastPathComponent) }
        return (image, source)
    }

    static func write(_ image: CGImage, to url: URL, type: UTType, properties: CFDictionary? = nil, quality: Double = 0.9) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw FileOpError.failed("This Mac can't write \(fileExtension(for: type).uppercased()) files.")
        }
        var props = (properties as? [CFString: Any]) ?? [:]
        if type != .png { props[kCGImageDestinationLossyCompressionQuality] = quality }
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw FileOpError.failed("Couldn't save \(url.lastPathComponent).") }
    }

    /// The original's EXIF, colour profile and dates, unless the user asked to strip them.
    static func properties(_ source: CGImageSource, options: FileOptions) -> CFDictionary? {
        options.stripMetadata ? nil : CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
    }

    /// Output type for edits that keep the format: anything ImageIO can't write goes to PNG.
    static func editableType(of url: URL) -> UTType {
        let type = UTType(filenameExtension: url.pathExtension) ?? .png
        let writable = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return writable.contains(type.identifier) ? type : .png
    }

    public static func convertImage(_ url: URL, to type: UTType, options: FileOptions = FileOptions()) throws -> URL {
        try convertImage(url, toExtension: fileExtension(for: type), options: options)
    }

    static func convertImage(_ url: URL, toExtension ext: String, options: FileOptions) throws -> URL {
        guard let type = imageTypes[ext] else { throw FileOpError.failed("Can't write \(ext.uppercased()) images.") }
        let (image, source) = try loadImage(url)
        let out = try destination(for: url, ext: ext, options: options)
        if type == .ico || type == .icns {
            // Icons must be square and standard sizes; an .icns carries several.
            let sides = type == .ico ? [256] : [16, 32, 128, 256, 512]
            guard let dest = CGImageDestinationCreateWithURL(out as CFURL, type.identifier as CFString, sides.count, nil) else {
                throw FileOpError.failed("This Mac can't write \(ext.uppercased()) files.")
            }
            for side in sides { CGImageDestinationAddImage(dest, try squareIcon(image, side: side), nil) }
            guard CGImageDestinationFinalize(dest) else { throw FileOpError.failed("Couldn't save \(out.lastPathComponent).") }
            return out
        }
        try write(flattenedIfNeeded(image, for: type), to: out, type: type,
                  properties: properties(source, options: options), quality: options.imageQuality)
        return out
    }

    static func squareIcon(_ image: CGImage, side: Int) throws -> CGImage {
        guard let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw FileOpError.failed("Couldn't make an icon.") }
        let scale = Double(side) / Double(max(image.width, image.height))
        let w = Double(image.width) * scale, h = Double(image.height) * scale
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: (Double(side) - w) / 2, y: (Double(side) - h) / 2, width: w, height: h))
        guard let icon = ctx.makeImage() else { throw FileOpError.failed("Couldn't make an icon.") }
        return icon
    }

    static func hasAlpha(_ image: CGImage) -> Bool {
        ![.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo)
    }

    /// Whether any pixel is see-through. Screenshots carry an alpha channel even
    /// when every pixel is solid, so the channel alone doesn't say.
    static func hasTransparency(_ image: CGImage) -> Bool {
        guard hasAlpha(image) else { return false }
        let w = image.width, h = image.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return true }
        return stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] < 255 }
    }

    /// JPG has no alpha; transparent pixels would turn black, so draw them on white.
    static func flattenedIfNeeded(_ image: CGImage, for type: UTType) -> CGImage {
        guard type == .jpeg || type == .bmp, hasAlpha(image),
              let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return image }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        ctx.setFillColor(.white)
        ctx.fill(rect)
        ctx.draw(image, in: rect)
        return ctx.makeImage() ?? image
    }

    static func thumbnail(_ source: CGImageSource, longestSide: Double) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(longestSide.rounded()),
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    public static func resize(_ url: URL, scale: Double, options: FileOptions = FileOptions()) throws -> URL {
        let (image, source) = try loadImage(url)
        let longest = Double(max(image.width, image.height)) * scale
        guard let small = thumbnail(source, longestSide: longest) else { throw FileOpError.failed("Couldn't resize \(url.lastPathComponent).") }
        let type = editableType(of: url)
        let out = try destination(for: url, suffix: " (\(Int(scale * 100))%)", ext: fileExtension(for: type), options: options)
        try write(small, to: out, type: type, quality: options.imageQuality)
        return out
    }

    public static func resize(_ url: URL, longestSide: Double, options: FileOptions = FileOptions()) throws -> URL {
        let (image, source) = try loadImage(url)
        guard Double(max(image.width, image.height)) > longestSide else {
            throw FileOpError.failed("\(url.lastPathComponent) is already \(Int(longestSide)) px or smaller.")
        }
        guard let small = thumbnail(source, longestSide: longestSide) else { throw FileOpError.failed("Couldn't resize \(url.lastPathComponent).") }
        let type = editableType(of: url)
        let out = try destination(for: url, suffix: " (\(Int(longestSide)) px)", ext: fileExtension(for: type), options: options)
        try write(small, to: out, type: type, quality: options.imageQuality)
        return out
    }

    public static func autoCrop(_ url: URL, tolerance: Int = 12, options: FileOptions = FileOptions()) throws -> URL {
        let (image, _) = try loadImage(url)
        guard let box = contentBounds(of: image, tolerance: tolerance), let cropped = image.cropping(to: box) else {
            throw FileOpError.failed("Nothing to crop in \(url.lastPathComponent).")
        }
        let type = editableType(of: url)
        let out = try destination(for: url, suffix: " (cropped)", ext: fileExtension(for: type), options: options)
        try write(cropped, to: out, type: type, quality: options.imageQuality)
        return out
    }

    /// The smallest rectangle containing every pixel that differs from the
    /// top-left corner's colour by more than `tolerance` on any channel.
    static func contentBounds(of image: CGImage, tolerance: Int) -> CGRect? {
        let w = image.width, h = image.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }

        let bg = Array(pixels[0..<4])
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            for x in 0..<w {
                let i = (y * w + x) * 4
                if (0..<4).contains(where: { abs(Int(pixels[i + $0]) - Int(bg[$0])) > tolerance }) {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        guard maxX >= 0 else { return nil }
        let box = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        return box.size == CGSize(width: w, height: h) ? nil : box
    }

    public static func removeBackground(_ url: URL, options: FileOptions = FileOptions()) throws -> URL {
        let (image, _) = try loadImage(url)
        let handler = VNImageRequestHandler(cgImage: image)
        let request = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([request])
        guard let observation = request.results?.first else {
            throw FileOpError.failed("Couldn't find a subject in \(url.lastPathComponent).")
        }
        let buffer = try observation.generateMaskedImage(ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: false)
        let ci = CIImage(cvPixelBuffer: buffer)
        guard let cut = CIContext().createCGImage(ci, from: ci.extent) else {
            throw FileOpError.failed("Couldn't cut out \(url.lastPathComponent).")
        }
        let out = try destination(for: url, suffix: " (no background)", ext: "png", options: options)
        try write(cut, to: out, type: .png)
        return out
    }

    /// Images turn 90° clockwise; PDFs turn every page.
    public static func rotate(_ url: URL, options: FileOptions = FileOptions()) throws -> URL {
        if FileActions.kind(of: url) == .pdf {
            let doc = try loadPDF(url)
            for i in 0..<doc.pageCount { doc.page(at: i)?.rotation += 90 }
            let out = try destination(for: url, suffix: " (rotated)", ext: "pdf", options: options)
            guard doc.write(to: out) else { throw FileOpError.failed("Couldn't save \(out.lastPathComponent).") }
            return out
        }
        let (image, source) = try loadImage(url)
        let upright = thumbnail(source, longestSide: Double(max(image.width, image.height))) ?? image
        let rotated = CIImage(cgImage: upright).oriented(.right)
        guard let cg = CIContext().createCGImage(rotated, from: rotated.extent) else {
            throw FileOpError.failed("Couldn't rotate \(url.lastPathComponent).")
        }
        let type = editableType(of: url)
        let out = try destination(for: url, suffix: " (rotated)", ext: fileExtension(for: type), options: options)
        try write(cg, to: out, type: type, quality: options.imageQuality)
        return out
    }

    public static func grayscale(_ url: URL, options: FileOptions = FileOptions()) throws -> URL {
        let (image, source) = try loadImage(url)
        let mono = CIImage(cgImage: image).applyingFilter("CIPhotoEffectNoir")
        guard let cg = CIContext().createCGImage(mono, from: mono.extent) else {
            throw FileOpError.failed("Couldn't convert \(url.lastPathComponent).")
        }
        let type = editableType(of: url)
        let out = try destination(for: url, suffix: " (B&W)", ext: fileExtension(for: type), options: options)
        try write(cg, to: out, type: type, properties: properties(source, options: options), quality: options.imageQuality)
        return out
    }

    /// Re-encodes the pixels with the photo's orientation applied, so nothing is
    /// lost visually but location, camera and dates are gone.
    public static func stripMetadata(_ url: URL, options: FileOptions = FileOptions()) throws -> URL {
        let (image, source) = try loadImage(url)
        let upright = thumbnail(source, longestSide: Double(max(image.width, image.height))) ?? image
        let type = editableType(of: url)
        let out = try destination(for: url, suffix: " (clean)", ext: fileExtension(for: type), options: options)
        try write(upright, to: out, type: type, quality: options.imageQuality)
        return out
    }

    /// On-device OCR, so screenshots and photos of documents become text without leaving the Mac.
    public static func recognizeText(_ url: URL) throws -> String {
        try recognizeText(in: try loadImage(url).0)
    }

    public static func recognizeText(in image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }

    /// Text from an image, or from a PDF: its own text if it has some, otherwise OCR of each page.
    static func text(in url: URL) throws -> String {
        guard FileActions.kind(of: url) == .pdf else { return try recognizeText(url) }
        let doc = try loadPDF(url)
        if let text = doc.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty { return text }
        return try (0..<doc.pageCount).compactMap { doc.page(at: $0).flatMap(render) }.map(recognizeText(in:)).joined(separator: "\n\n")
    }

    public static func imagesToPDF(_ urls: [URL], options: FileOptions = FileOptions()) throws -> URL {
        let doc = PDFDocument()
        for url in urls.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) {
            guard let image = NSImage(contentsOf: url), let page = PDFPage(image: image) else {
                throw FileOpError.unreadable(url.lastPathComponent)
            }
            doc.insert(page, at: doc.pageCount)
        }
        let first = urls[0]
        let out = urls.count == 1
            ? try destination(for: first, ext: "pdf", options: options)
            : uniqueURL(in: try folder(for: first, options: options), base: "Images", ext: "pdf")
        guard doc.write(to: out) else { throw FileOpError.failed("Couldn't save the PDF.") }
        return out
    }

    // MARK: Compress

    /// Keeps only results that came out smaller, and reports the saving.
    public static func compress(_ urls: [URL], options: FileOptions = FileOptions()) async throws -> FileOpResult {
        var outputs: [URL] = []
        var before: Int64 = 0, after: Int64 = 0
        for url in urls {
            let out: URL = switch FileActions.kind(of: url) {
            case .pdf: try compressPDF(url, options: options)
            case .video: try await exportVideo(url, preset: AVAssetExportPresetMediumQuality, type: .mp4, suffix: " (compressed)", options: options)
            default: try compressImage(url, options: options)
            }
            let old = size(of: url), new = size(of: out)
            // Some files have nothing left to squeeze and come out bigger; don't leave those around.
            if new >= old {
                try? FileManager.default.removeItem(at: out)
                continue
            }
            before += old; after += new
            outputs.append(out)
        }
        guard !outputs.isEmpty else {
            return FileOpResult(outputs: [], message: urls.count == 1 ? "Already as small as it gets" : "Already as small as they get")
        }
        let fmt = ByteCountFormatter()
        return FileOpResult(outputs: outputs, message: "\(fmt.string(fromByteCount: before)) → \(fmt.string(fromByteCount: after))")
    }

    /// Lossy formats are re-encoded harder; lossless ones become JPG, or HEIC
    /// when they have transparency to keep.
    static func compressImage(_ url: URL, options: FileOptions) throws -> URL {
        let (image, source) = try loadImage(url)
        let current = editableType(of: url)
        let type: UTType = [.jpeg, .heic, UTType("public.avif")].contains(current) ? current : (hasTransparency(image) ? .heic : .jpeg)
        let out = try destination(for: url, suffix: " (compressed)", ext: fileExtension(for: type), options: options)
        try write(flattenedIfNeeded(image, for: type), to: out, type: type,
                  properties: properties(source, options: options), quality: min(options.imageQuality, 0.6))
        return out
    }

    static func compressPDF(_ url: URL, options: FileOptions) throws -> URL {
        let doc = try loadPDF(url)
        let out = try destination(for: url, suffix: " (compressed)", ext: "pdf", options: options)
        let writeOptions: [PDFDocumentWriteOption: Any] = [.saveImagesAsJPEGOption: true, .optimizeImagesForScreenOption: true]
        guard doc.write(to: out, withOptions: writeOptions) else { throw FileOpError.failed("Couldn't save \(out.lastPathComponent).") }
        return out
    }

    public static func compressPDFs(_ urls: [URL]) async throws -> FileOpResult {
        try await compress(urls)
    }

    // MARK: PDF

    static func loadPDF(_ url: URL) throws -> PDFDocument {
        guard let doc = PDFDocument(url: url) else { throw FileOpError.unreadable(url.lastPathComponent) }
        return doc
    }

    public static func mergePDFs(_ urls: [URL], options: FileOptions = FileOptions()) throws -> URL {
        let merged = PDFDocument()
        let ordered = urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        for url in ordered {
            let doc = try loadPDF(url)
            for i in 0..<doc.pageCount {
                if let page = doc.page(at: i)?.copy() as? PDFPage { merged.insert(page, at: merged.pageCount) }
            }
        }
        let out = uniqueURL(in: try folder(for: ordered[0], options: options), base: "Merged", ext: "pdf")
        guard merged.write(to: out) else { throw FileOpError.failed("Couldn't save the merged PDF.") }
        return out
    }

    /// Each page as its own PDF, in a folder named after the original.
    public static func splitPDF(_ url: URL, options: FileOptions = FileOptions()) throws -> URL {
        let doc = try loadPDF(url)
        let folder = try destination(for: url, suffix: " pages", ext: "", options: options)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let digits = String(doc.pageCount).count
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i)?.copy() as? PDFPage else { continue }
            let single = PDFDocument()
            single.insert(page, at: 0)
            single.write(to: folder.appendingPathComponent("Page \(String(i + 1).leftPadded(to: digits)).pdf"))
        }
        return folder
    }

    static func render(_ page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let scale = 2.0
        guard let ctx = CGContext(data: nil, width: Int(bounds.width * scale), height: Int(bounds.height * scale),
                                  bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        ctx.setFillColor(.white)
        ctx.fill(CGRect(x: 0, y: 0, width: ctx.width, height: ctx.height))
        ctx.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: ctx)
        return ctx.makeImage()
    }

    /// Renders each page at 2× into a folder named after the PDF.
    public static func pdfToImages(_ url: URL, type: UTType = .png, options: FileOptions = FileOptions()) throws -> URL {
        let doc = try loadPDF(url)
        let folder = try destination(for: url, suffix: " pages", ext: "", options: options)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let digits = String(doc.pageCount).count
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i), let image = render(page) else { continue }
            let number = String(i + 1).leftPadded(to: digits)
            try write(image, to: folder.appendingPathComponent("Page \(number).\(fileExtension(for: type))"), type: type, quality: options.imageQuality)
        }
        return folder
    }

    public static func pdfText(_ url: URL, options: FileOptions = FileOptions()) throws -> URL {
        let text = try text(in: url)
        guard !text.isEmpty else { throw FileOpError.failed("\(url.lastPathComponent) has no text.") }
        let out = try destination(for: url, ext: "txt", options: options)
        try text.write(to: out, atomically: true, encoding: .utf8)
        return out
    }

    // MARK: Video

    public static func exportVideo(_ url: URL, preset: String, type: AVFileType, suffix: String, options: FileOptions = FileOptions()) async throws -> URL {
        let asset = AVURLAsset(url: url)
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw FileOpError.failed("Can't convert \(url.lastPathComponent) that way.")
        }
        let ext = switch type {
        case .m4a: "m4a"
        case .mov: "mov"
        default: "mp4"
        }
        let out = try destination(for: url, suffix: suffix, ext: ext, options: options)
        session.outputURL = out
        session.outputFileType = type
        session.shouldOptimizeForNetworkUse = true
        await session.export()
        if let error = session.error { throw FileOpError.failed(error.localizedDescription) }
        guard session.status == .completed else { throw FileOpError.failed("Converting \(url.lastPathComponent) didn't finish.") }
        return out
    }

    /// Long clips are cut at the GIF length in File settings; past that a GIF is the wrong format.
    public static func videoToGIF(_ url: URL, options: FileOptions = FileOptions()) async throws -> URL {
        let fps = options.gifFPS
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        let count = max(1, Int(min(duration, options.gifMaxSeconds) * fps))

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: options.gifWidth, height: options.gifWidth * 4)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let out = try destination(for: url, ext: "gif", options: options)
        guard let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.gif.identifier as CFString, count, nil) else {
            throw FileOpError.failed("Couldn't create \(out.lastPathComponent).")
        }
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let frame = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / fps]] as CFDictionary
        for i in 0..<count {
            let (image, _) = try await generator.image(at: CMTime(seconds: Double(i) / fps, preferredTimescale: 600))
            CGImageDestinationAddImage(dest, image, frame)
        }
        guard CGImageDestinationFinalize(dest) else { throw FileOpError.failed("Couldn't save \(out.lastPathComponent).") }
        return out
    }

    // MARK: Archives

    public static func zip(_ urls: [URL], options: FileOptions = FileOptions()) async throws -> URL {
        let folder = try self.folder(for: urls[0], options: options)
        let out = urls.count == 1
            ? uniqueURL(in: folder, base: urls[0].deletingPathExtension().lastPathComponent, ext: "zip")
            : uniqueURL(in: folder, base: "Archive", ext: "zip")
        // Files picked from search results or Recents can sit in different folders, so each
        // folder's files are added from that folder. Relative names keep the archive free of
        // absolute paths; the ./ stops a name like "-T" being read as a zip option.
        let byFolder = Dictionary(grouping: urls) { $0.deletingLastPathComponent() }
        for source in byFolder.keys.sorted(by: { $0.path < $1.path }) {
            let names = byFolder[source]!.map { "./" + $0.lastPathComponent }
            let result = try await Shell.run("/usr/bin/zip", ["-r", "-q", "-y", "-X", out.path] + names, cwd: source)
            guard result.status == 0 else { throw FileOpError.failed("zip failed: \(result.stderr)") }
        }
        return out
    }

    public static func unzip(_ url: URL, options: FileOptions = FileOptions()) async throws -> URL {
        let folder = try destination(for: url, ext: "", options: options)
        let result = try await Shell.run("/usr/bin/ditto", ["-x", "-k", url.path, folder.path])
        guard result.status == 0 else { throw FileOpError.failed("Couldn't extract \(url.lastPathComponent): \(result.stderr)") }
        return folder
    }
}

extension VideoQuality {
    var preset: String {
        switch self {
        case .original: AVAssetExportPresetHighestQuality
        case .p1080: AVAssetExportPreset1920x1080
        case .p720: AVAssetExportPreset1280x720
        case .small: AVAssetExportPresetMediumQuality
        }
    }
}

extension String {
    func leftPadded(to width: Int) -> String {
        String(repeating: "0", count: max(0, width - count)) + self
    }
}
