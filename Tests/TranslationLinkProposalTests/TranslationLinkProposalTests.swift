import Testing
import Foundation
@testable import StarHubTHCore

/// C7-T1 — le type pur des propositions de lien « pack-traduction → hôte ».
///
/// Fixtures inspirées du parc réel (mesure du 2026-11-18) :
/// `EasyAccessButtonsFR` → `.EasyAccessButtons.orig-Yadm` est la seule vraie
/// paire « traduction posée comme un mod » ; les fratries et packs
/// compagnons (`.WalletHorseFlute` ↔ `.[CP] WalletHorseFlute`, séries de
/// packs sociaux) doivent rester **silencieuses**. Le type ne lit pas le
/// disque et ne parse pas : les ensembles de clés arrivent prêts — la
/// lecture lenient est du ressort de l'appelant.
@Suite struct TranslationLinkProposalTests {

    // MARK: - Fabriques

    /// Des clés d'origine plausibles : `fr<n>` avec quelques `dialogue.<n>`.
    private func keySet(_ prefix: String, count: Int) -> Set<String> {
        Set((0..<count).map { "\($0 % 4 == 0 ? "dialogue." : "")\(prefix).\($0)" })
    }

    private func pack(_ folder: String, name: String,
                      keys: Set<String>? = nil, uniqueId: String = "",
                      marked: Bool? = nil, french: Bool = true,
                      nexusId: Int? = nil) -> TranslationLinkPack {
        TranslationLinkPack(
            folderName: folder, physicalFolderName: folder, name: name,
            uniqueId: uniqueId,
            isMarked: marked ?? TranslationLinkMatcher.isMarked(name: name + " " + folder),
            isFrench: french, keySet: keys, nexusId: nexusId)
    }

    private var easyAccessButtons: TranslationLinkPack {
        pack(".EasyAccessButtons.orig-Yadm", name: "Easy Access Buttons",
             keys: keySet("eab", count: 20), uniqueId: "Yadm.EasyAccessButtons")
    }

    private var easyAccessButtonsFR: TranslationLinkPack {
        pack("EasyAccessButtonsFR", name: "Easy Access Buttons FR",
             keys: keySet("eab", count: 20), uniqueId: "mrbabilo.EasyAccessButtons",
             nexusId: nil)
    }

    // MARK: - Le marqueur de nom

    @Test func thePinnedMarkerMatchesTheCentralParcCase() {
        // Le cas collé du parc — la regex doit l'attraper (relecture adverse).
        #expect(TranslationLinkMatcher.isMarked(name: "EasyAccessButtonsFR"))
        // Les formes séparées.
        #expect(TranslationLinkMatcher.isMarked(name: "EasyAccessButtons-FR"))
        #expect(TranslationLinkMatcher.isMarked(name: "Traduction FR de X"))
        #expect(TranslationLinkMatcher.isMarked(name: "[CP] SVE Français"))
        #expect(TranslationLinkMatcher.isMarked(name: "My Mod — French Version"))
        // Pas des faux positifs.
        #expect(!TranslationLinkMatcher.isMarked(name: "Fridge Organizer"))
        #expect(!TranslationLinkMatcher.isMarked(name: "Transfer Information"))
        #expect(!TranslationLinkMatcher.isMarked(name: "Easy Access Buttons"))
    }

    // MARK: - L'heuristique de langue

    @Test func frenchValuesAreJudgedNotTheFileName() {
        let french = Array(repeating: "Cette modification ajoute un nouveau bâtiment à la ferme",
                           count: 10)
        let english = Array(repeating: "This modification adds a new building to your farm plot",
                            count: 10)
        #expect(TranslationLinkMatcher.isFrench(values: french))
        #expect(!TranslationLinkMatcher.isFrench(values: english))
        #expect(!TranslationLinkMatcher.isFrench(values: []))
    }

    // MARK: - La proposition

    @Test func theParcPairProposesItsHostWithoutAmbiguity() {
        let packs = [easyAccessButtons, easyAccessButtonsFR]
        let proposals = TranslationLinkMatcher.propose(packs: packs)
        #expect(proposals.count == 1)
        let p = try! #require(proposals.first)
        #expect(p.packFolderName == "EasyAccessButtonsFR")
        #expect(p.hostFolderName == ".EasyAccessButtons.orig-Yadm")
        #expect(p.coverage == 1.0)
        #expect(p.evidence == .keys)
        #expect(p.alternates.isEmpty)
        #expect(p.nexusId == nil)
    }

    @Test func unmarkedSiblingPairsStaySilent() {
        // Mod ↔ son pack compagnon : 100 % de recouvrement mutuel, mais aucun
        // marqueur — exactement le bruit des 44 paires du parc.
        let mod = pack(".WalletHorseFlute", name: "Wallet Horse Flute",
                       keys: keySet("whf", count: 9))
        let cp = pack(".[CP] WalletHorseFlute", name: "Wallet Horse Flute (CP)",
                      keys: keySet("whf", count: 9))
        #expect(TranslationLinkMatcher.propose(packs: [mod, cp]).isEmpty)
    }

    @Test func aTieResolvedByThePackNameYieldsNameAndKeys() {
        let hostA = pack("Alpha Tools", name: "Alpha Tools", keys: keySet("t", count: 12))
        let hostB = pack("Beta Tools", name: "Beta Tools", keys: keySet("t", count: 12))
        let candidate = pack("Alpha Tools FR", name: "Alpha Tools FR",
                             keys: keySet("t", count: 12), marked: true)
        let proposals = TranslationLinkMatcher.propose(packs: [hostA, hostB, candidate])
        #expect(proposals.count == 1)
        #expect(proposals.first?.hostFolderName == "Alpha Tools")
        #expect(proposals.first?.evidence == .nameAndKeys)
        #expect(proposals.first?.alternates == ["Beta Tools"])
    }

    @Test func anUnresolvedTieProposesTheBestWithAlternates() {
        let hostA = pack("Outil Mystère", name: "Outil Mystère", keys: keySet("m", count: 12))
        let hostB = pack("Boîte Mystère", name: "Boîte Mystère", keys: keySet("m", count: 12))
        let candidate = pack("Mystère FR", name: "Mystère FR",
                             keys: keySet("m", count: 12), marked: true)
        let proposals = TranslationLinkMatcher.propose(packs: [hostA, hostB, candidate])
        #expect(proposals.count == 1)
        #expect(proposals.first?.alternates.count == 1)
    }

    @Test func aNonFrenchCandidateIsNeverProposed() {
        let host = easyAccessButtons
        let englishMarked = pack("EasyAccessButtonsFR", name: "Easy Access Buttons FR",
                                 keys: keySet("eab", count: 20), marked: true,
                                 french: false)
        #expect(TranslationLinkMatcher.propose(packs: [host, englishMarked]).isEmpty)
    }

    @Test func aPausedHostIsStillAHost() {
        // Les hôtes en pause (préfixe point) restent dans le pool.
        let pausedHost = pack(".EasyAccessButtons.orig-Yadm", name: "Easy Access Buttons",
                              keys: keySet("eab", count: 20),
                              uniqueId: "Yadm.EasyAccessButtons")
        #expect(TranslationLinkMatcher.propose(packs: [pausedHost, easyAccessButtonsFR]).count == 1)
    }

    @Test func aTwinWithTheSameUniqueIdIsExcludedFromThePool() {
        // Copie renommée du même mod (`-old`, variante) : mêmes clés, même
        // UniqueID — ni l'un ni l'autre n'est un hôte pour l'autre.
        let twin = pack(".EasyAccessButtonsFR.old", name: "Easy Access Buttons FR",
                        keys: keySet("eab", count: 20),
                        uniqueId: "mrbabilo.EasyAccessButtons")
        #expect(TranslationLinkMatcher.propose(packs: [twin, easyAccessButtonsFR]).isEmpty)
    }

    @Test func mutuallyMarkedPacksNeverAutoPropose() {
        // Deux traductions marquées dont le meilleur non-self est l'autre :
        // la règle « réciproque et mutuelle » bloque la proposition.
        let a = pack("Série FR 1", name: "Série FR 1", keys: keySet("s", count: 12),
                     marked: true)
        let b = pack("Série FR 2", name: "Série FR 2", keys: keySet("s", count: 12),
                     marked: true)
        #expect(TranslationLinkMatcher.propose(packs: [a, b]).isEmpty)
    }

    @Test func belowTheCoverageThresholdNothingIsProposed() {
        let host = pack("Big Mod", name: "Big Mod", keys: keySet("big", count: 100))
        let distant = pack("Small FR", name: "Small FR",
                           keys: Set((0..<10).map { "small.\($0)" }), marked: true)
        #expect(TranslationLinkMatcher.propose(packs: [host, distant]).isEmpty)
    }
}
