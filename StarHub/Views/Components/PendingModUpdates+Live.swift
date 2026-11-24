import SwiftUI

extension PendingModUpdates {
    /// L'index des mises à jour dues, construit depuis l'état de l'app — les
    /// mêmes sources et le même filtre que le badge « Mises à jour » (X113) :
    /// lignes du dernier contrôle, puis résultats du journal SMAPI dédoublonnés
    /// et confrontés aux versions installées.
    ///
    /// Le tableau et les compteurs construisent chacun leur index une fois par passe.
    @MainActor static func current(_ vm: StarHubTHViewModel) -> PendingModUpdates {
        let groups = PendingUpdateList(vm).groups
        let smapi = (groups.active + groups.paused).compactMap { row -> (folderName: String, version: String, url: String)? in
            guard row.isLogOnly, let mod = row.mod else { return nil }
            return (mod.folderName, row.update.latestVersion, row.update.url)
        }
        return PendingModUpdates(nexus: vm.nexusUpdates.map { ($0.uniqueId, $0.latestVersion) },
                                 smapi: smapi)
    }
}
