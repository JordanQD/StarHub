import SwiftUI

// MARK: - Quarantine View

/// Displays quarantined items grouped by rule inside Apple's native
/// `Form().formStyle(.grouped)`, plus toolbar actions to rescan, open the
/// `_Trash_` folder, or move quarantined items to the Mac Trash.
struct QuarantineView: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    @State private var showEmptyConfirmation = false

    var body: some View {
        let quarantineDir = quarantinePath
        let report = vm.maintenanceStore.lastRepairReport
        let onDisk = ModTrash.entries(vm.maintenanceStore.quarantineEntries,
                                      outsideReportedTrash: report?.trashPath)
        let hasReportItems = report.map { !$0.quarantined.isEmpty || !$0.duplicates.isEmpty || !$0.reviewItems.isEmpty } ?? false
        let isEmpty = !hasReportItems && onDisk.isEmpty

        Group {
            if isEmpty && vm.maintenanceStore.quarantineMessage == nil {
                ContentUnavailableView {
                    Label(localization.L(L10n.Quarantine.noQuarantine), systemImage: "tray")
                } description: {
                    Text(localization.L(L10n.Quarantine.subtitleShort))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Form {
                    if let result = vm.maintenanceStore.quarantineMessage {
                        Section {
                            Label(result.text, systemImage: result.isError ? "xmark.octagon.fill" : "checkmark.circle.fill")
                                .font(AppDesign.Font.body)
                                .foregroundStyle(result.isError ? AppDesign.Color.error : AppDesign.Color.success)
                        }
                    }

                    if let report, hasReportItems {
                        RepairReportCard(report: report, localization: localization, gameDir: vm.gameDir)
                    }

                    if !onDisk.isEmpty {
                        QuarantineOnDiskCard(entries: onDisk, localization: localization)
                    }

                    if isEmpty {
                        Section {
                            Label(localization.L(L10n.Quarantine.noQuarantine), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(AppDesign.Color.success)
                        }
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppDesign.Color.windowBg)
        .navigationSubtitle(localization.L(L10n.Quarantine.subtitleShort))
        .toolbar {
            ToolbarItemGroup {
                if vm.scanStore.scanProgress != nil {
                    ProgressView().controlSize(.small)
                }
                Button(action: { vm.refresh() }) {
                    Label(localization.L(L10n.Quarantine.rescan), systemImage: "arrow.clockwise")
                }
                .help(localization.L(L10n.Quarantine.rescan))
                .disabled(vm.scanStore.scanProgress != nil)

                Button(action: openQuarantineFolder) {
                    Label(localization.L(L10n.Quarantine.openFolder), systemImage: "folder")
                }
                .help(localization.L(L10n.Quarantine.openFolder))
                .disabled(quarantineDir == nil)

                Button(role: .destructive, action: { showEmptyConfirmation = true }) {
                    Label(localization.L(L10n.Quarantine.emptyTrash), systemImage: "trash")
                }
                .help(localization.L(L10n.Quarantine.emptyTrash))
                .disabled(quarantineDir == nil)
            }
        }
        .confirmationDialog(
            localization.L(L10n.Quarantine.emptyConfirmTitle),
            isPresented: $showEmptyConfirmation,
            titleVisibility: .visible
        ) {
            Button(localization.L(L10n.Quarantine.emptyTrash), role: .destructive) {
                emptyToMacTrash()
            }
            Button(localization.L(L10n.Main.ok), role: .cancel) {}
        } message: {
            Text(localization.L(L10n.Quarantine.emptyConfirmMessage))
        }
    }

    // MARK: - Actions

    private var quarantinePath: String? {
        guard !vm.gameDir.isEmpty else { return nil }
        let gameDirURL = URL(fileURLWithPath: vm.gameDir).resolvingSymlinksInPath()
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: gameDirURL.path) else { return nil }
        if let reported = vm.maintenanceStore.lastRepairReport?.trashPath,
           FileManager.default.fileExists(atPath: reported) {
            let reportedURL = URL(fileURLWithPath: reported).resolvingSymlinksInPath()
            let lastComponent = reportedURL.lastPathComponent
            if lastComponent.hasPrefix("_Trash_"),
               reportedURL.path.hasPrefix(gameDirURL.path + "/") {
                return reported
            }
        }
        let trashFolders = entries
            .filter { $0.hasPrefix("_Trash_") }
            .sorted()
        guard let newest = trashFolders.last else { return nil }
        return (vm.gameDir as NSString).appendingPathComponent(newest)
    }

    private func openQuarantineFolder() {
        guard let path = quarantinePath else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    private func emptyToMacTrash() {
        let vm = self.vm
        guard !vm.gameDir.isEmpty else { return }
        let fm = FileManager.default
        let gameDirURL = URL(fileURLWithPath: vm.gameDir).resolvingSymlinksInPath()
        guard let entries = try? fm.contentsOfDirectory(atPath: gameDirURL.path) else { return }
        let trashURLs = entries
            .filter { $0.hasPrefix("_Trash_") }
            .map { gameDirURL.appendingPathComponent($0) }

        guard !trashURLs.isEmpty else {
            vm.maintenanceStore.setQuarantineMessage(.init(text: localization.L(L10n.Quarantine.noQuarantine), isError: false))
            return
        }

        NSWorkspace.shared.recycle(trashURLs, completionHandler: { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    vm.maintenanceStore.setQuarantineMessage(.init(text: error.localizedDescription, isError: true))
                } else {
                    vm.maintenanceStore.setQuarantineMessage(.init(text: localization.L(L10n.Quarantine.emptied), isError: false))
                    vm.maintenanceStore.setRepairReport(nil)
                }
                vm.refreshTrash()
            }
        })
    }
}
