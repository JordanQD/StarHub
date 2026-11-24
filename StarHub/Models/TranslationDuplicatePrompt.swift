import Foundation

/// C7-T2 — une installation de traduction différée à la confirmation
/// Remplacer/Garder. Le pending porte tout ce qu'il faut pour exécuter le
/// dépôt **sans repasser par la garde** (le consentement est donné) : pour
/// `.dropped`, l'extrait temporaire vit le temps du dialogue ; pour
/// `.nexus`, l'archive téléchargée est purgée seulement au Remplacer (elle
/// est consommée) ou au Garder (abandon).
public enum PendingTranslationInstall {
    case nexus(archive: URL, hit: NexusModSearch.Hit, host: ModItem)
    case dropped(plan: ManifestlessArchive.Plan, extractedRoot: URL, sourceName: String,
                 downloadedModId: Int?, host: ModItem)

    public var host: ModItem {
        switch self {
        case .nexus(_, _, let host): return host
        case .dropped(_, _, _, _, let host): return host
        }
    }
}
