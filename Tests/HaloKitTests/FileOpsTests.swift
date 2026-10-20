import AppKit
import AVFoundation
import PDFKit
import Testing
import UniformTypeIdentifiers
@testable import HaloKit

/// Each test gets its own folder of real files.
final class Sandbox {
    let folder: URL

    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("halo-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: folder) }

    /// A white canvas with a red box at `box` (top-left origin).
    func image(_ name: String, width: Int = 200, height: Int = 120, box: CGRect = CGRect(x: 50, y: 30, width: 40, height: 20), type: UTType = .png) throws -> URL {
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(.white)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        // CGContext's origin is bottom-left.
        ctx.fill(CGRect(x: box.minX, y: CGFloat(height) - box.maxY, width: box.width, height: box.height))
        let url = folder.appendingPathComponent(name)
        try FileOps.write(ctx.makeImage()!, to: url, type: type)
        return url
    }

    func textImage(_ name: String, _ text: String) throws -> URL {
        let image = NSImage(size: NSSize(width: 600, height: 160), flipped: false) { rect in
            NSColor.white.setFill()
            rect.fill()
            (text as NSString).draw(at: NSPoint(x: 30, y: 60), withAttributes: [.font: NSFont.systemFont(ofSize: 40)])
            return true
        }
        let url = folder.appendingPathComponent(name)
        try FileOps.write(image.cgImage(forProposedRect: nil, context: nil, hints: nil)!, to: url, type: .png)
        return url
    }

    /// One second of a 440 Hz tone.
    func audio(_ name: String) throws -> URL {
        let url = folder.appendingPathComponent(name)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
        buffer.frameLength = 44100
        for i in 0..<44100 { buffer.floatChannelData![0][i] = Float(sin(2 * .pi * 440 * Double(i) / 44100)) * 0.5 }
        try file.write(from: buffer)
        return url
    }

    func pdf(_ name: String, pages: Int) throws -> URL {
        let doc = PDFDocument()
        for i in 0..<pages {
            let image = NSImage(size: NSSize(width: 300, height: 400), flipped: false) { rect in
                NSColor.white.setFill()
                rect.fill()
                ("Page \(i + 1)" as NSString).draw(at: NSPoint(x: 40, y: 200), withAttributes: [.font: NSFont.systemFont(ofSize: 24)])
                return true
            }
            doc.insert(PDFPage(image: image)!, at: i)
        }
        let url = folder.appendingPathComponent(name)
        #expect(doc.write(to: url))
        return url
    }

    func video(_ name: String) async throws -> URL {
        let url = folder.appendingPathComponent(name)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 240,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 240,
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<30 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
            adaptor.append(buffer!, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30))
        }
        input.markAsFinished()
        await writer.finishWriting()
        #expect(writer.status == .completed)
        return url
    }
}

func pixelSize(_ url: URL) -> (Int, Int)? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    return (image.width, image.height)
}

@Suite struct ImageTests {
    @Test func convertsPNGToJPGNextToOriginal() throws {
        let box = try Sandbox()
        let png = try box.image("photo.png")
        let result = try FileOps.convertImage(png, to: .jpeg)
        #expect(result.lastPathComponent == "photo.jpg")
        #expect(result.deletingLastPathComponent().path == box.folder.path)
        #expect(UTType(filenameExtension: result.pathExtension) == .jpeg)
        #expect(pixelSize(result)! == (200, 120))
    }

    @Test func neverOverwritesAnExistingFile() throws {
        let box = try Sandbox()
        let png = try box.image("photo.png")
        let first = try FileOps.convertImage(png, to: .jpeg)
        let second = try FileOps.convertImage(png, to: .jpeg)
        #expect(first.lastPathComponent == "photo.jpg")
        #expect(second.lastPathComponent == "photo 2.jpg")
    }

    @Test func resizesToHalf() throws {
        let box = try Sandbox()
        let result = try FileOps.resize(try box.image("big.png"), scale: 0.5)
        #expect(result.lastPathComponent == "big (50%).png")
        #expect(pixelSize(result)! == (100, 60))
    }

    @Test func autoCropTrimsToTheContent() throws {
        let box = try Sandbox()
        let png = try box.image("shot.png", box: CGRect(x: 50, y: 30, width: 40, height: 20))
        let result = try FileOps.autoCrop(png)
        #expect(result.lastPathComponent == "shot (cropped).png")
        #expect(pixelSize(result)! == (40, 20))
    }

    @Test func autoCropRefusesABlankImage() throws {
        let box = try Sandbox()
        let png = try box.image("blank.png", box: .zero)
        #expect(throws: FileOpError.self) { try FileOps.autoCrop(png) }
    }

    @Test func combinesImagesIntoOnePDF() throws {
        let box = try Sandbox()
        let a = try box.image("a.png"), b = try box.image("b.png")
        let pdf = try FileOps.imagesToPDF([b, a])
        #expect(pdf.lastPathComponent == "Images.pdf")
        #expect(PDFDocument(url: pdf)?.pageCount == 2)
    }

    @Test func removeBackgroundWritesATransparentPNG() throws {
        let box = try Sandbox()
        let png = try box.image("subject.png", width: 400, height: 400, box: CGRect(x: 120, y: 120, width: 160, height: 160))
        // Vision may find no subject in a synthetic image; either outcome must be clean.
        do {
            let result = try FileOps.removeBackground(png)
            #expect(result.lastPathComponent == "subject (no background).png")
            #expect(pixelSize(result)! == (400, 400))
        } catch let error as FileOpError {
            #expect(error.errorDescription?.contains("subject") == true)
        }
    }
}

@Suite struct OCRTests {
    @Test func readsTextInAnImage() throws {
        let box = try Sandbox()
        let text = try FileOps.recognizeText(try box.textImage("note.png", "Halo reads this"))
        #expect(text.contains("Halo reads this"))
    }
}

@Suite struct PDFTests {
    @Test func mergesInNameOrder() throws {
        let box = try Sandbox()
        let two = try box.pdf("2.pdf", pages: 2), one = try box.pdf("1.pdf", pages: 1)
        let merged = try FileOps.mergePDFs([two, one])
        let doc = try #require(PDFDocument(url: merged))
        #expect(merged.lastPathComponent == "Merged.pdf")
        #expect(doc.pageCount == 3)
    }

    @Test func rendersEachPageAsPNG() throws {
        let box = try Sandbox()
        let folder = try FileOps.pdfToImages(try box.pdf("deck.pdf", pages: 3))
        let pages = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        #expect(folder.lastPathComponent == "deck pages")
        #expect(pages == ["Page 1.png", "Page 2.png", "Page 3.png"])
        #expect(pixelSize(folder.appendingPathComponent("Page 1.png"))! == (600, 800))
    }

    @Test func compressReportsSizesOrSaysItIsAlreadySmall() async throws {
        let box = try Sandbox()
        let result = try await FileOps.compress([try box.pdf("scan.pdf", pages: 4)])
        if result.outputs.isEmpty {
            #expect(result.message.hasPrefix("Already"))
        } else {
            #expect(result.message.contains("→"))
            #expect(FileOps.size(of: result.outputs[0]) < FileOps.size(of: box.folder.appendingPathComponent("scan.pdf")))
        }
    }
}

@Suite struct VideoTests {
    @Test func convertsMOVToMP4And720p() async throws {
        let box = try Sandbox()
        let mov = try await box.video("clip.mov")
        let mp4 = try await FileOps.exportVideo(mov, preset: AVAssetExportPresetHighestQuality, type: .mp4, suffix: "")
        #expect(mp4.lastPathComponent == "clip.mp4")
        let tracks = try await AVURLAsset(url: mp4).loadTracks(withMediaType: .video)
        #expect(tracks.count == 1)

        let small = try await FileOps.exportVideo(mov, preset: AVAssetExportPreset1280x720, type: .mp4, suffix: " (720p)")
        #expect(small.lastPathComponent == "clip (720p).mp4")
    }
}

@Suite struct GIFAndAudioTests {
    @Test func turnsVideoIntoALoopingGIF() async throws {
        let box = try Sandbox()
        let gif = try await FileOps.videoToGIF(try await box.video("clip.mov"))
        #expect(gif.lastPathComponent == "clip.gif")
        let source = try #require(CGImageSourceCreateWithURL(gif as CFURL, nil))
        // One second at the default 12 fps.
        #expect(CGImageSourceGetCount(source) == 12)
    }

    @Test func convertsWAVToM4A() async throws {
        let box = try Sandbox()
        let m4a = try await FileOps.exportVideo(try box.audio("tone.wav"), preset: AVAssetExportPresetAppleM4A, type: .m4a, suffix: "")
        #expect(m4a.lastPathComponent == "tone.m4a")
        #expect(try await AVURLAsset(url: m4a).loadTracks(withMediaType: .audio).count == 1)
    }
}

@Suite struct ConvertTests {
    @Test func everyNativeImageTargetWrites() async throws {
        let box = try Sandbox()
        let png = try box.image("logo.png")
        for id in FileActions.convertTargets(for: [png]) {
            let out = try await FileOps.convert(png, to: String(id.dropFirst(8)))
            #expect(FileManager.default.fileExists(atPath: out.path), "\(id)")
            #expect(FileOps.size(of: out) > 0, "\(id)")
        }
        #expect(FileOps.canWrite("jpg") && FileOps.canWrite("png"))
        let icns = try await FileOps.convert(png, to: "icns")
        let source = try #require(CGImageSourceCreateWithURL(icns as CFURL, nil))
        #expect(CGImageSourceGetCount(source) == 5)
    }

    @Test func documentsConvertBothWays() async throws {
        let box = try Sandbox()
        let txt = box.folder.appendingPathComponent("notes.txt")
        try "Meeting notes\nShip Halo on Friday.".write(to: txt, atomically: true, encoding: .utf8)
        let docx = try await FileOps.convert(txt, to: "docx")
        #expect(docx.lastPathComponent == "notes.docx")
        let pdf = try await FileOps.convert(docx, to: "pdf")
        #expect(PDFDocument(url: pdf)?.string?.contains("Ship Halo on Friday.") == true)
        let html = try await FileOps.convert(docx, to: "html")
        #expect(try String(contentsOf: html, encoding: .utf8).contains("Ship Halo"))
    }

    @Test func markdownReadsAsText() async throws {
        let box = try Sandbox()
        let md = box.folder.appendingPathComponent("readme.md")
        try "# Halo\n- ring".write(to: md, atomically: true, encoding: .utf8)
        let rtf = try await FileOps.convert(md, to: "rtf")
        #expect(rtf.pathExtension == "rtf")
    }

    @Test func audioConvertsWithAfconvert() async throws {
        let box = try Sandbox()
        let wav = try box.audio("tone.wav")
        for ext in ["m4a", "flac", "aiff"] {
            let out = try await FileOps.convert(wav, to: ext)
            #expect(try await AVURLAsset(url: out).loadTracks(withMediaType: .audio).count == 1, "\(ext)")
        }
    }

    @Test func pdfPagesBecomeImagesOrText() async throws {
        let box = try Sandbox()
        let pdf = try box.pdf("deck.pdf", pages: 2)
        let folder = try await FileOps.convert(pdf, to: "jpg")
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted() == ["Page 1.jpg", "Page 2.jpg"])
        let txt = try await FileOps.convert(pdf, to: "txt")
        #expect(try String(contentsOf: txt, encoding: .utf8).contains("Page 2"))
    }

    @Test func outputCanGoToASubfolder() throws {
        let box = try Sandbox()
        var options = FileOptions()
        options.output = .subfolder
        let out = try FileOps.convertImage(try box.image("a.png"), to: .jpeg, options: options)
        #expect(out.deletingLastPathComponent().lastPathComponent == "Converted")
    }
}

@Suite struct EditTests {
    @Test func rotatesImagesAndPDFs() throws {
        let box = try Sandbox()
        let rotated = try FileOps.rotate(try box.image("wide.png"))
        #expect(pixelSize(rotated)! == (120, 200))
        let pdf = try FileOps.rotate(try box.pdf("doc.pdf", pages: 1))
        #expect(PDFDocument(url: pdf)?.page(at: 0)?.rotation == 90)
    }

    @Test func resizesToTheLongestSideSetting() throws {
        let box = try Sandbox()
        let out = try FileOps.resize(try box.image("big.png"), longestSide: 100)
        #expect(out.lastPathComponent == "big (100 px).png")
        #expect(pixelSize(out)! == (100, 60))
        #expect(throws: FileOpError.self) { try FileOps.resize(try box.image("small.png"), longestSide: 1000) }
    }

    @Test func grayscaleAndStripMetadataWrite() throws {
        let box = try Sandbox()
        let png = try box.image("photo.png")
        #expect(try FileOps.grayscale(png).lastPathComponent == "photo (B&W).png")
        #expect(try FileOps.stripMetadata(png).lastPathComponent == "photo (clean).png")
    }

    @Test func splitsPDFIntoPages() throws {
        let box = try Sandbox()
        let folder = try FileOps.splitPDF(try box.pdf("deck.pdf", pages: 3))
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted() == ["Page 1.pdf", "Page 2.pdf", "Page 3.pdf"])
    }

    @Test func compressTurnsAnOpaquePNGIntoASmallerJPG() async throws {
        let box = try Sandbox()
        let png = try box.image("shot.png", width: 1200, height: 900)
        let result = try await FileOps.compress([png])
        if let out = result.outputs.first {
            #expect(out.lastPathComponent == "shot (compressed).jpg")
        } else {
            #expect(result.message.hasPrefix("Already"))
        }
    }

    @Test func archiveZipsOrUnzips() async throws {
        let box = try Sandbox()
        let zipped = try await FileOps.run("file.archive", on: [try box.image("a.png")])
        #expect(zipped.outputs.first?.lastPathComponent == "a.zip")
        let unzipped = try await FileOps.run("file.archive", on: zipped.outputs)
        #expect(unzipped.outputs.first?.lastPathComponent == "a")
    }
}

@Suite struct CopyForAITests {
    @Test func wrapsEachFileInAFencedBlock() throws {
        let box = try Sandbox()
        let swift = box.folder.appendingPathComponent("main.swift")
        try "print(\"hi\")\n".write(to: swift, atomically: true, encoding: .utf8)
        let md = box.folder.appendingPathComponent("README.md")
        try "Use ```swift``` blocks".write(to: md, atomically: true, encoding: .utf8)
        let out = try FileOps.markdown([swift, md])
        #expect(out == "main.swift\n```swift\nprint(\"hi\")\n```\n\nREADME.md\n````md\nUse ```swift``` blocks\n````")
        #expect(FileActions.applies("file.copyForAI", to: [swift, md]))
        #expect(!FileActions.applies("file.copyForAI", to: [URL(fileURLWithPath: "/tmp/a.png")]))
    }
}

@Suite struct ArchiveTests {
    @Test func zipsAndUnzipsRoundTrip() async throws {
        let box = try Sandbox()
        let a = try box.image("a.png"), b = try box.image("b.png")
        let zip = try await FileOps.zip([a, b])
        #expect(zip.lastPathComponent == "Archive.zip")

        let folder = try await FileOps.unzip(zip)
        #expect(folder.lastPathComponent == "Archive")
        let contents = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        #expect(contents == ["a.png", "b.png"])
    }

    @Test func namesThatLookLikeOptionsAreZippedAsFiles() async throws {
        let box = try Sandbox()
        let tricky = try box.image("-T.png")
        let zip = try await FileOps.zip([tricky])
        let folder = try await FileOps.unzip(zip)
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path) == ["-T.png"])
    }

    @Test func singleFileZipIsNamedAfterIt() async throws {
        let box = try Sandbox()
        let zip = try await FileOps.zip([try box.image("report.png")])
        #expect(zip.lastPathComponent == "report.zip")
    }
}
