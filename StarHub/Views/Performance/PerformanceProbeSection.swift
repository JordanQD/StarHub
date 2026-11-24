import SwiftUI

/// La carte « Sonde », en tête de l'onglet Performances : ses réglages
/// d'abord — où en est la sonde StarHubFR (absente, en pause, active et sa
/// version), son installation, sa place en tête du chargement — et, seulement
/// si Profiler est présent, pourquoi s'en passer : la sonde fait le même
/// travail, et les deux faussent mutuellement leurs mesures (D1 clos le
/// 2026-10-03). La détection vient de `ModPresence` (Core, testé).
struct PerformanceProbeSection: View {
    var viewModel: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    var store: ProbePerformanceStore
    /// « Sonde en tête » (`ModsToLoadEarly`), partagé avec la carte Chargements.
    @AppStorage(UDKey.probeLoadEarlyConsent) private var loadEarlyConsent: Bool?
    /// D4-T3 — l'installation ou la mise à jour en attente de confirmation.
    @State private var pending: ProbeBundle.Action?
    @State private var failure: String?
    /// Après une installation ou une mise à jour : la DLL n'est lue qu'au
    /// lancement du jeu (lot D, G8).
    @State private var installedNote: String?
    /// La bannière « sonde en premier » est déjà en tête de page
    /// (`PerformanceMeasurementStatus.hoistsLoadOrderBanner`) : ne pas la répéter.
    var loadOrderBannerHoisted = false
    /// Embedded inside a grouped `Form` disclosure row: omits the outer card and duplicate title.
    var embedded = false

    private var bundledFolder: URL? { ProbeBundle.bundledFolder(resourcesURL: Bundle.main.resourceURL) }
    private var action: ProbeBundle.Action {
        ProbeBundle.action(bundled: bundledFolder.flatMap(ProbeBundle.version(ofFolder:)), presence: probe)
    }

    private var probe: ModPresence { ModPresence.resolve(uniqueId: ModPresence.probeId, in: viewModel.mods) }
    private var profiler: ModPresence { ModPresence.resolve(uniqueId: ModPresence.profilerId, in: viewModel.mods) }

    var body: some View {
        Group {
            if embedded {
                VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                    probeBody
                }
                .padding(.top, AppDesign.Spacing.xs)
            } else {
                PerformanceCard {
                    Text(localization.L(L10n.Performance.probeTitle))
                        .font(AppDesign.Font.headline(.semibold))
                    probeBody
                }
            }
        }
        .confirmationDialog(localization.L(L10n.Performance.probeInstallConfirmTitle),
                            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                            presenting: pending) { action in
            Button(title(action) ?? "") { perform() }
        } message: { _ in
            Text(String(format: localization.L(L10n.Performance.probeInstallConfirm), ProbeBundle.folderName))
        }
    }

    @ViewBuilder
    private var probeBody: some View {
        HStack(alignment: .center, spacing: AppDesign.Spacing.sm) {
            switch probe {
            case .absent:
                Label(localization.L(L10n.Performance.probeAbsent),
                      systemImage: "gauge.with.dots.needle.bottom.0percent")
                    .font(AppDesign.Font.footnote)
                    .foregroundStyle(.secondary)
            case .paused(let folderName, _):
                Label(String(format: localization.L(L10n.Performance.probePaused), folderName),
                      systemImage: "pause.circle")
                    .font(AppDesign.Font.footnote)
                    .foregroundStyle(.secondary)
            case .enabled(_, let version):
                Label(String(format: localization.L(L10n.Performance.probeEnabled), version),
                      systemImage: AppDesign.Status.ok.symbol)
                    .font(AppDesign.Font.footnote)
                    .foregroundStyle(AppDesign.Color.success)
            }
            Spacer(minLength: AppDesign.Spacing.sm)
            if case .paused(let folderName, _) = probe {
                Button(localization.L(L10n.Performance.probeEnable)) {
                    if let mod = mod(named: folderName) { viewModel.toggleMod(mod) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            installButton
        }
        if let installedNote { note(installedNote) }
        if case .enabled = probe, !loadOrderBannerHoisted {
            PerformanceLoadsProbeFirst(viewModel: viewModel, localization: localization, store: store,
                                       consent: $loadEarlyConsent)
        }
        if let failure {
            Label(failure, systemImage: "exclamationmark.triangle.fill")
                .font(AppDesign.Font.footnote).foregroundStyle(AppDesign.Color.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
        if case .enabled(let folderName, _) = profiler {
            Label(String(format: localization.L(L10n.Performance.profilerActive), folderName),
                  systemImage: "exclamationmark.triangle.fill")
                .font(AppDesign.Font.footnote)
                .foregroundStyle(AppDesign.Color.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Installer ou mettre à jour : jamais sans confirmation (D4-T3).
    @ViewBuilder private var installButton: some View {
        if let title = title(action) {
            Button(title) { failure = nil; pending = action }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        } else if action == .unavailable, probe == .absent {
            note(localization.L(L10n.Performance.probeUnavailable))
        }
    }

    private func title(_ action: ProbeBundle.Action) -> String? {
        switch action {
        case .install(let version):
            String(format: localization.L(L10n.Performance.probeInstall), version)
        case .update(let from, let to):
            String(format: localization.L(L10n.Performance.probeUpdate), from, to)
        case .unavailable, .upToDate, .newerInstalled:
            nil
        }
    }

    private func perform() {
        guard !viewModel.isGameRunning() else {
            failure = localization.L(L10n.Performance.gameRunning); return
        }
        let installing: String? = {
            switch action {
            case .install(let version): return version
            case .update(_, let to): return to
            case .unavailable, .upToDate, .newerInstalled: return nil
            }
        }()
        do {
            try ProbeBundle.installBundled(resourcesURL: Bundle.main.resourceURL,
                                           gameDir: viewModel.gameDir, mods: viewModel.mods)
            installedNote = installing.map { String(format: localization.L(L10n.Performance.probeUpdatedRelaunch), $0) }
            Task { await viewModel.rescanInBackground(includeRepair: false) } // X125
        } catch {
            failure = String(format: localization.L(L10n.Performance.probeInstallFailed),
                             error is ProbeBundle.InstallError ? ProbeBundle.folderName : error.localizedDescription)
        }
    }

    private func note(_ text: String) -> some View {
        PerformanceFormatting.note(text)
    }

    /// Le mod à basculer, relu au clic : `mods` change sous nos pieds
    /// (scan, activation ailleurs) et `folderName` est la clé stable.
    private func mod(named folderName: String) -> ModItem? {
        viewModel.mods.flattenedMods.first { $0.folderName == folderName }
    }
}
