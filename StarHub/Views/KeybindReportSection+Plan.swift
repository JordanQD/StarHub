import SwiftUI

/// Toolbar actions for the Keybinds segment inside `SystemAlertsView`.
/// Observes `KeybindScanService` directly so disabled/loading states update live.
struct KeybindToolbarActions: View {
    var vm: StarHubTHViewModel
    @ObservedObject var service: KeybindScanService
    @ObservedObject var localization: LocalizationStore
    @Binding var showsPlan: Bool

    private var noGameDir: Bool { vm.gameDir.isEmpty }

    var body: some View {
        Button {
            showsPlan = true
        } label: {
            Label(localization.L(L10n.KeybindPlan.propose), systemImage: "wand.and.stars")
        }
        .disabled(service.report == nil || service.isScanning || noGameDir)
        .help(localization.L(L10n.KeybindPlan.proposeHint))

        Button {
            if let report = service.report {
                KeybindReportSection.exportReport(report, vm: vm)
            }
        } label: {
            Label(localization.L(L10n.Keybinds.export), systemImage: "square.and.arrow.up")
        }
        .disabled(service.report == nil)
        .help(localization.L(L10n.Keybinds.exportHint))

        Button {
            service.scan(mods: vm.scanStore.mods, gameDir: vm.gameDir)
        } label: {
            Label(localization.L(L10n.Keybinds.rescan), systemImage: "arrow.clockwise")
        }
        .disabled(service.isScanning || noGameDir)
        .help(localization.L(L10n.Keybinds.rescan))
    }
}

/// Bottom `.bar` status bar for the Keybinds segment.
struct KeybindStatusBar: View {
    @ObservedObject var service: KeybindScanService
    @ObservedObject var localization: LocalizationStore

    var body: some View {
        if service.isScanning {
            bar {
                ProgressView().controlSize(.mini)
                Text(localization.L(L10n.Keybinds.scanning))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if let report = service.report, report.scannedMods > 0 {
            bar {
                Text(String(format: localization.L(L10n.Keybinds.counters),
                            report.scannedMods, report.keybindCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private func bar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: AppDesign.Spacing.sm) {
                content()
                Spacer()
            }
            .padding(.horizontal, AppDesign.Spacing.xl)
            .padding(.vertical, AppDesign.Spacing.xs)
        }
        .background(.bar)
    }
}

extension KeybindReportSection {
    private var navigation: NavigationStore { vm.navigationStore }
    var planFocusPending: Bool { navigation.pendingKeybindPlanFocus }

    /// L'intention posée par `NavigationStore.openKeybindPlan` (bandeau de la
    /// page Profils) : ouvrir la feuille. Sans rapport, rien à proposer — la
    /// section montre déjà son propre état vide ; l'intention est rendue
    /// quand même, pour ne pas ouvrir la feuille à retardement.
    func consumePlanFocus() {
        guard planFocusPending else { return }
        navigation.pendingKeybindPlanFocus = false
        if service.report != nil { showsPlan = true }
    }
}
