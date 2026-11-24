import SwiftUI

extension ModListView {
    func modTable(display: [ModItem], sections: [ModListSectionModel], visibleRows: [ModItem],
                  entries: [String: ModTableEntry]) -> some View {
        let visibleIDs = visibleRows.map(\.id)
        let selection = Binding(
            get: { Set(listState.selection.effectiveMembers(in: visibleIDs, current: vm.selectedModID)) },
            set: { ids in
                listState.selection.replace(with: ids, in: visibleIDs)
                if let current = vm.selectedModID, listState.selection.selected.contains(current) { return }
                vm.selectedModID = listState.selection.members(in: visibleIDs).first
            }
        )

        return Table(of: ModTableEntry.self, selection: selection, sortOrder: $tableSortOrder) {
            TableColumn(Text(Image(systemName: "arrow.up.circle")), sortUsing: ModTableSort(column: .update)) { row in
                if let update = row.update {
                    ModTableUpdateButton(pending: update, vm: vm, localization: localization)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .width(26)
            TableColumn(localization.L(L10n.Mods.tableName), sortUsing: ModTableSort(column: .name)) { row in
                HStack(spacing: 7) {
                    modTableThumbnail(for: row.mod)
                    Text(row.mod.name).lineLimit(1).help(row.mod.name)
                }
            }
            .width(min: 140, ideal: 260)
            TableColumn(localization.L(L10n.Mods.tableType), sortUsing: ModTableSort(column: .type)) { row in
                Text(row.type).lineLimit(1).help(row.type)
            }
            .width(min: 65, ideal: 110)
            TableColumn(localization.L(L10n.Mods.sortVersion), sortUsing: ModTableSort(column: .version)) { row in
                Text(row.version).lineLimit(1).truncationMode(.middle).help(row.version)
            }
            .width(min: 52, ideal: 82)
            TableColumn(localization.L(L10n.Mods.detailUpdated), sortUsing: ModTableSort(column: .updated)) { row in
                if let date = row.updated {
                    Text(date, format: .dateTime.year().month(.abbreviated).day())
                }
            }
            .width(min: 88, ideal: 109)
            TableColumn(localization.L(L10n.Mods.sortSize), sortUsing: ModTableSort(column: .size)) { row in
                if let size = row.bytes {
                    Text(SharedFormatters.bytes(size)).monospacedDigit()
                }
            }
            .width(min: 55, ideal: 72)
            TableColumn(localization.L(L10n.Mods.tableEnabled), sortUsing: ModTableSort(column: .enabled)) { row in
                if !row.mod.isPackComponent {
                    ModTableToggle(mod: row.mod, vm: vm, localization: localization)
                }
            }
            .width(min: 46, ideal: 54)
        } rows: {
            if sections.isEmpty {
                tableModRows(display, entries: entries)
            } else {
                ForEach(sections, id: \.key) { section in
                    Section(isExpanded: Binding(
                        get: { !section.collapsed },
                        set: { expanded in vm.groups.update { $0.setCollapsed(section.key, !expanded) } }
                    )) {
                        tableModRows(section.mods, entries: entries)
                    } header: {
                        ModListSectionHeader(section: section, viewModel: vm, localization: localization, listState: listState)
                    }
                }
            }
        }
        .contextMenu(forSelectionType: String.self) { ids in
            let mods = visibleRows.filter { ids.contains($0.id) }
            if mods.count == 1, let mod = mods.first {
                Button(localization.L(L10n.Mods.backupsOfMod)) {
                    navigation.openBackups(for: mod.folderName)
                }
            }
            modItemActions(for: mods)
        } primaryAction: { ids in
            openTableDetail(ids, in: visibleRows)
        }
        .onKeyPress(.return) {
            openTableDetail(selection.wrappedValue, in: visibleRows) ? .handled : .ignored
        }
        .onKeyPress(.space) {
            listState.toggleSelection(vm) ? .handled : .ignored
        }
        .onExitCommand { selection.wrappedValue = [] }
    }

    func makeTableEntries(_ mods: [ModItem]) -> [String: ModTableEntry] {
        let pending = PendingModUpdates.current(vm)
        var entries: [String: ModTableEntry] = [:]
        for mod in mods.flatMap({ [$0] + ($0.children ?? []) }) {
            entries[mod.id] = ModTableEntry(
                mod: mod, type: sectionCategory(mod)?.name ?? localization.L(L10n.ModTag.key(for: vm.inferredTagKey(for: mod))),
                version: mod.isGroup ? vm.displayVersion(for: mod) : mod.version,
                updated: vm.nexusLastUpdated(for: mod), bytes: vm.sizeOnDisk(of: mod), update: pending.pending(for: mod)
            )
        }
        return entries
    }

    func sortedTableMods(_ mods: [ModItem], entries: [String: ModTableEntry]) -> [ModItem] {
        ModTableSort.sorted(mods.compactMap { entries[$0.id] }, by: tableSortOrder).map(\.mod)
    }

    @TableRowBuilder<ModTableEntry>
    private func tableModRows(_ mods: [ModItem], entries: [String: ModTableEntry]) -> some TableRowContent<ModTableEntry> {
        ForEach(mods.compactMap { entries[$0.id] }) { row in
            if let children = row.mod.children, !children.isEmpty {
                DisclosureTableRow(row, isExpanded: Binding(
                    get: { expandedTablePacks.contains(row.id) },
                    set: { expanded in
                        if expanded { expandedTablePacks.insert(row.id) }
                        else { expandedTablePacks.remove(row.id) }
                    }
                )) {
                    ForEach(ModTableSort.sorted(children.compactMap { entries[$0.id] }, by: tableSortOrder)) { TableRow($0) }
                }
            } else {
                TableRow(row)
            }
        }
    }

    func selectedTableRows(in visibleRows: [ModItem]) -> [ModItem] {
        let ids = Set(listState.selection.effectiveMembers(in: visibleRows.map(\.id), current: vm.selectedModID))
        return visibleRows.filter { ids.contains($0.id) }
    }

    private func modTableThumbnail(for mod: ModItem) -> some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        return ZStack {
            shape.fill(.quaternary)
            if let urlString = gridPictureURL(for: mod), let url = URL(string: urlString) {
                CachedAsyncImage(url: url)
                    .allowsHitTesting(false)
            } else {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 20, height: 20)
        .clipShape(shape)
        .overlay(shape.stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
        .accessibilityHidden(true)
    }

    @discardableResult
    private func openTableDetail(_ ids: Set<String>, in visibleRows: [ModItem]) -> Bool {
        guard ids.count == 1, let mod = visibleRows.first(where: { ids.contains($0.id) }) else { return false }
        navigation.setViewingModDetail(mod)
        return true
    }
}
