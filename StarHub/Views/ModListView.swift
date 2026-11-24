import SwiftUI

// Les enums de cadrage de la liste (`ModFilter`, `FrenchTranslationScope`,
// `CategoryScope`, `ModSortOrder`) vivent désormais dans
// `Models/ModListFilters.swift` : ils sont entrés dans `StarHubTHCore` pour
// se tester (F1 — voir l'en-tête de ce fichier).

struct ModListView: View {
    @State private var searchPresented = false
    @State private var showsFilters = false
    @State private var showsToolbarLabels = false
    @State private var trashPlan: ModTrashSelection.Plan?
    @FocusState private var gridFocused: Bool

    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    /// L'onglet affiché, pour les rares endroits d'où la liste **mène
    /// ailleurs** (le badge de profil actif). Même patron que
    /// `ModProfilesView`, `UpdatesView` et `SystemAlertsView`.
    @Binding var currentTab: SidebarDestination
    /// Le cadrage de la liste, observé **à part** du ViewModel pour que taper
    /// dans la recherche ne redessine pas toute la fenêtre — voir `ModListState`.
    /// internal : lu par l'extension du panneau (P8, geste A).
    @ObservedObject var listState: ModListState

    init(vm: StarHubTHViewModel, localization: LocalizationStore, currentTab: Binding<SidebarDestination>) {
        self.localization = localization
        self.vm = vm
        self.listState = vm.modList
        self._currentTab = currentTab
    }

    /// Lecture seule du cadrage courant (recherche, filtres et tri). Les
    /// écritures passent par `listState.filters` en clair, pour qu'on voie au
    /// premier coup d'œil ce qui modifie un état partagé.
    /// internal : lu par l'extension du panneau (`ModListView+Filters.swift`) —
    /// `private` est file-scopé pour les extensions (P8, geste A).
    var filters: ModListFilters { listState.filters }

    func selectGridMod(_ mod: ModItem, kind: ModListSelection.ClickKind = .plain) {
        gridFocused = true
        listState.clickRow(mod.id, kind: kind, viewModel: vm)
    }

    /// A1-T1 — récapitulatif des dépendances requises absentes du disque.
    @State var showMissingDependencies = false
    /// La grille optionnelle du lot Mods (H-T4). Liste par défaut : 966 mods
    /// se parcourent en rangées denses. `@AppStorage` suit le patron de
    /// `discoveryHideInstalled` (`DiscoverView.swift:15`) — c'est une
    /// habitude de parcours, pas un état de session.
    enum ModsListLayout: String { case list, grid }
    @AppStorage("modsListLayout") var listLayout: ModsListLayout = .list
    @AppStorage(UDKey.modListGrouping) var groupingRaw = ModGrouping.none.rawValue   // I-T21
    /// Drives the confirmation dialog when the user picks "Enable All" or
    /// "Disable All" from the bulk-actions menu. `true` = enabling, `false`
    /// = disabling — kept as a single optional so the dialog binds cleanly.
    @State var bulkToggleTarget: Bool? = nil
    /// Puce de type active sous le cadrage « Problèmes ».
    @State private var problemKind: ModProblemKind? = nil

    /// Scopes the list to the mod the user asked to jump to, clearing anything
    /// that could filter it out, then clears the request so it fires once.
    private func consumePendingModFocus() {
        guard let modName = vm.navigationStore.pendingModFocus else { return }
        // Prefer the resolved mod's own name: SMAPI logs a display name that can
        // differ from the manifest, and the search matches on name/uniqueId.
        // The request may also carry a folder name (the guided search works in
        // those) — `ModFocusResolver` accepts either.
        let resolved = ModFocusResolver.resolve(modName, in: vm.scanStore.mods)
        listState.filters.focus(on: resolved?.name ?? modName)
        if let resolved { revealInGroups(resolved) }   // I-T21 : jamais derrière un bandeau replié
        vm.navigationStore.pendingModFocus = nil
    }

    // MARK: - Cadrage : amincissements de la règle du ViewModel
    //
    // La règle de cadrage (les cinq filtres, le tri, le scope) vit dans le
    // ViewModel — `mods(matching:)` et `scopedMods(from:scope:)` — pour que
    // la liste et la bascule en masse (« Tout activer », X57) la partagent
    // au lieu de la recopier. La vue n'en garde que des raccourcis de
    // lecture ; les facettes recomposent les prédicats **en laissant tomber
    // le leur** pour compter ce que la vue active contient.

    var filteredMods: [ModItem] { vm.mods(matching: filters) }

    private func displayMods(from scoped: [ModItem]) -> [ModItem] {
        guard filters.scope == .issues, let kind = problemKind else { return scoped }
        // La puce réduit la liste cadrée, sans recalculer le cadrage.
        return scoped.filter { problemKinds(of: $0).contains(kind) }
    }

    /// Les mods sur lesquels un menu compte ses options : ceux que la vue
    /// active contient — cadrage compris (« Tous », « Activés », « En pause »,
    /// « Problèmes ») — **moins le filtre du menu lui-même**. Sans cette
    /// exception, choisir une catégorie réduirait le menu à cette seule
    /// catégorie et on ne pourrait plus en changer.
    ///
    /// Les deux bases sortent d'un **seul** cadrage : `displayMods` fait, sous
    /// « Problèmes », un scan de dépendances par mod — c'est précisément ce que
    /// `scopeCounts` avait été écrit pour ne pas refaire à chaque évaluation.
    /// Les filtres commutant entre eux, retrancher le sien après le cadrage
    /// donne le même ensemble pour un parcours de moins.
    ///
    /// Le tri n'entre pas ici : il ne change pas quels mods sont là.
    func facetBases() -> (category: [ModItem], translation: [ModItem]) {
        let scoped = vm.scopedMods(from: vm.scanStore.mods.filter { mod in
            vm.matchesSearch(mod, filters: filters)
                && vm.matchesConfig(mod, filters: filters)
                && vm.matchesFavorites(mod, filters: filters)
                && vm.matchesBlacklisted(mod, filters: filters)
        }, scope: filters.scope)
        return (category: scoped.filter { vm.matchesTranslation($0, filters.frenchTranslation) },
                translation: scoped.filter { vm.matchesCategory($0, filters: filters) })
    }

    /// Categories actually present among the currently installed mods, sorted
    /// alphabetically by localized name. Drives the category-picker menu so the
    /// user never sees an empty scope. Computed from the *effective* category
    /// of every mod (manual override wins over the API-fetched category), so
    /// user-categorized mods appear in the picker as soon as they're pinned.
    func availableCategories(from base: [ModItem]) -> [(category: NexusCategory, count: Int)] {
        var counts: [Int: Int] = [:]
        // Counts must be derived the exact same way the `.category` filter
        // branch resolves a mod (`vm.category(for: mod)` on the top-level
        // mod, which already resolves a group to its dominant child
        // category) — counting each child's own category individually (as
        // this used to) could show a non-zero count for a category that,
        // once selected, filters nothing in because it's a group's minority
        // category rather than its dominant one.
        for mod in base {
            if let cid = vm.category(for: mod)?.id { counts[cid, default: 0] += 1 }
        }
        return NexusCategory.all
            .filter { counts[$0.id] != nil }
            .map { ($0, counts[$0.id] ?? 0) }
            .sorted { $0.category.localizedName(localization.L)
                .localizedCaseInsensitiveCompare($1.category.localizedName(localization.L)) == .orderedAscending }
    }

    /// (tag key, localized label, count) for top-level mods with no Nexus
    /// category and a non-"Other" inferred tag — the offline fallback buckets.
    func inferredTagBuckets(from base: [ModItem]) -> [(tag: String, label: String, count: Int)] {
        var counts: [String: Int] = [:]
        for mod in base where vm.category(for: mod) == nil {
            let tag = vm.inferredTagKey(for: mod)
            if tag != "Other" { counts[tag, default: 0] += 1 }
        }
        return counts.map { (tag: $0.key, label: localization.L(L10n.ModTag.key(for: $0.key)), count: $0.value) }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    /// Count of top-level mods (standalone mods + whole packs) with no
    /// category assigned AND an inferred tag of "Other" — matching the
    /// `.uncategorized` filter case above (mods with a more specific inferred
    /// tag are counted in `inferredTagBuckets` instead). Drives the
    /// "No Category (N)" menu entry and its visibility.
    func uncategorizedCount(from base: [ModItem]) -> Int {
        base.filter { vm.category(for: $0) == nil && vm.inferredTagKey(for: $0) == "Other" }.count
    }

    /// Counts for every scope filter, in one pass over `filtered` — the
    /// `.issues` dependency scan is not redone per Picker label.
    /// `issues` et `updates` appliquent les verdicts de `ModListScoping.scoped`
    /// — voir son commentaire pour ce que « en pause » y change.
    private func scopeCounts(for filtered: [ModItem])
    -> (all: Int, enabled: Int, disabled: Int, issues: Int, updates: Int) {
        var enabled = 0, disabled = 0, issues = 0, updates = 0
        let pending = PendingModUpdates.current(vm) // même index que le filtre
        for mod in filtered {
            if mod.isEnabled { enabled += 1 } else { disabled += 1 }
            if vm.matchesSelfOrAnyChild(mod, { vm.hasIssues($0) }) { issues += 1 }
            if pending.pending(for: mod) != nil { updates += 1 }
        }
        return (filtered.count, enabled, disabled, issues, updates)
    }

    /// Les attributs que la carte porte — les mêmes que la rangée de la
    /// liste, dans le même ordre : anomalie, note, config gardée par le
    /// profil. Sur la carte ils ne s'ouvrent pas au clic (celui-ci mène à la
    /// fiche, qui les détaille) ; leur infobulle porte le texte entier.
    func gridAttributes(for mod: ModItem) -> [CardAttribute] {
        var attributes: [CardAttribute] = []
        // La marque de la sonde d'abord : même famille visuelle que la
        // capsule de la rangée, sur la carte.
        if mod.isStarHubProbe {
            attributes.append(CardAttribute(id: "probe",
                                            systemImage: "gauge.with.dots.needle.67percent",
                                            tint: AppDesign.Color.accent,
                                            help: localization.L(L10n.Mods.probeBadgeHelp)))
        }
        if let anomaly = vm.anomaly(for: mod) {
            attributes.append(CardAttribute(id: "anomaly",
                                            systemImage: "exclamationmark.triangle.fill",
                                            tint: anomaly.severity == .error ? AppDesign.Color.error : AppDesign.Color.warning,
                                            help: anomalyReasons(anomaly, vm: vm)))
        }
        if let pending = PendingModUpdates.current(vm).pending(for: mod) { attributes.append(CardAttribute( // I-T13
            id: "update", systemImage: "arrow.up.circle.fill", tint: AppDesign.Color.info,
            help: String(format: localization.L(L10n.Updates.availableVersion), pending.availableVersion))) }
        if let note = vm.modNote(for: mod) {
            attributes.append(CardAttribute(id: "note", systemImage: "note.text", help: note))
        }
        if vm.isProfileConfigManaged(mod) {
            // Même glyphe que la rangée (voir `profileConfigSlot`) : des
            // curseurs à 10 pt s'y lisaient comme une note.
            attributes.append(CardAttribute(id: "profileConfig",
                                            systemImage: "gearshape",
                                            help: localization.L(L10n.Mods.profileConfigBadge)))
        }
        return attributes
    }

    /// L'adresse de la capture Nexus déjà en cache pour ce mod — celle que la
    /// fiche affiche (`nexusCachedExtras`, persisté : 769 de ses 791 entrées
    /// en portent une). Aucun réseau de plus n'est demandé ici : seules les
    /// cartes visibles chargent leur image, et `CachedAsyncImage` la garde
    /// (`NSCache` borné à 400 images / 128 Mo).
    ///
    /// L'identifiant passe par `sharedNexusId` : un pack **à plat** n'hérite
    /// pas de la capture de son premier composant.
    func gridPictureURL(for mod: ModItem) -> String? {
        // La sonde porte la couverture de l'app (celle du splash) : elle
        // n'a pas de page Nexus à illustrer sa carte.
        if mod.isStarHubProbe,
           let local = Bundle.main.url(forResource: "nexus_cover_final", withExtension: "png") {
            return local.absoluteString
        }
        guard let id = ModGridCardValues.sharedNexusId(of: mod, effectiveId: {
            vm.effectiveNexusModId(for: $0)
        }) else { return nil }
        return vm.nexusModExtras[id]?.pictureUrl
    }

    @State var expandedTablePacks: Set<String> = []
    @State var tableSortOrder = [ModTableSort(column: .name)]

    func confirmMovingModsToTrash(_ mods: [ModItem]) {
        guard vm.bulkToggleProgress == nil else { return }
        let plan = ModTrashSelection.plan(selected: mods, all: vm.mods)
        if !plan.trashable.isEmpty { trashPlan = plan }
    }

    var body: some View {
        // Compute the expensive derived data once per render instead of
        // re-evaluating the search/category/sort pass (and everything
        // downstream of it) on every Picker label and list access.
        let filtered = filteredMods
        let scoped = vm.scopedMods(from: filtered, scope: filters.scope)
        let results = displayMods(from: scoped)
        let tableEntries = listLayout == .list ? makeTableEntries(results) : [:]
        let display = listLayout == .list ? sortedTableMods(results, entries: tableEntries) : results
        let sections = groupedSections(display)
        let displayIds = sections.isEmpty ? display.map(\.folderName) : ModGroupSections.navigationOrder(sections)
        let selected = listState.selectedMods(vm, order: displayIds)
        let selectedIDs = Set(selected.map(\.id))
        let visibleTopLevel = sections.isEmpty ? display : sections.filter { !$0.collapsed }.flatMap(\.mods)
        let tableRows = listLayout == .list ? visibleTopLevel.flatMap { mod in
            expandedTablePacks.contains(mod.id)
                ? [mod] + sortedTableMods(mod.children ?? [], entries: tableEntries) : [mod]
        } : []
        let selectedEntries = listLayout == .list
            ? selectedTableRows(in: tableRows)
            : selected
        VStack(spacing: 0) {

            if showsFilters {
                filterBar(counts: scopeCounts(for: filtered))
                Divider()
            }

            if filters.scope == .issues, !scoped.isEmpty {
                ProblemKindChips(counts: problemKindCounts(in: scoped),
                                 selection: $problemKind, L: localization.L)
                    .padding(.horizontal, AppDesign.Spacing.xl)
                    .padding(.vertical, AppDesign.Spacing.xs)
                    .background(Color(nsColor: .controlBackgroundColor))
                Divider()
            }

            // ── Scrollable list — ↑ ↓ Début Fin Entrée (ModListView+Keyboard) ──
            if listLayout == .list && !display.isEmpty {
                modTable(display: display, sections: sections, visibleRows: tableRows, entries: tableEntries)
            } else {
                GeometryReader { viewport in
                    ScrollViewReader { proxy in
                        BackToTopScrollView(localization, bottomContentMargin: 0) {
                            LazyVStack(alignment: .leading, spacing: AppDesign.Spacing.xxl) {
                                if display.isEmpty {
                                    if vm.scanStore.mods.isEmpty {
                                        EmptyStateDropZone(vm: vm, localization: localization,
                                                           onInstall: { navigation.showsInstallSheet = true })
                                            .padding(.top, 40)
                                    } else {
                                        ModListFilteredEmptyState(cause: problemKind == nil ? filters.emptyCause : .combined,
                                                                  filters: filters, localization: localization) {
                                            listState.filters.clearFiltering()
                                            problemKind = nil
                                        }
                                    }
                                } else if !sections.isEmpty {
                                    groupedResults(sections, selectedIDs: selectedIDs)
                                } else {
                                    modResults(display, selectedIDs: selectedIDs)
                                }
                            }
                            .padding(.horizontal, AppDesign.Spacing.xl)
                            .padding(.top, AppDesign.Spacing.lg)
                            .padding(.bottom, BackToTopButton.reservedHeight)
                            .frame(maxWidth: .infinity, minHeight: viewport.size.height, alignment: .topLeading)
                            .background {
                                if listLayout == .grid {
                                    Rectangle()
                                        .fill(.clear)
                                        .contentShape(Rectangle())
                                        .onTapGesture { clearModSelection() }
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .focusable().focusEffectDisabled()
                        .focused($gridFocused)
                        .onKeyPress(keys: Self.navigationKeys) {
                            handleListKey($0, order: displayIds, results: display, proxy: proxy)
                        }
                        .onChange(of: filters) { _, _ in proxy.scrollTo(BackToTop.anchor, anchor: .top) }
                        .onChange(of: groupingRaw) { _, _ in proxy.scrollTo(BackToTop.anchor, anchor: .top) }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            modStatusBar(display: display, selected: selectedEntries,
                         resultCount: display.count + tableRows.lazy.filter(\.isPackComponent).count)
                .background(.bar)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .searchable(text: $listState.filters.search, isPresented: $searchPresented,
                    placement: .toolbar, prompt: localization.L(L10n.Mods.searchMods))
        .background {
            Button(localization.L(L10n.Mods.searchMods)) { searchPresented = true }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .background { ModListToolbarDisplayMode(showsLabels: $showsToolbarLabels) }
        .toolbar {
            modListToolbar(display: display, selected: selected, selectedEntries: selectedEntries,
                           showsFilters: $showsFilters,
                           showsLabels: showsToolbarLabels)
        }
        .confirmationDialog(
            localization.plural(L10n.Mods.trashSelectionTitle, trashPlan?.trashable.count ?? 0),
            isPresented: Binding(get: { trashPlan != nil }, set: { if !$0 { trashPlan = nil } }),
            titleVisibility: .visible, presenting: trashPlan
        ) { plan in
            Button(localization.L(L10n.Mods.trashSelection), role: .destructive) {
                if vm.trashMods(plan.trashable) {
                    listState.selection.clear()
                    vm.selectedModID = nil
                }
            }
            Button(localization.L(L10n.Saves.cancel), role: .cancel) {}
        } message: { plan in
            Text(ModTrashSelectionConfirm.message(plan, localization))
        }
        .onChange(of: filters.scope) { _, _ in problemKind = nil }
        .sheet(item: $listState.groupNameRequest) { ModGroupNameSheet(request: $0, viewModel: viewModel, localization: localization) }
        // Clicking a mod name in the logs must land on that mod, not on the full
        // list. Scope the list to that mod and clear any filters that could hide it.
        // A jump request can arrive before this view exists (from the Logs tab),
        // so it's read on appear as well as while already on screen.
        .onAppear { consumePendingModFocus() }
        .onChange(of: vm.navigationStore.pendingModFocus) { _, _ in consumePendingModFocus() }
        // Publier l'instantané du cadrage au patrimoine commun : la fiche
        // (qui s'exclut de la liste dans MainView) y lira l'ordre de son
        // pager. Non publié sur ModListState — voir là-bas le pourquoi.
        .onAppear { vm.modList.displayOrder = displayIds }
        .task { await loadNexusStats() }
        .onChange(of: displayIds) { _, order in vm.modList.displayOrder = order }
        // D5-C — l'historique de la sonde ne se relit sinon qu'à la fermeture
        // du jeu : première lecture à l'apparition de la liste, en fond.
        .task { await vm.modImpactStore.reloadIfIdle(mods: vm.mods, gameRunning: vm.isGameRunning(), gameDir: vm.gameDir) }
        .sheet(isPresented: $showMissingDependencies) {
            MissingDependenciesSheet(vm: vm, localization: localization,
                                     isPresented: $showMissingDependencies)
        }
        .confirmationDialog(
            bulkToggleTarget == true
                ? localization.L(L10n.Mods.enableAllConfirm)
                : localization.L(L10n.Mods.disableAllConfirm),
            isPresented: Binding(
                get: { bulkToggleTarget != nil },
                set: { if !$0 { bulkToggleTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(bulkToggleTarget == true
                   ? localization.L(L10n.Mods.enableAll)
                   : localization.L(L10n.Mods.disableAll),
                   role: .destructive) {
                if let target = bulkToggleTarget {
                    vm.toggleMods(display, enable: target)
                }
                bulkToggleTarget = nil
            }
            Button(localization.L(L10n.Saves.cancel), role: .cancel) {
                bulkToggleTarget = nil
            }
        } message: {
            // Le compte dit la portée réelle — celle du cadrage courant, pas
            // du parc entier (X57). C'est lui qui rend « Tout » lisible :
            // filtrer sur une catégorie puis « Tout désactiver » annonce les
            // mods de cette catégorie, tous confondus sinon.
            let enable = bulkToggleTarget ?? true, kept = display.bulkToggleKept(enable: enable)
            let base = String(format: localization.L(enable ? L10n.Mods.enableAllMessage : L10n.Mods.disableAllMessage),
                              display.bulkToggleTargets(enable: enable).count)
            Text(kept.isEmpty ? base : base + "\n\n" + String(format: localization.L(L10n.Mods.disableAllKeptSmapi),
                                                               kept.map(\.name).joined(separator: ", ")))
        }
    }
}
