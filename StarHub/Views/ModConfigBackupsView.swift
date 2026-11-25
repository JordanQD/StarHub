import SwiftUI

/// Single `.alert` presenter for config-backup confirmations.
private enum ModConfigBackupsConfirmation {
    case restore(ModConfigBackup, [ModConfigBackupItem])
    case delete(ModConfigBackup, soleCopy: [String])
    case cleanup(String)
}

/// Finder-style expandable table view for managing mod configuration backups.
struct ModConfigBackupsView: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    @Binding var modFilter: String?
    @Binding var search: String

    @State private var backups: [ModConfigBackup] = []
    @AppStorage("configBackupsByDate") private var byDate = false
    @State private var expandedMods: Set<String> = []
    @State private var comparing: ConfigBackupBrowser.Version?

    @State private var expandedBackupId: UUID?
    @State private var selectedItemIds: Set<UUID> = []
    @State private var dateSelection: Set<String> = []
    @State private var isBusy = false
    @State private var confirmation: ModConfigBackupsConfirmation?

    private struct DateTableRow: Identifiable {
        enum Kind {
            case backup(ModConfigBackup)
            case item(ModConfigBackup, ModConfigBackupItem)
        }
        let id: String
        let kind: Kind

        static func backup(_ b: ModConfigBackup) -> Self {
            Self(id: "b:\(b.id.uuidString)", kind: .backup(b))
        }
        static func item(_ b: ModConfigBackup, _ i: ModConfigBackupItem) -> Self {
            Self(id: "i:\(b.id.uuidString):\(i.id.uuidString)", kind: .item(b, i))
        }
    }

    private func visibleItems(_ backup: ModConfigBackup) -> [ModConfigBackupItem] {
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return backup.items.filter {
            (modFilter == nil || $0.modFolderName == modFilter)
                && ConfigBackupBrowser.matches($0, needle)
        }
    }

    private var shown: [ModConfigBackup] {
        backups.filter { !visibleItems($0).isEmpty }
    }

    private var groups: [ConfigBackupBrowser.ModGroup] {
        ConfigBackupBrowser.groups(from: backups, search: search)
            .filter { modFilter == nil || $0.folderName == modFilter }
    }

    private var createDisabledReason: String? {
        if vm.gameDir.isEmpty { return localization.L(L10n.ModConfigBackups.noGameDir) }
        if vm.enabledMods.isEmpty { return localization.L(L10n.ModConfigBackups.noEnabledMods) }
        return nil
    }

    private var expandedBackup: ModConfigBackup? {
        guard byDate, let id = expandedBackupId else { return nil }
        return shown.first { $0.id == id }
    }

    var body: some View {
        Group {
            if byDate ? shown.isEmpty : groups.isEmpty {
                emptyState
            } else if byDate {
                byDateTable
            } else {
                ModConfigBackupsByMod(
                    localization: localization,
                    groups: groups,
                    expanded: $expandedMods,
                    restore: { confirmation = .restore($0, [$1].compactMap(\.configOnly)) },
                    compare: { comparing = $0 },
                    showRecoverable: { vm.navigationStore.backupsSegment = .files }
                )
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            statusBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Menu {
                    Picker(localization.L(L10n.A11y.configBackupsGrouping), selection: $byDate) {
                        Text(localization.L(L10n.ModConfigBackups.byMod)).tag(false)
                        Text(localization.L(L10n.ModConfigBackups.byDate)).tag(true)
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label(localization.L(byDate ? L10n.ModConfigBackups.byDate : L10n.ModConfigBackups.byMod),
                          systemImage: "rectangle.3.group")
                }
                .help(localization.L(L10n.A11y.configBackupsGrouping))

                Button(action: createBackup) {
                    if isBusy {
                        ProgressView().controlSize(.small)
                    } else {
                        Label(localization.L(L10n.ModConfigBackups.createBackup), systemImage: "plus")
                    }
                }
                .disabled(isBusy || createDisabledReason != nil)
                .help(createDisabledReason ?? localization.L(L10n.ModConfigBackups.createBackup))
            }
        }
        .onAppear { reload() }
        .sheet(item: $comparing) { version in
            ConfigBackupCompareSheet(localization: localization, version: version,
                                     currentURL: currentConfigURL(version.item.modFolderName))
        }
        .onChange(of: modFilter, initial: true) { _, folder in
            if let folder { expandedMods.insert(folder); byDate = false }
        }
        .alert(confirmationTitle,
               isPresented: Binding(get: { confirmation != nil },
                                    set: { if !$0 { confirmation = nil } }),
               presenting: confirmation) { pending in
            switch pending {
            case .restore(let backup, let items):
                Button(localization.L(L10n.ModConfigBackups.restoreBackup), role: .destructive) {
                    performRestore(backup, items)
                }
                Button(localization.L(L10n.ModConfigBackups.cancel), role: .cancel) { }
            case .delete(let backup, _):
                Button(localization.L(L10n.ModConfigBackups.deleteBackup), role: .destructive) {
                    performDelete(backup)
                }
                Button(localization.L(L10n.ModConfigBackups.cancel), role: .cancel) { }
            case .cleanup:
                Button(localization.L(L10n.Main.ok)) { }
            }
        } message: { pending in
            switch pending {
            case .restore(_, let items): Text(restoreWarning(items))
            case .delete(_, let soleCopy): if !soleCopy.isEmpty { Text(soleCopyMessage(soleCopy)) }
            case .cleanup(let message): Text(message)
            }
        }
    }

    // MARK: - By-Date Finder Table

    private var byDateTable: some View {
        let backupById = Dictionary(uniqueKeysWithValues: shown.map { ("b:\($0.id.uuidString)", $0) })

        return Table(of: DateTableRow.self, selection: $dateSelection) {
            TableColumn(localization.L(L10n.Mods.tableName)) { row in
                switch row.kind {
                case .backup(let backup):
                    HStack(spacing: 7) {
                        Image(systemName: "archivebox")
                            .foregroundStyle(.tint)
                            .frame(width: 16, alignment: .center)
                        Text(backup.formattedDate)
                            .font(AppDesign.Font.body(.medium))
                            .monospacedDigit()
                    }
                case .item(_, let item):
                    Toggle(isOn: Binding(
                        get: { selectedItemIds.contains(item.id) },
                        set: { isOn in
                            if isOn { selectedItemIds.insert(item.id) }
                            else { selectedItemIds.remove(item.id) }
                        }
                    )) {
                        Text(item.modDisplayName)
                            .font(AppDesign.Font.body)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .toggleStyle(.checkbox)
                    .disabled(item.configOnly == nil)
                }
            }
            .width(min: 200, ideal: 280)

            TableColumn(localization.L(L10n.Mods.tableType)) { row in
                switch row.kind {
                case .backup(let backup):
                    Text("\(String(format: localization.L(L10n.ModConfigBackups.filesCount), backup.totalFiles)) · \(backup.formattedSize)")
                        .font(AppDesign.Font.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                case .item(_, let item):
                    let subtitle = item.parentFolderName.map {
                        "\(item.files.joined(separator: ", ")) — \(String(format: localization.L(L10n.ModConfigBackups.partOfGroup), $0))"
                    } ?? item.files.joined(separator: ", ")
                    Text(subtitle)
                        .font(AppDesign.Font.monoIconXS)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .width(min: 160, ideal: 240)

            TableColumn("") { row in
                if case .backup(let backup) = row.kind {
                    HStack {
                        Spacer(minLength: 0)
                        Button(role: .destructive) {
                            askDelete(backup)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(AppDesign.Color.error)
                        }
                        .buttonStyle(.borderless)
                        .help(localization.L(L10n.ModConfigBackups.deleteBackup))
                    }
                }
            }
            .width(min: 36, ideal: 44, max: 52)
        } rows: {
            ForEach(shown) { backup in
                DisclosureTableRow(DateTableRow.backup(backup), isExpanded: Binding(
                    get: { expandedBackupId == backup.id },
                    set: { isOpen in
                        if isOpen {
                            expandedBackupId = backup.id
                            selectedItemIds = Set(backup.items.filter { $0.modFolderName == modFilter }.map(\.id))
                        } else if expandedBackupId == backup.id {
                            expandedBackupId = nil
                            selectedItemIds = []
                        }
                    }
                )) {
                    ForEach(visibleItems(backup)) { item in
                        TableRow(DateTableRow.item(backup, item))
                    }
                }
            }
        }
        .contextMenu(forSelectionType: String.self) { ids in
            if ids.count == 1, let id = ids.first, let backup = backupById[id] {
                let isOpen = expandedBackupId == backup.id
                Button(localization.L(isOpen ? L10n.Main.collapse : L10n.Main.expand)) {
                    toggleExpand(backup)
                }
                Divider()
                Button(localization.L(L10n.ModConfigBackups.deleteBackup), role: .destructive) {
                    askDelete(backup)
                }
            }
        } primaryAction: { ids in
            guard ids.count == 1, let id = ids.first, let backup = backupById[id] else { return }
            toggleExpand(backup)
        }
    }

    // MARK: - Empty State & Status Bar

    @ViewBuilder
    private var emptyState: some View {
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if backups.isEmpty || needle.isEmpty {
            ContentUnavailableView {
                Label(localization.L(L10n.ModConfigBackups.noBackups), systemImage: "archivebox")
            } actions: {
                if createDisabledReason == nil {
                    Button {
                        createBackup()
                    } label: {
                        Label(localization.L(L10n.ModConfigBackups.createBackup), systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView {
                Label(String(format: localization.L(L10n.ModInstall.backupsNoMatch), needle),
                      systemImage: "magnifyingglass")
            } actions: {
                Button(localization.L(L10n.Discovery.clearSearch)) {
                    search = ""
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var statusBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: AppDesign.Spacing.sm) {
                Text(byDate
                     ? String(format: localization.L(L10n.ModConfigBackups.headerCount), Int64(shown.count))
                     : String(format: localization.L(L10n.ModConfigBackups.modsCount), Int64(groups.count)))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let modFilter {
                    Button {
                        self.modFilter = nil
                    } label: {
                        Label(modFilter, systemImage: "xmark.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help(localization.L(L10n.Backups.configFilterClear))
                }

                Spacer(minLength: AppDesign.Spacing.sm)

                if let activeBackup = expandedBackup {
                    let items = visibleItems(activeBackup)
                    let restorableCount = items.filter { selectedItemIds.contains($0.id) && $0.configOnly != nil }.count
                    Button(localization.L(L10n.ModConfigBackups.checkAll)) {
                        selectedItemIds = Set(items.filter { $0.configOnly != nil }.map(\.id))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button(localization.L(L10n.ModConfigBackups.checkNone)) {
                        selectedItemIds = []
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button(String(format: localization.L(L10n.ModConfigBackups.restoreCount), restorableCount)) {
                        let picked = items.filter { selectedItemIds.contains($0.id) }.compactMap(\.configOnly)
                        confirmation = .restore(activeBackup, picked)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                    .disabled(restorableCount == 0)
                }
            }
            .padding(.horizontal, AppDesign.Spacing.xl)
            .padding(.vertical, AppDesign.Spacing.xs)
        }
        .background(.bar)
    }

    // MARK: - Actions & Helpers

    private var confirmationTitle: String {
        switch confirmation {
        case .restore: return localization.L(L10n.ModConfigBackups.restoreWarning)
        case .delete: return localization.L(L10n.ModConfigBackups.deleteConfirm)
        case .cleanup: return localization.L(L10n.ModConfigBackups.title)
        case nil: return ""
        }
    }

    private func reload() {
        Task { backups = await Task.detached(priority: .userInitiated) { ModConfigBackupManager.shared.loadBackups() }.value }
    }

    private func toggleExpand(_ backup: ModConfigBackup) {
        if expandedBackupId == backup.id {
            expandedBackupId = nil
            selectedItemIds = []
        } else {
            expandedBackupId = backup.id
            selectedItemIds = Set(backup.items.filter { $0.modFolderName == modFilter }.map(\.id))
        }
    }

    private func createBackup() {
        guard !isBusy, createDisabledReason == nil else { return }
        isBusy = true
        let model = vm, gameDir = model.gameDir, mods = model.enabledMods
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let manager = ModConfigBackupManager.shared
                _ = try manager.createBackup(gameDir: gameDir, mods: mods)
                let deletedCount = manager.cleanupOldBackups(), fetched = manager.loadBackups()
                DispatchQueue.main.async {
                    self.backups = fetched
                    self.isBusy = false
                    if deletedCount > 0 && self.confirmation == nil {
                        self.confirmation = .cleanup(String(format: self.localization.L(L10n.ModConfigBackups.cleanupComplete), deletedCount))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isBusy = false
                    self.vm.alertStore.show(self.localizedMessage(for: error, genericKey: L10n.ModConfigBackups.backupFailed))
                }
            }
        }
    }

    private func localizedMessage(for error: Error, genericKey: String) -> String {
        if let backupError = error as? ModConfigBackupManager.BackupError {
            switch backupError {
            case .gameDirEmpty: return localization.L(L10n.ModConfigBackups.noGameDir)
            case .noEnabledMods: return localization.L(L10n.ModConfigBackups.noEnabledMods)
            case .nothingToBackUp: return localization.L(L10n.ModConfigBackups.nothingToBackUp)
            }
        }
        return String(format: localization.L(genericKey), error.localizedDescription)
    }

    private func restoreReportMessage(_ report: ModConfigRestoreReport) -> String {
        if report.isComplete {
            return localization.L(L10n.ModConfigBackups.backupRestored)
        }
        var lines: [String] = []
        if report.filesWritten == 0 {
            lines.append(localization.L(L10n.ModConfigBackups.restoreReportNothing))
        } else {
            lines.append(String(format: localization.L(L10n.ModConfigBackups.restoreReportWritten),
                                Int64(report.filesWritten), Int64(report.modsRestored)))
        }
        if !report.skippedMods.isEmpty {
            lines.append(String(format: localization.L(L10n.ModConfigBackups.restoreReportSkippedMods),
                                report.skippedMods.joined(separator: ", ")))
        }
        if !report.skippedFiles.isEmpty {
            lines.append(String(format: localization.L(L10n.ModConfigBackups.restoreReportSkippedFiles),
                                report.skippedFiles.joined(separator: ", ")))
        }
        return lines.joined(separator: "\n\n")
    }

    private func currentConfigURL(_ folder: String) -> URL? {
        let model = vm
        return model.scanStore.mods.flattenedMods.first { $0.folderName == folder }.map {
            ProfileConfigStore.configURL(modsPath: (model.gameDir as NSString).appendingPathComponent("Mods"),
                                         physicalFolderName: $0.physicalFolderName)
        }
    }

    private func restoreWarning(_ items: [ModConfigBackupItem]) -> String {
        let lines = items.prefix(8).map { "• \($0.modDisplayName)" }
            + (items.count > 8 ? ["…"] : [])
        let model = vm
        let active = ConfigRestoreWhileRunning.activeNames(items, mods: model.scanStore.mods,
                                                           gameRunning: model.isGameRunning())
        let running = active.isEmpty ? "" : String(
            format: localization.L(L10n.ModConfigBackups.restoreGameRunning),
            active.joined(separator: ", ")) + "\n\n"
        return running + localization.L(L10n.ModConfigBackups.restoreWarningCreateBackup) + "\n\n"
            + localization.L(L10n.ModConfigBackups.restoreFiles) + "\n" + lines.joined(separator: "\n")
    }

    private func performRestore(_ backup: ModConfigBackup, _ selected: [ModConfigBackupItem]) {
        guard !selected.isEmpty else { return }
        isBusy = true
        let model = vm, gameDir = model.gameDir
        let currentMods = model.scanStore.mods
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let report = try ModConfigBackupManager.shared.restoreBackup(
                    gameDir: gameDir,
                    backup: backup,
                    selectedItems: selected,
                    currentMods: currentMods
                )
                let fetched = ModConfigBackupManager.shared.loadBackups()
                DispatchQueue.main.async {
                    self.backups = fetched
                    self.isBusy = false
                    model.alertStore.show(self.restoreReportMessage(report))
                    model.log(self.restoreReportMessage(report),
                              level: report.isComplete ? .info : .warning)
                    model.rescanKeybindsAfterConfigWrite()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isBusy = false
                    model.alertStore.show(self.localizedMessage(for: error, genericKey: L10n.ModConfigBackups.restoreFailed))
                }
            }
        }
    }

    private func askDelete(_ backup: ModConfigBackup) {
        let modsRoot = (vm.gameDir as NSString).appendingPathComponent("Mods")
        Task {
            let files = await Task.detached(priority: .userInitiated) {
                ConfigBackupSoleCopy.files(in: backup) {
                    FileManager.default.fileExists(atPath: (modsRoot as NSString).appendingPathComponent($0))
                }
            }.value
            confirmation = .delete(backup, soleCopy: files)
        }
    }

    private func soleCopyMessage(_ files: [String]) -> String {
        let shown = files.prefix(8).joined(separator: ", ")
        let more = files.count > 8 ? " " + String(format: localization.L(L10n.Logs.healthAndMore), Int64(files.count - 8)) : ""
        return String(format: localization.L(L10n.ModInstall.deleteSoleCopy), shown + more)
    }

    private func performDelete(_ backup: ModConfigBackup) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let manager = ModConfigBackupManager.shared
                try manager.trashBackup(backup)
                let fetched = manager.loadBackups()
                DispatchQueue.main.async {
                    self.backups = fetched
                    if self.expandedBackupId == backup.id {
                        self.expandedBackupId = nil
                        self.selectedItemIds = []
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.vm.alertStore.show(self.localizedMessage(for: error, genericKey: L10n.ModConfigBackups.deleteFailed))
                }
            }
        }
    }
}
