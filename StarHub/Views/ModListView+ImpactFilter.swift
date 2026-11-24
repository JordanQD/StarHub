import SwiftUI

/// D5-C — le filtre et les comptes d'impact de la liste, sortis de
/// `ModListView+Filters` (fichier au cliquet) : le menu à trois états, son
/// entrée, et les comptes qu'il affiche.
extension ModListView {
    /// Menu à trois états : tout, les mods d'impact mesuré élevé, ou les
    /// moyens. Même famille de puce que le menu « traduction FR ». Les
    /// comptes viennent du store de la sonde, pas de la liste cadrée : ils
    /// ne bougent pas quand le filtre s'applique à lui-même — et à la
    /// première lecture ils valent 0, le temps que la relecture de fond
    /// finisse.
    func impactPicker(counts: (high: Int, medium: Int)) -> some View {
        let scope = filters.impactScope
        let label: String = {
            switch scope {
            case .off:     return localization.L(L10n.Mods.impactFilterLabel)
            case .high:    return localization.L(L10n.Mods.impactFilterHigh)
            case .medium:  return localization.L(L10n.Mods.impactFilterMedium)
            }
        }()
        let icon: String = {
            switch scope {
            case .off:     return "gauge"
            // La charte des pastilles (`ModImpactBadge.visuals`) : rond
            // plein rouge pour l'élevé, cercle à tiret orange pour le
            // moyen — pas de triangle, c'est la signalétique des problèmes.
            case .high:    return "circle.fill"
            case .medium:  return "minus.circle.fill"
            }
        }()
        return Menu {
            Button {
                listState.filters.impactScope = .off
            } label: {
                Label(localization.L(L10n.Mods.impactFilterLabel), systemImage: "gauge")
            }
            impactItem(.high, label: L10n.Mods.impactFilterHigh,
                       icon: "circle.fill", count: counts.high)
            impactItem(.medium, label: L10n.Mods.impactFilterMedium,
                       icon: "minus.circle.fill", count: counts.medium)
        } label: {
            Label(label, systemImage: icon)
        }
        .fixedSize()
        .help(localization.L(L10n.Mods.impactFilterLabel))
    }

    private func impactItem(_ scope: ImpactScope,
                            label: String,
                            icon: String,
                            count: Int) -> some View {
        Button {
            listState.filters.impactScope = scope
        } label: {
            Label("\(localization.L(label)) (\(count))", systemImage: icon)
        }
    }

    /// Les comptes du menu impact (D5-C) : les classes du store de la sonde,
    /// composants de pack compris — la même carte que lit
    /// `ModListScoping.matchesImpact`. Zéro tant que la relecture de fond
    /// n'a pas abouti ; le menu reste utilisable, ses entrées montrent (0).
    func impactFilterCounts() -> (high: Int, medium: Int) {
        let classes = vm.modImpactStore.classesById.values
        return (classes.filter { $0 == .high }.count,
                classes.filter { $0 == .medium }.count)
    }
}
