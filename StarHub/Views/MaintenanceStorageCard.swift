import SwiftUI

/// Native grouped `Form` sections for Maintenance storage overview and space-freeing controls.
struct MaintenanceStorageCard: View {
    let report: MaintenanceInventory.Report
    @ObservedObject var localization: LocalizationStore
    let onPurge: (_ keepPerMod: Int, _ doomed: Int, _ freedBytes: Int64) -> Void
    var onCleanStale: (() -> Void)? = nil
    var openBackups: (BackupsSegment) -> Void = { _ in }

    private static let installTint = AppDesign.Color.accent
    private static let configTint = AppDesign.Color.accent.opacity(0.4)

    @State private var keep = 1

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                HStack(alignment: .center, spacing: AppDesign.Spacing.md) {
                    IconTile(icon: "internaldrive", tint: AppDesign.Color.accent)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(localization.L(L10n.Maintenance.total))
                            .font(AppDesign.Font.caption(.semibold))
                            .foregroundStyle(.secondary)
                        Text(SharedFormatters.bytes(report.totalBytes))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    Spacer()
                }
                if report.backupBytes + report.configBackupBytes > 0 { bar }
            }
            .padding(.vertical, 2)

            breakdownRow(
                localization.L(L10n.Maintenance.installBackups),
                "\(report.backups.count) · \(SharedFormatters.bytes(report.backupBytes))",
                dot: Self.installTint,
                open: .install
            )

            breakdownRow(
                localization.L(L10n.Maintenance.configBackups),
                "\(report.configBackupCount) · \(SharedFormatters.bytes(report.configBackupBytes))",
                dot: Self.configTint,
                open: .config
            )

            if !report.orphanSessions.isEmpty {
                breakdownRow(localization.L(L10n.Maintenance.orphanSessions),
                             String(report.orphanSessions.count), dot: nil)
            }

            if !report.stalePreferenceKeys.isEmpty {
                breakdownRow(localization.L(L10n.Maintenance.staleKeys),
                             String(report.stalePreferenceKeys.count), dot: nil)
            }

            if (!report.orphanSessions.isEmpty || !report.stalePreferenceKeys.isEmpty),
               let onCleanStale {
                HStack {
                    Spacer()
                    Button(action: onCleanStale) {
                        Label(localization.L(L10n.Maintenance.actionClean), systemImage: "paintbrush")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }

        Section {
            let crans = [1, 3, 5].filter { report.freedBytes(keepPerMod: $0) > 0 }
            if let chosen = crans.contains(keep) ? keep : crans.first {
                HStack(spacing: AppDesign.Spacing.md) {
                    Picker(localization.L(L10n.Maintenance.keepPicker),
                           selection: Binding(get: { chosen }, set: { keep = $0 })) {
                        ForEach(crans, id: \.self) { cran in
                            Text(String(format: localization.L(L10n.Maintenance.keepPerMod),
                                        cran, SharedFormatters.bytes(report.freedBytes(keepPerMod: cran))))
                                .tag(cran)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()

                    Spacer()

                    Button(String(format: localization.L(L10n.Maintenance.trashChosen),
                                  SharedFormatters.bytes(report.freedBytes(keepPerMod: chosen)))) {
                        let plan = MaintenanceInventory.plan(keepPerMod: chosen, entries: report.backups,
                                                             protections: report.protections)
                        onPurge(chosen, plan.doomed.count, plan.freedBytes)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Label(localization.L(L10n.Maintenance.nothingToFree), systemImage: "checkmark.circle")
                    .font(AppDesign.Font.body)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(localization.L(L10n.Maintenance.freeSpaceTitle))
        } footer: {
            Text(localization.L(L10n.Maintenance.trashHint))
        }
    }

    private var bar: some View {
        let total = max(report.backupBytes + report.configBackupBytes, 1)
        return GeometryReader { proxy in
            HStack(spacing: report.backupBytes > 0 && report.configBackupBytes > 0 ? 2 : 0) {
                Self.installTint
                    .frame(width: proxy.size.width * CGFloat(report.backupBytes) / CGFloat(total))
                Self.configTint
            }
            .clipShape(Capsule())
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func breakdownRow(_ label: String, _ value: String, dot: Color?,
                              open segment: BackupsSegment? = nil) -> some View {
        let line = HStack(spacing: AppDesign.Spacing.sm) {
            Circle()
                .fill(dot ?? .clear)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(label)
                .font(AppDesign.Font.body)
            Spacer()
            Text(value)
                .font(AppDesign.Font.body)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if segment != nil {
                Image(systemName: "chevron.right")
                    .font(AppDesign.Font.iconXS)
                    .foregroundStyle(.tertiary)
            }
        }
        if let segment {
            Button { openBackups(segment) } label: { line.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .pointingHandCursor()
        } else {
            line
        }
    }
}
