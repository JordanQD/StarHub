import SwiftUI

extension SystemAlertsView {
    var emptyState: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            Spacer()
            AllClearGlyph()
            Text(localization.L(L10n.Updates.noAlerts))
                .font(AppDesign.Font.headline(.semibold))
            Text(localization.L(L10n.Health.allClearHint))
                .font(AppDesign.Font.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Spacer()
        }
        .padding(AppDesign.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func filteredEmptyState(onReset: @escaping () -> Void) -> some View {
        ContentUnavailableView {
            Label(localization.L(L10n.Discovery.noMatch), systemImage: "line.3.horizontal.decrease.circle")
        } description: {
            Text(localization.L(L10n.Health.tileFilterHint))
        } actions: {
            Button(localization.L(L10n.Mods.clearFilters), action: onReset)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    var recheckLogButton: some View {
        Button(action: { viewModel.refreshSmapiLog() }) {
            if viewModel.isRefreshingSmapiLog {
                ProgressView().controlSize(.small)
            } else {
                Label(localization.L(L10n.Updates.recheckLog), systemImage: "arrow.clockwise")
            }
        }
        .disabled(viewModel.isRefreshingSmapiLog)
        .help(localization.L(L10n.Updates.recheckLog))
    }
}
