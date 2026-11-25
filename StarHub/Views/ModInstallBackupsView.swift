import SwiftUI

/// Single `.alert` presenter for install-backup confirmations.
private enum ModInstallBackupsConfirmation {
    case error(String)
    case restore(ModInstallBackup)
    case delete(ModInstallBackup, soleCopy: [MaintenanceInventory.UserFile])
}

/// Unified row model for Finder-style `Table` + `DisclosureTableRow`.
private struct InstallBackupTableRow: Identifiable {
    enum Kind {
        case group(BackupBrowser.ModGroup)
        case backup(ModInstallBackup)
    }

    let id: String
    let kind: Kind
    let sortName: String
    let sortDate: Date
    let sortCount: Int

    static func group(_ group: BackupBrowser.ModGroup) -> Self {
        Self(
            id: "group:\(group.id)",
            kind: .group(group),
            sortName: group.displayName,
            sortDate: group.latest,
            sortCount: group.backups.count
        )
    }

    static func backup(_ backup: ModInstallBackup) -> Self {
        Self(
            id: "backup:\(backup.id.uuidString)",
            kind: .backup(backup),
            sortName: backup.modMetadata.name,
            sortDate: backup.timestamp,
            sortCount: 1
        )
    }
}

/// Finder-style expandable table view for managing mod installation backups.
struct ModInstallBackupsView: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    @Binding var search: String

    @State private var backups: [ModInstallBackup] = []
    @State private var hasLoaded = false
    @State private var confirmation: ModInstallBackupsConfirmation?
    @State private var restoreReport: ModInstallRestoreReport?
    @State private var busyBackupId: UUID? = nil
    @State private var expandedGroups: Set<String> = []
    @State private var selection: Set<String> = []
    @State private var sortOrder: [KeyPathComparator<InstallBackupTableRow>] = [
        .init(\.sortDate, order: .reverse)
    ]

    private let backupManager = ModInstallBackupManager.shared

    private var activeSort: BackupBrowser.Sort {
        guard let first = sortOrder.first else { return .mostRecent }
        switch first.keyPath {
        case \.sortName:
            return first.order == .forward ? .nameAscending : .nameDescending
        case \.sortCount:
            return .count
        default:
            return .mostRecent
        }
    }

    private var groups: [BackupBrowser.ModGroup] {
        let base = BackupBrowser.groups(from: backups, search: search, sort: activeSort)
        if let first = sortOrder.first, first.keyPath == \.sortDate, first.order == .forward {
            return base.reversed()
        }
        if let first = sortOrder.first, first.keyPath == \.sortCount, first.order == .forward {
            return base.reversed()
        }
        return base
    }

    var body: some View {
        VStack(spacing: 0) {
            if let report = restoreReport {
                restoreReportBanner(report)
                Divider()
            }

            if !hasLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if backups.isEmpty {
                ContentUnavailableView {
                    Label(localization.L(L10n.ModInstall.noBackups), systemImage: "tray")
                } description: {
                    Text(localization.L(L10n.ModInstall.noBackupsHint))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if groups.isEmpty {
                ContentUnavailableView {
                    Label(String(format: localization.L(L10n.ModInstall.backupsNoMatch), search),
                          systemImage: "magnifyingglass")
                } actions: {
                    Button(localization.L(L10n.Discovery.clearSearch)) {
                        search = ""
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                backupTable
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            statusBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: loadBackups) {
                    Label(localization.L(L10n.ModInstall.refreshBackups), systemImage: "arrow.clockwise")
                }
                .help(localization.L(L10n.ModInstall.refreshBackups))
            }
        }
        .task {
            let manager = backupManager
            backups = await Task.detached(priority: .userInitiated) { manager.loadBackups() }.value
            hasLoaded = true
            if await Task.detached(priority: .utility, operation: { manager.cleanupOldBackups() }).value > 0 {
                backups = await Task.detached(priority: .userInitiated) { manager.loadBackups() }.value
            }
        }
        .onAppear { consumePendingBackupsFocus() }
        .onChange(of: vm.navigationStore.pendingBackupsFocus) { _, _ in consumePendingBackupsFocus() }
        .alert(confirmationTitle,
               isPresented: Binding(get: { confirmation != nil },
                                    set: { if !$0 { confirmation = nil } }),
               presenting: confirmation) { pending in
            switch pending {
            case .error:
                Button(localization.L(L10n.Main.ok)) { }
            case .restore(let backup):
                Button(localization.L(L10n.ModInstall.restoreBackup), role: .destructive) {
                    performRestore(backup)
                }
                Button(localization.L(L10n.ModInstall.cancel), role: .cancel) { }
            case .delete(let backup, _):
                Button(localization.L(L10n.ModInstall.deleteBackup), role: .destructive) {
                    performDelete(backup)
                }
                Button(localization.L(L10n.ModInstall.cancel), role: .cancel) { }
            }
        } message: { pending in
            switch pending {
            case .error(let message): Text(message)
            case .restore: Text(localization.L(L10n.ModInstall.restoreConfirmMessage))
            case .delete(_, let soleCopy): Text(deleteMessage(soleCopy: soleCopy))
            }
        }
    }

    // MARK: - Finder-Style Table

    private var backupTable: some View {
        let shown = groups
        let autoExpand = !search.trimmingCharacters(in: .whitespaces).isEmpty && shown.count == 1
        let backupById = Dictionary(uniqueKeysWithValues: backups.map { ("backup:\($0.id.uuidString)", $0) })

        return Table(of: InstallBackupTableRow.self, selection: $selection, sortOrder: $sortOrder) {
            TableColumn(localization.L(L10n.Mods.tableName), value: \.sortName) { row in
                switch row.kind {
                case .group(let group):
                    HStack(spacing: 7) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.tint)
                            .frame(width: 16, alignment: .center)
                        Text(group.displayName)
                            .font(AppDesign.Font.body(.medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .help(group.folderName)
                case .backup(let backup):
                    HStack(spacing: 7) {
                        Image(systemName: reasonIcon(for: backup.reason))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, alignment: .center)
                        Text("v\(backup.modMetadata.version)")
                            .font(AppDesign.Font.body(.medium))
                            .monospacedDigit()
                        if !backup.modMetadata.author.isEmpty {
                            Text("· \(backup.modMetadata.author)")
                                .font(AppDesign.Font.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .help(backup.originalFolderName)
                }
            }
            .width(min: 180, ideal: 280)

            TableColumn(localization.L(L10n.Mods.tableType), value: \.sortCount) { row in
                switch row.kind {
                case .group(let group):
                    Text(group.backups.count == 1
                         ? localization.L(L10n.ModInstall.backupsGroupSingle)
                         : String(format: localization.L(L10n.ModInstall.backupsGroupSummary),
                                  Int64(group.backups.count), Int64(group.versions.count)))
                        .font(AppDesign.Font.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                case .backup(let backup):
                    Text(reasonText(for: backup.reason))
                        .font(AppDesign.Font.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .width(min: 100, ideal: 140)

            TableColumn(localization.L(L10n.Mods.detailUpdated), value: \.sortDate) { row in
                switch row.kind {
                case .group(let group):
                    Text(group.backups.first?.formattedDate ?? "")
                        .font(AppDesign.Font.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                case .backup(let backup):
                    Text(backup.formattedDate)
                        .font(AppDesign.Font.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            .width(min: 110, ideal: 145)

            TableColumn("") { row in
                if case .backup(let backup) = row.kind {
                    if busyBackupId == backup.id {
                        ProgressView()
                            .controlSize(.mini)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        HStack(spacing: 4) {
                            Spacer(minLength: 0)
                            Button {
                                confirmation = .restore(backup)
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                            }
                            .buttonStyle(.borderless)
                            .disabled(busyBackupId != nil)
                            .help(localization.L(L10n.ModInstall.restoreBackup))

                            Button(role: .destructive) {
                                askDelete(backup)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(AppDesign.Color.error)
                            }
                            .buttonStyle(.borderless)
                            .disabled(busyBackupId != nil)
                            .help(localization.L(L10n.ModInstall.deleteBackup))
                        }
                    }
                }
            }
            .width(min: 60, ideal: 68, max: 76)
        } rows: {
            ForEach(shown) { group in
                DisclosureTableRow(InstallBackupTableRow.group(group), isExpanded: Binding(
                    get: { expandedGroups.contains(group.id) || autoExpand },
                    set: { expanded in
                        if expanded { expandedGroups.insert(group.id) }
                        else { expandedGroups.remove(group.id) }
                    }
                )) {
                    ForEach(group.backups) { backup in
                        TableRow(InstallBackupTableRow.backup(backup))
                    }
                }
            }
        }
        .contextMenu(forSelectionType: String.self) { ids in
            if ids.count == 1, let id = ids.first {
                if let backup = backupById[id] {
                    Button(localization.L(L10n.ModInstall.restoreBackup)) {
                        confirmation = .restore(backup)
                    }
                    Divider()
                    Button(localization.L(L10n.ModInstall.deleteBackup), role: .destructive) {
                        askDelete(backup)
                    }
                } else if id.hasPrefix("group:") {
                    let groupId = String(id.dropFirst("group:".count))
                    let isOpen = expandedGroups.contains(groupId)
                    Button(localization.L(isOpen ? L10n.Main.collapse : L10n.Main.expand)) {
                        if isOpen { expandedGroups.remove(groupId) }
                        else { expandedGroups.insert(groupId) }
                    }
                }
            }
        } primaryAction: { ids in
            guard ids.count == 1, let id = ids.first, id.hasPrefix("group:") else { return }
            let groupId = String(id.dropFirst("group:".count))
            if expandedGroups.contains(groupId) { expandedGroups.remove(groupId) }
            else { expandedGroups.insert(groupId) }
        }
    }

    // MARK: - Status Bar & Restore Report

    private var statusBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: AppDesign.Spacing.sm) {
                let count = hasLoaded
                    ? String(format: localization.L(L10n.ModInstall.backupsModsCount),
                             Int64(groups.count), Int64(backups.count))
                    : "…"
                Text(count)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Button(localization.L(L10n.Maintenance.backupsTrashLink)) {
                    vm.navigationStore.openMaintenance()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
            .padding(.horizontal, AppDesign.Spacing.xl)
            .padding(.vertical, AppDesign.Spacing.xs)
        }
        .background(.bar)
    }

    private func restoreReportBanner(_ report: ModInstallRestoreReport) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            HStack {
                Label(localization.L(L10n.ModInstall.restoreReportTitle), systemImage: "checkmark.circle.fill")
                    .font(AppDesign.Font.headline)
                    .foregroundStyle(AppDesign.Color.success)
                Spacer()
                SeverityBadge(severity: report.landedEnabled ? .info : .warning,
                              label: localization.L(report.landedEnabled ? L10n.ModInstall.landedActiveBadge
                                                                        : L10n.ModInstall.landedPausedBadge))
                Button {
                    restoreReport = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(localization.L(L10n.Main.close))
            }

            HStack(spacing: AppDesign.Spacing.lg) {
                LabeledContent(localization.L(L10n.ModInstall.labelName), value: "\(report.modName) v\(report.version)")
                LabeledContent(localization.L(L10n.ModInstall.labelFilesWritten), value: "\(report.fileCount)")
                Spacer()
                Button(localization.L(L10n.ModInstall.revealInFinder)) {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: report.destinationPath)])
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .font(AppDesign.Font.footnote)

            Text(report.displayPath)
                .font(AppDesign.Font.monoIconXS)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(report.displayPath)

            if !report.replacedVersions.isEmpty {
                let replacedText = report.replacedVersions.joined(separator: ", ")
                LabeledContent(localization.L(L10n.ModInstall.labelKeptVersions), value: replacedText)
                    .font(AppDesign.Font.footnote)
                    .foregroundStyle(.secondary)
                    .help(replacedText)
            }
        }
        .padding(.horizontal, AppDesign.Spacing.xl)
        .padding(.vertical, AppDesign.Spacing.md)
        .background(AppDesign.Color.controlBg)
    }

    // MARK: - Helpers & Actions

    private var confirmationTitle: String {
        switch confirmation {
        case .error: return localization.L(L10n.ModInstall.operationFailed)
        case .restore: return localization.L(L10n.ModInstall.restoreConfirm)
        case .delete: return localization.L(L10n.ModInstall.deleteConfirm)
        case nil: return ""
        }
    }

    private func consumePendingBackupsFocus() {
        let navigation = vm.navigationStore
        guard let folder = navigation.pendingBackupsFocus else { return }
        search = folder
        expandedGroups.insert(folder)
        navigation.pendingBackupsFocus = nil
    }

    private func loadBackups() {
        backups = backupManager.loadBackups()
    }

    private func performRestore(_ backup: ModInstallBackup) {
        guard busyBackupId == nil else { return }
        guard !vm.gameDir.isEmpty else {
            DispatchQueue.main.async {
                confirmation = .error(localization.L(L10n.Settings.gameDirNotSet))
            }
            return
        }

        busyBackupId = backup.id
        let gameDir = vm.gameDir
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let report = try backupManager.restoreBackup(backup, gameDir: gameDir)
                DispatchQueue.main.async {
                    busyBackupId = nil
                    vm.log(restoreReportMessage(report), level: .info)
                    restoreReport = report
                    vm.anchorInstalledMods(installedFolderPaths: [report.destinationPath])
                    vm.refresh()
                    loadBackups()
                }
            } catch {
                DispatchQueue.main.async {
                    busyBackupId = nil
                    confirmation = .error(vm.installErrorMessage(error))
                }
            }
        }
    }

    private func askDelete(_ backup: ModInstallBackup) {
        guard busyBackupId == nil else { return }
        busyBackupId = backup.id
        Task {
            let files = await soleCopy(of: backup)
            (busyBackupId, confirmation) = (nil, .delete(backup, soleCopy: files))
        }
    }

    private func performDelete(_ backup: ModInstallBackup) {
        guard busyBackupId == nil else { return }
        busyBackupId = backup.id
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try backupManager.trashBackup(backup)
                DispatchQueue.main.async {
                    busyBackupId = nil
                    loadBackups()
                }
            } catch {
                DispatchQueue.main.async {
                    busyBackupId = nil
                    confirmation = .error(vm.installErrorMessage(error))
                }
            }
        }
    }
}
