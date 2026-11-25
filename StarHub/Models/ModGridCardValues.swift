import Foundation

/// Ce qu'une `ModCard` peut servir depuis un mod **installé**.
///
/// La vue résout la catégorie et pilote l'interrupteur d'activation.
///
/// La **vignette**, elle, existe : le cache Nexus persisté (`nexusCachedExtras`)
/// porte une `pictureUrl` pour 769 de ses 791 entrées, mesuré sur le parc
/// réel — aucun réseau supplémentaire n'est nécessaire pour la connaître.
/// L'adaptateur ne la va pas chercher (c'est le ViewModel qui tient le cache),
/// il la reçoit et la convertit.
///
/// Pour un pack, la carte affiche la version lorsque les composants en
/// partagent une.
public enum ModGridCardValues {
    public struct Card: Equatable, Sendable {
        public let title: String
        public let version: String?
        public let thumbnailURL: URL?
        public let neutralBadge: String?
    }

    /// - Parameters:
    ///   - mod: le mod installé, tel que servi par `vm.mods` — en-tête de
    ///     pack compris.
    ///   - pictureURL: l'adresse de la capture Nexus en cache pour ce mod,
    ///     résolue par `sharedNexusId(of:effectiveId:)` puis lue dans
    ///     `nexusModExtras`. Absente, vide ou illisible : le rectangle gris
    ///     de la carte tient la place, rien ne se décale.
    public static func card(mod: ModItem,
                            pictureURL: String? = nil) -> Card {
        let versions = Set(mod.components.map(\.version).filter { !$0.isEmpty && $0 != "Unknown" }.map { version in
            let numericPart = version.dropFirst()
            if (version.first == "v" || version.first == "V"), numericPart.first?.isNumber == true {
                return String(numericPart)
            }
            return version
        })
        let version = versions.count == 1 ? versions.first : nil
        let targetLang = TranslationTargetLanguage.currentResolved()
        return Card(title: mod.name,
                    version: version,
                    thumbnailURL: pictureURL.flatMap {
                        $0.isEmpty ? nil : URL(string: $0)
                    },
                    neutralBadge: targetLang.matchesModLanguages(mod.languages) ? targetLang.badgeLabel : nil)
    }

    /// L'identifiant Nexus qui donne droit à une image — `nil` quand aucun ne
    /// représente honnêtement la carte.
    ///
    /// Un en-tête de pack est fabriqué avec `nexusModId: ""`
    /// (`StarHubTHViewModel.swift:2738`) : sans règle, une carte de pack
    /// n'aurait jamais d'image. Prendre celui du **premier enfant qui en a
    /// un** — ce que fait `resolvedNexusModId` pour la fiche, où l'utilisateur
    /// a demandé ce pack-là — donnerait en revanche à un pack **à plat** (des
    /// mods sans rapport rangés dans un même dossier, 19 dans le parc réel)
    /// la capture d'écran de son premier composant, présentée comme la
    /// sienne. Comme pour la version, seul compte ce
    /// que les enfants partagent.
    ///
    /// Un enfant **muet** ne disqualifie pas le pack, lui : mesuré sur le parc
    /// réel (101 packs, 2026-08-30), 49 packs voient tous leurs composants
    /// déclarer le même identifiant, 35 n'en ont qu'un seul distinct parce que
    /// les autres composants n'en déclarent aucun — des annexes de vrais packs
    /// — et 2 seulement en mêlent plusieurs. Exiger un identifiant de *chaque*
    /// enfant coûterait 35 vignettes légitimes sans en écarter une seule
    /// fausse de plus.
    ///
    /// - Parameter effectiveId: l'identifiant propre d'un mod, saisi par
    ///   l'utilisateur ou lu du manifeste (`vm.effectiveNexusModId(for:)`),
    ///   injecté pour garder la règle pure.
    public static func sharedNexusId(of mod: ModItem,
                                     effectiveId: (ModItem) -> String) -> String? {
        let own = effectiveId(mod)
        if !own.isEmpty { return own }
        guard mod.isGroup, let children = mod.children else { return nil }
        let ids = Set(children.map(effectiveId).filter { !$0.isEmpty })
        return ids.count == 1 ? ids.first : nil
    }
}
