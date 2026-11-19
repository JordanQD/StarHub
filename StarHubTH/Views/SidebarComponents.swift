import SwiftUI

// MARK: - Sidebar Nav Groups

/// Les trois groupes d'entrées de la barre latérale — Bibliothèque, Parties,
/// Santé & secours. Extrait du corps de `MainView` (densité) et
/// posé dans le `ScrollView` de la colonne : en fenêtre basse, ce sont ces
/// lignes qui défilent.
struct SidebarNavGroups: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    @Binding var currentTab: SidebarDestination

    /// Le badge d'une destination — donnée **vivante** du ViewModel, pas de
    /// `SidebarOrder` : il change à chaque scan. `nil` quand l'entrée ne
    /// compte rien.
    private func badge(_ d: SidebarDestination) -> (count: Int, color: Color)? {
        let model = vm
        switch d {
        case .updates:
            // P5-6b : les mods actifs seulement (décision de l'auteur).
            return (model.pendingUpdateCounts.active, AppDesign.Color.info)
        case .systemAlerts:
            let color = model.healthIssues.contains { $0.severity == .critical }
                ? AppDesign.Color.error
                : AppDesign.Color.warning
            return (model.systemAlertCount, color)
        case .quarantine:
            return (model.maintenanceStore.quarantineItemCount, AppDesign.Color.quarantine)
        case .frenchTranslations:
            // P5-10 : mods actifs, mises à jour et traductions confirmées.
            return (model.frenchTranslationBadgeCount, AppDesign.Color.accent)
        case .home, .mods, .discover, .profiles, .saves,
             .backups, .maintenance, .logs:
            return nil
        }
    }

    private func group(_ g: SidebarGroup, header: String,
                       icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            SidebarSectionHeader(title: header, icon: icon)
            ForEach(SidebarOrder.entries(in: g)) { e in
                // `badge: Int?` est déjà optionnel côté SidebarItem — `nil`
                // veut dire « cet item ne compte rien », `0` « il compte, et
                // il n'y a rien ». Pas de branche à écrire.
                let b = badge(e.destination)
                SidebarItem(icon: e.icon, label: localization.L(e.sidebarLabelKey),
                            tab: e.destination, badge: b?.count,
                            badgeColor: b?.color ?? AppDesign.Color.info,
                            currentTab: $currentTab)
            }
        }
    }

    /// Le groupe `.top` (l'Accueil) n'est **pas** rendu ici : il vit dans
    /// `AccountHeaderCard`, en tête de colonne. Il est dans `SidebarOrder`
    /// parce que le menu « Aller » et la palette en ont besoin, pas la barre.
    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.lg) {
            group(.library, header: localization.L(L10n.Main.groupLibrary),
                  icon: "square.grid.2x2")
            group(.saves, header: localization.L(L10n.Main.groupSaves),
                  icon: "gamecontroller")
            group(.health, header: localization.L(L10n.Main.groupHealth),
                  icon: "cross.case")
        }
    }
}

struct SidebarSectionHeader: View {
    let title: String
    var icon: String = ""   // optionnel, vide par défaut (pas de breaking change)

    var body: some View {
        HStack(spacing: AppDesign.Spacing.xs + 2) {
            if !icon.isEmpty {
                Image(systemName: icon)
                    .font(AppDesign.Font.iconXS.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            Text(title)
                .font(AppDesign.Font.caption(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(.leading, AppDesign.Spacing.sm)
        .padding(.top, AppDesign.Spacing.sm)
        .padding(.bottom, 0)
        .accessibilityAddTraits(.isHeader)
    }
}
