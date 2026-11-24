import SwiftUI

/// C7-T1 — la carte « semble traduire… » sur la fiche d'un pack-traduction
/// posé comme un mod. Proposition seulement : `[Rattacher]` crée la
/// déclaration (**aucune écriture disque**), `[Ignorer]` mémorise le refus
/// par `folderName|mtime`. Un ex-æquo non tranché par le nom offre le choix
/// d'hôte (`alternates`) ; un pack sans identité Nexus rattache **sans
/// suivi de version** — dit avant le clic ; un hôte déjà suivi par l'app
/// est annoncé (terrain C7-T2).
struct TranslationLinkProposalCard: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    let proposal: TranslationLinkProposal

    /// L'hôte choisi dans le menu quand un ex-æquo subsiste — vide tant que
    /// l'utilisateur n'a pas touché, l'hôte du calcul fait foi.
    @State private var alternateHost: String = ""

    private var currentHost: String {
        alternateHost.isEmpty ? proposal.hostFolderName : alternateHost
    }
    private var coveragePercent: Int { Int((proposal.coverage * 100).rounded()) }
    private var hostTracked: Bool {
        vm.installedTranslations.declaredLinkHosts().contains(currentHost)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "link")
                .foregroundColor(.accentColor)
                .font(AppDesign.Font.caption)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(localization.L(L10n.Mods.translationLinkCardTitle))
                    .font(AppDesign.Font.caption(.medium))
                if proposal.alternates.isEmpty {
                    Text(currentHost)
                        .font(AppDesign.Font.footnote)
                } else {
                    Picker(localization.L(L10n.Mods.translationLinkCardTitle),
                           selection: Binding(
                               get: { currentHost },
                               set: { alternateHost = $0 })) {
                        ForEach([proposal.hostFolderName] + proposal.alternates, id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                }
                Text(String(format: localization.L(L10n.Mods.translationLinkCoverage),
                            coveragePercent))
                    .font(AppDesign.Font.iconXS)
                    .foregroundColor(.secondary)
                if proposal.nexusId == nil {
                    Text(localization.L(L10n.Mods.translationLinkNoTracking))
                        .font(AppDesign.Font.iconXS)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if hostTracked {
                    Text(localization.L(L10n.Mods.translationLinkHostTracked))
                        .font(AppDesign.Font.iconXS)
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 6) {
                    Button(localization.L(L10n.Mods.translationLinkAttach)) {
                        vm.confirmTranslationLink(retargeted())
                    }
                    .buttonStyle(.bordered).focusRing(cornerRadius: 5)
                    .controlSize(.small)
                    .pointingHandCursor()
                    Button(localization.L(L10n.Mods.translationLinkDismiss)) {
                        vm.dismissTranslationLink(proposal)
                    }
                    .buttonStyle(.borderless).focusRing(cornerRadius: 4)
                    .controlSize(.small)
                    .pointingHandCursor()
                }
            }
        }
        .padding(8)
        .background(Color.accentColor.opacity(0.08))
        .cornerRadius(AppDesignCore.Radius.sm)
    }

    /// La proposition retargetée vers l'hôte choisi — même dossier de pack,
    /// même preuve ; seul le destinataire suit le menu.
    private func retargeted() -> TranslationLinkProposal {
        TranslationLinkProposal(
            packFolderName: proposal.packFolderName,
            packName: proposal.packName,
            packVersion: proposal.packVersion,
            nexusId: proposal.nexusId,
            hostFolderName: currentHost,
            coverage: proposal.coverage,
            evidence: proposal.evidence,
            alternates: proposal.alternates)
    }
}
