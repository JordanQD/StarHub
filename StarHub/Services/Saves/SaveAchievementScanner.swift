import Foundation

/// Lightweight, off-main-thread scanner that extracts unlocked Stardew Valley
/// achievement IDs (`<achievements><int>N</int></achievements>`) and the most
/// recent save modification date across all local saves.
public enum SaveAchievementScanner {

    public struct Snapshot: Equatable, Sendable {
        public let unlockedIDs: Set<Int>
        public let lastPlayed: Date?
        public let saveCount: Int

        public static let empty = Snapshot(unlockedIDs: [], lastPlayed: nil, saveCount: 0)

        public init(unlockedIDs: Set<Int>, lastPlayed: Date?, saveCount: Int) {
            self.unlockedIDs = unlockedIDs
            self.lastPlayed = lastPlayed
            self.saveCount = saveCount
        }
    }

    /// Scans all save folders inside `savesDirectory`, preferring the small
    /// `SaveGameInfo` XML file and falling back to the main save file.
    public static func scan(in savesDirectory: URL) -> Snapshot {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: savesDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return .empty
        }

        var unlocked: Set<Int> = []
        var latestDate: Date?
        var saveCount = 0

        for dir in entries {
            guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                continue
            }
            let infoURL = dir.appendingPathComponent("SaveGameInfo")
            let mainURL = dir.appendingPathComponent(dir.lastPathComponent)
            let targetURL: URL
            if fm.fileExists(atPath: infoURL.path) {
                targetURL = infoURL
            } else if fm.fileExists(atPath: mainURL.path) {
                targetURL = mainURL
            } else {
                continue
            }

            saveCount += 1

            // Track latest modification date across SaveGameInfo and main save.
            for candidate in [infoURL, mainURL] {
                if let date = try? candidate.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                    if let current = latestDate {
                        if date > current { latestDate = date }
                    } else {
                        latestDate = date
                    }
                }
            }

            if let data = try? Data(contentsOf: targetURL),
               let xml = String(data: data, encoding: .utf8) {
                unlocked.formUnion(parseAchievementIDs(from: xml))
            }
        }

        return Snapshot(unlockedIDs: unlocked, lastPlayed: latestDate, saveCount: saveCount)
    }

    /// Parses `<achievements><int>...</int></achievements>` from Stardew XML.
    public static func parseAchievementIDs(from xml: String) -> Set<Int> {
        guard let openRange = xml.range(of: "<achievements>"),
              let closeRange = xml.range(of: "</achievements>", range: openRange.upperBound..<xml.endIndex)
        else {
            return []
        }

        let block = xml[openRange.upperBound..<closeRange.lowerBound]
        var result: Set<Int> = []
        var cursor = block.startIndex

        while let intStart = block.range(of: "<int>", range: cursor..<block.endIndex),
              let intEnd = block.range(of: "</int>", range: intStart.upperBound..<block.endIndex) {
            let raw = block[intStart.upperBound..<intEnd.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let value = Int(raw) {
                result.insert(value)
            }
            cursor = intEnd.upperBound
        }

        return result
    }
}
