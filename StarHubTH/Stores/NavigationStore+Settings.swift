import Foundation

/// R7 (audit UX 2026-10-16) — ouvrir les Réglages sur une section, depuis
/// n'importe quel écran. Fichier à part : `NavigationStore.swift` est au
/// plafond de 400 lignes.
extension NavigationStore {
    /// La vue appelante ouvre la fenêtre native. Celle-ci consomme la section
    /// une fois le bon onglet affiché.
    func openSettings(_ section: SettingsSection) {
        pendingSettingsSection = section
    }
}

/// N-11 — les fichiers récupérables d'un mod, depuis sa fiche.
extension NavigationStore {
    /// Même canal que `openBackups(for:)` : seule la vue du segment affiché le
    /// consomme (`RecoverableFilesView` ici), qui filtre sur ce dossier.
    func openRecoverableFiles(for folderName: String) {
        backupsSegment = .files
        pendingBackupsFocus = folderName
        requestTab(.backups)
    }
}
