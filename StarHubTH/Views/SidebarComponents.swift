import SwiftUI

// MARK: - Barre latérale (List native)

/// La colonne de navigation — une `List` en style `.sidebar`, rien de dessiné
/// à la main.
///
/// Ce que la version précédente peignait elle-même et qui appartient
/// désormais au système : le fond de sélection, la teinte de l'icône et du
/// libellé sur la ligne choisie, l'effet de survol, la bague de focus, la
/// navigation ↑↓ et le type-select, le fond translucide de la colonne, le
/// défilement sous la barre de titre, les badges et leur place au bord fuyant.
/// Survivre ici serait les défaire — ce fichier ne garde que la **donnée** :
/// quelles pages, sous quel intitulé, avec quel compte.
///
/// Modèle : la barre de la référence visuelle de l'auteur (2026-11-19) —
/// intitulés de groupe en gris, lignes d'une seule ligne, identité du compte
/// au pied de la colonne plutôt qu'en tête.
struct SidebarNavGroups: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    @Binding var currentTab: SidebarDestination

    /// `List` ne rend la sélection que sous forme optionnelle, alors qu'une
    /// page est toujours ouverte ici. Un clic dans le vide (désélection) ne
    /// doit pas vider le détail : il ne fait rien.
    private var selection: Binding<SidebarDestination?> {
        Binding(get: { currentTab },
                set: { page in if let page { currentTab = page } })
    }

    /// Ce qu'une destination compte. `0` — et non `nil` — pour celles qui ne
    /// comptent rien : `.badge(0)` n'affiche aucune pastille, la ligne reste
    /// atteignable quand tout va bien.
    private func badgeCount(_ destination: SidebarDestination) -> Int {
        switch destination {
        case .updates:
            // P5-6b : les mods actifs seulement (décision de l'auteur).
            return vm.pendingUpdateCounts.active
        case .systemAlerts:
            return vm.systemAlertCount
        case .quarantine:
            return vm.maintenanceStore.quarantineItemCount
        case .frenchTranslations:
            // P5-10 : mods actifs, mises à jour et traductions confirmées.
            return vm.frenchTranslationBadgeCount
        case .home, .mods, .discover, .profiles, .saves,
             .backups, .maintenance, .logs:
            return 0
        }
    }

    var body: some View {
        List(selection: selection) {
            // Le groupe `.top` (l'Accueil) se lit au-dessus du premier
            // intitulé, sans le sien — comme la première ligne de la
            // référence.
            Section {
                ForEach(SidebarOrder.entries(in: .top)) { row($0) }
            }
            section(.library, headerKey: L10n.Main.groupLibrary)
            section(.saves, headerKey: L10n.Main.groupSaves)
            section(.health, headerKey: L10n.Main.groupHealth)
        }
        // Seul réglage de style : il donne la sélection, le fond translucide
        // et l'espacement de la barre latérale macOS. Tout le reste suit.
        .listStyle(.sidebar)
    }

    /// Un intitulé de groupe et ses lignes. `Section` dessine l'intitulé
    /// (petite capitale grise) et le fait coller en haut du défilement.
    private func section(_ group: SidebarGroup, headerKey: String) -> some View {
        Section {
            ForEach(SidebarOrder.entries(in: group)) { row($0) }
        } header: {
            Text(localization.L(headerKey))
        }
    }

    /// Une ligne : l'icône et le libellé par la `Label` du système, le
    /// compte par `.badge`. Aucun style par état — c'est `List` qui sait si
    /// la ligne est choisie, survolée ou focalisée.
    private func row(_ entry: SidebarEntry) -> some View {
        Label(localization.L(entry.sidebarLabelKey), systemImage: entry.icon)
            .tag(entry.destination)
            .badge(badgeCount(entry.destination))
    }
}
