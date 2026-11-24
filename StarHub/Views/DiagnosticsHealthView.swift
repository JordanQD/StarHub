import SwiftUI

/// « 运行状况 » tab inside `DiagnosticsView`.
/// Uses Apple's official `Form().formStyle(.grouped)` so every section and box
/// matches macOS System Settings natively across macOS 14–27.
struct DiagnosticsHealthView: View {
    var viewModel: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    @State private var scrollRequest: ScrollRequest?

    private struct ScrollRequest: Equatable {
        let anchor: String
        let id = UUID()
    }

    private static let bisectionAnchor = "bisection"

    private var diagnostics: SmapiDiagnostics? {
        guard let diag = viewModel.smapiDiagnostics, !diag.isEmpty else { return nil }
        return diag
    }

    private var advisoryCount: Int {
        guard let d = diagnostics else { return 0 }
        return d.saveSerializerMods.count + d.patchedMods.count + d.consoleMods.count
    }

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                if let diag = diagnostics {
                    statusSection(diag)
                    SmapiHealthCard(vm: viewModel, localization: localization,
                                    showBlock: requestScroll,
                                    showBisection: { requestScroll(Self.bisectionAnchor) })
                } else {
                    if viewModel.systemAlertCount > 0 {
                        Section {
                            alertsRow
                        }
                    }
                    Section {
                        ContentUnavailableView {
                            Label(localization.L(L10n.Logs.segmentHealth), systemImage: "stethoscope")
                        } description: {
                            Text(localization.L(L10n.Logs.healthEmpty))
                        } actions: {
                            Button {
                                viewModel.refreshSmapiLog()
                            } label: {
                                Label(localization.L(L10n.Updates.recheckLog), systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, AppDesign.Spacing.md)
                        .frame(maxWidth: .infinity)
                    }
                }

                BisectionCard(vm: viewModel, localization: localization)
                    .id(Self.bisectionAnchor)
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(AppDesign.Color.windowBg)
            .task(id: scrollRequest?.id) {
                guard let request = scrollRequest else { return }
                await Task.yield()
                withAnimation { proxy.scrollTo(request.anchor, anchor: .top) }
            }
        }
    }

    private func requestScroll(_ anchor: String) {
        scrollRequest = ScrollRequest(anchor: anchor)
    }

    // MARK: - Top Status Section

    @ViewBuilder
    private func statusSection(_ diag: SmapiDiagnostics) -> some View {
        let isHealthy = diag.problemCount == 0
        let alertCount = viewModel.systemAlertCount
        let lastMeasure = viewModel.modImpactStore.lastInGame

        Section {
            HStack(alignment: .center, spacing: AppDesign.Spacing.md) {
                Image(systemName: isHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(isHealthy ? AppDesign.Color.success : AppDesign.Color.warning)
                    .frame(width: 32, alignment: .center)

                VStack(alignment: .leading, spacing: 3) {
                    Text(isHealthy ? localization.L(L10n.Logs.healthHealthy) : localization.L(L10n.Logs.healthTitle))
                        .font(AppDesign.Font.headline(.semibold))
                    let summaryLine = versionLine(for: diag)
                    if !summaryLine.isEmpty {
                        Text(summaryLine)
                            .font(AppDesign.Font.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: AppDesign.Spacing.sm)

                if viewModel.smapiLogStale {
                    staleBadge
                }
            }
            .padding(.vertical, 2)

            if alertCount > 0 {
                alertsRow
            }

            if let lastMeasure {
                HStack(alignment: .center, spacing: AppDesign.Spacing.md) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 20))
                        .foregroundStyle(AppDesign.Color.info)
                        .frame(width: 32, alignment: .center)

                    Text(String(format: localization.L(L10n.Performance.healthLastMeasure),
                                lastMeasure.formatted(date: .abbreviated, time: .shortened)))
                        .font(AppDesign.Font.footnote)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: AppDesign.Spacing.sm)

                    Button(localization.L(L10n.Performance.healthOpen)) {
                        viewModel.navigationStore.openPerformance()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var alertsRow: some View {
        HStack(alignment: .center, spacing: AppDesign.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundStyle(AppDesign.Color.warning)
                .frame(width: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(localization.plural(L10n.Health.openAlerts, viewModel.systemAlertCount))
                    .font(AppDesign.Font.body(.semibold))
                if advisoryCount > 0 {
                    Text("\(advisoryCount) \(localization.L(L10n.Logs.healthCountAdvisory))")
                        .font(AppDesign.Font.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: AppDesign.Spacing.sm)

            Button(localization.L(L10n.Health.openAlertsAction)) {
                viewModel.navigationStore.alertsSegment = .alerts
                viewModel.navigationStore.requestTab(.systemAlerts)
            }
            .buttonStyle(.bordered)
        }
    }

    private var staleBadge: some View {
        HStack(spacing: AppDesignCore.Spacing.xs) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(AppDesign.Font.iconXS)
            Text(localization.L(L10n.Logs.healthStale))
                .font(AppDesign.Font.iconXS(.medium))
            if let age = SmapiLogSource(logDate: viewModel.smapiLogDate, isStale: true,
                                        locale: Locale.autoupdatingCurrent)?.staleAge {
                Text(age).font(AppDesign.Font.iconXS)
            }
        }
        .padding(.horizontal, AppDesignCore.Spacing.sm)
        .padding(.vertical, 3)
        .background(AppDesign.Color.warning.opacity(AppDesignCore.Opacity.medium),
                    in: RoundedRectangle(cornerRadius: AppDesignCore.Radius.sm))
        .foregroundStyle(AppDesign.Color.warning)
    }

    private func versionLine(for d: SmapiDiagnostics) -> String {
        var parts: [String] = []
        if let v = d.smapiVersion { parts.append("SMAPI \(v)") }
        if let g = d.gameVersion { parts.append("Stardew Valley \(g)") }
        if let m = d.modsLoaded { parts.append(String(format: localization.L(L10n.Logs.healthModsCount), Int64(m))) }
        if let c = d.contentPacksLoaded { parts.append(String(format: localization.L(L10n.Logs.healthPacksCount), Int64(c))) }
        return parts.joined(separator: "  ·  ")
    }
}
