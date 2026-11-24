import SwiftUI

extension ModListView {
    var navigation: NavigationStore { vm.navigationStore }

    var hasActiveFilters: Bool {
        filters.scope != .all || filters.category != .all || filters.configOnly
            || filters.favoritesOnly || filters.blacklistedOnly
            || filters.frenchTranslation != .off || filters.impactScope != .off
    }

    @ToolbarContentBuilder
    func modListToolbar(display: [ModItem], selected: [ModItem], selectedEntries: [ModItem],
                        showsFilters: Binding<Bool>, showsLabels: Bool) -> some ToolbarContent {
        presentationItems(showsLabels: showsLabels)
        if listLayout == .grid { ToolbarItem { sortPicker } }
        ToolbarItem {
            Button {
                showsFilters.wrappedValue.toggle()
            } label: {
                Label(localization.L(L10n.Mods.filtersTitle),
                      systemImage: hasActiveFilters || showsFilters.wrappedValue
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle")
            }
            .help(localization.L(L10n.Mods.filtersTitle))
            .accessibilityAddTraits(showsFilters.wrappedValue ? .isSelected : [])
        }
        ToolbarItem {
            ModBulkToggleMenu(scoped: display, selected: selected, viewModel: vm,
                              localization: localization, target: $bulkToggleTarget)
                .disabled(vm.scanStore.mods.isEmpty || vm.bulkToggleProgress != nil)
        }
        if !vm.missingDependenciesPlan.isEmpty {
            ToolbarItem {
                Button {
                    showMissingDependencies = true
                } label: {
                    Label(String(format: localization.L(L10n.Mods.missingDepsButton),
                                 Int64(vm.missingDependenciesPlan.count)),
                          systemImage: "shippingbox.and.arrow.backward")
                }
                .help(localization.L(L10n.Mods.depsSheetTitle))
            }
        }
        ToolbarItem {
            Button {
                navigation.showsInstallSheet = true
            } label: {
                Label(localization.L(L10n.ModInstall.installButton), systemImage: "plus.circle")
            }
            .help(localization.L(L10n.ModInstall.installButton))
        }
        sharingAndSearchItems(selected: selectedEntries)
    }

    @ToolbarContentBuilder
    private func presentationItems(showsLabels: Bool) -> some ToolbarContent {
        if listLayout == .grid {
            ToolbarItem { layoutPicker(showsLabels: showsLabels) }
            ToolbarItem { groupingPicker }
        } else {
            ToolbarItemGroup {
                layoutPicker(showsLabels: showsLabels)
                if !showsLabels { groupingPicker }
            }
        }
    }

    @ToolbarContentBuilder
    private func sharingAndSearchItems(selected: [ModItem]) -> some ToolbarContent {
        ToolbarItem {
            ModListShareButton(selected: selected, viewModel: vm, localization: localization)
        }
        if #available(macOS 26.0, *) {
            DefaultToolbarItem(kind: .search, placement: .automatic)
        }
    }

    @ViewBuilder
    private func layoutPicker(showsLabels: Bool) -> some View {
        let title = localization.L(L10n.Mods.layoutTitle)
        let grid = localization.L(L10n.Mods.layoutGrid)
        let list = localization.L(L10n.Mods.layoutList)
        if showsLabels {
            Menu {
                Picker(title, selection: $listLayout) {
                    Label(grid, systemImage: "square.grid.2x2").tag(ModsListLayout.grid)
                    Label(list, systemImage: "list.bullet").tag(ModsListLayout.list)
                }
                .pickerStyle(.inline)
                if listLayout == .list {
                    Divider()
                    groupingPicker
                }
            } label: {
                Label(title, systemImage: listLayout == .grid ? "square.grid.2x2" : "list.bullet")
            }
            .help(title)
        } else {
            Picker(title, selection: $listLayout) {
                Image(systemName: "square.grid.2x2").accessibilityLabel(grid).tag(ModsListLayout.grid)
                Image(systemName: "list.bullet").accessibilityLabel(list).tag(ModsListLayout.list)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .help(title)
        }
    }

    func filterBar(counts: (all: Int, enabled: Int, disabled: Int, issues: Int, updates: Int)) -> some View {
        let facets = facetBases()
        let categories = availableCategories(from: facets.category)
        let uncatCount = uncategorizedCount(from: facets.category)
        let tags = inferredTagBuckets(from: facets.category)
        let noCategory = categories.isEmpty && uncatCount == 0 && tags.isEmpty
        return VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            SplitRow {
                ViewThatFits(in: .horizontal) {
                    scopePicker(counts: counts).pickerStyle(.segmented).labelsHidden().fixedSize()
                    scopePicker(counts: counts).pickerStyle(.menu)
                }
            } trailing: {
                activeProfileButton
            }

            WrapHStack(spacing: 6, lineSpacing: AppDesign.Spacing.sm) {
                attributeFiltersMenu
                frenchTranslationPicker(counts: frenchTranslationCounts(from: facets.translation))
                impactPicker(counts: impactFilterCounts())
                categoryPicker(categories: categories, uncatCount: uncatCount, tagBuckets: tags)
                    .disabled(noCategory && filters.category == .all)
                    .help(localization.L(noCategory ? L10n.Mods.categoryFilterEmptyHint : L10n.Mods.categoryFilterHint))
                if hasActiveFilters {
                    Button(localization.L(L10n.Mods.clearFilters)) {
                        var updated = filters
                        updated.clearFiltering()
                        updated.search = filters.search
                        listState.filters = updated
                    }
                    .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppDesign.Spacing.xl)
        .padding(.vertical, AppDesign.Spacing.sm)
    }

    func modStatusBar(display: [ModItem], selected: [ModItem], resultCount: Int) -> some View {
        let count = selected.isEmpty
            ? localization.plural(L10n.Mods.statusItems, resultCount)
            : String(format: localization.L(L10n.Mods.statusSelection),
                     selected.count.formatted(), resultCount.formatted())
        let mods = selected.isEmpty ? display : selected
        let measured = mods.compactMap { vm.sizeOnDisk(of: $0) }
        let occupied = !mods.isEmpty && measured.count == mods.count ? String(
            format: localization.L(selected.isEmpty ? L10n.Mods.statusOccupied : L10n.Mods.statusSelectionOccupied),
            SharedFormatters.bytes(measured.reduce(0, +))) : nil
        let available = vm.modsFolderSizes?.availableBytes.map {
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

    private func scopePicker(counts: (all: Int, enabled: Int, disabled: Int, issues: Int, updates: Int)) -> some View {
        Picker(localization.L(L10n.Mods.filtersTitle), selection: $listState.filters.scope) {
            scopeOption(.all, L10n.Mods.filterAll, count: counts.all)
            scopeOption(.enabled, L10n.Mods.enabled, count: counts.enabled)
            scopeOption(.disabled, L10n.Mods.disabled, count: counts.disabled)
            scopeOption(.issues, L10n.Mods.filterIssues, count: counts.issues)
            scopeOption(.updates, L10n.Mods.filterUpdates, count: counts.updates)
        }
    }

    private func scopeOption(_ scope: ModFilter, _ key: String, count: Int) -> some View {
        Text("\(localization.L(key)) (\(count))").tag(scope)
    }

    @ViewBuilder
    private var activeProfileButton: some View {
        if let profile = vm.activeProfile {
            let title = String(format: localization.L(L10n.Profiles.activeLabel), profile.name)
            ViewThatFits(in: .horizontal) {
                profileButton(title: title)
                profileButton(title: title).labelStyle(.iconOnly)
            }
        }
    }

    private func profileButton(title: String) -> some View {
        Button {
            currentTab = .profiles
        } label: {
            Label(title, systemImage: "person.crop.circle")
        }
        .help(title)
    }
}
