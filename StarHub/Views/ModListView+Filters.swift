import SwiftUI

// Le panneau de filtres de `ModListView` — P8, geste A (cadrage
// 2026-09-14) : même type, extension dans un second fichier, aucune
// réécriture. Les membres lus ici mais posés dans le fichier principal
// (`filters`, `listState`, `pageSize`…) y sont `internal` : `private`
// est file-scopé pour les extensions.
extension ModListView {

    /// Une option du menu traduction, avec son compte dans la vue active.
    ///
    /// Le compte, et rien d'autre : l'entrée ne s'éteint pas à zéro. « À
    /// revoir » et « Partiellement traduits » se lisent dans des mesures qui
    /// se font en tâche de fond — au lancement elles valent zéro pour un
    /// moment, et une entrée grisée aurait dit « il n'y en a pas » là où il
    /// fallait lire « pas encore compté ».
    private func translationItem(_ scope: FrenchTranslationScope,
                                 label: String,
                                 icon: String,
                                 count: Int) -> some View {
        Button {
            listState.filters.frenchTranslation = scope
        } label: {
            Label("\(localization.L(label)) (\(count))", systemImage: icon)
        }
    }

    var sortPicker: some View {
        let title = localization.L(L10n.Mods.sortTitle)
        return Menu {
            Picker(title, selection: $listState.filters.sort) {
                ForEach(ModSortOrder.allCases) { order in
                    Text(sortLabel(for: order)).tag(order)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(title, systemImage: "list.bullet.indent")
        }
        .help(title)
    }

    private func sortLabel(for order: ModSortOrder) -> String {
        switch order {
        case .name: return localization.L(L10n.Mods.sortName)
        case .nameDescending: return localization.L(L10n.Mods.sortNameDescending)
        case .activationOrder: return localization.L(L10n.Mods.sortActivationOrder)
        case .installDate: return localization.L(L10n.Mods.sortInstallDate)
        case .author: return localization.L(L10n.Mods.sortAuthor)
        case .version: return localization.L(L10n.Mods.sortVersion)
        case .size: return localization.L(L10n.Mods.sortSize)
        case .endorsements: return localization.L(L10n.Mods.sortEndorsements)
        case .lastNexusUpdate: return localization.L(L10n.Mods.sortLastNexusUpdate)
        }
    }

    var attributeFiltersMenu: some View {
        Menu {
            Toggle(localization.L(L10n.Mods.configFilterLabel), isOn: $listState.filters.configOnly)
            Toggle(localization.L(L10n.Mods.filterFavorites), isOn: $listState.filters.favoritesOnly)
                .disabled(vm.favoriteMods.isEmpty && !filters.favoritesOnly)
                .help(localization.L(vm.favoriteMods.isEmpty ? L10n.Mods.filterFavoritesEmptyHint
                                      : L10n.Mods.filterFavoritesHint))
            Toggle(localization.L(L10n.Mods.filterBlacklisted), isOn: $listState.filters.blacklistedOnly)
                .disabled(vm.blacklistedMods.isEmpty && !filters.blacklistedOnly)
                .help(localization.L(vm.blacklistedMods.isEmpty ? L10n.Mods.filterBlacklistedEmptyHint
                                      : L10n.Mods.filterBlacklistedHint))
        } label: {
            Label(localization.L(L10n.Mods.attributeFilters), systemImage: "checklist")
        }
        .fixedSize()
    }

    func frenchTranslationCounts(from base: [ModItem]) -> [FrenchTranslationScope: Int] {
        var counts: [FrenchTranslationScope: Int] = [:]
        for scope in [FrenchTranslationScope.available, .partial, .missing, .stale] {
            counts[scope] = base.filter { vm.matchesTranslation($0, scope) }.count
        }
        return counts
    }

    func frenchTranslationPicker(counts: [FrenchTranslationScope: Int]) -> some View {
        let label: String = {
            switch filters.frenchTranslation {
            case .off:       return localization.L(L10n.Mods.frTranslationFilterLabel)
            case .available: return localization.L(L10n.Mods.frTranslationAvailable)
            case .partial:   return localization.L(L10n.Mods.frTranslationPartial)
            case .missing:   return localization.L(L10n.Mods.frTranslationMissing)
            case .stale:     return localization.L(L10n.Mods.frTranslationStale)
            }
        }()
        let icon: String = {
            switch filters.frenchTranslation {
            case .off:       return "character.bubble"
            case .available: return "checkmark.bubble"
            case .partial:   return "ellipsis.bubble"
            // Le symbole `xmark` sur bulle n'existe pas sur macOS 26
            // (mesuré) : l'entrée « À traduire » n'affichait rien.
            case .missing:   return "exclamationmark.bubble"
            case .stale:     return "clock.badge.exclamationmark"
            }
        }()
        return Menu {
            Button {
                listState.filters.frenchTranslation = .off
            } label: {
                Label(localization.L(L10n.Mods.frTranslationFilterLabel), systemImage: "character.bubble")
            }
            translationItem(.available, label: L10n.Mods.frTranslationAvailable,
                            icon: "checkmark.bubble", count: counts[.available] ?? 0)
            translationItem(.partial, label: L10n.Mods.frTranslationPartial,
                            icon: "ellipsis.bubble", count: counts[.partial] ?? 0)
            translationItem(.missing, label: L10n.Mods.frTranslationMissing,
                            icon: "exclamationmark.bubble", count: counts[.missing] ?? 0)
            translationItem(.stale, label: L10n.Mods.frTranslationStale,
                            icon: "clock.badge.exclamationmark", count: counts[.stale] ?? 0)
        } label: {
            Label(label, systemImage: icon)
        }
        .fixedSize()
        .help(localization.L(L10n.Mods.frTranslationFilterLabel))
    }

    // MARK: - Category picker

    /// Dropdown listing every category present in the installed mods list.
    /// Selecting one scopes the list to that category; selecting "All" clears
    /// it. Each row shows the category color + localized name + mod count.
    func categoryPicker(categories: [(category: NexusCategory, count: Int)], uncatCount: Int, tagBuckets: [(tag: String, label: String, count: Int)]) -> some View {
        Menu {
            Button {
                listState.filters.category = .all
            } label: {
                Label(localization.L(L10n.Mods.categoryFilterAll), systemImage: "square.grid.2x2")
            }
            if uncatCount > 0 {
                Button {
                    listState.filters.category = .uncategorized
                } label: {
                    Label("\(localization.L(L10n.Mods.categoryFilterUncategorized))   (\(uncatCount))", systemImage: "circle.dashed")
                }
            }
            if !categories.isEmpty {
                Divider()
            }
            ForEach(categories, id: \.category.id) { entry in
                Button {
                    listState.filters.category = .category(entry.category)
                } label: {
                    // SwiftUI Menus render Button labels as plain text — an
                    // HStack would only show its first child. Concatenating
                    // Text views (or building a single string) keeps both the
                    // icon and the category name visible in the row.
                    Text(entry.category.emoji + " " + entry.category.localizedName(localization.L) + "   (\(entry.count))")
                }
            }
            // Offline fallback: mods with no Nexus category, grouped by their
            // inferred type tag instead of a single "uncategorized" bucket.
            if !tagBuckets.isEmpty {
                Divider()
                ForEach(tagBuckets, id: \.tag) { bucket in
                    Button {
                        listState.filters.category = .inferredTag(bucket.tag)
                    } label: {
                        Text("\(bucket.label)   (\(bucket.count))")
                    }
                }
            }
            if filters.category != .all {
                Divider()
                Button {
                    listState.filters.category = .all
                } label: {
                    Label(localization.L(L10n.Mods.categoryFilterClear), systemImage: "xmark.circle")
                }
            }
        } label: {
            Label(categoryFilterName, systemImage: "tag")
        }
        .fixedSize()
    }

    private var categoryFilterName: String {
        switch filters.category {
        case .all: return localization.L(L10n.Mods.categoryFilter)
        case .category(let category): return category.localizedName(localization.L)
        case .inferredTag(let tag): return localization.L(L10n.ModTag.key(for: tag))
        case .uncategorized: return localization.L(L10n.Mods.categoryFilterUncategorized)
        }
    }
}
