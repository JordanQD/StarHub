import SwiftUI

/// App Store–style capsule pill colors (light crisp pill + system accent text
/// in both Light and Dark appearances).
enum UpdatePillStyle {
    static let background = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [
            .accessibilityHighContrastDarkAqua, .darkAqua,
            .accessibilityHighContrastAqua, .aqua
        ]).map { $0 == .darkAqua || $0 == .accessibilityHighContrastDarkAqua } ?? false
        if isDark {
            return NSColor(srgbRed: 0.95, green: 0.95, blue: 0.97, alpha: 1)
        }
        return NSColor(srgbRed: 0.92, green: 0.93, blue: 0.95, alpha: 1)
    })

    static let divider = Color.accentColor.opacity(0.24)
    static let height: CGFloat = 28
}

/// Pressable segment button inside the App Store capsule pill.
private struct UpdatePillSegmentStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.black.opacity(0.08) : Color.clear)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct NexusUpdateActions: View {
    let update: NexusUpdateChecker.ModUpdate
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    var isLogOnly = false

    var body: some View {
        let website = update.updateWebsite
        let nexusID = update.updatePageID
        if let nexusID, vm.downloadingNexusModId == nexusID {
            downloadProgress
        } else {
            let isUpdateDisabled = nexusID != nil && vm.hasConfirmedNexusPremium && vm.isDownloadingFromNexus
            HStack(spacing: 0) {
                if let website {
                    Button {
                        if vm.hasConfirmedNexusPremium, let nexusID {
                            vm.downloadModFromNexus(nexusId: nexusID)
                        } else if nexusID != nil {
                            NexusWebLinks.openUpdateFiles(for: website.absoluteString)
                        } else {
                            NSWorkspace.shared.open(website)
                        }
                    } label: {
                        Text(localization.L(L10n.Updates.installUpdate))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isUpdateDisabled ? Color.accentColor.opacity(0.45) : Color.accentColor)
                            .padding(.leading, 14)
                            .padding(.trailing, 10)
                            .frame(height: UpdatePillStyle.height)
                            .contentShape(.rect)
                    }
                    .buttonStyle(UpdatePillSegmentStyle())
                    .focusRing(cornerRadius: FocusRing.capsule, inset: true)
                    .help(localization.L(actionHelp(nexusID: nexusID)))
                    .disabled(isUpdateDisabled)

                    Rectangle()
                        .fill(UpdatePillStyle.divider)
                        .frame(width: 1, height: 14)
                }

                Menu {
                    if vm.hasConfirmedNexusPremium, nexusID != nil, let website {
                        Button(localization.L(L10n.Mods.nexusUpdate)) {
                            NexusWebLinks.openUpdateFiles(for: website.absoluteString)
                        }
                    }
                    Menu(localization.L(L10n.Updates.snoozeButton)) {
                        snoozeButton(L10n.Updates.snoozeOneWeek, mode: .oneWeek)
                        if !isLogOnly {
                            snoozeButton(L10n.Updates.snoozeUntilModVersion, mode: .untilModVersion)
                            snoozeButton(L10n.Updates.snoozeUntilGameVersion, mode: .untilGameVersion)
                        }
                    }
                    if !isLogOnly {
                        Button(localization.L(L10n.Updates.nexusAlreadyHave)) {
                            vm.affirmInstalled(uniqueId: update.uniqueId, version: update.latestVersion)
                        }
                        .help(localization.L(L10n.Updates.nexusAlreadyHaveHelp))
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: website == nil ? 32 : 28, height: UpdatePillStyle.height)
                        .contentShape(.rect)
                }
                .menuStyle(.button)
                .buttonStyle(UpdatePillSegmentStyle())
                .menuIndicator(.hidden)
                .fixedSize()
                .focusRing(cornerRadius: FocusRing.capsule, inset: true)
                .iconHelp(localization.L(L10n.Updates.updateOptions))
            }
            .background(UpdatePillStyle.background, in: Capsule())
            .clipShape(Capsule())
            .fixedSize()
        }
    }

    private func actionHelp(nexusID: Int?) -> String {
        if nexusID == nil { return L10n.Updates.openSmapiPage }
        return vm.hasConfirmedNexusPremium ? L10n.Mods.premiumUpdate : L10n.Mods.nexusUpdate
    }

    private var downloadProgress: some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.small)
            if let percent = vm.nexusDownloadProgress?.displayPercent {
                Text("\(percent)%")
                    .font(AppDesign.Font.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Button(action: { vm.cancelNexusDownload() }) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain).focusRing()
            .iconHelp(localization.L(L10n.Downloads.cancel))
        }
    }

    private func snoozeButton(_ title: String, mode: ModUpdateSnoozeEntry.Mode) -> some View {
        Button(localization.L(title)) { vm.snoozeUpdate(update, mode: mode) }
    }
}
