import AppKit
import HaloKit

/// Runs a chosen ring action and reports through the HUD.
@MainActor
final class ActionRunner {
    private unowned let model: AppModel
    let hud = HUD()

    init(model: AppModel) {
        self.model = model
    }

    func run(_ id: String, context: RingContext, at point: NSPoint) {
        hud.successDuration = model.settings.behavior.hudDuration
        Task {
            do {
                try await perform(id, context: context, at: point)
            } catch is CancellationError {
                hud.hide()
            } catch {
                hud.show(.failure(error.localizedDescription), at: point)
            }
        }
    }

    private func perform(_ id: String, context: RingContext, at point: NSPoint) async throws {
        let info = model.settings.info(id)
        if let custom = model.settings.customActions.first(where: { $0.actionID == id }) {
            return try await runCustom(custom, context: context, at: point)
        }
        if let keys = info?.keys {
            guard requireAccessibility(at: point) else { return }
            return ContextReader.press(keys)
        }
        if let link = info?.link {
            NSWorkspace.shared.open(link)
            return
        }

        switch (id, context) {
        case let (_, .text(text)) where info?.category == .ai:
            try await rewrite(id, text: text, at: point)

        case let (_, .text(text)) where id.hasPrefix("text."):
            try await textTool(id, text: text, at: point)

        case let (_, .files(files)) where id.hasPrefix("file.ai"):
            let working = switch id {
            case "file.aiRename": "Claude is naming…"
            case "file.aiNotes": "Claude is writing notes…"
            case "file.aiFlashcards": "Claude is making flashcards…"
            default: "Claude is reading…"
            }
            hud.show(.working(working), at: point)
            finish(try await FileAI.run(id, on: files, client: client, options: model.settings.files))

        case let ("file.openCursor", .files(files)):
            open(app: Apps.cursor, files: files)

        case let ("file.openVSCode", .files(files)):
            open(app: Apps.vscode, files: files)

        case let (_, .files(files)) where id.hasPrefix("file.") || id.hasPrefix("convert."):
            hud.show(.working(files.count == 1 ? "Working on \(files[0].lastPathComponent)…" : "Working on \(files.count) files…"), at: point)
            finish(try await FileOps.run(id, on: files, options: model.settings.files))

        case ("general.screenshot", _), ("general.screenshotWindow", _):
            let board = NSPasteboard.general.changeCount
            _ = try await Shell.run("/usr/sbin/screencapture", id == "general.screenshot" ? ["-i", "-c"] : ["-i", "-w", "-c"])
            if NSPasteboard.general.changeCount != board {
                hud.show(.success("Screenshot copied"), at: point)
            }

        case ("general.screenText", _):
            try await grabText(at: point)

        case ("general.colorPicker", _):
            pickColor(at: point)

        case ("general.polishClipboard", _):
            guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
                hud.show(.failure("The clipboard has no text"), at: point)
                return
            }
            hud.show(.working("Polishing clipboard…"), at: point)
            let result = try await client.ask(RewriteRequest.forAction(id, text: text, settings: model.settings)!.claude)
            copy(result)
            hud.update(.success("Clipboard polished"))

        case ("general.pastePlain", _):
            guard let text = NSPasteboard.general.string(forType: .string) else { return }
            guard requireAccessibility(at: point) else { return }
            await ContextReader.paste(text)

        case ("general.keepAwake", _):
            model.keepingAwake = SystemActions.toggleKeepAwake()
            hud.show(.success(model.keepingAwake ? "Staying awake until you turn it off" : "Mac can sleep again"), at: point)

        case ("general.displaySleep", _):
            _ = try await Shell.run("/usr/bin/pmset", ["displaysleepnow"])

        case ("general.claude", _):
            open(app: Apps.claude, files: [])

        case ("general.downloads", _):
            NSWorkspace.shared.open(FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0])

        case ("general.settings", _):
            model.openSettings()

        default:
            break
        }
    }

    private var client: ClaudeClient {
        let ai = model.settings.ai
        return ClaudeClient(settings: ai, apiKey: ai.provider == .anthropicAPI ? Keychain.apiKey() : nil)
    }

    private func finish(_ result: FileOpResult) {
        hud.update(.success(result.message))
        if model.settings.files.revealResult, !result.outputs.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(result.outputs)
        }
    }

    private func open(app bundleID: String, files: [URL]) {
        guard let app = Apps.url(bundleID) else { return }
        if files.isEmpty {
            NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
        } else {
            NSWorkspace.shared.open(files, withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func rewrite(_ id: String, text: String, at point: NSPoint) async throws {
        guard let request = RewriteRequest.forAction(id, text: text, settings: model.settings) else { return }
        guard request.copiesResult || requireAccessibility(at: point) else { return }

        hud.show(.working(request.copiesResult ? "Thinking…" : "Rewriting…"), at: point)
        let result = try await client.ask(request.claude)

        if request.copiesResult {
            copy(result)
            hud.update(.success("Copied to clipboard"))
        } else {
            hud.hide()
            await ContextReader.paste(result)
        }
    }

    private func textTool(_ id: String, text: String, at point: NSPoint) async throws {
        switch try TextTools.run(id, on: text) {
        case let .replace(result):
            guard requireAccessibility(at: point) else { return }
            await ContextReader.paste(result)
        case let .message(message):
            hud.show(.success(message), at: point)
        case let .open(url):
            NSWorkspace.shared.open(url)
        }
    }

    /// Lets the user drag over any part of the screen and copies the text in it.
    private func grabText(at point: NSPoint) async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("halo-grab-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: file) }
        _ = try await Shell.run("/usr/sbin/screencapture", ["-i", "-x", file.path])
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        let text = try FileOps.recognizeText(file)
        guard !text.isEmpty else { throw FileOpError.failed("No text found there.") }
        copy(text)
        hud.show(.success("Text copied"), at: point)
    }

    private func runCustom(_ action: CustomAction, context: RingContext, at point: NSPoint) async throws {
        switch action.kind {
        case .prompt:
            guard case let .text(text) = context else { return }
            try await rewrite(action.actionID, text: text, at: point)
        case let .keys(combo):
            guard requireAccessibility(at: point) else { return }
            ContextReader.press(combo)
        case let .url(string):
            guard let url = URL(string: string.contains("://") ? string : "https://\(string)") else {
                throw FileOpError.failed("“\(string)” isn't a link.")
            }
            NSWorkspace.shared.open(url)
        case let .shortcut(name):
            hud.show(.working("Running \(name)…"), at: point)
            let result = try await Shell.run("/usr/bin/shortcuts", ["run", name])
            guard result.status == 0 else { throw FileOpError.failed(result.stderr.isEmpty ? "Shortcut failed." : result.stderr) }
            hud.update(.success("Ran \(name)"))
        case let .shell(command):
            hud.show(.working("Running \(action.title)…"), at: point)
            // The selection rides along so scripts can act on it.
            var env: [String: String] = [:]
            if case let .text(text) = context { env["HALO_TEXT"] = text }
            if case let .files(files) = context { env["HALO_FILES"] = files.map(\.path).joined(separator: "\n") }
            let result = try await Shell.run("/bin/zsh", ["-lc", command], environment: env)
            guard result.status == 0 else {
                throw FileOpError.failed(result.stderr.isEmpty ? "Exited with status \(result.status)." : result.stderr)
            }
            let firstLine = result.stdout.split(separator: "\n").first.map(String.init)
            hud.update(.success(firstLine ?? "Done"))
        case let .openApp(path):
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
        }
    }

    /// Pasting and pressing shortcuts means posting keystrokes into another app,
    /// which macOS only allows once Halo is trusted for Accessibility.
    private func requireAccessibility(at point: NSPoint) -> Bool {
        guard !Permissions.accessibility else { return true }
        hud.show(.failure("Allow Halo in Accessibility settings first"), at: point)
        model.openSettings(.permissions)
        return false
    }

    private func pickColor(at point: NSPoint) {
        NSColorSampler().show { [weak self] color in
            MainActor.assumeIsolated { self?.copyHex(color, at: point) }
        }
    }

    private func copyHex(_ color: NSColor?, at point: NSPoint) {
        guard let rgb = color?.usingColorSpace(.sRGB) else { return }
        let hex = String(format: "#%02X%02X%02X",
                         Int((rgb.redComponent * 255).rounded()),
                         Int((rgb.greenComponent * 255).rounded()),
                         Int((rgb.blueComponent * 255).rounded()))
        copy(hex)
        hud.show(.success("\(hex) copied"), at: point)
    }
}
