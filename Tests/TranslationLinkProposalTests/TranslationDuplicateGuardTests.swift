import Testing
import Foundation
@testable import StarHubTHCore

/// C7-T2 — la garde anti-doublon : volet a (traduction gérée par l'app).
/// Règle d'identité : même id Nexus non nul, ou noms égaux (idiome zéro pour
/// « sans id ») = mise à jour, silence ; sinon conflit, sauf fantôme (aucun
/// fichier de l'incumbent n'existe plus — B4-T4).
@Suite struct TranslationDuplicateGuardTests {

    private func makeHost(filesWritten: Int) -> (hostPath: String, incumbent: InstalledTranslation) {
        let hostPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("TDGuard-\(UUID().uuidString)").path
        let fr = (hostPath as NSString).appendingPathComponent("i18n/fr.json")
        let def = (hostPath as NSString).appendingPathComponent("i18n/default.json")
        for path in [fr, def].prefix(filesWritten) {
            try? FileManager.default.createDirectory(
                at: URL(fileURLWithPath: (path as NSString).deletingLastPathComponent),
                withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: path, contents: Data("{}".utf8))
        }
        let incumbent = InstalledTranslation(
            hostFolderName: "Wallet", nexusModId: 42, nexusName: "Wallet FR 1.0",
            version: "1.0", updatedAt: nil, installedAt: Date(timeIntervalSince1970: 0),
            files: ["i18n/fr.json", "i18n/default.json"])
        return (hostPath, incumbent)
    }

    private func incoming(id: Int, name: String,
                          files: [String] = ["i18n/fr.json"]) -> InstalledTranslation {
        InstalledTranslation(hostFolderName: "Wallet", nexusModId: id, nexusName: name,
                             version: "2.0", updatedAt: nil,
                             installedAt: Date(timeIntervalSince1970: 100), files: files)
    }

    private func conflict(with incumbent: InstalledTranslation?, hostPath: String,
                          incoming: InstalledTranslation) -> TranslationDuplicateConflict? {
        var registry = InstalledTranslationRegistry()
        if let incumbent { registry.record(incumbent) }
        return TranslationDuplicateGuard.conflict(
            hostFolderName: "Wallet", incoming: incoming, registry: registry,
            proposedLinks: [:], hostPath: hostPath)
    }

    @Test func sameNexusIdIsAnUpdateAndStaysSilent() {
        let (hostPath, incumbent) = makeHost(filesWritten: 2)
        #expect(conflict(with: incumbent, hostPath: hostPath,
                         incoming: incoming(id: 42, name: "Wallet FR 1.1")) == nil)
    }

    @Test func aDifferentNexusIdConflictsAndNamesTheIncumbent() {
        let (hostPath, incumbent) = makeHost(filesWritten: 2)
        let c = conflict(with: incumbent, hostPath: hostPath,
                         incoming: incoming(id: 99, name: "Autre trad FR"))
        #expect(c?.existing == [.appManaged(name: "Wallet FR 1.0")])
        #expect(c?.parcCandidateCount == 0)
    }

    @Test func anIdlessIncomingWithTheSameNameStaysSilent() {
        let (hostPath, incumbent) = makeHost(filesWritten: 2)
        // Idiome zéro : le ZIP déposé sans id porte 0 ; même nom = re-dépôt.
        #expect(conflict(with: incumbent, hostPath: hostPath,
                         incoming: incoming(id: 0, name: "Wallet FR 1.0")) == nil)
    }

    @Test func anIdlessIncomingWithAnotherNameConflicts() {
        let (hostPath, incumbent) = makeHost(filesWritten: 2)
        let c = conflict(with: incumbent, hostPath: hostPath,
                         incoming: incoming(id: 0, name: "zip-traduction.zip"))
        #expect(c?.existing == [.appManaged(name: "Wallet FR 1.0")])
    }

    @Test func aPartiallyAliveIncumbentStillWarns() {
        let (hostPath, incumbent) = makeHost(filesWritten: 1)
        let c = conflict(with: incumbent, hostPath: hostPath,
                         incoming: incoming(id: 99, name: "Autre trad FR"))
        #expect(c?.existing == [.appManaged(name: "Wallet FR 1.0")])
    }

    @Test func aGhostIncumbentStaysSilent() {
        let (hostPath, incumbent) = makeHost(filesWritten: 0)
        #expect(conflict(with: incumbent, hostPath: hostPath,
                         incoming: incoming(id: 99, name: "Autre trad FR")) == nil)
    }

    @Test func aNonFrenchDepositStillConflicts() {
        let (hostPath, incumbent) = makeHost(filesWritten: 2)
        // La garde juge l'hôte, pas la langue entrante (th/zh compris).
        let c = conflict(with: incumbent, hostPath: hostPath,
                         incoming: incoming(id: 99, name: "Wallet TH",
                                            files: ["i18n/th.json"]))
        #expect(c?.existing == [.appManaged(name: "Wallet FR 1.0")])
    }

    // MARK: - Volet b (lien C7-T1) + advisory c

    private func registryDeclaring(pack folder: String, name: String,
                                   onHost host: String) -> InstalledTranslationRegistry {
        var registry = InstalledTranslationRegistry()
        registry.declare(
            DeclaredTranslation(nexusModId: nil, nexusName: name, version: "1.0",
                                updatedAt: nil, declaredAt: Date(),
                                packFolderName: folder),
            forHost: host)
        return registry
    }

    private func proposal(pack: String, host: String) -> TranslationLinkProposal {
        TranslationLinkProposal(packFolderName: pack, packName: pack,
                                packVersion: "1.0", nexusId: nil,
                                hostFolderName: host, coverage: 1.0,
                                evidence: .keys, alternates: [])
    }

    @Test func aDeclaredLinkConflictsAndNamesThePack() {
        let registry = registryDeclaring(pack: "SomeModFR", name: "Some Mod FR",
                                         onHost: "Wallet")
        let c = TranslationDuplicateGuard.conflict(
            hostFolderName: "Wallet", incoming: incoming(id: 99, name: "Autre trad FR"),
            registry: registry, proposedLinks: [:],
            hostPath: makeHost(filesWritten: 0).hostPath, declaredPackEnabled: true)
        #expect(c?.existing == [.declaredPack(folderName: "SomeModFR",
                                              name: "Some Mod FR", isEnabled: true)])
    }

    @Test func anAppIncumbentAndADeclaredLinkCombineInOrder() {
        let (hostPath, incumbent) = makeHost(filesWritten: 2)
        var registry = registryDeclaring(pack: "SomeModFR", name: "Some Mod FR",
                                         onHost: "Wallet")
        registry.record(incumbent)
        let c = TranslationDuplicateGuard.conflict(
            hostFolderName: "Wallet", incoming: incoming(id: 99, name: "Autre trad FR"),
            registry: registry, proposedLinks: [:], hostPath: hostPath,
            declaredPackEnabled: false)
        #expect(c?.existing == [.appManaged(name: "Wallet FR 1.0"),
                                .declaredPack(folderName: "SomeModFR",
                                              name: "Some Mod FR", isEnabled: false)])
    }

    @Test func parcCandidatesAreCountedAsAdvisoryOnly() {
        let (hostPath, incumbent) = makeHost(filesWritten: 2)
        let links = ["Pack1": proposal(pack: "Pack1", host: "Wallet"),
                     "Pack2": proposal(pack: "Pack2", host: "Wallet"),
                     "Pack3": proposal(pack: "Pack3", host: "AutreMod")]
        var registry = InstalledTranslationRegistry()
        registry.record(incumbent)
        let c = TranslationDuplicateGuard.conflict(
            hostFolderName: "Wallet", incoming: incoming(id: 99, name: "Autre trad FR"),
            registry: registry, proposedLinks: links, hostPath: hostPath)
        #expect(c?.parcCandidateCount == 2)
        #expect(c?.existing == [.appManaged(name: "Wallet FR 1.0")])
    }

    @Test func dismissedProposalsAreNotAdvisory() {
        // Limite documentée : l'appelant passe le vivant seulement — un pack
        // écarté (Ignorer) n'entre plus dans proposedLinks.
        let (hostPath, incumbent) = makeHost(filesWritten: 2)
        let links = ["Pack1": proposal(pack: "Pack1", host: "AutreMod")]
        var registry = InstalledTranslationRegistry()
        registry.record(incumbent)
        let c = TranslationDuplicateGuard.conflict(
            hostFolderName: "Wallet", incoming: incoming(id: 99, name: "Autre trad FR"),
            registry: registry, proposedLinks: links, hostPath: hostPath)
        #expect(c?.parcCandidateCount == 0)
    }

    @Test func declaredOnlySilenceWhenNothingExists() {
        // Ni incumbent, ni déclaration, ni candidat : la garde ne se déclenche pas.
        let c = TranslationDuplicateGuard.conflict(
            hostFolderName: "Wallet", incoming: incoming(id: 99, name: "Autre trad FR"),
            registry: InstalledTranslationRegistry(), proposedLinks: [:],
            hostPath: makeHost(filesWritten: 0).hostPath)
        #expect(c == nil)
    }
}
