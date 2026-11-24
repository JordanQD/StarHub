import SwiftUI

extension UpdatesView {
    var emptyState: some View {
        let verdict = vm.updateCheckVerdict(pending: 0)
        let (symbol, color, key): (String, Color, String) = switch verdict {
        case .upToDate, .pending:
            ("checkmark.circle.fill", AppDesign.Color.success, L10n.Updates.allUpToDate)
        case .verifiableUpToDate:
            (AppDesign.Status.ok.symbol, .secondary, L10n.Updates.allVerifiedUpToDate)
        case .neverChecked:
            ("questionmark.circle", .secondary, L10n.Updates.neverChecked)
        }
        return VStack(spacing: AppDesign.Spacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(localization.L(key))
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .padding(AppDesign.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct UpdateSectionDisclosure<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: AppDesign.Spacing.sm) {
                    Text(title)
                        .font(.headline)
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, AppDesign.Spacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusRing(cornerRadius: 4)
            .clickableCursor()

            if isExpanded {
                content()
            }
        }
    }
}

struct UpdateCheckButton: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    @State private var hovered = false

    var body: some View {
        let checking = vm.isCheckingNexusUpdates
        let stopping = checking && vm.updateStopRequested
        let title = localization.L(stopping ? L10n.Updates.checkStopping
                                   : checking ? L10n.Updates.checkStop : L10n.Updates.nexusCheckButton)
        Button {
            if checking {
                vm.stopUpdateCheck()
            } else {
                vm.checkNexusUpdates()
            }
        } label: {
            Group {
                if checking && (!hovered || stopping) {
                    ProgressView()
                        .controlSize(.mini)
                        .allowsHitTesting(false)
                } else {
                    Image(systemName: checking ? "stop.fill" : "arrow.clockwise")
                }
            }
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
        }
        .onHover { hovered = $0 }
        .disabled(stopping)
        .iconHelp(title)
    }
}
