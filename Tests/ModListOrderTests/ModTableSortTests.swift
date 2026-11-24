import Foundation
import Testing
@testable import StarHubTHCore

struct ModTableSortTests {
    @Test func sizesSortNumericallyAndUnknownSizesStayLast() {
        let rows = [row("Unknown"), row("Big", bytes: 10_000), row("Small", bytes: 900)]
        #expect(ModTableSort.sorted(rows, by: [.init(column: .size)]).map(\.id) == ["Small", "Big", "Unknown"])
        #expect(ModTableSort.sorted(rows, by: [.init(column: .size, order: .reverse)]).map(\.id)
                == ["Big", "Small", "Unknown"])
    }

    @Test func versionSortUsesTheDisplayedVersionAndSemverOrder() {
        let rows = [row("New", version: "1.10"), row("Beta", version: "1.10-beta"), row("Old", version: "1.2")]
        #expect(ModTableSort.sorted(rows, by: [.init(column: .version)]).map(\.id) == ["Old", "Beta", "New"])
    }

    @Test func availableUpdatesAppearBeforeRowsWithoutUpdates() {
        let pending = PendingModUpdates(nexus: [("new", "2.0"), ("old", "1.0")], smapi: [])
        let rows = [row("new", pending: pending), row("none", pending: pending), row("old", pending: pending)]
        #expect(ModTableSort.sorted(rows, by: [.init(column: .update, order: .reverse)]).map(\.id)
                == ["new", "old", "none"])
    }

    private func row(_ name: String, version: String = "0", bytes: Int64? = nil,
                     pending: PendingModUpdates = .empty) -> ModTableEntry {
        let mod = ModItem(uniqueId: name, name: name, folderName: name, version: "0", author: "",
                          description: "", nexusUrl: "", nexusModId: "", isEnabled: true, dependencies: [],
                          languages: [])
        return ModTableEntry(mod: mod, type: "", version: version, updated: nil, bytes: bytes,
                             update: pending.pending(for: mod))
    }
}
