import SwiftUI

// Actions ponctuelles sorties des Réglages le 2026-09-25 (revue de la page,
// décision de l'auteur) : ce ne sont pas des réglages, et elles vivent
// désormais sur l'écran de leur objet.

/// Barre d'outils de « Sauvegardes du jeu » : ouvrir le dossier des parties,
/// et en faire un zip là où l'utilisateur le choisit (`FolderArchiveSheet`).
struct SavesDataActions: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    @State private var archive: FolderArchiveRequest?

    var body: some View {
        Button(action: { vm.openSavesFolder() }) {
            Label(localization.L(L10n.Settings.savesFolder), systemImage: "folder")
        }
        .help(localization.L(L10n.Settings.savesFolder))

        Button(action: { archive = .saves(localization) }) {
            Label(localization.L(L10n.Saves.backupLabel), systemImage: "archivebox")
        }
        .help(localization.L(L10n.Saves.backupLabel))
        .sheet(item: $archive) { FolderArchiveSheet(localization: localization, request: $0) }
    }
}

/// Toolbar actions for Maintenance: archive `Mods/` or move disabled mods to trash.
struct MaintenanceModActions: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    @State private var targets: [String] = []
    @State private var confirming = false
    @State private var archive: FolderArchiveRequest?

    var body: some View {
        Button(action: archiveMods) {
            Label(localization.L(L10n.Settings.backupMods), systemImage: "archivebox")
        }
        .help(localization.L(L10n.Settings.hintCompressMods))
        .sheet(item: $archive) { FolderArchiveSheet(localization: localization, request: $0) }

        Button(role: .destructive) {
            targets = vm.disabledModTargets()
            if targets.isEmpty {
                vm.showModal(message: localization.L(L10n.VM.cleanModsNotFound))
            } else {
                confirming = true
            }
        } label: {
            Label(localization.L(L10n.Settings.clearDisabledMods), systemImage: "trash")
        }
        .help(localization.L(L10n.Settings.clearDisabledMods))
        .alert(localization.L(L10n.Settings.clearDisabledMods), isPresented: $confirming) {
            Button(localization.L(L10n.Settings.deleteJunkMods), role: .destructive) {
                vm.cleanDisabledMods(targets: targets)
            }
            Button(localization.L(L10n.Saves.cancel), role: .cancel) { }
        } message: {
            Text(String(format: localization.L(L10n.Settings.clearDisabledConfirmCount),
                        Int64(targets.count)))
        }
    }

    private func archiveMods() {
        guard let request = FolderArchiveRequest.mods(from: vm, localization) else {
            vm.showModal(message: localization.L(L10n.Settings.gameDirNotSet))
            return
        }
        archive = request
    }
}
