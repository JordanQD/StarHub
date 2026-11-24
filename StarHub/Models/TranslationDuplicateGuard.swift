import Foundation

/// C7-T2 — ce qui existe déjà pour l'hôte quand une traduction veut se poser.
/// Le remplacement est déjà sain (`depositIntoMod` désinstalle l'incumbent) ;
/// la garde décrit **le silence qui manque** : elle nomme l'existant avant
/// l'écriture. Zéro mutation ici — l'appelant décide Remplacer/Garder.
public struct TranslationDuplicateConflict: Equatable, Sendable {
    /// Volet **a** : la traduction gérée par l'app (fichiers + sauvegardes).
    /// Volet **b** : le lien C7-T1 déclaré vers un pack-traduction du parc.
    public enum Existing: Equatable, Sendable {
        case appManaged(name: String)
        case declaredPack(folderName: String, name: String, isEnabled: Bool)
    }

    /// Vide seulement si tout est fantôme — l'appelant traite `nil`.
    public let existing: [Existing]
    /// Advisory c — les packs du parc **candidats** vers cet hôte. Limite
    /// documentée : packs écartés et packs sans lien détecté invisibles.
    public let parcCandidateCount: Int
}

/// Les règles pures de la garde. Règle d'identité du volet a : même id Nexus
/// **non nul** (idiome zéro de `DepositIdentity`) ou noms égaux = mise à jour,
/// silence ; sinon conflit, sauf **fantôme** — un incumbent dont aucun
/// fichier n'existe plus (mod mis à jour, B4-T4) est remplacé sans bruit.
public enum TranslationDuplicateGuard {
    public static func conflict(hostFolderName: String,
                                incoming: InstalledTranslation,
                                registry: InstalledTranslationRegistry,
                                proposedLinks: [String: TranslationLinkProposal],
                                hostPath: String,
                                declaredPackEnabled: Bool = true) -> TranslationDuplicateConflict? {
        var existing: [TranslationDuplicateConflict.Existing] = []
        if let incumbent = registry.translation(forHost: hostFolderName),
           !isSameIdentity(incumbent, incoming),
           isGhost(incumbent, hostPath: hostPath) == false {
            existing.append(.appManaged(name: incumbent.nexusName))
        }
        if let declared = registry.declaredTranslation(forHost: hostFolderName),
           let folder = declared.packFolderName, !folder.isEmpty {
            existing.append(.declaredPack(folderName: folder, name: declared.nexusName,
                                          isEnabled: declaredPackEnabled))
        }
        guard !existing.isEmpty else { return nil }
        let count = proposedLinks.values
            .filter { $0.hostFolderName == hostFolderName }.count
        return TranslationDuplicateConflict(existing: existing, parcCandidateCount: count)
    }

    /// Même id Nexus non nul, ou noms égaux (insensible à la casse, nom
    /// entrant non vide) — les deux idiomes du « re-dépôt ».
    private static func isSameIdentity(_ incumbent: InstalledTranslation,
                                       _ incoming: InstalledTranslation) -> Bool {
        if incumbent.nexusModId != 0, incumbent.nexusModId == incoming.nexusModId {
            return true
        }
        return !incoming.nexusName.isEmpty
            && incoming.nexusName.caseInsensitiveCompare(incumbent.nexusName) == .orderedSame
    }

    /// Aucun des fichiers revendiqués n'existe plus sur l'hôte.
    private static func isGhost(_ incumbent: InstalledTranslation, hostPath: String) -> Bool {
        !incumbent.files.contains {
            FileManager.default.fileExists(
                atPath: (hostPath as NSString).appendingPathComponent($0))
        }
    }
}
