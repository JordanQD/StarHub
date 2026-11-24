import AppKit
import SwiftUI

/// I-T20 — les gestes de sélection multiple de la liste des mods.
extension ModListState {
    @MainActor
    func clickRow(_ folderName: String, kind: ModListSelection.ClickKind, viewModel: StarHubTHViewModel) {
        selection.click(folderName, kind: kind, in: displayOrder)
        viewModel.selectedModID = selection.selected.contains(folderName)
            ? folderName : selection.members(in: displayOrder).last
    }

    /// Les mods sélectionnés encore affichés ; à défaut, la ligne courante si
    /// elle l'est — Espace bascule alors ce seul mod (`effectiveMembers`).
    @MainActor
    func selectedMods(_ viewModel: StarHubTHViewModel, order: [String]? = nil) -> [ModItem] {
        let ids = Set(selection.effectiveMembers(in: order ?? displayOrder, current: viewModel.selectedModID))
        guard !ids.isEmpty else { return [] }
        return viewModel.mods.filter { ids.contains($0.folderName) }
    }

    /// Bascule la sélection ; `enable` absent, c'est la règle d'Espace.
    @MainActor
    func toggleSelection(_ viewModel: StarHubTHViewModel, enable: Bool? = nil) -> Bool {
        let mods = selectedMods(viewModel)
        guard !mods.isEmpty else { return false }
        viewModel.toggleMods(mods, enable: enable ?? ModListSelection.spaceEnables(mods))
        return true
    }
}

extension ModListView {
    @discardableResult
    func clearModSelection() -> Bool {
        guard !listState.selection.selected.isEmpty || vm.selectedModID != nil else { return false }
        listState.selection.clear()
        vm.selectedModID = nil
        return true
    }

    @ViewBuilder
    func modItemActions(for mods: [ModItem]) -> some View {
        if !mods.isEmpty {
            let configurableMod = mods.count == 1 && mods[0].hasConfigFile ? mods[0] : nil
            let topLevelMods = mods.filter { !$0.isPackComponent }

            Button {
                let folders = mods.map { LegacyCleanupSession.modFolder(for: $0, gameDir: vm.gameDir) }
                if folders.count == 1, let folder = folders.first {
                    NSWorkspace.shared.open(folder)
                } else {
                    NSWorkspace.shared.activateFileViewerSelecting(folders)
                }
            } label: {
                Label(localization.L(L10n.Mods.openInFinder), systemImage: "folder")
            }
            .disabled(vm.gameDir.isEmpty)

            Button {
                if let configurableMod { navigation.setEditingModConfig(configurableMod) }
            } label: {
                Label(localization.L(L10n.Settings.configModSettings), systemImage: "gearshape")
            }
            .disabled(configurableMod == nil || vm.gameDir.isEmpty)

            ModGroupMoveMenu(folders: topLevelMods.map(\.folderName), viewModel: vm,
                             localization: localization, listState: listState)
                .disabled(vm.bulkToggleProgress != nil || topLevelMods.count != mods.count)

            Divider()

            Button(role: .destructive) {
                confirmMovingModsToTrash(topLevelMods)
            } label: {
                Label(localization.L(L10n.Mods.trashSelection), systemImage: "trash")
            }
            .disabled(vm.bulkToggleProgress != nil || topLevelMods.count != mods.count
                      || !ModTrashSelection.hasTrashable(topLevelMods))
        }
    }

    /// Nombres d'approbations et dates de tout le parc (une fois par jour),
    /// puis tes approbations (une requête, avec clé).
    func loadNexusStats() async {
        NexusModStatsRefresher.refreshIfDue(viewModel: vm)
        if vm.hasNexusApiKey { await vm.endorsementStore.loadIfNeeded { vm.log($0) } }
    }
}
