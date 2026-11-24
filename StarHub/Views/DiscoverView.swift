import SwiftUI

/// L'onglet « Découvrir » : tendances, récents, sélection FR, recherche —
/// et le croisement permanent avec le parc installé (spec §7).
///
/// La fiche vit en **sheet interne** : les états globaux de MainView sont
/// remis à nil au changement d'onglet, et cette vue ne doit ni les vider ni
/// en dépendre (spec §7.1).
struct DiscoverView: View {
    @Environment(\.openSettings) private var openSettings

    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    @AppStorage("discoveryHideInstalled") private var hideInstalled = false
    @State private var searchText = ""
    @State private var searchFocusRequest = 0
    @State private var detailRow: StarHubTHViewModel.DiscoveryRow?
    @Binding var section: ModCatalog.SectionKind?

    var body: some View { content }

    private var content: some View {
        BackToTopScrollView(localization) {
            VStack(alignment: .leading, spacing: AppDesign.Spacing.lg) {
                if let error = vm.lastDiscoveryError { discoveryErrorBanner(error) }
                if let search = vm.discoverySearch {
                    searchResults(search)
                } else if let section {
                    sectionPage(section)
                } else {
                    ForEach(ModCatalog.SectionKind.allCases, id: \.self) { kind in
                        sectionShelf(kind)
                    }
                }
            }
            .padding(AppDesign.Spacing.xl)
        }
        .withoutTopScrollEdgeEffect()
        .id(section)
        .id(vm.discoverySearch?.term)
        .background(AppDesign.Color.windowBg)
        .background {
            Button("") { searchFocusRequest += 1 }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .toolbar { discoveryToolbar }
        .onAppear {
            if searchText.isEmpty, let search = vm.discoverySearch { searchText = search.term }
            vm.loadDiscovery()
        }
        .onChange(of: searchText) { _, text in
            if text.isEmpty { vm.clearDiscoverySearch() }
        }
        .sheet(item: $detailRow) { row in
            DiscoveryDetailSheet(vm: vm, localization: localization, row: row)
        }
    }

    @ToolbarContentBuilder
    private var discoveryToolbar: some ToolbarContent {
        let searchItem = ToolbarItem(placement: .principal) { toolbarSearchField }
        if #available(macOS 26.0, *) {
            searchItem.sharedBackgroundVisibility(.visible)
        } else {
            searchItem
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                categoryPicker
                Divider()
                Toggle(localization.L(L10n.Discovery.hideInstalled), isOn: $hideInstalled)
                    .disabled(vm.discoverySearch != nil)
            } label: {
                Label(localization.L(L10n.Mods.filtersTitle),
                      systemImage: vm.discoveryCategory != nil || (vm.discoverySearch == nil && hideInstalled)
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle")
            }
            .help(localization.L(L10n.Mods.filtersTitle))
        }
    }

    private var toolbarSearchField: some View {
        DiscoverySearchField(text: $searchText,
                             placeholder: localization.L(L10n.Discovery.searchPlaceholder),
                             focusRequest: searchFocusRequest) { query in
            section = nil
            vm.searchDiscovery(name: query)
        }
            .frame(minWidth: 150, idealWidth: 360, maxWidth: 460)
    }

    /// Le filtre de catégorie : les 26 catégories Nexus du jeu, dans l'ordre
    /// de leur nom traduit. Il part au serveur — chaque choix redemande les
    /// trois sections, et chaque catégorie a son propre cache de 24 h.
    private var categoryPicker: some View {
        // Un `Picker` lié à une valeur, et non un `Menu` de `Button` : chaque
        // choix remplace la vitrine **et** la recherche affichée, donc
        // reconstruit la hiérarchie sous le menu ouvert — un second choix ne
        // partait plus. Un `Picker` porte sa sélection, il survit à la
        // reconstruction.
        Picker(localization.L(L10n.Mods.categoryFilter), selection: categorySelection) {
            Text(localization.L(L10n.Mods.categoryFilterAll)).tag(0)
            Divider()
            ForEach(sortedCategories, id: \.id) { category in
                // Un menu SwiftUI rend l'item en texte simple : le glyphe doit
                // tenir dans le `Text`, un `Label` le perdrait.
                Text(category.emoji + " " + category.localizedName(localization.L)).tag(category.id)
            }
        }
        .pickerStyle(.menu)
    }

    /// `0` = toutes les catégories : `NexusCategory` n'utilise pas cet
    /// identifiant (la racine `1` non plus n'est jamais assignée).
    private var categorySelection: Binding<Int> {
        Binding(get: { vm.discoveryCategory?.id ?? 0 },
                set: { vm.setDiscoveryCategory($0 == 0 ? nil : NexusCategory.from(id: $0)) })
    }

    private var sortedCategories: [NexusCategory] {
        NexusCategory.all.sorted {
            $0.localizedName(localization.L)
                .localizedCaseInsensitiveCompare($1.localizedName(localization.L)) == .orderedAscending
        }
    }

    private func searchResults(_ search: DiscoverySearchResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: AppDesign.Grid.minCardWidth),
                                                 spacing: AppDesign.Grid.gutter)],
                      spacing: AppDesign.Grid.gutter) {
                ForEach(search.rows) { row in card(row) }
            }
            if search.loaded < search.totalCount {
                DiscoveryPageEnd(isLoading: vm.discoveryLoading,
                                 nextOffset: vm.lastDiscoveryError == nil ? search.loaded : nil,
                                 load: { vm.loadMoreDiscoverySearch() })
            } else if search.rows.isEmpty {
                StateCard(icon: "magnifyingglass", text: localization.L(L10n.Discovery.noMatch),
                          actionTitle: nil, action: {})
            }
        }
    }

    private func sectionShelf(_ kind: ModCatalog.SectionKind) -> some View {
        let rows = vm.discoveryRows(for: kind, hidingInstalled: hideInstalled).rows
        return VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            Button { section = kind } label: {
                Label(title(for: kind), systemImage: "chevron.forward")
                    .labelStyle(DiscoverySectionLabelStyle())
                    .font(.title2.weight(.semibold))
            }
            .buttonStyle(.plain)
            .focusRing()

            if rows.isEmpty {
                sectionPlaceholder(kind)
            } else {
                DiscoveryShelf(rows: Array(rows.prefix(ModCatalog.previewLimit)), localization: localization, card: card)
                    .id(vm.discoveryCategory?.id)
            }
        }
    }

    private func sectionPage(_ kind: ModCatalog.SectionKind) -> some View {
        let (rows, nextOffset) = vm.discoveryRows(for: kind, hidingInstalled: hideInstalled)
        return VStack(alignment: .leading, spacing: AppDesign.Spacing.lg) {
            Text(title(for: kind)).font(.title.weight(.semibold)).accessibilityAddTraits(.isHeader)
            if rows.isEmpty {
                sectionPlaceholder(kind)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: AppDesign.Grid.minCardWidth),
                                             spacing: AppDesign.Grid.gutter)],
                          spacing: AppDesign.Grid.gutter) {
                    ForEach(rows) { card($0) }
                }
            }
            if let nextOffset {
                DiscoveryPageEnd(isLoading: vm.discoveryLoading,
                                 nextOffset: vm.lastDiscoveryError == nil ? nextOffset : nil,
                                 load: { vm.loadMoreDiscovery(kind) })
                    .id(vm.discoveryCategory?.id)
            }
        }
    }

    @ViewBuilder
    private func sectionPlaceholder(_ kind: ModCatalog.SectionKind) -> some View {
        if case .empty(let reason) = vm.discovery[kind] ?? .empty(.neverLoaded) {
            if vm.discoveryLoading, reason == .neverLoaded {
                ProgressView().controlSize(.small)
            } else {
                emptySection(reason)
            }
        } else {
            noMatchState
        }
    }

    private func title(for kind: ModCatalog.SectionKind) -> String {
        switch kind {
        case .trending: return localization.L(L10n.Discovery.trending)
        case .recent: return localization.L(L10n.Discovery.recent)
        case .french: return localization.L(L10n.Discovery.french)
        }
    }

    /// Jamais de section muette (spec §8) : chaque raison a son texte, son
    /// icône **et l'action qui la lève** — un état sans issue n'est qu'un
    /// constat d'échec.
    @ViewBuilder private func emptySection(_ reason: ModCatalog.EmptyReason) -> some View {
        switch reason {
        case .neverLoaded:
            StateCard(icon: "square.grid.2x2", text: localization.L(L10n.Discovery.neverLoaded),
                      actionTitle: localization.L(L10n.Discovery.retry)) { vm.loadDiscovery(force: true) }
        case .failed:
            switch vm.lastDiscoveryError {
            case .noApiKey:
                StateCard(icon: "key", text: localization.L(L10n.Discovery.noKey),
                          actionTitle: localization.L(L10n.Discovery.openSettings)) {
                    vm.navigationStore.openSettings(.nexus)
                    openSettings()
                }
            case .rateLimited:
                StateCard(icon: "hourglass", text: localization.L(L10n.Discovery.rateLimited),
                          actionTitle: localization.L(L10n.Discovery.retry)) { vm.loadDiscovery(force: true) }
            default:
                StateCard(icon: "wifi.exclamationmark", text: localization.L(L10n.Discovery.error),
                          actionTitle: localization.L(L10n.Discovery.retry)) { vm.loadDiscovery(force: true) }
            }
        }
    }

    /// La section a répondu, les filtres n'ont rien laissé passer. L'action
    /// est de **retirer les filtres**, pas de rafraîchir : rafraîchir
    /// rapporterait les mêmes mods, écartés par les mêmes règles.
    @ViewBuilder private var noMatchState: some View {
        if vm.discoveryCategory != nil || hideInstalled {
            StateCard(icon: "line.3.horizontal.decrease.circle",
                      text: localization.L(L10n.Discovery.noMatch),
                      actionTitle: localization.L(L10n.Discovery.clearFilters)) {
                hideInstalled = false
                vm.setDiscoveryCategory(nil)
            }
        } else {
            StateCard(icon: "line.3.horizontal.decrease.circle",
                      text: localization.L(L10n.Discovery.noMatch), actionTitle: nil, action: {})
        }
    }

    /// Adapte une ligne de la vitrine aux valeurs qu'attend `ModCard`.
    private func card(_ row: StarHubTHViewModel.DiscoveryRow) -> some View {
        ModCard(
            title: row.hit.name,
            thumbnailURL: row.hit.thumbnailUrl.flatMap { URL(string: $0) },
            installedLabel: row.installed ? localization.L(L10n.Discovery.installedBadge) : nil,
            category: row.hit.categoryId.flatMap(NexusCategory.from(id:)),
            neutralBadge: row.hit.tags.contains(NexusModSearch.frenchTag) ? "FR" : nil,
            endorsements: row.hit.endorsements,
            L: localization.L,
            action: { detailRow = row }
        )
    }

    /// Une seule panne, un seul message : les sections ne répètent pas. La vue
    /// résout le texte et l'action, le bandeau se contente de les rendre.
    ///
    /// Trois messages mais **deux** issues seulement : hors « pas de clé », la
    /// panne se réessaie. Les séparer en trois branches dupliquait l'action
    /// sans rien clarifier.
    private func discoveryErrorBanner(_ error: NexusSearchClient.SearchError) -> some View {
        let text: String
        switch error {
        case .noApiKey: text = localization.L(L10n.Discovery.noKey)
        case .rateLimited: text = localization.L(L10n.Discovery.rateLimited)
        default: text = localization.L(L10n.Discovery.error)
        }
        if case .noApiKey = error {
            return ErrorBanner(text: text,
                               actionTitle: localization.L(L10n.Discovery.openSettings)) {
                vm.navigationStore.openSettings(.nexus)
                openSettings()
            }
        }
        return ErrorBanner(text: text,
                           actionTitle: localization.L(L10n.Discovery.retry)) {
            if let search = vm.discoverySearch, search.loaded < search.totalCount {
                vm.loadMoreDiscoverySearch()
            } else if vm.discoverySearch == nil && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                vm.searchDiscovery(name: searchText)
            } else if let section, vm.discovery[section]?.page?.nextOffset != nil {
                vm.loadMoreDiscovery(section)
            } else {
                vm.loadDiscovery(force: true)
            }
        }
    }
}

/// Met en avant celui des deux boutons qui **fonctionne**. SwiftUI n'a pas
/// de `ButtonStyle` effaçable en type : la branche vit ici plutôt que dans un
/// ternaire impossible à écrire.
private struct ProminentButton: ViewModifier {
    let prominent: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if prominent {
            content.buttonStyle(.borderedProminent).focusRing()
        } else {
            content.buttonStyle(.bordered).focusRing()
        }
    }
}

/// La fiche éclair (spec §7.2) : sheet, jamais un état global.
struct DiscoveryDetailSheet: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    let row: StarHubTHViewModel.DiscoveryRow
    @Environment(\.dismiss) private var dismiss

    /// L'onglet **Files** directement : c'est là qu'on va quand on ouvre la
    /// page depuis la vitrine — la description, on vient de la lire ici.
    private var nexusURL: URL? {
        URL(string: "https://www.nexusmods.com/stardewvalley/mods/\(row.hit.modId)?tab=files")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            hero
            statStrip
            Divider()
            actions
            switch vm.discoveryDetailState {
            case .loading:
                ProgressView().frame(maxWidth: .infinity).padding()
            case .failed:
                Text(localization.L(L10n.Discovery.detailFailed))
                    .font(AppDesign.Font.body).foregroundStyle(.secondary).padding()
            case .idle, .loaded:
                if let detail = vm.discoveryDetail {
                    detailBody(detail)
                } else {
                    Text(localization.L(L10n.Discovery.neverLoaded))
                        .font(AppDesign.Font.body).foregroundStyle(.secondary).padding()
                }
            }
            Spacer(minLength: 0)
        }
        .frame(width: AppDesign.Metrics.sheetDetailSize.width,
               height: AppDesign.Metrics.sheetDetailSize.height)
        .onAppear { vm.loadDiscoveryDetail(modId: row.hit.modId) }
        .onDisappear { vm.closeDiscoveryDetail() }
    }

    /// Le bandeau : la vignette du mod, son nom et son auteur par-dessus.
    private var hero: some View {
        HeroHeader(title: row.hit.name,
                   subtitle: row.hit.uploader,
                   imageURL: row.hit.thumbnailUrl.flatMap { URL(string: $0) },
                   closeHelp: localization.L(L10n.Main.close)) {
            dismiss()
        }
    }

    /// Ce que la carte ne disait pas, en une bande : endossements, version,
    /// âge de la mise à jour, catégorie. Ces quatre chiffres décident de
    /// l'installation plus sûrement qu'un paragraphe de description.
    private var statStrip: some View {
        StatStrip(items: [
            .init(label: localization.L(L10n.Discovery.statEndorsements),
                  value: (vm.discoveryDetail?.endorsements ?? row.hit.endorsements)
                      .map { "\($0)" } ?? "—"),
            .init(label: localization.L(L10n.ModInstall.labelVersion),
                  value: vm.discoveryDetail?.version.isEmpty == false
                      ? vm.discoveryDetail!.version
                      : (row.hit.version.isEmpty ? "—" : row.hit.version)),
            .init(label: localization.L(L10n.Discovery.statUpdated), value: updatedText),
            .init(label: localization.L(L10n.Mods.categoryFilter),
                  value: row.hit.categoryId.flatMap(NexusCategory.from(id:))?
                      .localizedName(localization.L)
                      ?? (row.hit.categoryName.isEmpty ? "—" : row.hit.categoryName)),
        ])
    }

    private var updatedText: String {
        guard let date = vm.discoveryDetail?.updatedAt ?? row.hit.updatedAt else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Les deux actions ne dépendent que du `modId` de la carte, pas de la
    /// fiche : elles restent offertes quand Nexus ne rend pas la fiche (quota,
    /// panne). Les enfermer dans le corps chargé aurait retiré la porte de
    /// sortie au moment précis où elle sert.
    ///
    /// **Celle qui marche est la proéminente** : sur un compte gratuit
    /// l'installation directe est refusée par l'API, alors le site prend le
    /// bouton bleu.
    private var actions: some View {
        HStack(spacing: AppDesign.Spacing.sm) {
            installButton
            if let url = nexusURL {
                // Un `Button` et non un `Link` : la fiche doit se fermer en
                // même temps que la page s'ouvre, et un `Link` ne laisse pas
                // la main pour `dismiss()`.
                Button {
                    NSWorkspace.shared.open(url)
                    dismiss()
                } label: {
                    Label(localization.L(L10n.Discovery.openNexus), systemImage: "arrow.up.forward.square")
                }
                .modifier(ProminentButton(prominent: !installOffered))
            }
            Spacer(minLength: 0)
            if row.installed {
                Label(localization.L(L10n.Discovery.installedBadge), systemImage: "checkmark.circle.fill")
                    .font(AppDesign.Font.footnote)
                    .foregroundStyle(AppDesign.Color.installed)
            }
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.vertical, AppDesign.Spacing.md)
    }

    /// L'installation directe est-elle réellement praticable ici ?
    private var installOffered: Bool {
        !vm.nexusDirectDownloadUnavailable && !row.installed
    }

    /// Installer sans passer par le site (G-T3) : le mod non installé emprunte
    /// le **pipeline des mises à jour** — `downloadModFromNexus` résout le
    /// fichier principal, télécharge, et la feuille d'installation prend le
    /// relais. Aucune voie parallèle : c'est le même chemin, éprouvé, que le
    /// bouton des mises à jour et que `nxm://`.
    ///
    /// Trois raisons de le refuser, chacune avec son explication au survol :
    /// un téléchargement déjà en cours, un compte non premium (l'API de lien
    /// répond 403 — le site et `nxm://` restent la voie gratuite), et un mod
    /// déjà installé, qui se met à jour depuis la liste des mods.
    @ViewBuilder private var installButton: some View {
        Button {
            // La fiche se ferme **avant** de lancer : la feuille
            // d'installation est présentée par MainView quelques secondes
            // plus tard, et deux feuilles empilées ne s'affichent pas.
            dismiss()
            vm.downloadModFromNexus(nexusId: row.hit.modId)
        } label: {
            Label(localization.L(L10n.Discovery.install), systemImage: "arrow.down.circle")
        }
        .modifier(ProminentButton(prominent: installOffered))
        .disabled(vm.isDownloadingFromNexus || vm.nexusDirectDownloadUnavailable
                  || row.installed)
        .help(installHint)
    }

    private var installHint: String {
        if row.installed { return localization.L(L10n.Discovery.alreadyInstalled) }
        if vm.nexusDirectDownloadUnavailable { return localization.L(L10n.Mods.premiumOnlyHint) }
        return localization.L(L10n.Discovery.install)
    }

    @ViewBuilder private func detailBody(_ detail: NexusModSearch.Detail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                // Les endossements sont montés dans la bande de chiffres : les
                // répéter ici doublonnait.
                if let summary = detail.summary {
                    Text(summary).font(AppDesign.Font.body).italic()
                        .foregroundStyle(.secondary)
                }
                // La description Nexus est du **BBCode** (`[b]`, `[img]`, `<br />`…)
                // — le même rendu que la fiche mod : blocs parsés, images à taille
                // native via cache, liens cliquables. Les captures y sont déjà des
                // `[img]` : l'image d'en-tête du schéma serait un doublon.
                DescriptionBlocksView(blocks: DescriptionBlockParser.parse(
                    detail.descriptionText ?? ""), vm: vm, localization: localization)
            }
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.bottom, AppDesign.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
