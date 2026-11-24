import SwiftUI

struct SaveDetailView: View {
    var viewModel: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    let save: SaveGameInfo
    @Binding var currentTab: SidebarDestination
    @State private var backupRefreshToken = 0

    var body: some View {
        let navigation = viewModel.navigationStore
        ZStack {
            shown(.details, navigation.saveSegment) {
                SaveEditorView(vm: viewModel, localization: localization, save: save, currentTab: $currentTab)
            }
            shown(.mods, navigation.saveSegment) { modsSegment }
            shown(.history, navigation.saveSegment) {
                SaveTimelineView(vm: viewModel, localization: localization, save: save,
                                 refreshToken: backupRefreshToken)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationSubtitle(save.farmName)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker(localization.L(L10n.Saves.saves), selection: Binding(
                    get: { navigation.saveSegment },
                    set: { navigation.saveSegment = $0 }
                )) {
                    ForEach(SaveSegment.allCases, id: \.self) { segment in
                        Text(label(segment)).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            if navigation.saveSegment == .history {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            if await viewModel.createBackup(info: save) {
                                backupRefreshToken += 1
                            }
                        }
                    } label: {
                        if viewModel.isSaveOperationRunning {
                            ProgressView().controlSize(.small)
                        } else {
                            Label(localization.L(L10n.Saves.backupLabel), systemImage: "plus")
                        }
                    }
                    .prominentToolbarAction()
                    .disabled(viewModel.isSaveOperationRunning)
                    .help(localization.L(L10n.Saves.backupLabel))
                }
            }
        }
    }

    private var modsSegment: some View {
        Form {
            SavePausedFootprintSection(vm: viewModel, localization: localization, save: save, currentTab: $currentTab)
            SaveAbsentModsSection(vm: viewModel, localization: localization, save: save)
        }
        .formStyle(.grouped)
    }

    private func shown(_ segment: SaveSegment, _ current: SaveSegment,
                       @ViewBuilder content: () -> some View) -> some View {
        let visible = segment == current
        return content()
            .zIndex(visible ? 1 : 0)
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .disabled(!visible)
            .accessibilityHidden(!visible)
    }

    private func label(_ segment: SaveSegment) -> String {
        switch segment {
        case .details: return localization.L(L10n.Saves.segmentDetails)
        case .mods:    return localization.L(L10n.Saves.segmentMods)
        case .history: return localization.L(L10n.Saves.timeline)
        }
    }
}
