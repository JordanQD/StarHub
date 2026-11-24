import SwiftUI

struct SettingsView: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore

    @AppStorage(UDKey.settingsGroup) private var group = SettingsGroup.game

    @AppStorage("launchProfile") private var launchProfile: String = "SMAPI"
    @AppStorage("closeAfterLaunch") private var closeAfterLaunch: Bool = false
    @AppStorage("showDeveloperLogs") private var showDeveloperLogs: Bool = false
    @AppStorage(UDKey.autoCheckNexusUpdates) private var autoCheckNexusUpdates: Bool = true
    /// X103-C — inactif par défaut : une fonction qui écrit sur le disque sans
    /// qu'on l'ait demandée fait croître l'empreinte en silence.
    @AppStorage(UDKey.keepNexusArchives) private var keepNexusArchives: Bool = false
    /// A1-T7 (suite) — remettre les données de mod après une mise à jour ;
    /// le vrai défaut (clé absente = true) vit dans `shouldRestore`.
    @AppStorage(UDKey.restoreModDataOnUpdate) private var restoreModData: Bool = true

    // Nexus Mods API key entry (only used when no key is stored yet).
    @State private var nexusApiKeyInput: String = ""
    @State private var nexusKeySavedFlash: Bool = false
    @State private var alerts = AlertStore()

    var body: some View {
        TabView(selection: $group) {
            settingsPane(.game)
                .tabItem { Label(tabTitle(.game), systemImage: "gamecontroller") }
                .tag(SettingsGroup.game)
            settingsPane(.content)
                .tabItem { Label(tabTitle(.content), systemImage: "puzzlepiece.extension") }
                .tag(SettingsGroup.content)
            settingsPane(.about)
                .tabItem { Label(tabTitle(.about), systemImage: "info.circle") }
                .tag(SettingsGroup.about)
        }
        .navigationTitle(tabTitle(group))
        .frame(width: 640, height: 520)
        .alert(localization.L(L10n.Main.alert), isPresented: Bindable(alerts).shown) {
            Button(localization.L(L10n.Main.ok), role: .cancel) {}
        } message: { Text(alerts.message) }
        .onChange(of: vm.navigationStore.pendingSettingsSection, initial: true) { _, section in
            if let section { group = SettingsSectionOrder.group(of: section) }
        }
    }

    private func settingsPane(_ pane: SettingsGroup) -> some View {
        let pendingSection = group == pane ? vm.navigationStore.pendingSettingsSection : nil
        return ScrollViewReader { proxy in
            BackToTopScrollView(localization) {
                VStack(alignment: .leading, spacing: AppDesign.Spacing.xl) {
                    ForEach(SettingsSectionOrder.sections(in: pane), id: \.self) { section in
                        sectionView(section).id(section)
                    }
                }
                .padding(AppDesign.Spacing.xl)
            }
            .task(id: pendingSection) {
                guard let pendingSection, SettingsSectionOrder.group(of: pendingSection) == pane else { return }
                await Task.yield()
                guard !Task.isCancelled, group == pane,
                      vm.navigationStore.pendingSettingsSection == pendingSection else { return }
                withMotion { proxy.scrollTo(pendingSection, anchor: .top) }
                vm.navigationStore.pendingSettingsSection = nil
            }
        }
    }

    // MARK: - Groupes

    private func tabTitle(_ group: SettingsGroup) -> String {
        switch group {
        case .game:    return localization.L(L10n.Settings.groupGame)
        case .content: return localization.L(L10n.Settings.groupContent)
        case .about:   return localization.L(L10n.Settings.groupAbout)
        }
    }

    @ViewBuilder
    private func sectionView(_ section: SettingsSection) -> some View {
        switch section {
        case .gameFolder:     gameFolderSection
        case .smapi:          SettingsSmapiSection(vm: vm, localization: localization, alerts: alerts)
        case .launch:         launchSection
        case .coreExtensions: coreExtensionsSection
        case .nexus:          nexusSection
        case .translationAI:  translationAISection
        case .modBehavior:    modBehaviorSection
        case .developer:      developerSection
        case .appInfo:        SettingsAppInfoSection(vm: vm, localization: localization)
        case .support:        SettingsSupportSection(localization: localization)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var nexusSection: some View {
        // ── Nexus Mods ──
        StandardSection(
            title: localization.L(L10n.Settings.nexusMods), icon: ("globe", .blue),  // C2c : l'orange se lisait comme un avertissement
            footer: localization.L(L10n.Settings.nexusApiKeyHint)
        ) {
            VStack(alignment: .leading, spacing: 16) {
                if vm.hasNexusApiKey {
                    // Key stored — offer removal and link to fetch another.
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(localization.L(L10n.Settings.nexusApiKey))
                                .font(AppDesign.Font.body)
                            Text("••••••••••••")
                                .font(AppDesign.Font.monoCaption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            NSWorkspace.shared.open(NexusRequestBuilder.apiKeyPageURL)
                        }) {
                            Text(localization.L(L10n.Settings.nexusGetKey))
                        }
                        Button(role: .destructive, action: {
                            vm.clearNexusApiKey()
                        }) {
                            Text(localization.L(L10n.Settings.nexusClearKey))
                        }
                    }

                    Divider()

                    NexusQuotaRow(vm: vm, localization: localization)
                } else {
                    // No key yet — secure field + save action.
                    VStack(alignment: .leading, spacing: 8) {
                        SecureField(localization.L(L10n.Settings.nexusKeyPlaceholder), text: $nexusApiKeyInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(AppDesign.Font.monoCaption)
                            .autocorrectionDisabled(true)
                            .textContentType(.password)

                        HStack {
                            Button(action: {
                                NSWorkspace.shared.open(NexusRequestBuilder.apiKeyPageURL)
                            }) {
                                Text(localization.L(L10n.Settings.nexusGetKey))
                            }

                            Spacer()

                            if nexusKeySavedFlash {
                                Text(localization.L(L10n.Settings.nexusKeySaved))
                                    .font(AppDesign.Font.footnote)
                                    .foregroundColor(.green)
                                    .transition(.opacity)
                            }

                            Button {
                                let trimmed = nexusApiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                vm.setNexusApiKey(trimmed)
                                nexusApiKeyInput = ""
                                withMotion { nexusKeySavedFlash = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withMotion { nexusKeySavedFlash = false }
                                }
                            } label: {
                                Text(localization.L(L10n.Settings.nexusSaveKey))
                            }
                            .buttonStyle(.borderedProminent).focusRing()
                            .disabled(nexusApiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }

                SettingsRow(title: localization.L(L10n.Settings.nexusAutoCheck), hint: localization.L(L10n.Settings.nexusAutoCheckHint)) {
                    Toggle(localization.L(L10n.Settings.nexusAutoCheck), isOn: $autoCheckNexusUpdates)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }

                // X103-C. Il vit ici, avec ce qui touche à Nexus, plutôt que
                // dans « Données & stockage » : c'est en réglant Nexus qu'on
                // se demande ce que deviennent les fichiers téléchargés. Son
                // poids et sa purge, eux, sont à l'écran Entretien.
                SettingsRow(title: localization.L(L10n.Settings.keepNexusArchives), hint: localization.L(L10n.Settings.keepNexusArchivesHint)) {
                    Toggle(localization.L(L10n.Settings.keepNexusArchives), isOn: $keepNexusArchives)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }
            }
        }
    }

    @ViewBuilder
    private var translationAISection: some View {
        // ── Traduction assistée ──
        LocalAISettingsSection(vm: vm, localization: localization)
    }

    @ViewBuilder
    private var launchSection: some View {
        // ── Launch Options ──
        StandardSection(
            title: localization.L(L10n.Settings.launchOptions), icon: ("play.fill", .green),
            footer: localization.L(L10n.Settings.footerLaunch)
        ) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsRow(title: localization.L(L10n.Settings.defaultLaunchMode), hint: localization.L(L10n.Settings.hintNextLaunchMode)) {
                    Picker(localization.L(L10n.Settings.defaultLaunchMode), selection: $launchProfile) {
                        Text(localization.L(L10n.Settings.playSMAPI)).tag("SMAPI")
                        Text(localization.L(L10n.Settings.vanillaGame)).tag("Vanilla")
                    }
                    .pickerStyle(MenuPickerStyle()).labelsHidden()
                    .fixedSize()
                }
                
                Divider().padding(.leading, 0)
                
                SettingsRow(title: localization.L(L10n.Settings.closeLauncher), hint: localization.L(L10n.Settings.hintSaveResources)) {
                    Toggle(localization.L(L10n.Settings.closeLauncher), isOn: $closeAfterLaunch)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }
            }
        }
    }

    @ViewBuilder
    private var developerSection: some View {
        // ── Developer ──
        StandardSection(
            title: localization.L(L10n.Settings.developer), icon: ("hammer.fill", .gray),
            footer: localization.L(L10n.Settings.footerAppearance)
        ) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsRow(title: localization.L(L10n.Settings.showDevLogs), hint: localization.L(L10n.Settings.hintDevLogs)) {
                    Toggle(localization.L(L10n.Settings.showDevLogs), isOn: $showDeveloperLogs)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }
            }
        }
    }

    @ViewBuilder
    private var modBehaviorSection: some View {
        // ── Mod Behavior ──
        StandardSection(
            title: localization.L(L10n.Settings.modBehavior), icon: ("link", .teal)
        ) {
            VStack(spacing: AppDesign.Spacing.md) {
                SettingsRow(title: localization.L(L10n.Settings.chainToggle), hint: localization.L(L10n.Settings.chainToggleHint)) {
                    Toggle(localization.L(L10n.Settings.chainToggle), isOn: Binding(
                        get: { vm.chainToggleDependencies },
                        set: { vm.chainToggleDependencies = $0 }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                }
                Divider()
                SettingsRow(title: localization.L(L10n.Settings.restoreModData), hint: localization.L(L10n.Settings.restoreModDataHint)) {
                    Toggle(localization.L(L10n.Settings.restoreModData), isOn: $restoreModData)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }
            }
        }
    }

    @ViewBuilder
    private var gameFolderSection: some View {
        // Folder Settings
        StandardSection(title: localization.L(L10n.Home.gameFolder), icon: ("folder.fill", .blue)) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(localization.L(L10n.Home.gamePath))
                        .font(AppDesign.Font.body)
                    let gameDirectory = vm.gameDir
                    if gameDirectory.isEmpty {
                        Text(localization.L(L10n.Home.notSet))
                            .font(AppDesign.Font.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(gameDirectory)
                            .font(AppDesign.Font.caption)
                            .foregroundColor(.secondary)
                            .truncatedHelp(gameDirectory, mode: .middle)
                    }
                }
                Spacer()
                Button(localization.L(L10n.Home.selectFolder)) { vm.selectGameDir(alerts: alerts) }
            }
        }
    }

    @ViewBuilder
    private var coreExtensionsSection: some View {
        AppExtensionsSettingsSection(viewModel: vm, localization: localization)
    }
}

/// Ce qu'il reste de quota Nexus, tel que l'API l'annonce à chaque réponse
/// (B2-T6). Aucune requête n'est faite pour l'obtenir : les six en-têtes
/// `x-rl-*` arrivent avec tout appel, l'app se contentait de les jeter.
///
/// ⚠️ L'app n'interroge plus l'API Nexus qu'à la demande (les mises à jour
/// passent par smapi.io) : sur une installation neuve, le quota n'a **jamais**
/// été mesuré, et c'est le cas normal, pas le cas limite. D'où l'état
/// « jamais mesuré » explicite, avec ce qui le fera apparaître.
private struct NexusQuotaRow: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(localization.L(L10n.Settings.nexusQuota))
                .font(AppDesign.Font.body)

            if let quota = vm.nexusQuota {
                if quota.isStale() {
                    // Les chiffres d'hier mentent après la remise à zéro : ne
                    // rien affirmer plutôt qu'afficher un reste périmé.
                    Text(localization.L(L10n.Settings.nexusQuotaRenewed))
                        .font(AppDesign.Font.caption)
                        .foregroundColor(.secondary)
                } else {
                    measured(quota)
                }
            } else {
                Text(localization.L(L10n.Settings.nexusQuotaNever))
                    .font(AppDesign.Font.caption)
                    .foregroundColor(.secondary)
                Text(localization.L(L10n.Settings.nexusQuotaNeverHint))
                    .font(AppDesign.Font.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { vm.refreshNexusQuota() }
        .onReceive(NotificationCenter.default.publisher(
            for: NexusUpdateChecker.quotaDidChange)) { _ in
            vm.refreshNexusQuota()
        }
    }

    /// Chaque fenêtre est jugée pour elle-même : l'horaire se périme en une
    /// heure, le compte journalier tient jusqu'à minuit. Les agréger ferait
    /// disparaître le chiffre du jour une heure après le dernier appel — soit,
    /// l'app n'interrogeant Nexus qu'à la demande, presque tout le temps.
    @ViewBuilder
    private func measured(_ quota: NexusQuota) -> some View {
        if let daily = quota.dailyIfCurrent() {
            HStack(spacing: 6) {
                Text(String(format: localization.L(L10n.Settings.nexusQuotaDaily), counts(daily)))
                    .font(AppDesign.Font.caption)
                    .foregroundColor(daily.remaining == 0 ? .orange : .secondary)
                if daily.remaining == 0 {
                    Text(localization.L(L10n.Settings.nexusQuotaExhausted))
                        .font(AppDesign.Font.footnote(.medium))
                        .foregroundColor(.orange)
                }
            }
            if let reset = daily.reset {
                Text(String(format: localization.L(L10n.Settings.nexusQuotaReset), Self.time(reset)))
                    .font(AppDesign.Font.footnote)
                    .foregroundColor(.secondary)
            }
        }
        if let hourly = quota.hourlyIfCurrent() {
            Text(String(format: localization.L(L10n.Settings.nexusQuotaHourly), counts(hourly)))
                .font(AppDesign.Font.footnote)
                .foregroundColor(.secondary)
        }
    }

    /// « 19 983 sur 20 000 », ou le seul reste quand l'API tait le plafond.
    private func counts(_ window: NexusQuota.Window) -> String {
        let remaining = Self.number(window.remaining)
        guard let limit = window.limit else { return remaining }
        return String(format: localization.L(L10n.Settings.nexusQuotaOf), remaining, Self.number(limit))
    }

    private static func number(_ value: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }

    private static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
