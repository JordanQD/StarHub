import SwiftUI

extension ModListView {
    var viewModel: StarHubTHViewModel { vm }

    func groupedSections(_ display: [ModItem]) -> [ModListSectionModel] {
        ModGroupSections.sections(display: display, mode: ModGrouping(rawValue: groupingRaw) ?? .none,
                                  state: vm.groups.state, category: sectionCategory)
    }

    func groupedResults(_ sections: [ModListSectionModel], selectedIDs: Set<String>) -> some View {
        ForEach(sections, id: \.key) { section in
            Section {
                if !section.collapsed { modResults(section.mods, selectedIDs: selectedIDs) }
            } header: {
                ModListSectionHeader(section: section, viewModel: vm, localization: localization, listState: listState) {
                    toggleCollapse(section)
                }
            }
        }
    }

    func modResults(_ mods: [ModItem], selectedIDs: Set<String>) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: AppDesign.Grid.minCardWidth),
                                    spacing: AppDesign.Grid.gutter)],
                  spacing: AppDesign.Grid.gutter) {
            ForEach(mods) { mod in modGridCard(mod, isSelected: selectedIDs.contains(mod.id)) }
        }
    }

    func sectionCategory(_ mod: ModItem) -> (id: Int, name: String)? {
        viewModel.category(for: mod).map { (id: $0.id, name: $0.localizedName(localization.L)) }
    }

    func toggleCollapse(_ section: ModListSectionModel) {
        viewModel.groups.update { $0.setCollapsed(section.key, !section.collapsed) }
    }

    /// Un saut vers un mod (journaux, diagnostics) ouvre sa section si elle
    /// est repliée : l'écran conduit au mod, pas à un bandeau.
    func revealInGroups(_ mod: ModItem) {
        let grouping = ModGrouping(rawValue: groupingRaw) ?? .none
        guard grouping != .none,
              let section = ModGroupSections.sections(display: [mod], mode: grouping, state: viewModel.groups.state,
                                                   category: sectionCategory).first,
              section.collapsed else { return }
        viewModel.groups.update { $0.setCollapsed(section.key, false) }
    }

    /// « Regrouper par » : aucun, mes groupes, catégorie.
    var groupingPicker: some View {
        let title = localization.L(L10n.Mods.grouping)
        return Menu {
            Picker(title, selection: $groupingRaw) {
                Text(localization.L(L10n.Mods.groupingNone)).tag(ModGrouping.none.rawValue)
                Text(localization.L(L10n.Mods.groupingCategory)).tag(ModGrouping.category.rawValue)
                Divider()
                Text(localization.L(L10n.Mods.groupingGroups)).tag(ModGrouping.groups.rawValue)
            }
            .pickerStyle(.inline)
        } label: {
            Label(title, systemImage: "square.grid.3x2")
        }
        .help(localization.L(L10n.Mods.grouping))
    }

    /// Une carte de la grille — la même dans le rendu groupé et l'autre.
    @ViewBuilder
    private func modGridCard(_ mod: ModItem, isSelected: Bool) -> some View {
        let values = ModGridCardValues.card(
            mod: mod,
            pictureURL: gridPictureURL(for: mod))
        let age = filters.sort == .lastNexusUpdate
            ? viewModel.nexusLastUpdated(for: mod).map { NexusUpdateAge.line(for: $0) } : nil
        let metadata = [age, values.version].compactMap { $0 }.joined(separator: " · ")
        ModCard(title: values.title,
                thumbnailURL: values.thumbnailURL,
                installedLabel: nil,
                // Assignée, Nexus ou dominante
                // d'un pack (`category(for:)`).
                category: viewModel.category(for: mod),
                neutralBadge: values.neutralBadge,
                endorsements: nil,
                trailingText: metadata,
                usesDefaultArtwork: true,
                attributes: gridAttributes(for: mod),
                pageState: viewModel.nexusPageState(for: mod)?.state,
                L: localization.L)
        .contentShape(.rect(cornerRadius: AppDesign.Radius.section))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: AppDesign.Radius.section)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .padding(-4)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .gesture(gridCardClick(mod, isSelected: isSelected))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction { selectGridMod(mod) }
        .accessibilityAction(named: Text(localization.L(L10n.Mods.openDetails))) {
            openGridMod(mod, isSelected: isSelected)
        }
        .overlay(alignment: .topTrailing) {
            ModTableToggle(mod: mod, vm: viewModel, localization: localization)
                .padding(.horizontal, AppDesign.Spacing.xs)
                .padding(.vertical, 3)
                .background(Color(nsColor: .windowBackgroundColor), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(Color(nsColor: .separatorColor))
                        .allowsHitTesting(false)
                }
                .padding(AppDesign.Spacing.sm)
        }
        .contextMenu {
            let selected = listState.selectedMods(vm)
            modItemActions(for: selected.contains(where: { $0.id == mod.id }) ? selected : [mod])
        }
    }

    private func gridCardClick(_ mod: ModItem, isSelected: Bool) -> some Gesture {
        let toggle = TapGesture().modifiers(.command).onEnded { selectGridMod(mod, kind: .toggle) }
        let extend = TapGesture().modifiers(.shift).onEnded { selectGridMod(mod, kind: .extend) }
        let open = TapGesture(count: 2).onEnded { openGridMod(mod, isSelected: isSelected) }
        let select = TapGesture().onEnded { selectGridMod(mod) }
        // Le premier clic sélectionne sans attendre un éventuel second clic.
        return toggle.exclusively(before: extend)
            .exclusively(before: select.simultaneously(with: open))
    }

    private func openGridMod(_ mod: ModItem, isSelected: Bool) {
        if !isSelected { selectGridMod(mod) }
        navigation.setViewingModDetail(mod)
    }
}
