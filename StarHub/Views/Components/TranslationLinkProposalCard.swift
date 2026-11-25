import SwiftUI

/// C7-T1 translation pack → host link proposal row, styled natively for
/// `Form().formStyle(.grouped)` as well as standalone detail cards.
struct TranslationLinkProposalCard: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    let proposal: TranslationLinkProposal

    @State private var alternateHost: String = ""

    private var currentHost: String {
        alternateHost.isEmpty ? proposal.hostFolderName : alternateHost
    }
    private var coveragePercent: Int { Int((proposal.coverage * 100).rounded()) }
    private var hostTracked: Bool {
        vm.installedTranslations.declaredLinkHosts().contains(currentHost)
    }

    var body: some View {
        HStack(alignment: .center, spacing: AppDesign.Spacing.md) {
            Image(systemName: "link")
                .foregroundStyle(.tint)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 20, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: AppDesign.Spacing.xs) {
                    Text(proposal.packName)
                        .font(AppDesign.Font.body(.medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("→")
                        .font(AppDesign.Font.footnote)
                        .foregroundStyle(.secondary)
                    if proposal.alternates.isEmpty {
                        Text(currentHost)
                            .font(AppDesign.Font.body(.medium))
                            .lineLimit(1)
                            .truncationMode(.tail)
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
                        .labelsHidden()
                        .controlSize(.small)
                        .fixedSize()
                    }
                }

                HStack(spacing: AppDesign.Spacing.sm) {
                    Text(String(format: localization.L(L10n.Mods.translationLinkCoverage), coveragePercent))
                        .font(AppDesign.Font.footnote)
                        .foregroundStyle(.secondary)
                    if proposal.nexusId == nil {
                        Text(localization.L(L10n.Mods.translationLinkNoTracking))
                            .font(AppDesign.Font.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if hostTracked {
                    Text(localization.L(L10n.Mods.translationLinkHostTracked))
                        .font(AppDesign.Font.footnote)
                        .foregroundStyle(AppDesign.Color.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: AppDesign.Spacing.sm)

            HStack(spacing: AppDesign.Spacing.xs) {
                Button(localization.L(L10n.Mods.translationLinkAttach)) {
                    vm.confirmTranslationLink(retargeted())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(localization.L(L10n.Mods.translationLinkDismiss)) {
                    vm.dismissTranslationLink(proposal)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .fixedSize()
        }
        .padding(.vertical, 2)
    }

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
