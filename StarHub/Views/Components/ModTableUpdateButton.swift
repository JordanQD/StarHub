import SwiftUI

struct ModTableUpdateButton: View {
    let pending: PendingModUpdates.Pending
    var vm: StarHubTHViewModel
    let localization: LocalizationStore

    var body: some View {
        if let update = nexusUpdate,
           let nexusID = update.updatePageID,
           vm.hasConfirmedNexusPremium {
            if vm.downloadingNexusModId == nexusID {
                ProgressView()
                    .controlSize(.small)
                    .help(title(L10n.Mods.premiumUpdate))
            } else {
                updateButton(title(L10n.Mods.premiumUpdate)) {
                    vm.downloadModFromNexus(nexusId: nexusID)
                }
            }
        } else if let update = nexusUpdate, let url = update.updateWebsite {
            let isNexus = update.updatePageID != nil
            updateButton(title(isNexus ? L10n.Mods.nexusUpdate : L10n.Updates.openSmapiPage)) {
                if isNexus {
                    NexusWebLinks.openUpdateFiles(for: url.absoluteString)
                } else {
                    NSWorkspace.shared.open(url)
                }
            }
        } else if case .smapi(let link) = pending.source,
                  let url = URL(string: link), url.scheme == "https" || url.scheme == "http" {
            updateButton(title(L10n.Updates.openSmapiPage)) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private var nexusUpdate: NexusUpdateChecker.ModUpdate? {
        guard case .nexus(let id) = pending.source else { return nil }
        return vm.nexusUpdates.first { $0.uniqueId == id }
    }

    private func title(_ key: String) -> String {
        localization.L(key) + " · " + String(format: localization.L(L10n.Updates.availableVersion),
                                             pending.availableVersion)
    }

    private func updateButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(.tint)
                .frame(minWidth: 18, minHeight: 18)
        }
        .buttonStyle(.borderless)
        .disabled(vm.isDownloadingFromNexus)
        .iconHelp(title)
    }
}
