import Foundation

public enum Shell {
    /// Where Halo looks for command-line tools: the user's own shell PATH, so tools installed
    /// with nvm, asdf or a custom npm prefix are found, then the usual install folders.
    public static let searchPath: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fallback = ["\(home)/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        return merged(loginShellPath() ?? [], fallback)
    }()

    /// Keeps the first occurrence of each folder, in order.
    public static func merged(_ first: [String], _ second: [String]) -> [String] {
        var seen = Set<String>()
        return (first + second).filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// The PATH an interactive login shell would have. Markers fence it off from anything the
    /// user's shell config prints, and a timeout stops a slow config from holding Halo up.
    static func loginShellPath(timeout: TimeInterval = 3) -> [String]? {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-ilc", "printf '__HALO_PATH__%s__HALO_PATH__' \"$PATH\""]
        let out = Pipe()
        process.standardOutput = out
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        let done = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in done.signal() }
        guard (try? process.run()) != nil else { return nil }
        guard done.wait(timeout: .now() + timeout) == .success else {
            process.terminate()
            return nil
        }
        return pathFromMarkers(String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))
    }

    static func pathFromMarkers(_ output: String) -> [String]? {
        let parts = output.components(separatedBy: "__HALO_PATH__")
        guard parts.count >= 3, !parts[1].isEmpty else { return nil }
        return parts[1].split(separator: ":").map(String.init)
    }

    /// The first executable called `name` on the search path.
    public static func which(_ name: String, in dirs: [String] = searchPath) -> String? {
        dirs.lazy.map { ($0 as NSString).appendingPathComponent(name) }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public struct Result: Sendable {
        public let status: Int32
        public let stdout: String
        public let stderr: String
    }

    /// Each field is written by one reader thread and read only after the group
    /// finishes, so the unchecked conformance is safe.
    private final class Output: @unchecked Sendable {
        var stdout = Data()
        var stderr = Data()
        var timedOut = false
    }

    public enum Failure: LocalizedError {
        case timedOut(TimeInterval)

        public var errorDescription: String? {
            switch self {
            case let .timedOut(seconds): "Gave up after \(Int(seconds)) seconds without an answer."
            }
        }
    }

    /// Runs a program without a shell, so file names never need quoting.
    /// `timeout` stops a process that hangs, so the HUD can report it instead of waiting forever.
    public static func run(_ path: String, _ args: [String], stdin: String? = nil, cwd: URL? = nil, unsetting: [String] = [],
                           environment: [String: String] = [:], timeout: TimeInterval? = nil) async throws -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        if let cwd { process.currentDirectoryURL = cwd }

        // Apps launched from Finder get a bare PATH; tools like `claude` expect a normal one.
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = searchPath.joined(separator: ":")
        for name in unsetting { env[name] = nil }
        env.merge(environment) { _, new in new }
        process.environment = env

        let out = Pipe(), err = Pipe(), input = Pipe()
        process.standardOutput = out
        process.standardError = err
        process.standardInput = input

        return try await withCheckedThrowingContinuation { continuation in
            // Read both pipes while the process runs so a large output can't fill
            // the pipe buffer and deadlock it.
            let group = DispatchGroup()
            let output = Output()
            group.enter()
            DispatchQueue.global().async {
                output.stdout = out.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }
            group.enter()
            DispatchQueue.global().async {
                output.stderr = err.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }

            process.terminationHandler = { process in
                group.notify(queue: .global()) {
                    if output.timedOut, let timeout { return continuation.resume(throwing: Failure.timedOut(timeout)) }
                    continuation.resume(returning: Result(
                        status: process.terminationStatus,
                        stdout: String(decoding: output.stdout, as: UTF8.self),
                        stderr: String(decoding: output.stderr, as: UTF8.self)
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
                return
            }
            if let timeout {
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    guard process.isRunning else { return }
                    output.timedOut = true
                    process.terminate()
                }
            }
            // A process can exit before reading all its input; the throwing write turns that into an
            // error rather than an exception (the app ignores SIGPIPE so it isn't killed either).
            if let stdin { try? input.fileHandleForWriting.write(contentsOf: Data(stdin.utf8)) }
            try? input.fileHandleForWriting.close()
        }
    }
}
