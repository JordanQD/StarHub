import Testing
import Foundation
@testable import StarHubTHCore

/// C7-T1 — l'option B du design : une déclaration peut exister **sans
/// identité Nexus** (`nexusModId` optionnel) en portant le dossier du pack
/// qu'elle rattache (`packFolderName`). Rétrocompatibilité : les registres
/// écrits avant (id obligatoire, pas de dossier de pack) se relisent tels
/// quels, et les règles d'appariement d'une proposition au registre existant
/// vivent dans `TranslationLinkConfirmation.swift`.
@Suite struct DeclaredTranslationLinkTests {

    private func declared(id: Int?, pack: String? = nil,
                          at date: Date = Date(timeIntervalSince1970: 0)) -> DeclaredTranslation {
        DeclaredTranslation(nexusModId: id, nexusName: "X Traduction FR",
                            version: "1.0", updatedAt: nil,
                            declaredAt: date, packFolderName: pack)
    }

    // MARK: - Décodage rétrocompatible

    @Test func oldJsonWithMandatoryIdStillDecodes() throws {
        // Registre écrit avant l'option B : id obligatoire, pas de dossier de pack.
        let json = #"{"nexusModId": 12345, "nexusName": "X FR", "version": "1.0", "updatedAt": null, "declaredAt": 0}"#
        let decl = try JSONDecoder().decode(DeclaredTranslation.self,
                                            from: Data(json.utf8))
        #expect(decl.nexusModId == 12345)
        #expect(decl.packFolderName == nil)
    }

    @Test func newJsonWithoutIdDecodesToNil() throws {
        let json = #"{"nexusModId": null, "nexusName": "Easy Access Buttons FR", "version": "1.0.5", "updatedAt": null, "declaredAt": 0, "packFolderName": "EasyAccessButtonsFR"}"#
        let decl = try JSONDecoder().decode(DeclaredTranslation.self,
                                            from: Data(json.utf8))
        #expect(decl.nexusModId == nil)
        #expect(decl.packFolderName == "EasyAccessButtonsFR")
    }

    // MARK: - Appariement d'une proposition au registre

    @Test func matchesByPackFolderName() {
        let decl = declared(id: nil, pack: "EasyAccessButtonsFR")
        // Le dossier de pack est la preuve la plus directe : elle l'emporte
        // sur un identifiant deviné différent.
        #expect(decl.matchesLink(packFolderName: "EasyAccessButtonsFR", nexusId: nil))
        #expect(decl.matchesLink(packFolderName: "EasyAccessButtonsFR", nexusId: 999))
        #expect(!decl.matchesLink(packFolderName: "AutrePack", nexusId: nil))
    }

    @Test func matchesByNexusId() {
        let decl = declared(id: 55410)
        #expect(decl.matchesLink(packFolderName: ".TranslationHub", nexusId: 55410))
        #expect(!decl.matchesLink(packFolderName: ".TranslationHub", nexusId: nil))
        #expect(!decl.matchesLink(packFolderName: ".TranslationHub", nexusId: 1))
    }

    @Test func asTrackedWithoutIdUsesTheExistingZeroIdiom() {
        let tracked = declared(id: nil, pack: "EasyAccessButtonsFR")
            .asTracked(hostFolderName: "Easy Access Buttons")
        #expect(tracked.nexusModId == 0)
        #expect(tracked.hostFolderName == "Easy Access Buttons")
    }

    // MARK: - Le registre : liaison posée, hôtes liés

    @Test func isLinkDeclaredSeesBothKindsOfLink() {
        var registry = InstalledTranslationRegistry()
        registry.declare(declared(id: nil, pack: "EasyAccessButtonsFR"),
                         forHost: "Easy Access Buttons")
        registry.declare(declared(id: 55410), forHost: ".TranslationHub")
        #expect(registry.isLinkDeclared(packFolderName: "EasyAccessButtonsFR", nexusId: nil))
        #expect(registry.isLinkDeclared(packFolderName: "inconnu", nexusId: 55410))
        #expect(!registry.isLinkDeclared(packFolderName: "inconnu", nexusId: nil))
    }

    @Test func declaredLinkHostsListsEveryLinkedHost() {
        var registry = InstalledTranslationRegistry()
        registry.declare(declared(id: nil, pack: "EasyAccessButtonsFR"),
                         forHost: "Easy Access Buttons")
        registry.declare(declared(id: 55410), forHost: ".TranslationHub")
        #expect(registry.declaredLinkHosts() == ["Easy Access Buttons", ".TranslationHub"])
    }

    @Test func oneDeclarationPerHostSurvivesALinkThenAnotherLink() {
        var registry = InstalledTranslationRegistry()
        registry.declare(declared(id: nil, pack: "PackFR1"), forHost: "Hôte")
        registry.declare(declared(id: 7, pack: "PackFR2"), forHost: "Hôte")
        #expect(registry.declaredTranslations["Hôte"]?.nexusModId == 7)
        #expect(registry.declaredTranslations["Hôte"]?.packFolderName == "PackFR2")
        #expect(registry.declaredLinkHosts().count == 1)
    }

    // MARK: - C7-T1 — la confirmation d'une proposition

    @Test func applyCreatesTheDeclarationWithIdentity() throws {
        var registry = InstalledTranslationRegistry()
        let proposal = TranslationLinkProposal(
            packFolderName: "EasyAccessButtonsFR", packName: "Easy Access Buttons FR",
            packVersion: "1.0.5", nexusId: nil,
            hostFolderName: "Easy Access Buttons", coverage: 1.0,
            evidence: .keys, alternates: [])
        let date = Date(timeIntervalSince1970: 100)
        let decl = TranslationLinkConfirmation.apply(
            proposal: proposal, name: "Easy Access Buttons FR", version: "1.0.5",
            nexusId: nil, to: &registry, declaredAt: date)
        #expect(decl.nexusModId == nil)                 // option B : id-less accepté
        #expect(decl.packFolderName == "EasyAccessButtonsFR")
        #expect(decl.declaredAt == date)
        #expect(registry.isLinkDeclared(packFolderName: "EasyAccessButtonsFR", nexusId: nil))
        #expect(registry.declaredLinkHosts() == ["Easy Access Buttons"])
    }

    @Test func applyKeepsAnIdentityWhenThePackHasOne() {
        var registry = InstalledTranslationRegistry()
        let proposal = TranslationLinkProposal(
            packFolderName: ".TranslationHubFR", packName: "Translation Hub FR",
            packVersion: "0.6.1", nexusId: 60100,
            hostFolderName: ".TranslationHub", coverage: 0.95,
            evidence: .nameAndKeys, alternates: [])
        let decl = TranslationLinkConfirmation.apply(
            proposal: proposal, name: "Translation Hub FR", version: "0.6.1",
            nexusId: 60100, to: &registry, declaredAt: Date())
        #expect(decl.nexusModId == 60100)
        #expect(registry.isLinkDeclared(packFolderName: ".TranslationHubFR", nexusId: 60100))
    }
}
