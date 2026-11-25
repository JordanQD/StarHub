import SwiftUI

/// Pressable segment button style matching `NexusUpdateActions`.
private struct LaunchPillSegmentStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.black.opacity(0.08) : Color.clear)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// macOS 27 Apple Games–inspired Home screen: crisp upper backdrop with
/// progressive blur below the Stardew Valley logo, centered game hero with
/// mode-aware icon & split launch capsule, 4 quick-status tiles, and an
/// official Steam-icon achievement wall read from local save XMLs.
struct HomeView: View {
    var viewModel: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    @ObservedObject var smapiInstaller: SmapiInstaller
    @ObservedObject private var bisection: BisectionRunner
    @ObservedObject private var keybindScanService: KeybindScanService
    @Binding var currentTab: SidebarDestination

    @AppStorage("launchProfile") private var launchProfile: String = "SMAPI"

    @State private var achievementSnapshot: SaveAchievementScanner.Snapshot = .empty

    /// Bundled assets loaded once per process.
    private static let backdropImage: NSImage? = {
        if let url = Bundle.main.url(forResource: "home_backdrop", withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        if let url = Bundle.main.url(forResource: "nexus_cover_final", withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        return nil
    }()

    private static let smapiIconImage: NSImage? = {
        guard let url = Bundle.main.url(forResource: "launch_icon_smapi", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }()

    private static let vanillaIconImage: NSImage? = {
        guard let url = Bundle.main.url(forResource: "launch_icon_vanilla", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }()

    private static let backdropHeight: CGFloat = 420
    private static let backdropUpwardOffset: CGFloat = -34

    init(viewModel: StarHubTHViewModel, localization: LocalizationStore, currentTab: Binding<SidebarDestination>) {
        self.localization = localization
        self.viewModel = viewModel
        self.smapiInstaller = viewModel.smapiInstaller
        self.bisection = viewModel.bisection
        self.keybindScanService = viewModel.keybindScanService
        self._currentTab = currentTab
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppDesign.Color.windowBg
                .ignoresSafeArea()

            backdropLayer

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    heroSection
                        .padding(.top, 224)

                    InterruptedOperationsNotice(viewModel: viewModel, localization: localization, bisection: bisection)
                    HomeProbeUpdateNotice(viewModel: viewModel, localization: localization)

                    attentionStrip

                    HomeAchievementsSection(
                        unlockedIDs: achievementSnapshot.unlockedIDs,
                        localization: localization
                    )

                    Spacer(minLength: 28)
                }
                .padding(.horizontal, 36)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await loadAchievements()
        }
        .onAppear {
            Task { await loadAchievements() }
            guard !viewModel.gameDir.isEmpty,
                  FolderRescanPolicy.needsRescan(last: viewModel.scanStore.folderStamps,
                                                 now: .read(gameDir: viewModel.gameDir)) else { return }
            viewModel.refresh()
        }
    }

    // MARK: - Progressive Blur Backdrop

    private var backdropLayer: some View {
        GeometryReader { proxy in
            if let image = Self.backdropImage {
                ZStack {
                    // Upper crisp layer: keeps the Stardew Valley logo & upper scenery completely sharp
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: Self.backdropHeight, alignment: .top)
                        .offset(y: Self.backdropUpwardOffset)
                        .clipped()
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0.0),
                                    .init(color: .black, location: 0.62),
                                    .init(color: .black.opacity(0.35), location: 0.82),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Lower progressive blur layer: lighter blur starting well below the logo
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: Self.backdropHeight, alignment: .top)
                        .offset(y: Self.backdropUpwardOffset)
                        .clipped()
                        .blur(radius: 9, opaque: true)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: .clear, location: 0.58),
                                    .init(color: .black, location: 0.74),
                                    .init(color: .black.opacity(0.70), location: 0.88),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Dark lower readability veil behind white Hero text, fading smoothly to windowBg
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .clear, location: 0.54),
                            .init(color: Color.black.opacity(0.36), location: 0.74),
                            .init(color: Color.black.opacity(0.24), location: 0.86),
                            .init(color: AppDesign.Color.windowBg, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(width: proxy.size.width, height: Self.backdropHeight, alignment: .top)
            }
        }
        .frame(height: Self.backdropHeight)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }

    // MARK: - Apple Games Hero

    private var heroIconImage: NSImage {
        if launchProfile == "Vanilla" {
            return Self.vanillaIconImage ?? NSApplication.shared.applicationIconImage
        }
        return Self.smapiIconImage ?? NSApplication.shared.applicationIconImage
    }

    private var heroSection: some View {
        HStack(alignment: .center, spacing: 22) {
            Spacer(minLength: 0)

            Image(nsImage: heroIconImage)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 96, height: 96)
                .shadow(color: Color.black.opacity(0.35), radius: 12, y: 6)
                .animation(.easeInOut(duration: 0.18), value: launchProfile)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Stardew Valley")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: Color.black.opacity(0.40), radius: 5, y: 1)
                        .lineLimit(1)

                    if let lastPlayedText {
                        Text(lastPlayedText)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.84))
                            .shadow(color: Color.black.opacity(0.35), radius: 4, y: 1)
                            .lineLimit(1)
                    }
                }

                heroPrimaryAction
            }
            .frame(minWidth: 220, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var lastPlayedText: String? {
        guard let lastPlayed = achievementSnapshot.lastPlayed else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: localization.currentLanguage)
        let relative = formatter.localizedString(for: lastPlayed, relativeTo: Date())
        return String(format: localization.L(L10n.Home.lastPlayed), relative)
    }

    private var launchButtonTitle: String {
        if launchProfile == "Vanilla" {
            return localization.L(L10n.Home.launchVanilla)
        }
        if viewModel.modProfiles.count > 1, let active = viewModel.activeProfile {
            return String(format: localization.L(L10n.Home.launchSmapiProfile), active.name)
        }
        return localization.L(L10n.Home.launchSmapi)
    }

    @ViewBuilder
    private var heroPrimaryAction: some View {
        switch HomeLaunchState.resolve(gameDirIsEmpty: viewModel.gameDir.isEmpty,
                                       smapiInstalled: viewModel.smapiInstalledVersion != nil,
                                       profileIsVanilla: launchProfile == "Vanilla") {
        case .ready:
            splitLaunchCapsule

        case .needsGameFolder:
            Button {
                viewModel.selectGameDir()
            } label: {
                Label(localization.L(L10n.Home.selectFolder), systemImage: "folder.badge.questionmark")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(minWidth: 196, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Capsule())
            .controlSize(.large)

        case .needsSmapi:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 0) {
                    Button {
                        viewModel.installSmapi()
                    } label: {
                        Label(localization.L(L10n.Home.installSmapi), systemImage: "shippingbox")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.leading, 18)
                            .padding(.trailing, 14)
                            .frame(height: 36)
                            .contentShape(.rect)
                    }
                    .buttonStyle(LaunchPillSegmentStyle())
                    .disabled(smapiInstaller.isInstalling)

                    Rectangle()
                        .fill(UpdatePillStyle.divider)
                        .frame(width: 1, height: 18)

                    launchModeMenu
                }
                .background(UpdatePillStyle.background, in: Capsule())
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.22), radius: 8, y: 3)

                if smapiInstaller.isInstalling {
                    ProgressView(value: smapiInstaller.progress, total: 1.0)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 220)
                    Text(localization.L(smapiInstaller.statusMessage))
                        .font(AppDesign.Font.footnote)
                        .foregroundStyle(Color.white.opacity(0.85))
                }
            }
        }
    }

    /// App Store / Updates–style split capsule pill (crisp in both Light & Dark modes).
    private var splitLaunchCapsule: some View {
        HStack(spacing: 0) {
            Button {
                viewModel.launchGame()
            } label: {
                Text(launchButtonTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.leading, 22)
                    .padding(.trailing, 16)
                    .frame(minWidth: 154)
                    .frame(height: 36)
                    .contentShape(.rect)
            }
            .buttonStyle(LaunchPillSegmentStyle())
            .pointingHandCursor()
            .focusRing(cornerRadius: FocusRing.capsule, inset: true)

            Rectangle()
                .fill(UpdatePillStyle.divider)
                .frame(width: 1, height: 18)

            launchModeMenu
        }
        .background(UpdatePillStyle.background, in: Capsule())
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.22), radius: 8, y: 3)
        .fixedSize()
    }

    private var launchModeMenu: some View {
        Menu {
            if viewModel.modProfiles.count > 1 {
                Section(localization.L(L10n.Home.launchSmapi)) {
                    ForEach(viewModel.modProfiles) { profile in
                        let isSelected = launchProfile != "Vanilla" && viewModel.activeProfileId == profile.id
                        Button {
                            launchProfile = "SMAPI"
                            if viewModel.activeProfileId != profile.id {
                                viewModel.applyProfile(id: profile.id)
                            }
                        } label: {
                            if isSelected {
                                Label(profile.name, systemImage: "checkmark")
                            } else {
                                Text(profile.name)
                            }
                        }
                    }
                }
                Divider()
            } else {
                Button {
                    launchProfile = "SMAPI"
                } label: {
                    if launchProfile != "Vanilla" {
                        Label(localization.L(L10n.Home.launchSmapi), systemImage: "checkmark")
                    } else {
                        Text(localization.L(L10n.Home.launchSmapi))
                    }
                }
            }

            Button {
                launchProfile = "Vanilla"
            } label: {
                if launchProfile == "Vanilla" {
                    Label(localization.L(L10n.Home.launchVanilla), systemImage: "checkmark")
                } else {
                    Text(localization.L(L10n.Home.launchVanilla))
                }
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .bold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .contentShape(.rect)
        }
        .menuStyle(.button)
        .buttonStyle(LaunchPillSegmentStyle())
        .menuIndicator(.hidden)
        .fixedSize()
        .focusRing(cornerRadius: FocusRing.capsule, inset: true)
        .help(localization.L(L10n.Settings.defaultLaunchMode))
    }

    // MARK: - 4 Quick-Status Tiles

    private var attentionStrip: some View {
        let counters = HomeAttention.counters(
            updates: viewModel.pendingUpdateCounts.active,
            alerts: viewModel.systemAlertCount,
            quarantined: viewModel.maintenanceStore.quarantineItemCount,
            mods: viewModel.scanStore.mods.count
        )
        return HStack(spacing: AppDesign.Spacing.md) {
            ForEach(counters) { counter in
                AttentionCounterTile(
                    glyph: glyph(for: counter.kind),
                    value: counter.count,
                    label: label(for: counter.kind),
                    tint: counter.level == .attention ? tint(for: counter.kind) : nil,
                    tab: counter.tab,
                    currentTab: $currentTab,
                    onOpen: counter.kind == .alerts ? { viewModel.navigationStore.alertsSegment = .alerts } : nil
                )
            }
        }
    }

    private func glyph(for kind: HomeAttention.Kind) -> String {
        switch kind {
        case .updates: return "arrow.triangle.2.circlepath"
        case .alerts: return "exclamationmark.triangle.fill"
        case .quarantine: return "tray.full.fill"
        case .library: return "puzzlepiece.extension.fill"
        }
    }

    private func tint(for kind: HomeAttention.Kind) -> Color {
        switch kind {
        case .updates: return AppDesign.Color.info
        case .alerts: return AppDesign.Color.warning
        case .quarantine: return AppDesign.Color.quarantine
        case .library: return .secondary
        }
    }

    private func label(for kind: HomeAttention.Kind) -> String {
        switch kind {
        case .updates: return localization.L(L10n.Main.modUpdates)
        case .alerts: return localization.L(L10n.Main.systemAlerts)
        case .quarantine: return localization.L(L10n.Main.quarantine)
        case .library: return localization.L(L10n.Mods.mods)
        }
    }

    // MARK: - Local Save Achievement Scan

    private func loadAchievements() async {
        let savesDir = FolderStamps.savesDirectory
        let snapshot = await Task.detached(priority: .utility) {
            SaveAchievementScanner.scan(in: savesDir)
        }.value
        achievementSnapshot = snapshot
    }
}

// MARK: - Attention Counter Tile

private struct AttentionCounterTile: View {
    let glyph: String
    let value: Int
    let label: String
    let tint: Color?
    let tab: SidebarDestination
    @Binding var currentTab: SidebarDestination
    var onOpen: (() -> Void)? = nil

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            onOpen?()
            currentTab = tab
        } label: {
            VStack(spacing: AppDesign.Spacing.xs) {
                Image(systemName: glyph)
                    .font(.system(size: AppDesign.Icon.md))
                    .foregroundStyle(tint ?? Color.secondary)
                Text("\(value)")
                    .font(AppDesign.Font.viewTitle)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(label)
                    .font(AppDesign.Font.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.primary.opacity(isHovered ? 0.05 : 0.0))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.09), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .onHover { isHovered = $0 }
        .focusRing(cornerRadius: 14)
        .accessibilityLabel(label)
        .accessibilityValue("\(value)")
    }
}

// MARK: - Core Mod Status

/// Row for a non-mod tool status (e.g. unar), used by SettingsView.
struct CoreToolRow: View {
    let title: String
    let status: CoreModStatus
    let tooltip: String
    let installCommand: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppDesign.Font.body)
                Group {
                    switch status {
                    case .enabledAndInstalled:
                        Text("")
                    case .installedButDisabled:
                        Text("")
                    case .notInstalled:
                        Text(installCommand)
                            .font(AppDesign.Font.iconXS)
                            .foregroundColor(.secondary)
                    }
                }
                .font(AppDesign.Font.footnote)
            }
            Spacer()
            switch status {
            case .enabledAndInstalled:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppDesign.Color.success)
            case .installedButDisabled:
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(AppDesign.Color.warning)
            case .notInstalled:
                Image(systemName: AppDesign.Status.error.symbol)
                    .foregroundColor(AppDesign.Color.error.opacity(0.6))
            }
        }
        .padding(.vertical, AppDesign.Spacing.xs)
        .padding(.horizontal, AppDesign.Spacing.sm)
        .help(tooltip)
    }
}
