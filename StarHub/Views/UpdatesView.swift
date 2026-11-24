import SwiftUI

struct UpdatesView: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore

    var body: some View {
        let list = PendingUpdateList(vm)
        let hasUpdates = !list.groups.active.isEmpty || !list.groups.paused.isEmpty
        let error = vm.isCheckingNexusUpdates ? nil : vm.nexusCheckError
        let hasUpdateRecords = hasUpdates || !list.snoozed.isEmpty || !list.affirmed.isEmpty
        let showEmptyState = !hasUpdateRecords && !vm.isCheckingNexusUpdates && error == nil

        Group {
            if showEmptyState && vm.unverifiableMods.isEmpty {
                emptyState
            } else {
                BackToTopScrollView(localization) {
                    LazyVStack(alignment: .leading, spacing: AppDesign.Spacing.lg) {
                        if let error {
                            UpdateCheckFailureBanner(viewModel: vm, localization: localization,
                                                     error: error, listIsStale: !vm.nexusUpdates.isEmpty)
                        } else if showEmptyState {
                            emptyState.containerRelativeFrame(.vertical) { height, _ in height * 0.8 }
                        }

                        NexusUpdateList(list: list, viewModel: vm, localization: localization)

                        if !vm.unverifiableMods.isEmpty {
                            UnverifiableModsSection(viewModel: vm, localization: localization)
                        }
                    }
                    .padding(AppDesign.Spacing.xl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppDesign.Color.windowBg)
        .toolbar {
            ToolbarItem {
                UpdateCheckButton(vm: vm, localization: localization)
            }
        }
        .onAppear { vm.refreshAffirmedUpdates() }
    }
}
