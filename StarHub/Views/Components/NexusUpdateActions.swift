import SwiftUI

struct NexusUpdateActions: View {
    let update: NexusUpdateChecker.ModUpdate
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    var isLogOnly = false

    var body: some View {
        let website = update.updateWebsite
        let nexusID = update.updatePageID
        if let nexusID, vm.downloadingNexusModId == nexusID {
            downloadProgress
        } else {
            AdaptiveLabels {
                HStack(spacing: 4) {
                    if let website {
                        Button {
                            if vm.hasConfirmedNexusPremium, let nexusID {
                                vm.downloadModFromNexus(nexusId: nexusID)
                            } else if nexusID != nil {
                                NexusWebLinks.openUpdateFiles(for: website.absoluteString)
                            } else {
                                NSWorkspace.shared.open(website)
                            }
                        } label: {
                            Label(localization.L(L10n.Updates.installUpdate), systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.bordered).focusRing()
                        .help(localization.L(actionHelp(nexusID: nexusID)))
                        .disabled(nexusID != nil && vm.hasConfirmedNexusPremium && vm.isDownloadingFromNexus)
                    }

                    Menu {
                        if vm.hasConfirmedNexusPremium, nexusID != nil, let website {
                            Button(localization.L(L10n.Mods.nexusUpdate)) {
                                NexusWebLinks.openUpdateFiles(for: website.absoluteString)
                            }
                        }
                        Menu(localization.L(L10n.Updates.snoozeButton)) {
                            snoozeButton(L10n.Updates.snoozeOneWeek, mode: .oneWeek)
                            if !isLogOnly {
                                snoozeButton(L10n.Updates.snoozeUntilModVersion, mode: .untilModVersion)
                                snoozeButton(L10n.Updates.snoozeUntilGameVersion, mode: .untilGameVersion)
                            }
                        }
                        if !isLogOnly {
                            Button(localization.L(L10n.Updates.nexusAlreadyHave)) {
                                vm.affirmInstalled(uniqueId: update.uniqueId, version: update.latestVersion)
                            }
                            .help(localization.L(L10n.Updates.nexusAlreadyHaveHelp))
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .focusRing(cornerRadius: 4)
                    .iconHelp(localization.L(L10n.Updates.updateOptions))
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func actionHelp(nexusID: Int?) -> String {
        if nexusID == nil { return L10n.Updates.openSmapiPage }
        return vm.hasConfirmedNexusPremium ? L10n.Mods.premiumUpdate : L10n.Mods.nexusUpdate
    }

    private var downloadProgress: some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.small)
            if let percent = vm.nexusDownloadProgress?.displayPercent {
                Text("\(percent)%")
                    .font(AppDesign.Font.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Button(action: { vm.cancelNexusDownload() }) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain).focusRing()
            .iconHelp(localization.L(L10n.Downloads.cancel))
        }
    }

    private func snoozeButton(_ title: String, mode: ModUpdateSnoozeEntry.Mode) -> some View {
        Button(localization.L(title)) { vm.snoozeUpdate(update, mode: mode) }
    }
}
