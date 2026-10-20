import Foundation

/// Mac-wide tools for the Everywhere ring.
@MainActor
enum SystemActions {
    private static var caffeinate: Process?

    /// Holds the Mac and display awake until called again. Returns the new state.
    static func toggleKeepAwake() -> Bool {
        if let process = caffeinate {
            process.terminate()
            caffeinate = nil
            return false
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        // -w ties it to Halo, so quitting Halo lets the Mac sleep again.
        process.arguments = ["-di", "-w", String(ProcessInfo.processInfo.processIdentifier)]
        try? process.run()
        caffeinate = process.isRunning ? process : nil
        return caffeinate != nil
    }
}
