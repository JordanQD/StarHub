import SwiftUI

/// D4-T4 §3a — en tête du Journal, ce que la carte Santé et la bissection
/// disaient au-dessus des lignes quand elles partageaient la page : l'état
/// SMAPI (et s'il est périmé), la recherche guidée (en cours, interrompue ou
/// terminée), et le chemin vers l'onglet Santé. La décision vit dans
/// `DiagnosticsStripStatus` (Core, testée).
struct DiagnosticsHealthStrip: View {
    var viewModel: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    var compact: Bool = false
    // Observé séparément, comme dans `HomeView` : `BisectionRunner` publie
    // son propre état.
    @ObservedObject private var bisection: BisectionRunner

    init(viewModel: StarHubTHViewModel, localization: LocalizationStore, compact: Bool = false) {
        self.viewModel = viewModel
        self.localization = localization
        self.compact = compact
        self.bisection = viewModel.bisection
    }

    private var health: (icon: String, color: Color, text: String) {
        let diag = viewModel.smapiDiagnostics
        switch DiagnosticsStripStatus.health(hasLog: !(diag?.isEmpty ?? true),
                                             problemCount: diag?.problemCount ?? 0) {
        case .noLog:
            return ("questionmark.circle", .secondary, localization.L(L10n.Logs.stripNoLog))
        case .healthy:
            return ("checkmark.circle.fill", AppDesign.Color.success, localization.L(L10n.Logs.stripHealthy))
        case .problems(let count):
            return ("exclamationmark.triangle.fill", AppDesign.Color.warning,
                    String(format: localization.L(L10n.Logs.stripProblems), count))
        }
    }

    private var search: (icon: String, text: String)? {
        switch DiagnosticsStripStatus.search(state: bisection.state,
                                             hasInterruptedSnapshot: bisection.interruptedSnapshot != nil,
                                             isApplying: bisection.isApplying) {
        case .none:
            return nil
        case .running:
            return ("magnifyingglass", localization.L(L10n.Logs.stripBisection))
        case .interrupted:
            return ("exclamationmark.arrow.circlepath", localization.L(L10n.Logs.stripBisectionInterrupted))
        case .resultReady:
            return ("checkmark.magnifyingglass", localization.L(L10n.Logs.stripBisectionResult))
        }
    }

    var body: some View {
        let health = health
        HStack(spacing: AppDesign.Spacing.sm) {
            HStack(spacing: AppDesign.Spacing.xs) {
                Image(systemName: health.icon).foregroundStyle(health.color)
                Text(health.text).font(compact ? .caption : AppDesign.Font.footnote(.medium))
                if viewModel.smapiLogStale {
                    Text(localization.L(L10n.Logs.healthStale))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let search {
                    Label(search.text, systemImage: search.icon)
                        .font(compact ? .caption : AppDesign.Font.footnote)
                }
            }
            .accessibilityElement(children: .combine)
            if !compact {
                Spacer(minLength: AppDesign.Spacing.sm)
            }
            Button(localization.L(L10n.Logs.stripOpenHealth)) {
                viewModel.navigationStore.diagnosticsSegment = .health
            }
            .buttonStyle(.link)
            .font(compact ? .caption : AppDesign.Font.footnote)
        }
        .lineLimit(1)
        .padding(.horizontal, compact ? 0 : 12)
        .padding(.vertical, compact ? 0 : 6)
    }
}
