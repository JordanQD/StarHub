import SwiftUI

struct SettingsAppInfoSection: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    @State private var showsChangelog = false

    var body: some View {
        StandardSection(title: localization.L(L10n.Home.appInfo), icon: ("info.circle.fill", .blue)) {
            VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                Text(String(format: localization.L(L10n.Settings.appVersion), currentAppVersion))
                    .font(AppDesign.Font.body(.semibold))
                StandardRow(title: LocalizedStringKey(localization.L(L10n.Home.developer)),
                            detail: "AppleBoiy (original) · mrbabilo (fork)", showDivider: false)
                Divider()
                releaseStatusRow
                Divider()
                Button {
                    showsChangelog = true
                } label: {
                    Label(localization.L(L10n.Main.appChangelog), systemImage: "doc.text")
                }
            }
        }
        .sheet(isPresented: $showsChangelog) {
            AppChangelogView(localization: localization)
        }
    }

    /// L'état de mise à jour + le bouton de vérification manuelle. Le
    /// check manuel bypass le throttle ; l'échec, lui, ne se dit qu'ICI —
    /// au lancement, une app hors-ligne ne doit pas brair (spec §7.5).
    @ViewBuilder private var releaseStatusRow: some View {
        HStack(spacing: 8) {
            if vm.releaseCheckInFlight {
                Text(localization.L(L10n.Settings.appChecking))
                    .font(AppDesign.Font.footnote)
                    .foregroundColor(.secondary)
            } else if let known = vm.lastKnownRelease,
                      NexusUpdateChecker.compare(known.tagName, currentAppVersion) == .orderedDescending {
                Text(String(format: localization.L(L10n.Settings.appUpdateAvailableState), known.tagName))
                    .font(AppDesign.Font.footnote)
                    .foregroundColor(.orange)
            } else {
                Text(localization.L(L10n.Settings.appUpToDate))
                    .font(AppDesign.Font.footnote)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(localization.L(L10n.Settings.appCheckUpdates)) {
                vm.checkForAppRelease(bypassThrottle: true)
            }
            .disabled(vm.releaseCheckInFlight)
            .font(AppDesign.Font.footnote)
        }
        if let failure = vm.releaseCheckFailedMessage {
            Text(failure)
                .font(AppDesign.Font.footnote)
                .foregroundColor(.red)
        }
    }

    private var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

}

struct SettingsSupportSection: View {
    @ObservedObject var localization: LocalizationStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openURL) private var openURL
    @State private var showsShortcuts = false

    var body: some View {
        StandardSection(title: localization.L(L10n.Settings.support), icon: ("questionmark.circle", .teal)) {
            VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                Button {
                    showsShortcuts = true
                } label: {
                    Label(localization.L(L10n.Shortcuts.title), systemImage: "keyboard")
                }
                Divider()
                Button {
                    UserDefaults.standard.set(false, forKey: UDKey.onboardingCompleted)
                    openWindow(id: AppWindowID.main)
                } label: {
                    Label(localization.L(L10n.Onboarding.settingsCard), systemImage: "book")
                }
                Divider()
                Button {
                    openURL(BugReportLink.current)
                } label: {
                    Label(localization.L(L10n.Help.reportBug), systemImage: "arrow.up.right")
                }
            }
            .buttonStyle(.link)
        }
        .sheet(isPresented: $showsShortcuts) {
            ShortcutsHelpView(localization: localization)
        }
    }
}
