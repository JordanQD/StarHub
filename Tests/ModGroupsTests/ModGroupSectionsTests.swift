import Foundation
import Testing
@testable import StarHubTHCore

struct ModGroupSectionsTests {
    private func mod(_ f: String, enabled: Bool = true) -> ModItem {
        ModItem(uniqueId: "x.\(f)", name: f, folderName: f, version: "1", author: "", description: "",
                nexusUrl: "", nexusModId: "", isEnabled: enabled, dependencies: [], languages: [])
    }

    private func state(_ groups: [(String, [String])], collapsed: Set<String> = []) -> ModGroupsState {
        var s = ModGroupsState()
        for (name, folders) in groups {
            let id = try! s.createGroup(named: name).get()
            s.assign(folders, to: id)
            if collapsed.contains(name) { s.setCollapsed(group: id, true) }
        }
        return s
    }

    @Test func groupsFollowRankUngroupedLastEmptyHidden() {
        let s = state([("B", ["b1"]), ("A", ["a1"]), ("Empty", [])])
        let display = [mod("a1"), mod("z"), mod("b1", enabled: false)]
        let sections = ModGroupSections.sections(display: display, mode: .groups, state: s, category: { _ in nil })
        #expect(sections.map(\.title) == ["B", "A", nil])
        #expect(sections.map { $0.mods.map(\.folderName) } == [["b1"], ["a1"], ["z"]])
        #expect(sections[0].pausedCount == 1)
    }

    @Test func categoriesSortByNameUncategorizedLast() {
        let cats: [String: (Int, String)] = ["v": (4, "Visuels"), "a": (2, "Audio")]
        let sections = ModGroupSections.sections(display: [mod("v"), mod("n"), mod("a")], mode: .category,
                                              state: ModGroupsState(),
                                              category: { cats[$0.folderName].map { (id: $0.0, name: $0.1) } })
        #expect(sections.map(\.key) == [.category(2), .category(4), .uncategorized])
    }

    @Test func longGroupHasOneHeaderAndRetainsAllMods() {
        let folders = (1...30).map { "mod-\($0)" }
        let s = state([("A", folders), ("Folded", ["f1"])], collapsed: ["Folded"])
        let sections = ModGroupSections.sections(display: (folders + ["f1"]).map { mod($0) },
                                                mode: .groups, state: s, category: { _ in nil })
        #expect(sections.map(\.title) == ["A", "Folded"])
        #expect(sections.map { $0.mods.count } == [30, 1])
        #expect(ModGroupSections.navigationOrder(sections) == folders)
    }

    /// Review Focus 2 : on ne navigue ni ne sélectionne ce qu'on ne voit pas.
    @Test func navigationSkipsCollapsedGroups() {
        let s = state([("Open", ["o1"]), ("Folded", ["f1"])], collapsed: ["Folded"])
        let sections = ModGroupSections.sections(display: [mod("o1"), mod("f1"), mod("u")], mode: .groups,
                                              state: s, category: { _ in nil })
        #expect(ModGroupSections.navigationOrder(sections) == ["o1", "u"])
    }

    @Test func aFilterThatEmptiesAGroupHidesIt() {
        let s = state([("A", ["a1"]), ("B", ["b1"])])
        let sections = ModGroupSections.sections(display: [mod("b1")], mode: .groups, state: s, category: { _ in nil })
        #expect(sections.map(\.title) == ["B"])
    }
}
