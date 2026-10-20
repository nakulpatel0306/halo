import Foundation

public enum Shell {
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
    }

    /// Runs a program without a shell, so file names never need quoting.
    public static func run(_ path: String, _ args: [String], stdin: String? = nil, cwd: URL? = nil, unsetting: [String] = [],
                           environment: [String: String] = [:]) async throws -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        if let cwd { process.currentDirectoryURL = cwd }

        // Apps launched from Finder get a bare PATH; tools like `claude` expect a normal one.
        var env = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        env["PATH"] = ["\(home)/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
            .joined(separator: ":")
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
            if let stdin { input.fileHandleForWriting.write(Data(stdin.utf8)) }
            try? input.fileHandleForWriting.close()
        }
    }
}
