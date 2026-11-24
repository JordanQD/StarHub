import Foundation

struct ModDetailRaw: Codable {
    let description: String
    let changelog: String
    /// Nombre d'approbations Nexus ; `nil` dans un cache d'avant le champ.
    var endorsements: Int? = nil
    var pictureURL: String? = nil
    var releaseDates: [String: Date]? = nil

    func notes(for version: String) -> String? {
        var matchesVersion = false
        var notes: [String] = []
        for line in changelog.components(separatedBy: "\n") {
            if line.hasPrefix("**"), line.hasSuffix("**"), line.count > 4 {
                if matchesVersion { break }
                let heading = String(line.dropFirst(2).dropLast(2))
                matchesVersion = NexusUpdateChecker.compare(heading, version) == .orderedSame
            } else if matchesVersion {
                notes.append(line)
            }
        }
        let text = notes.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    func releaseDate(for version: String) -> Date? {
        releaseDates?.filter { NexusUpdateChecker.compare($0.key, version) == .orderedSame }
            .values.max()
    }
}

/// File-backed cache (Caches/) for raw mod description + changelog, keyed by
/// modId. Not UserDefaults — these blobs are large.
enum ModDetailCache {
    private static var dir: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("ModDetails", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    private static func file(_ modId: Int) -> URL { dir.appendingPathComponent("\(modId).json") }

    static func load(modId: Int) -> ModDetailRaw? {
        guard let data = try? Data(contentsOf: file(modId)) else { return nil }
        return try? JSONDecoder().decode(ModDetailRaw.self, from: data)
    }
    static func save(modId: Int, _ raw: ModDetailRaw) {
        if let data = try? JSONEncoder().encode(raw) { try? data.write(to: file(modId), options: .atomic) }
    }
}
