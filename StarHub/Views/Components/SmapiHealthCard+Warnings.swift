import SwiftUI

extension SmapiHealthCard {

    var recurringWarningsRow: some View {
        let preview = diagnostics.recurringWarnings.prefix(3).map(\.mod).joined(separator: " · ")
        return groupedRow(key: "recurringWarnings",
                          icon: "exclamationmark.bubble.fill",
                          tint: AppDesign.Color.warning,
                          title: localization.L(L10n.Logs.healthWarnings),
                          count: diagnostics.recurringWarnings.count,
                          preview: preview,
                          defaultOpen: false) {
            Text(localization.L(L10n.Logs.healthExpWarnings))
                .font(AppDesign.Font.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                ForEach(diagnostics.recurringWarnings) { warning in
                    recurringWarningItem(warning)
                        .contextMenu { modContextMenu(warning.mod) }
                }
            }
        }
    }

    private func recurringWarningItem(_ warning: SmapiDiagnostics.RecurringWarning) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
            HStack(spacing: AppDesign.Spacing.sm) {
                Text(warning.mod)
                    .font(AppDesign.Font.body(.medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(warning.mod)
                Text(String(format: localization.L(L10n.Logs.healthWarningsCount), Int64(warning.count)))
                    .font(AppDesign.Font.iconXS(.medium))
                    .foregroundStyle(AppDesign.Color.warning)
                    .padding(.horizontal, AppDesignCore.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(AppDesign.Color.warning.opacity(AppDesignCore.Opacity.light),
                                in: RoundedRectangle(cornerRadius: 4))
                    .fixedSize()
                Spacer(minLength: AppDesign.Spacing.sm)
                modActions(warning.mod)
            }
            if warning.distinct < warning.count {
                Text(String(format: localization.L(L10n.Logs.healthWarningsDistinct), Int64(warning.distinct)))
                    .font(AppDesign.Font.footnote)
                    .foregroundStyle(.secondary)
            }
            Text(warning.sample)
                .font(AppDesign.Font.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.tail)
                .help(warning.sample)
        }
    }
}
