import SwiftUI

/// Finder-style table for files lost during mod updates that can still be
/// recovered from installation backups.
struct RecoverableFilesView: View {
    var viewModel: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    @Binding var search: String

    @State private var previewing: RecoverableFile?
    @State private var previewText = ""
    @State private var comparing: RecoverableFile?
    @State private var soleCopies: [MaintenanceInventory.SoleCopyFile] = []
    @State private var resolved: [String: RecoverableFile] = [:]
    @State private var modFilter: String?
    @State private var selection: Set<String> = []

    private struct TableRowItem: Identifiable {
        enum Kind {
            case recoverable(RecoverableFile)
            case gone(MaintenanceInventory.SoleCopyFile)
        }
        let id: String
        let modName: String
        let relativePath: String
        let kind: Kind
    }

    private var trimmedSearch: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var allRows: [TableRowItem] {
        var result: [TableRowItem] = []
        for file in viewModel.recoverableFiles where modFilter == nil || file.folderName == modFilter {
            result.append(TableRowItem(id: "r:\(file.id)", modName: file.modName,
                                       relativePath: file.relativePath, kind: .recoverable(file)))
        }
        for copy in soleCopies where modFilter == nil || copy.modFolder == modFilter {
            if let file = resolved[copy.id] {
                result.append(TableRowItem(id: "sr:\(file.id)", modName: file.modName,
                                           relativePath: file.relativePath, kind: .recoverable(file)))
            } else {
                result.append(TableRowItem(id: "g:\(copy.id)", modName: copy.modFolder,
                                           relativePath: copy.relativePath, kind: .gone(copy)))
            }
        }
        return result
    }

    private var filteredRows: [TableRowItem] {
        let needle = trimmedSearch
        guard !needle.isEmpty else { return allRows }
        return allRows.filter {
            $0.modName.localizedCaseInsensitiveContains(needle)
                || $0.relativePath.localizedCaseInsensitiveContains(needle)
        }
    }

    var body: some View {
        Group {
            if viewModel.isScanningRecoverableFiles
                || (viewModel.maintenanceReport == nil && viewModel.maintenanceStore.isBuilding) {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if allRows.isEmpty {
                ContentUnavailableView {
                    Label(localization.L(L10n.Recovery.empty), systemImage: "checkmark.circle")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredRows.isEmpty {
                ContentUnavailableView {
                    Label(String(format: localization.L(L10n.ModInstall.backupsNoMatch), trimmedSearch),
                          systemImage: "magnifyingglass")
                } actions: {
                    Button(localization.L(L10n.Discovery.clearSearch)) {
                        search = ""
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                filesTable
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            statusBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.scanRecoverableFiles()
                    viewModel.buildMaintenanceReport()
                } label: {
                    Label(localization.L(L10n.ModInstall.refreshBackups), systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isScanningRecoverableFiles)
                .help(localization.L(L10n.ModInstall.refreshBackups))
            }
        }
        .onAppear {
            if viewModel.recoverableFiles.isEmpty { viewModel.scanRecoverableFiles() }
            viewModel.buildMaintenanceReport()
            refreshSoleCopies()
            consumePendingFocus()
        }
        .onChange(of: viewModel.navigationStore.pendingBackupsFocus) { consumePendingFocus() }
        .onChange(of: viewModel.maintenanceReport) { refreshSoleCopies() }
        .onChange(of: viewModel.recoverableFiles) { refreshSoleCopies() }
        .sheet(item: $comparing) { file in
            TranslationRecoveryDiffView(
                vm: viewModel,
                localization: localization,
                file: file,
                isPresented: Binding(get: { comparing != nil },
                                     set: { if !$0 { comparing = nil } })
            )
        }
        .sheet(item: $previewing) { file in
            previewSheet(for: file)
        }
    }

    // MARK: - Finder Table

    private var filesTable: some View {
        let rows = filteredRows
        let byId = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })

        return Table(rows, selection: $selection) {
            TableColumn(localization.L(L10n.Mods.tableName)) { row in
                HStack(spacing: 7) {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                        .frame(width: 16, alignment: .center)
                    Text(row.modName)
                        .font(AppDesign.Font.body(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .help(row.modName)
            }
            .width(min: 150, ideal: 210)

            TableColumn(localization.L(L10n.Backups.segmentFiles)) { row in
                Text(row.relativePath)
                    .font(AppDesign.Font.monoIconXS)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(row.relativePath)
            }
            .width(min: 130, ideal: 190)

            TableColumn(localization.L(L10n.Mods.tableType)) { row in
                let label: String = switch row.kind {
                case .recoverable(let file): reasonLabel(file.reason)
                case .gone: localization.L(L10n.Maintenance.reasonGone)
                }
                Text(label)
                    .font(AppDesign.Font.footnote)
                    .foregroundStyle(AppDesign.Color.warning)
                    .lineLimit(1)
            }
            .width(min: 100, ideal: 130)

            TableColumn("") { row in
                HStack(spacing: 4) {
                    Spacer(minLength: 0)
                    switch row.kind {
                    case .recoverable(let file):
                        if file.relativePath.hasPrefix("i18n/") {
                            Button {
                                comparing = file
                            } label: {
                                Image(systemName: "arrow.left.arrow.right")
                            }
                            .buttonStyle(.borderless)
                            .help(localization.L(L10n.Recovery.compareKeys))
                        }
                        Button {
                            openPreview(file)
                        } label: {
                            Image(systemName: "eye")
                        }
                        .buttonStyle(.borderless)
                        .help(localization.L(L10n.Recovery.preview))

                        if file.reason != .translationDiffers {
                            Button(localization.L(L10n.Recovery.recover)) {
                                viewModel.recoverFile(file)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    case .gone(let copy):
                        Button(localization.L(L10n.Maintenance.actionReveal)) {
                            if let path = viewModel.maintenanceProtectedFilePath(
                                session: copy.session, relativePath: copy.relativePath) {
                                viewModel.revealProtectedBackup(atPath: path)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .width(min: 110, ideal: 145)
        }
        .contextMenu(forSelectionType: String.self) { ids in
            if ids.count == 1, let id = ids.first, let row = byId[id] {
                switch row.kind {
                case .recoverable(let file):
                    if file.relativePath.hasPrefix("i18n/") {
                        Button(localization.L(L10n.Recovery.compareKeys)) { comparing = file }
                    }
                    Button(localization.L(L10n.Recovery.preview)) { openPreview(file) }
                    if file.reason != .translationDiffers {
                        Divider()
                        Button(localization.L(L10n.Recovery.recover)) { viewModel.recoverFile(file) }
                    }
                case .gone(let copy):
                    Button(localization.L(L10n.Maintenance.actionReveal)) {
                        if let path = viewModel.maintenanceProtectedFilePath(
                            session: copy.session, relativePath: copy.relativePath) {
                            viewModel.revealProtectedBackup(atPath: path)
                        }
                    }
                }
            }
        } primaryAction: { ids in
            guard ids.count == 1, let id = ids.first, let row = byId[id] else { return }
            if case .recoverable(let file) = row.kind {
                openPreview(file)
            }
        }
    }

    // MARK: - Status Bar & Preview Sheet

    @ViewBuilder
    private var statusBar: some View {
        if !allRows.isEmpty || modFilter != nil {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: AppDesign.Spacing.sm) {
                    Text(String(format: localization.L(L10n.ModConfigBackups.filesCount), filteredRows.count))
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
                        .help(localization.L(L10n.Recovery.showAll))
                    }
                    Spacer()
                }
                .padding(.horizontal, AppDesign.Spacing.xl)
                .padding(.vertical, AppDesign.Spacing.xs)
            }
            .background(.bar)
        }
    }

    private func previewSheet(for file: RecoverableFile) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.modName).font(AppDesign.Font.headline)
                    Text(file.relativePath)
                        .font(AppDesign.Font.monoFootnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(localization.L(L10n.Main.close)) {
                    previewing = nil
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(AppDesign.Spacing.lg)

            Divider()

            ScrollView {
                Text(previewText)
                    .font(AppDesign.Font.monoFootnote)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppDesign.Spacing.lg)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(minWidth: 520, minHeight: 360)
    }

    // MARK: - Helpers

    private func consumePendingFocus() {
        guard let folder = viewModel.navigationStore.pendingBackupsFocus else { return }
        modFilter = folder
        viewModel.navigationStore.pendingBackupsFocus = nil
    }

    private func refreshSoleCopies() {
        guard let report = viewModel.maintenanceReport else { return }
        soleCopies = MaintenanceInventory.soleCopyFiles(
            in: report, excluding: Set(viewModel.recoverableFiles.map(\.id)))
        resolved = viewModel.maintenanceRecoverableFiles(soleCopies)
    }

    private func openPreview(_ file: RecoverableFile) {
        let raw = (try? String(contentsOfFile: file.backupPath, encoding: .utf8)) ?? ""
        previewText = raw.count > 8000 ? String(raw.prefix(8000)) + "\n…" : raw
        previewing = file
    }

    private func reasonLabel(_ reason: RecoveryReason) -> String {
        switch reason {
        case .absentFromInstall:
            return localization.L(L10n.Recovery.reasonAbsent)
        case .keysLostSinceBackup(let keys):
            return String(format: localization.L(L10n.Recovery.reasonLostKeys), Int64(keys.count))
        case .translationDiffers:
            return localization.L(L10n.Recovery.reasonDiffers)
        }
    }
}
