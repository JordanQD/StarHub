import SwiftUI

/// Une vérification en échec (2026-10-08 : smapi.io en panne, HTTP 500) :
/// la cause, l'âge de la liste affichée s'il y en a une, et l'alternative —
/// vérifier directement sur Nexus, au choix de l'utilisateur.
struct UpdateCheckFailureBanner: View {
    var viewModel: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    let error: String
    /// Une liste en cache est affichée dessous : dire qu'elle date d'avant.
    let listIsStale: Bool

    private var message: String {
        let cause = switch error {
        case "rate_limited": localization.L(L10n.Updates.nexusRateLimited)
        case "server_down": localization.L(L10n.Updates.smapiServerDown)
        default: localization.L(L10n.Updates.nexusError)
        }
        return listIsStale ? cause + " " + localization.L(L10n.Updates.checkFailedStale) : cause
    }

    var body: some View {
        let pages = viewModel.nexusAlternativePages
        VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
            Text(message)
                .font(AppDesign.Font.caption)
                .foregroundColor(AppDesign.Color.error.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            if pages > 0 {
                if viewModel.hasNexusApiKey {
                    Button(localization.L(L10n.Updates.nexusAlternativeButton)) {
                        viewModel.checkUpdatesViaNexus()
                    }
                    .controlSize(.small)
                    Text(String(format: localization.L(L10n.Updates.nexusAlternativeHint), Int64(pages)))
                        .font(AppDesign.Font.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    NexusAccessNote(message: localization.L(L10n.Updates.nexusAlternativeNoKey),
                                    navigation: viewModel.navigationStore, localization: localization)
                }
            }
        }
    }
}

/// Les mods sans verdict de mise à jour et la raison par mod.
struct UnverifiableModsSection: View {
    var viewModel: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    /// Dépliée ou non, **hors de la vue** : la page est recréée à chaque
    /// retour (ouvrir la fiche d'un mod de la liste, puis revenir), et un
    /// état local la repliait — la liste semblait effacée (2026-10-08).
    @AppStorage(UDKey.unverifiableUpdatesExpanded) private var expanded = false

    var body: some View {
        let rows = viewModel.unverifiableMods
        UpdateSectionDisclosure(title: String(format: localization.L(L10n.Updates.unverifiableTitle),
                                              Int64(rows.count)), isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 3) {
                // Indexé par `UniqueID` : deux mods peuvent porter le même nom,
                // et la reprise Nexus retire des lignes en cours de route.
                ForEach(rows, id: \.uniqueId) { row in
                    UnverifiableRow(viewModel: viewModel, localization: localization, row: row)
                }
            }
            .padding(.vertical, AppDesign.Spacing.xs)
        }
    }
}

/// Une ligne « sans verdict » : la ligne entière ouvre la fiche, la flèche de
/// la page Santé le dit. Onglet **Gestion**, où se saisit
/// l'identifiant Nexus (2026-10-08).
private struct UnverifiableRow: View {
    var viewModel: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    let row: SmapiVerdicts.Unverifiable

    var body: some View {
        let content = HStack(spacing: 6) {
            Text(row.name)
                .font(AppDesign.Font.footnote(.medium))
            Text(localization.L(row.outcome?.labelKey ?? row.blocker.labelKey))
                .font(AppDesign.Font.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
        }
        if let mod = viewModel.scanStore.mods.mod(withUniqueId: row.uniqueId) {
            Button {
                viewModel.navigationStore.openModDetail(folderName: mod.folderName, door: .unverifiable)
            } label: {
                HStack(spacing: 6) {
                    content
                    OpenDetailIcon()
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain).focusRing()
            .pointingHandCursor()
            .help(localization.L(row.blocker.labelKey))
            .accessibilityHint(localization.L(L10n.Mods.openDetails))
        } else {
            content.help(localization.L(row.blocker.labelKey))
        }
    }
}
