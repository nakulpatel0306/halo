import Foundation

/// Whether a newer Halo is out, from the latest GitHub release. Halo isn't on the App Store,
/// so without this nobody would hear about fixes.
public enum Updates {
    public struct Release: Equatable, Sendable {
        public let version: String
        public let page: URL
    }

    static let latestURL = URL(string: "https://api.github.com/repos/nakulpatel0306/halo/releases/latest")!

    /// Compares dotted versions numerically, ignoring a leading "v", so 1.0.10 is newer than 1.0.9.
    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        let parts = { (v: String) in v.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).split(separator: ".").map { Int($0) ?? 0 } }
        let a = parts(candidate), b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    static func release(from json: [String: Any]) -> Release? {
        guard let tag = json["tag_name"] as? String,
              let page = (json["html_url"] as? String).flatMap(URL.init(string:))
        else { return nil }
        return Release(version: tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV")), page: page)
    }

    /// The latest release if it's newer than `current`, `nil` if Halo is up to date.
    public static func check(current: String) async throws -> Release? {
        var request = URLRequest(url: latestURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any], let release = release(from: json) else {
            throw URLError(.cannotParseResponse)
        }
        return isNewer(release.version, than: current) ? release : nil
    }
}
