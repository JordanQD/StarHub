import SwiftUI

// MARK: - Save Table Entry & Sort Comparator

private struct SaveTableEntry: Identifiable {
    var id: String { save.id }
    let save: SaveGameInfo
    let children: [SaveTableEntry]
    let tag: String
    let dayText: String
    let dayOrdinal: Int
}

private struct SaveTableSort: SortComparator {
    enum Column: Hashable { case name, farm, day, money, totalEarned, lastPlayed }
    let column: Column
    var order: SortOrder = .forward

    func compare(_ lhs: SaveTableEntry, _ rhs: SaveTableEntry) -> ComparisonResult {
        let base: ComparisonResult = switch column {
        case .name:        lhs.save.playerName.localizedCaseInsensitiveCompare(rhs.save.playerName)
        case .farm:        lhs.save.farmName.localizedCaseInsensitiveCompare(rhs.save.farmName)
        case .day:         compareScalar(lhs.dayOrdinal, rhs.dayOrdinal)
        case .money:       compareScalar(lhs.save.money, rhs.save.money)
        case .totalEarned: compareScalar(lhs.save.totalMoneyEarned, rhs.save.totalMoneyEarned)
        case .lastPlayed:  lhs.save.lastModified.compare(rhs.save.lastModified)
        }
        guard order == .reverse else { return base }
        switch base {
        case .orderedAscending:  return .orderedDescending
        case .orderedDescending: return .orderedAscending
        case .orderedSame:       return .orderedSame
        }
    }

    private func compareScalar<T: Comparable>(_ a: T, _ b: T) -> ComparisonResult {
        if a < b { return .orderedAscending }
        if a > b { return .orderedDescending }
        return .orderedSame
    }
}

// MARK: - SavesView

struct SavesView: View {
    @Bindable var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    @State private var searchText = ""
    @State private var searchPresented = false
    @State private var selectedSaveIDs: Set<String> = []
    @State private var expandedSaves: Set<String> = []
    @State private var tableSortOrder = [SaveTableSort(column: .lastPlayed, order: .reverse)]
    @State private var saveToDelete: SaveGameInfo?
    @State private var saveSizes: [String: Int64] = [:]
    @State private var diskAvailableBytes: Int64?

    var filteredSaves: [SaveGameInfo] {
        vm.saves.filter {
            $0.playerName.localizedCaseInsensitiveContains(searchText) ||
            $0.farmName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if vm.saves.isEmpty {
                VStack(spacing: AppDesign.Spacing.lg) {
                    Spacer()
                    IconTile(icon: "folder.badge.questionmark", tint: AppDesign.Color.accent, size: 64)
                    Text(localization.L(L10n.Saves.noSaves))
                        .multilineTextAlignment(.center)
                        .font(AppDesign.Font.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.saveViewMode == .grid {
                SavesGridView(
                    vm: vm,
                    localization: localization,
                    saves: searchText.isEmpty ? vm.savesHierarchy.map(\.info) : filteredSaves,
                    onDelete: { saveToDelete = $0 }
                )
            } else {
                savesTable
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !vm.saves.isEmpty {
                savesStatusBar
                    .background(.bar)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .navigationSubtitle(headerSummary ?? "")
        .searchable(text: $searchText, isPresented: $searchPresented,
                    placement: .toolbar, prompt: localization.L(L10n.Saves.searchPlaceholder))
        .background {
            Button(localization.L(L10n.Saves.searchPlaceholder)) { searchPresented = true }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .toolbar {
            savesToolbar
        }
        .task(id: vm.saves.map(\.folderName)) {
            await measureSaveSizes()
        }
        .sheet(item: $vm.saveToDuplicate) { save in
            DuplicateSaveSheet(vm: vm, localization: localization, save: save)
        }
        .itemConfirmationDialog(
            localization.L(L10n.Saves.confirmDeleteSave),
            item: $saveToDelete
        ) { save in
            Button(localization.L(L10n.Saves.deleteSave), role: .destructive) {
                Task { await vm.deleteSave(info: save) }
            }
            Button(localization.L(L10n.Saves.cancel), role: .cancel) {}
        } message: { _ in
            Text(localization.L(L10n.Saves.confirmDeleteSaveMsg))
        }
    }

    // MARK: - Native Sortable & Resizable Table (ModListView + Finder style)

    private var savesTable: some View {
        let topEntries = sortedEntries(
            searchText.isEmpty
                ? vm.savesHierarchy.map(makeEntry)
                : filteredSaves.map { makeLeafEntry($0) }
        )

        return Table(of: SaveTableEntry.self, selection: $selectedSaveIDs, sortOrder: $tableSortOrder) {
            TableColumn(localization.L(L10n.Saves.characterName), sortUsing: SaveTableSort(column: .name)) { row in
                HStack(spacing: 7) {
                    SavePreviewAvatar(save: row.save, size: 20, vm: vm)
                    if !row.tag.isEmpty {
                        Text(row.tag)
                    }
                    Text(row.save.playerName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(row.save.playerName)
                }
            }
            .width(min: 130, ideal: 210)

            TableColumn(localization.L(L10n.Saves.farmName), sortUsing: SaveTableSort(column: .farm)) { row in
                Text(row.save.farmName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(row.save.farmName)
            }
            .width(min: 90, ideal: 150)

            TableColumn(localization.L(L10n.Saves.colDay), sortUsing: SaveTableSort(column: .day)) { row in
                Text(row.dayText)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                    .help(row.dayText)
            }
            .width(min: 110, ideal: 145)

            TableColumn(localization.L(L10n.Saves.money), sortUsing: SaveTableSort(column: .money)) { row in
                Text(SaveRow.moneyText(row.save.money))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .width(min: 75, ideal: 105)

            TableColumn(localization.L(L10n.Saves.totalMoneyEarned), sortUsing: SaveTableSort(column: .totalEarned)) { row in
                Text(SaveRow.moneyText(row.save.totalMoneyEarned))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .width(min: 85, ideal: 115)

            TableColumn(localization.L(L10n.Saves.sortLastPlayed), sortUsing: SaveTableSort(column: .lastPlayed)) { row in
                Text(row.save.lastModified, format: .dateTime.year().month(.abbreviated).day())
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            .width(min: 95, ideal: 120)
        } rows: {
            tableSaveRows(topEntries)
        }
        .contextMenu(forSelectionType: String.self) { ids in
            if ids.count == 1, let id = ids.first, let save = resolveSave(id: id) {
                SaveActionItems(save: save, viewModel: vm, localization: localization) {
                    saveToDelete = save
                }
            }
        } primaryAction: { ids in
            if ids.count == 1, let id = ids.first, let save = resolveSave(id: id) {
                vm.navigationStore.setEditingSave(save)
            }
        }
        .onKeyPress(.return) {
            guard selectedSaveIDs.count == 1,
                  let id = selectedSaveIDs.first,
                  let save = resolveSave(id: id) else { return .ignored }
            vm.navigationStore.setEditingSave(save)
            return .handled
        }
        .onExitCommand { selectedSaveIDs = [] }
    }

    @TableRowBuilder<SaveTableEntry>
    private func tableSaveRows(_ entries: [SaveTableEntry]) -> some TableRowContent<SaveTableEntry> {
        ForEach(entries) { row in
            if !row.children.isEmpty {
                DisclosureTableRow(row, isExpanded: Binding(
                    get: { expandedSaves.contains(row.id) },
                    set: { expanded in
                        if expanded { expandedSaves.insert(row.id) }
                        else { expandedSaves.remove(row.id) }
                    }
                )) {
                    ForEach(sortedEntries(row.children)) { child in
                        TableRow(child)
                    }
                }
            } else {
                TableRow(row)
            }
        }
    }

    private func makeEntry(_ node: SaveNode) -> SaveTableEntry {
        let save = node.info
        return SaveTableEntry(
            save: save,
            children: node.children.map(makeEntry),
            tag: vm.getNote(for: save.folderName).tag,
            dayText: formattedDay(save),
            dayOrdinal: dayOrdinal(save)
        )
    }

    private func makeLeafEntry(_ save: SaveGameInfo) -> SaveTableEntry {
        SaveTableEntry(
            save: save,
            children: [],
            tag: vm.getNote(for: save.folderName).tag,
            dayText: formattedDay(save),
            dayOrdinal: dayOrdinal(save)
        )
    }

    private func sortedEntries(_ entries: [SaveTableEntry]) -> [SaveTableEntry] {
        entries.sorted(using: tableSortOrder)
    }

    private func formattedDay(_ save: SaveGameInfo) -> String {
        String(format: localization.L(L10n.Saves.yearDayFormat),
               save.year, localization.L(save.seasonName), save.day)
    }

    private func dayOrdinal(_ save: SaveGameInfo) -> Int {
        let seasonRank: Int = switch save.seasonName {
        case L10n.Saves.spring: 0
        case L10n.Saves.summer: 1
        case L10n.Saves.fall:   2
        case L10n.Saves.winter: 3
        default:                0
        }
        return save.year * 1_000 + seasonRank * 100 + save.day
    }

    private func resolveSave(id: String) -> SaveGameInfo? {
        if let found = vm.saves.first(where: { $0.id == id }) { return found }
        return flatten(vm.savesHierarchy).first(where: { $0.id == id })
    }

    private func flatten(_ nodes: [SaveNode]) -> [SaveGameInfo] {
        nodes.flatMap { [$0.info] + flatten($0.children) }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var savesToolbar: some ToolbarContent {
        ToolbarItemGroup {
            Picker(localization.L(L10n.Saves.listViewHint), selection: $vm.saveViewMode) {
                Image(systemName: "square.grid.2x2")
                    .accessibilityLabel(localization.L(L10n.Saves.gridViewHint))
                    .tag(SaveViewMode.grid)
                Image(systemName: "list.bullet")
                    .accessibilityLabel(localization.L(L10n.Saves.listViewHint))
                    .tag(SaveViewMode.list)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .help(vm.saveViewMode == .list
                  ? localization.L(L10n.Saves.listViewHint)
                  : localization.L(L10n.Saves.gridViewHint))

            if vm.saveViewMode == .grid {
                Menu {
                    Picker(localization.L(L10n.Saves.sortLastPlayed), selection: $vm.saveSortOption) {
                        Label(localization.L(L10n.Saves.sortLastPlayed), systemImage: "clock")
                            .tag(SaveSortOption.lastPlayed)
                        Label(localization.L(L10n.Saves.sortName), systemImage: "a.square")
                            .tag(SaveSortOption.name)
                        Label(localization.L(L10n.Saves.sortMoney), systemImage: "dollarsign")
                            .tag(SaveSortOption.money)
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label(sortLabel, systemImage: "arrow.up.arrow.down")
                }
                .help(sortLabel)
            }

            Menu {
                Picker(localization.L(L10n.Saves.filterTag), selection: $vm.saveFilterTag) {
                    Label(localization.L(L10n.Saves.filterAll), systemImage: "tray.2").tag("")
                    ForEach(vm.availableFilterTags, id: \.self) { tag in
                        Text(tag).tag(tag)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label(
                    vm.saveFilterTag.isEmpty ? localization.L(L10n.Saves.filterTag) : vm.saveFilterTag,
                    systemImage: vm.saveFilterTag.isEmpty ? "tag" : "tag.fill"
                )
            }
            .help(vm.saveFilterTag.isEmpty ? localization.L(L10n.Saves.filterTag) : vm.saveFilterTag)

            Button(action: { vm.reloadSaves() }) {
                Label(localization.L(L10n.Saves.reloadHint), systemImage: "arrow.clockwise")
            }
            .help(localization.L(L10n.Saves.reloadHint))

            SavesDataActions(vm: vm, localization: localization)
        }

        if #available(macOS 26.0, *) {
            DefaultToolbarItem(kind: .search, placement: .automatic)
        }
    }

    // MARK: - Status Bar & Helpers

    private var visibleSaves: [SaveGameInfo] {
        searchText.isEmpty ? flatten(vm.savesHierarchy) : filteredSaves
    }

    private var savesStatusBar: some View {
        let all = visibleSaves
        let selected = all.filter { selectedSaveIDs.contains($0.id) }
        let count = selected.isEmpty
            ? localization.plural(L10n.Mods.statusItems, all.count)
            : String(format: localization.L(L10n.Mods.statusSelection),
                     selected.count.formatted(), all.count.formatted())
        let target = selected.isEmpty ? all : selected
        let measured = target.compactMap { saveSizes[$0.folderName] }
        let occupied = !target.isEmpty && measured.count == target.count ? String(
            format: localization.L(selected.isEmpty ? L10n.Mods.statusOccupied : L10n.Mods.statusSelectionOccupied),
            SharedFormatters.bytes(measured.reduce(0, +))) : nil
        let available = diskAvailableBytes.map {
            String(format: localization.L(L10n.Mods.statusAvailable), SharedFormatters.bytes($0))
        }
        let status = [count, occupied, available].compactMap { $0 }.joined(separator: " · ")
        return VStack(spacing: 0) {
            Divider()
            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppDesign.Spacing.sm)
                .padding(.vertical, AppDesign.Spacing.xs)
                .frame(maxWidth: .infinity)
        }
    }

    private func measureSaveSizes() async {
        let folders = vm.saves.map(\.folderName)
        let savesRoot = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".config/StardewValley/Saves", isDirectory: true)
        let result = await Task.detached(priority: .utility) { () -> ([String: Int64], Int64?) in
            let fm = FileManager.default
            var sizes: [String: Int64] = [:]
            for folder in folders {
                let url = savesRoot.appendingPathComponent(folder, isDirectory: true)
                var total: Int64 = 0
                if let enumerator = fm.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                    options: []
                ) {
                    for case let fileURL as URL in enumerator {
                        if let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                           vals.isRegularFile == true,
                           let size = vals.fileSize {
                            total += Int64(size)
                        }
                    }
                }
                sizes[folder] = total
            }
            let avail = ModsFolderSizer.availableBytes(on: savesRoot)
            return (sizes, avail)
        }.value
        saveSizes = result.0
        diskAvailableBytes = result.1
    }

    private var headerSummary: String? {
        let farms = vm.savesHierarchy.map(\.info)
        guard let last = farms.max(by: { $0.lastModified < $1.lastModified }) else { return nil }
        return String(format: localization.L(L10n.Saves.headerSummary),
                      Int64(farms.count), last.playerName, last.farmName)
    }

    private var displayedCount: Int {
        searchText.isEmpty ? vm.savesHierarchy.count : filteredSaves.count
    }

    private var sortLabel: String {
        switch vm.saveSortOption {
        case .lastPlayed: return localization.L(L10n.Saves.sortLastPlayed)
        case .name: return localization.L(L10n.Saves.sortName)
        case .money: return localization.L(L10n.Saves.sortMoney)
        }
    }
}
