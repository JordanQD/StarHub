import Foundation

/// Toutes les raisons d'une anomalie, une par ligne : un mod peut cumuler une
/// dépendance manquante et des erreurs, et n'en montrer qu'une enverrait sur
/// une fausse piste.
///
/// `@MainActor` : la fonction lit l’état du ViewModel.
@MainActor
func anomalyReasons(_ anomaly: ModAnomaly, vm: StarHubTHViewModel) -> String {
    var lines: [String] = []
    if anomaly.isUnloadable { lines.append(vm.localization.L(L10n.Mods.anomalyUnloadable)) }
    if anomaly.hasDependencyIssue { lines.append(vm.localization.L(L10n.Mods.anomalyDependency)) }
    if let duplicate = anomaly.duplicate {
        // Les dossiers **nommés** : un compte seul laisserait chercher lequel supprimer parmi 863.
        lines.append(String(format: vm.localization.L(duplicate.isActive
                                         ? L10n.Mods.anomalyDuplicateActive
                                         : L10n.Mods.anomalyDuplicateDormant),
                            duplicate.copies,
                            duplicate.folders.joined(separator: ", ")))
    }
    if let renamed = anomaly.renamed { lines.append(renamedReason(renamed, vm.localization)) }
    if let status = anomaly.compatibility {
        lines.append(String(format: vm.localization.L(L10n.Mods.anomalyCompat),
                            CompatibilityWarning.label(status, vm.localization)))
    }
    if anomaly.errorCount > 0 {
        lines.append(String(format: vm.localization.L(L10n.Mods.anomalyErrors), anomaly.errorCount))
    }
    if anomaly.warningCount > 0 {
        lines.append(String(format: vm.localization.L(L10n.Mods.anomalyWarnings), anomaly.warningCount))
    }
    return lines.joined(separator: "\n")
}
