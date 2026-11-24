import Testing
@testable import StarHubTHCore

/// Valeurs affichées sur la carte d'un mod installé.
struct ModGridCardValuesTests {
    /// Le patron de `CoreModSlotTests:9` — l'init public explicite de
    /// `ModItem` (`ModItem.swift:70`).
    private func mod(name: String = "Space Core",
                     author: String = "Lita",
                     version: String = "1.4.2",
                     languages: [String] = ["en"],
                     nexusModId: String = "") -> ModItem {
        ModItem(uniqueId: "id.\(name)", name: name, folderName: name,
                version: version, author: author, description: "",
                nexusUrl: "", nexusModId: nexusModId, isEnabled: true,
                dependencies: [], languages: languages)
    }

    /// Le pack n'a pas sa propre version. La carte lit celle des composants.
    private func pack(children: [ModItem]) -> ModItem {
        ModItem(uniqueId: "id.pack", name: "Mon Pack", folderName: "Mon Pack",
                version: "", author: "Group", description: "",
                nexusUrl: "", nexusModId: "", isEnabled: true,
                dependencies: [],
                children: children, isGroup: true,
                languages: Set(children.flatMap { $0.languages }).sorted())
    }

    @Test func titleAndUnprefixedVersion() {
        let card = ModGridCardValues.card(mod: mod(version: "v1.4.2"))
        #expect(card.title == "Space Core")
        #expect(card.version == "1.4.2")
    }

    @Test func aPackShowsItsSharedVersion() {
        let pack = self.pack(children: [mod(version: "2.0"),
                                        mod(name: "Composant", author: "Nikki", version: "V2.0")])
        let card = ModGridCardValues.card(mod: pack)
        #expect(card.title == "Mon Pack")
        #expect(card.version == "2.0")
    }

    @Test func aPackWithMixedVersionsHasNoVersion() {
        let mixed = pack(children: [mod(author: "Lita", version: "2.0"),
                                    mod(name: "Composant", author: "Nikki", version: "2.1")])
        let card = ModGridCardValues.card(mod: mixed)
        #expect(card.version == nil)
    }

    /// Le seul badge qu'un mod installé peut porter : « FR », quand une de
    /// ses langues servies est le français — même source que le slot FR de
    /// la rangée (`frenchSlot`, `ModListView.swift:1342` : `langs.contains("fr")`).
    /// Un pack hérite de l'union des langues de ses enfants (ViewModel:2748).
    @Test func frenchBadge() {
        #expect(ModGridCardValues.card(mod: mod(languages: ["en", "fr"])).neutralBadge == "FR")
        #expect(ModGridCardValues.card(mod: mod(languages: ["en"])).neutralBadge == nil)
        let pack = self.pack(children: [mod(languages: ["en", "fr"])])
        #expect(ModGridCardValues.card(mod: pack).neutralBadge == "FR")
    }

    /// La vignette vient du cache Nexus déjà sur le disque (769 des 791
    /// entrées en portent une, mesuré sur le parc réel) : la carte la sert
    /// telle quelle. Une URL absente, vide ou illisible laisse le rectangle
    /// gris — la hauteur est réservée, rien ne bouge.
    @Test func thumbnailComesFromTheGivenURL() {
        let served = ModGridCardValues.card(mod: mod(),
                                            pictureURL: "https://x.test/a.png")
        #expect(served.thumbnailURL?.absoluteString == "https://x.test/a.png")
        #expect(ModGridCardValues.card(mod: mod(),
                                       pictureURL: "").thumbnailURL == nil)
        #expect(ModGridCardValues.card(mod: mod()).thumbnailURL == nil)
    }

    /// **L'identifiant qui a droit à une image.** Un pack n'en porte pas :
    /// son en-tête est fabriqué avec `nexusModId: ""` (ViewModel:2738). Le
    /// prendre au premier enfant qui en a un — ce que fait
    /// `resolvedNexusModId` pour la fiche — donnerait à un pack **à plat**
    /// (19 dans le parc réel : des mods sans rapport dans un même dossier)
    /// la capture d'écran de son premier composant. La carte n'accepte donc
    /// que l'identifiant que **tous** les enfants partagent, comme
    /// `sharedValue` pour l'auteur et la version.
    @Test func onlyASharedNexusIdEarnsAPicture() {
        let effective: (ModItem) -> String = { $0.nexusModId }
        // Un mod ordinaire : son propre identifiant.
        #expect(ModGridCardValues.sharedNexusId(of: mod(nexusModId: "1234"),
                                                effectiveId: effective) == "1234")
        // Un vrai pack : un seul mod Nexus, plusieurs dossiers.
        let real = pack(children: [mod(nexusModId: "42"),
                                   mod(name: "Composant", nexusModId: "42")])
        #expect(ModGridCardValues.sharedNexusId(of: real, effectiveId: effective) == "42")
        // Un pack à plat : des mods sans rapport, aucune image légitime.
        let flat = pack(children: [mod(nexusModId: "42"),
                                   mod(name: "Composant", nexusModId: "77")])
        #expect(ModGridCardValues.sharedNexusId(of: flat, effectiveId: effective) == nil)
        // Rien de déclaré : rien à servir.
        #expect(ModGridCardValues.sharedNexusId(of: mod(), effectiveId: effective) == nil)
        #expect(ModGridCardValues.sharedNexusId(of: pack(children: [mod()]),
                                                effectiveId: effective) == nil)
    }

    /// **Un enfant muet ne disqualifie pas le pack.** Mesuré sur le parc
    /// réel (101 packs, dossier `Mods` lu le 2026-08-30) : 49 packs voient
    /// tous leurs composants déclarer le même identifiant, **35** n'en ont
    /// qu'un seul distinct parce que les autres composants n'en déclarent
    /// aucun (« Desert Expansion » : un `[CP]` porteur, deux annexes muettes)
    /// — ce sont de vrais packs — et **2** en mêlent plusieurs, les seuls que
    /// la règle doit écarter. Exiger un identifiant de *chaque* enfant
    /// coûterait donc 35 vignettes légitimes pour n'en éviter aucune fausse
    /// de plus.
    @Test func aSilentChildDoesNotDisqualifyThePack() {
        let effective: (ModItem) -> String = { $0.nexusModId }
        let real = pack(children: [mod(nexusModId: "42"),
                                   mod(name: "Annexe"),
                                   mod(name: "Autre annexe")])
        #expect(ModGridCardValues.sharedNexusId(of: real, effectiveId: effective) == "42")
    }

    /// L'identifiant **propre** d'un en-tête l'emporte : c'est celui que
    /// l'utilisateur a saisi à la main pour ce pack (`nexusCustomModIds`,
    /// clé `folderName`), et il vaut mieux que n'importe quelle déduction.
    @Test func anOwnIdWinsOverTheChildren() {
        let flat = pack(children: [mod(nexusModId: "42"),
                                   mod(name: "Composant", nexusModId: "77")])
        let effective: (ModItem) -> String = { $0.isGroup ? "999" : $0.nexusModId }
        #expect(ModGridCardValues.sharedNexusId(of: flat, effectiveId: effective) == "999")
    }
}
