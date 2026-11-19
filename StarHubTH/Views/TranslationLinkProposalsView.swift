import SwiftUI

/// C7-T1 — la revue des propositions de lien, une à la fois : ouverte depuis
/// le compteur discret du panorama « Traductions FR ». Chaque ligne porte la
/// carte de la fiche (mêmes gestes : rattacher crée la déclaration, ignorer
/// mémorise le refus par `folderName|mtime` — le pack modifié redevient
/// proposable). Aucune écriture disque : la déclaration ne fait que suivre.
struct TranslationLinkProposalsView: View {
    var viewModel: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    /// Le relevé figé à l'ouverture — confirmations et écarts retirent leurs
    /// lignes du store, la liste se réduit sous les yeux.
    let proposals: [TranslationLinkProposal]
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(localization.L(L10n.Mods.translationLinkCardTitle))
                        .font(AppDesign.Font.viewTitle)
                    Text(String(format: localization.L(L10n.Mods.translationLinkCounter),
                                proposals.count))
                        .font(AppDesign.Font.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(localization.L(L10n.Mods.translationLinkDismiss)) { onClose() }
                    .controlSize(.small)
            }
            .padding(AppDesign.Spacing.lg)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                    ForEach(proposals, id: \.packFolderName) { proposal in
                        TranslationLinkProposalCard(vm: viewModel,
                                                    localization: localization,
                                                    proposal: proposal)
                        Divider()
                    }
                    if proposals.isEmpty {
                        Text(localization.L(L10n.Mods.translationLinkNoTracking))
                            .font(AppDesign.Font.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(AppDesign.Spacing.lg)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, AppDesign.Spacing.lg)
        .frame(minWidth: 520, minHeight: 380)
    }

}
