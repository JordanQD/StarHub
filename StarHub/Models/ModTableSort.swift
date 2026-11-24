import Foundation

struct ModTableEntry: Identifiable {
    let mod: ModItem
    let type: String
    let version: String
    let updated: Date?
    let bytes: Int64?
    let update: PendingModUpdates.Pending?

    var id: String { mod.id }
}

struct ModTableSort: SortComparator {
    enum Column: Hashable { case update, name, type, version, updated, size, enabled }

    let column: Column
    var order: SortOrder = .forward

    func compare(_ lhs: ModTableEntry, _ rhs: ModTableEntry) -> ComparisonResult {
        let result: ComparisonResult
        switch column {
        case .update:
            return compareKnown(lhs.update?.availableVersion, rhs.update?.availableVersion,
                                using: NexusUpdateChecker.compare)
        case .name: result = lhs.mod.name.localizedStandardCompare(rhs.mod.name)
        case .type: result = lhs.type.localizedStandardCompare(rhs.type)
        case .version: result = NexusUpdateChecker.compare(lhs.version, rhs.version)
        case .updated: return compareKnown(lhs.updated, rhs.updated, using: compareValues)
        case .size: return compareKnown(lhs.bytes, rhs.bytes, using: compareValues)
        case .enabled: result = compareValues(lhs.mod.isEnabled ? 1 : 0, rhs.mod.isEnabled ? 1 : 0)
        }
        return directed(result)
    }

    private func compareKnown<T>(_ lhs: T?, _ rhs: T?,
                                 using compare: (T, T) -> ComparisonResult) -> ComparisonResult {
        switch (lhs, rhs) {
        case let (lhs?, rhs?): return directed(compare(lhs, rhs))
        case (.some, nil): return .orderedAscending
        case (nil, .some): return .orderedDescending
        case (nil, nil): return .orderedSame
        }
    }

    private func compareValues<T: Comparable>(_ lhs: T, _ rhs: T) -> ComparisonResult {
        if lhs < rhs { return .orderedAscending }
        return lhs == rhs ? .orderedSame : .orderedDescending
    }

    private func directed(_ result: ComparisonResult) -> ComparisonResult {
        guard order == .reverse, result != .orderedSame else { return result }
        return result == .orderedAscending ? .orderedDescending : .orderedAscending
    }

    static func sorted(_ rows: [ModTableEntry], by order: [Self]) -> [ModTableEntry] {
        rows.sorted { lhs, rhs in
            if lhs.mod.isStarHubProbe != rhs.mod.isStarHubProbe { return lhs.mod.isStarHubProbe }
            for comparator in order {
                let result = comparator.compare(lhs, rhs)
                if result != .orderedSame { return result == .orderedAscending }
            }
            let name = lhs.mod.name.localizedStandardCompare(rhs.mod.name)
            return name == .orderedSame ? lhs.id < rhs.id : name == .orderedAscending
        }
    }
}
