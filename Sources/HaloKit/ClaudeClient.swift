import Foundation
import ImageIO
import UniformTypeIdentifiers

/// One question for Claude: how to behave, what to do, and any files it should read.
public struct ClaudeRequest: Sendable, Equatable {
    public let system: String
    public let message: String
    public let files: [URL]

    public init(system: String, message: String, files: [URL] = []) {
        self.system = system
        self.message = message
        self.files = files
    }
}

/// Sends requests to Claude, either through the `claude` CLI so they run on the
/// user's Claude subscription, or through the Messages API with their own key.
public struct ClaudeClient: Sendable {
    public let settings: AISettings
    public let apiKey: String?

    public init(settings: AISettings, apiKey: String?) {
        self.settings = settings
        self.apiKey = apiKey
    }

    public func ask(_ request: ClaudeRequest) async throws -> String {
        let output = switch settings.provider {
        case .anthropicAPI: try await viaAPI(request)
        case .claudeCode: try await viaCLI(request)
        }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw RewriteError.empty }
        return trimmed
    }

    // MARK: Messages API

    func body(for request: ClaudeRequest) throws -> [String: Any] {
        var body: [String: Any] = [
            "model": settings.model.rawValue,
            "max_tokens": 16000,
            "system": request.system,
            "messages": [["role": "user", "content": try content(for: request)]],
            // Rewrites are short and someone is waiting on them.
            "output_config": ["effort": "low"],
        ]
        if settings.model != .haiku {
            body["fallbacks"] = "default"
        }
        return body
    }

    /// Plain text when there are no files; otherwise each file as its own block
    /// followed by the instruction.
    func content(for request: ClaudeRequest) throws -> Any {
        guard !request.files.isEmpty else { return request.message }
        var blocks = try request.files.map(Self.block(for:))
        blocks.append(["type": "text", "text": request.message])
        return blocks
    }

    static let apiImageTypes: [UTType] = [.jpeg, .png, .gif, .webP]

    static func block(for url: URL) throws -> [String: Any] {
        let type = UTType(filenameExtension: url.pathExtension) ?? .data
        let base64 = { (data: Data, mime: String) in ["type": "base64", "media_type": mime, "data": data.base64EncodedString()] }
        if type.conforms(to: .pdf) {
            return ["type": "document", "title": url.lastPathComponent, "source": base64(try Data(contentsOf: url), "application/pdf")]
        }
        if type.conforms(to: .image) {
            if apiImageTypes.contains(type), let mime = type.preferredMIMEType {
                return ["type": "image", "source": base64(try Data(contentsOf: url), mime)]
            }
            return ["type": "image", "source": base64(try jpegData(url), "image/jpeg")]
        }
        let text = String(decoding: try Data(contentsOf: url), as: UTF8.self)
        return ["type": "text", "text": "<file name=\"\(url.lastPathComponent)\">\n\(text)\n</file>"]
    }

    /// The API only takes a few image formats, so anything else (HEIC, TIFF) is re-encoded.
    static func jpegData(_ url: URL) throws -> Data {
        let data = NSMutableData()
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw FileOpError.unreadable(url.lastPathComponent) }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw FileOpError.unreadable(url.lastPathComponent) }
        return data as Data
    }

    func viaAPI(_ request: ClaudeRequest) async throws -> String {
        guard let apiKey, !apiKey.isEmpty else { throw RewriteError.missingAPIKey }

        var http = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        http.httpMethod = "POST"
        http.timeoutInterval = 120
        http.setValue("application/json", forHTTPHeaderField: "content-type")
        http.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        http.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        if settings.model != .haiku {
            http.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        }
        http.httpBody = try JSONSerialization.data(withJSONObject: body(for: request))

        let (data, response) = try await URLSession.shared.data(for: http)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

        guard status == 200 else {
            let message = (json["error"] as? [String: Any])?["message"] as? String
                ?? String(decoding: data, as: UTF8.self)
            throw RewriteError.http(status, message)
        }
        return try Self.text(fromResponse: json)
    }

    static func text(fromResponse json: [String: Any]) throws -> String {
        if json["stop_reason"] as? String == "refusal" { throw RewriteError.refused }
        let blocks = json["content"] as? [[String: Any]] ?? []
        return blocks
            .filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
    }

    // MARK: Claude Code CLI

    static let cliCandidates = [
        "~/.local/bin/claude",
        "~/.claude/local/claude",
        "/opt/homebrew/bin/claude",
        "/usr/local/bin/claude",
    ].map { NSString(string: $0).expandingTildeInPath }

    public static func findCLI() -> String? {
        cliCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Text requests get no tools at all. File requests get only Read, scoped to
    /// the folders the files are in, so Claude can look but never change anything.
    func cliArguments(for request: ClaudeRequest) -> [String] {
        var args = [
            "-p",
            "--model", settings.model.cliAlias,
            "--system-prompt", request.system,
            "--strict-mcp-config",
            "--no-session-persistence",
            "--output-format", "text",
        ]
        if request.files.isEmpty {
            args += ["--tools", ""]
        } else {
            let folders = Set(request.files.map { $0.deletingLastPathComponent().path }).sorted()
            args += ["--tools", "Read", "--allowedTools", "Read", "--add-dir"] + folders
        }
        return args
    }

    func cliMessage(for request: ClaudeRequest) -> String {
        guard !request.files.isEmpty else { return request.message }
        return request.message + "\n\nRead these files:\n" + request.files.map(\.path).joined(separator: "\n")
    }

    func viaCLI(_ request: ClaudeRequest) async throws -> String {
        guard let cli = Self.findCLI() else { throw RewriteError.claudeCodeNotFound }
        // With an API key in the environment the CLI bills that key instead of
        // the subscription, which is the whole point of this provider.
        let result = try await Shell.run(cli, cliArguments(for: request), stdin: cliMessage(for: request),
                                         cwd: FileManager.default.temporaryDirectory, unsetting: ["ANTHROPIC_API_KEY"])
        guard result.status == 0 else {
            throw RewriteError.process(result.stderr.isEmpty ? result.stdout : result.stderr)
        }
        return result.stdout
    }
}
