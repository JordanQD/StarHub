import SwiftUI

/// Single `.alert` presenter for all Maintenance confirmations.
private enum MaintenanceConfirmation {
    case purge(keepPerMod: Int, doomed: Int, freedBytes: Int64)
    case cleanStale(orphans: Int, keys: Int)
    case removeProtected(session: String, modName: String)
    case purgeTrashAll(events: Int)
    case purgeTrashEntry(event: String, entry: String)
    case purgeArchives(only: NexusArchiveEntry?)
}

/// Maintenance hub: macOS System Settings Storage-style native `Form().formStyle(.grouped)`
/// with top-level mod actions in the native `.toolbar`.
struct MaintenanceView: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore

    @State private var confirmation: MaintenanceConfirmation?
    @AppStorage(UDKey.keepNexusArchives) private var keepNexusArchives: Bool = false

    var body: some View {
        Group {
            if let report = vm.maintenanceReport {
                if !report.isEmpty || !vm.trashEvents.isEmpty || keepNexusArchives
                    || !vm.nexusArchives.isEmpty {
                    Form {
                        if report.isEmpty {
                            Section {
                                Label(localization.L(L10n.Maintenance.nothingToDo), systemImage: "sparkles")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            MaintenanceStorageCard(
                                report: report,
                                localization: localization,
                                onPurge: { keep, doomed, freed in
                                    confirmation = .purge(keepPerMod: keep, doomed: doomed, freedBytes: freed)
                                },
                                onCleanStale: {
                                    confirmation = .cleanStale(
                                        orphans: report.orphanSessions.count,
                                        keys: report.stalePreferenceKeys.count
                                    )
                                },
                                openBackups: { vm.navigationStore.openBackups(segment: $0) }
                            )

                            if report.protectedCount > 0 {
                                protectedSection(report)
                            }
                        }

                        MaintenanceTrashSection(
                            viewModel: vm,
                            localization: localization,
                            onPurgeAll: { confirmation = .purgeTrashAll(events: $0) },
                            onPurgeEntry: { confirmation = .purgeTrashEntry(event: $0, entry: $1) }
                        )

                        MaintenanceArchivesSection(
                            vm: vm,
                            localization: localization,
                            keepNexusArchives: keepNexusArchives,
                            onPurgeAll: { confirmation = .purgeArchives(only: nil) },
                            onDelete: { confirmation = .purgeArchives(only: $0) }
                        )
                    }
                    .formStyle(.grouped)
                    .scrollContentBackground(.hidden)
                } else {
                    ContentUnavailableView {
                        Label(localization.L(L10n.Maintenance.nothingToDo), systemImage: "sparkles")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: AppDesign.Spacing.md) {
                    ProgressView()
                    Text(localization.L(L10n.Maintenance.loading))
                        .font(AppDesign.Font.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AppDesign.Color.windowBg)
        .navigationSubtitle(headerSubtitle)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                MaintenanceModActions(vm: vm, localization: localization)

                if vm.isBuildingMaintenanceReport {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        vm.buildMaintenanceReport()
                        vm.refreshTrash()
                        vm.refreshNexusArchives()
                    } label: {
                        Label(localization.L(L10n.ModInstall.refreshBackups), systemImage: "arrow.clockwise")
                    }
                    .help(localization.L(L10n.ModInstall.refreshBackups))
                }
            }
        }
        .onAppear {
            vm.buildMaintenanceReport()
            vm.refreshTrash()
            vm.refreshNexusArchives()
        }
        .alert(alertTitle,
               isPresented: Binding(get: { confirmation != nil },
                                    set: { if !$0 { confirmation = nil } }),
               presenting: confirmation) { pending in
            switch pending {
            case .purge(let keep, _, _):
                Button(localization.L(L10n.Maintenance.confirmTrash), role: .destructive) {
                    vm.purgeInstallBackups(keepPerMod: keep)
                }
                Button(localization.L(L10n.Maintenance.cancel), role: .cancel) { }
            case .cleanStale:
                Button(localization.L(L10n.Maintenance.confirmRemove), role: .destructive) {
                    vm.cleanStaleMaintenanceEntries()
                }
                Button(localization.L(L10n.Maintenance.cancel), role: .cancel) { }
            case .removeProtected(let session, _):
                Button(localization.L(L10n.Maintenance.actionRemoveAnyway), role: .destructive) {
                    vm.purgeProtectedBackup(session: session)
                }
                Button(localization.L(L10n.Maintenance.cancel), role: .cancel) { }
            case .purgeTrashAll:
                Button(localization.L(L10n.Maintenance.confirmRemove), role: .destructive) {
                    vm.purgeAllTrash()
                }
                Button(localization.L(L10n.Maintenance.cancel), role: .cancel) { }
            case .purgeTrashEntry(let event, let entry):
                Button(localization.L(L10n.Maintenance.confirmRemove), role: .destructive) {
                    vm.purgeTrashEntry(event: event, entry: entry)
                }
                Button(localization.L(L10n.Maintenance.cancel), role: .cancel) { }
            case .purgeArchives(let only):
                Button(localization.L(L10n.Maintenance.confirmRemove), role: .destructive) {
                    if let only { vm.deleteNexusArchive(only) } else { vm.purgeNexusArchives() }
                }
                Button(localization.L(L10n.Maintenance.cancel), role: .cancel) { }
            }
        } message: { pending in
            switch pending {
            case .purge(_, let doomed, let freed):
                Text(String(format: localization.L(L10n.Maintenance.purgeMessage),
                            doomed, SharedFormatters.bytes(freed)))
            case .cleanStale(let orphans, let keys):
                Text(String(format: localization.L(L10n.Maintenance.cleanMessage),
                            orphans, keys))
            case .removeProtected(_, let modName):
                Text(String(format: localization.L(L10n.Maintenance.protectedRemoveMessage),
                            modName))
            case .purgeTrashAll(let events):
                Text(String(format: localization.L(L10n.Maintenance.trashPurgeAllMessage), events))
            case .purgeTrashEntry(_, let entry):
                Text(String(format: localization.L(L10n.Maintenance.trashPurgeOneMessage), entry))
            case .purgeArchives(let only):
                Text(only.map { String(format: localization.L(L10n.Maintenance.archivesDeleteConfirm), $0.modName,
                                       $0.version) } ?? localization.L(L10n.Maintenance.archivesPurgeConfirm))
            }
        }
    }

    // MARK: - Protected Backups Section

    private var headerSubtitle: String {
        vm.maintenanceReport.map {
            String(format: localization.L(L10n.Maintenance.headerTotal),
                   SharedFormatters.bytes($0.totalBytes))
        } ?? ""
    }

    private func protectedSection(_ report: MaintenanceInventory.Report) -> some View {
        Section(String(format: localization.L(L10n.Maintenance.protectedTitle), report.protectedCount)) {
            ForEach(protectedRows(report)) { row in
                protectedRowView(row)
            }
        }
    }

    private func protectedRowView(_ row: ProtectedRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: AppDesign.Spacing.sm) {
                Image(systemName: row.isGone ? AppDesign.Status.warning.symbol : "arrow.uturn.backward")
                    .foregroundStyle(AppDesign.Color.warning)
                Text(row.modFolder)
                    .font(AppDesign.Font.body(.medium))
                Spacer()
                Text(row.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Button(role: .destructive) {
                    confirmation = .removeProtected(session: row.session, modName: row.modFolder)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(AppDesign.Color.error)
                }
                .buttonStyle(.borderless)
                .help(localization.L(L10n.Maintenance.actionRemoveAnyway))
            }

            ForEach(row.files, id: \.relativePath) { file in
                HStack(alignment: .firstTextBaseline, spacing: AppDesign.Spacing.sm) {
                    Text(file.relativePath)
                        .font(AppDesign.Font.monoCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text(localization.L(row.isGone ? L10n.Maintenance.reasonGone
                                                   : L10n.Maintenance.reasonMissing))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if row.isGone {
                        Button(localization.L(L10n.Maintenance.actionReveal)) {
                            if let path = vm.maintenanceProtectedFilePath(
                                session: row.session, relativePath: file.relativePath) {
                                vm.revealProtectedBackup(atPath: path)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button(localization.L(L10n.Maintenance.actionOpenRecovery)) {
                            vm.navigationStore.openBackups(segment: .files)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.leading, AppDesign.Spacing.md)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private struct ProtectedRow: Identifiable {
        let session: String
        let modFolder: String
        let timestamp: Date
        let files: [MaintenanceInventory.UserFile]
        let isGone: Bool
        var id: String { session }
    }

    private func protectedRows(_ report: MaintenanceInventory.Report) -> [ProtectedRow] {
        report.backups.compactMap { entry in
            guard case .soleCopy(let files)? = report.protections[entry.id],
                  !files.isEmpty else { return nil }
            return ProtectedRow(session: entry.id,
                                modFolder: entry.modFolder,
                                timestamp: entry.timestamp,
                                files: files,
                                isGone: report.missingMods.contains(entry.id))
        }
    }

    private var alertTitle: String {
        switch confirmation {
        case .purge: return localization.L(L10n.Maintenance.purgeTitle)
        case .cleanStale: return localization.L(L10n.Maintenance.cleanTitle)
        case .removeProtected: return localization.L(L10n.Maintenance.protectedRemoveTitle)
        case .purgeTrashAll, .purgeTrashEntry:
            return localization.L(L10n.Maintenance.trashSectionTitle)
        case .purgeArchives: return localization.L(L10n.Maintenance.archivesTitle)
        case nil: return ""
        }
    }
}
