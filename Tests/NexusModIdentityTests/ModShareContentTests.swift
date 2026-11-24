import Foundation
import Testing
@testable import StarHubTHCore

struct ModShareContentTests {
    @Test func sharesCanonicalLinksAndDeduplicatesPackComponents() {
        let first = mod("First", link: "https://nexusmods.com/games/stardewvalley/mods/17?tab=files")
        let second = mod("Second", nexusID: "17")
        let third = mod("Third", nexusID: "33")
        let pack = mod("Pack", children: [first, second, third])

        #expect(content([pack, second]) == .links([
            URL(string: "https://www.nexusmods.com/stardewvalley/mods/17")!,
            URL(string: "https://www.nexusmods.com/stardewvalley/mods/33")!
        ]))
    }

    @Test func honorsExplicitPackAssociation() {
        let pack = mod("Pack", children: [mod("First", nexusID: "17"), mod("Second")])
        #expect(content([pack], customIDs: ["Pack": "42"]) == .links([
            URL(string: "https://www.nexusmods.com/stardewvalley/mods/42")!
        ]))
    }

    @Test func unavailableComponentDoesNotSuppressAnUnrelatedPackPage() {
        let removed = mod("Removed", nexusID: "17")
        let pack = mod("Pack", children: [removed])

        #expect(content([pack], customIDs: ["Pack": "42"], isPageUnavailable: { $0.id == removed.id })
                == .links([URL(string: "https://www.nexusmods.com/stardewvalley/mods/42")!]))
        #expect(content([pack], customIDs: ["Pack": "17"], isPageUnavailable: { $0.id == removed.id })
                == .text("Pack (Test.Pack)"))
    }

    @Test func mixedSelectionKeepsLocalModsAndValidLinks() {
        let local = mod("Local")
        let online = mod("Online", nexusID: "17")
        #expect(content([local, online]) == .text(
            "Local (Test.Local)\n\nOnline (Test.Online)\nhttps://www.nexusmods.com/stardewvalley/mods/17"))
    }

    @Test func rejectedLinksAndUnavailablePagesFallBackToModDetails() {
        let unrelated = mod("Other", link: "https://nexusmods.com.example/stardewvalley/mods/17")
        let removed = mod("Removed", nexusID: "18")
        let differentGame = mod("WrongGame", link: "https://www.nexusmods.com/skyrim/mods/19")
        let pack = mod("Pack", children: [unrelated, removed, differentGame])

        #expect(content([pack], isPageUnavailable: { $0.uniqueId == removed.uniqueId }) == .text(
            "Other (Test.Other)\n\nRemoved (Test.Removed)\n\nWrongGame (Test.WrongGame)"))
    }

    @Test func emptySelectionHasNoSharePayload() {
        #expect(content([]) == nil)
    }

    private func content(_ mods: [ModItem], customIDs: [String: String] = [:],
                         isPageUnavailable: (ModItem) -> Bool = { _ in false }) -> ModShareContent? {
        ModShareContent.make(for: mods, customIDs: customIDs, isPageUnavailable: isPageUnavailable) {
            "\($0.name) (\($0.uniqueId))"
        }
    }

    private func mod(_ name: String, nexusID: String = "", link: String = "",
                     children: [ModItem]? = nil) -> ModItem {
        ModItem(uniqueId: "Test.\(name)", name: name, folderName: name, version: "1.0",
                author: "Test", description: "", nexusUrl: link, nexusModId: nexusID,
                isEnabled: true, dependencies: [], children: children, isGroup: children != nil)
    }
}
