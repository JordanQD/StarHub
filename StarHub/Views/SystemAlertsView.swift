import SwiftUI

// MARK: - System Alerts View

private struct RenameFolderSheet: Identifiable {
    let name: String
    var id: String { name }
}

struct SystemAlertsView: View {
    var viewModel: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    @Binding var currentTab: SidebarDestination

    @State private var renameSheet: RenameFolderSheet?
    @State private var showsKeybindPlan = false
    @State private var searchText = ""
    @State private var searchPresented = false
    @State private var criticalExpanded = true
    @State private var warningExpanded = true
    @State private var infoExpanded = false

    var body: some View {
        let issues = viewModel.healthIssues
        let segment = viewModel.navigationStore.alertsSegment
        Group {
            switch segment {
            case .alerts:
                alertsContent(issues)
            case .keybinds:
                KeybindReportSection(vm: viewModel,
                                     localization: localization,
                                     currentTab: $currentTab,
                                     showsPlan: $showsKeybindPlan,
                                     searchText: searchText,
                                     onClearSearch: clearSearch)
            case .conflicts:
                conflictsContent
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            switch segment {
            case .alerts, .conflicts:
                logSourceStatusBar
            case .keybinds:
                KeybindStatusBar(service: viewModel.keybindScanService, localization: localization)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppDesign.Color.windowBg)
        .navigationSubtitle(alertsSubtitle(issues))
        .searchable(text: $searchText, isPresented: $searchPresented,
                    placement: .toolbar, prompt: searchPrompt(for: segment))
        .background {
            Button(searchPrompt(for: segment)) { searchPresented = true }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker(localization.L(L10n.A11y.alertsSegment), selection: Binding(
                    get: { viewModel.navigationStore.alertsSegment },
                    set: { viewModel.navigationStore.alertsSegment = $0 }
                )) {
                    ForEach(AlertsSegment.allCases, id: \.self) { seg in
                        Text(segmentLabel(seg, issues)).tag(seg)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            ToolbarItemGroup(placement: .primaryAction) {
                switch segment {
                case .alerts, .conflicts:
                    recheckLogButton
                case .keybinds:
                    KeybindToolbarActions(vm: viewModel,
                                          service: viewModel.keybindScanService,
                                          localization: localization,
                                          showsPlan: $showsKeybindPlan)
                }
            }

            if #available(macOS 26.0, *) {
                DefaultToolbarItem(kind: .search, placement: .automatic)
            }
        }
        .sheet(item: $renameSheet) { target in
            renameSheetContent(target.name)
        }
        .sheet(isPresented: $showsKeybindPlan) {
            KeybindPlanSheet(viewModel: viewModel, localization: localization)
        }
    }

    private func clearSearch() {
        withMotion(.snappy) { searchText = "" }
    }

    private func searchPrompt(for segment: AlertsSegment) -> String {
        switch segment {
        case .keybinds: return localization.L(L10n.Keybinds.searchPlaceholder)
        case .alerts, .conflicts: return localization.L(L10n.Mods.searchMods)
        }
    }

    private var conflictsContent: some View {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return ModConflictsTabContent(vm: viewModel,
                                      localization: localization,
                                      searchQuery: query,
                                      onClearSearch: clearSearch)
    }

    // MARK: - Alerts Content

    @ViewBuilder
    private func alertsContent(_ issues: [HealthIssue]) -> some View {
        if issues.isEmpty {
            emptyState
        } else {
            let shown = filteredIssues(issues)
            if shown.isEmpty {
                filteredEmptyState {
                    withMotion(.snappy) { searchText = "" }
                }
            } else {
                alertsCollapsibleList(shown)
            }
        }
    }

    private func filteredIssues(_ issues: [HealthIssue]) -> [HealthIssue] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return issues }
        return issues.filter { issue in
            let title = issue.titleKey.map { localization.L($0) } ?? issue.title
            return title.localizedCaseInsensitiveContains(query)
                || (issue.detail?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private func alertsCollapsibleList(_ shown: [HealthIssue]) -> some View {
        let isSearching = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return BackToTopScrollView(localization) {
            LazyVStack(alignment: .leading, spacing: AppDesign.Spacing.lg) {
                severitySection(.critical, in: shown, expanded: isSearching ? .constant(true) : $criticalExpanded)
                severitySection(.warning, in: shown, expanded: isSearching ? .constant(true) : $warningExpanded)
                severitySection(.info, in: shown, expanded: isSearching ? .constant(true) : $infoExpanded)
            }
            .padding(AppDesign.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .optionalSwipeActionsContainer()
    }

    @ViewBuilder
    private func severitySection(_ severity: HealthIssue.Severity,
                                 in issues: [HealthIssue],
                                 expanded: Binding<Bool>) -> some View {
        let bucket = issues.filter { $0.severity == severity }
        if !bucket.isEmpty {
            let title = "\(localization.L(severity.l10nKey)) (\(bucket.count))"
            UpdateSectionDisclosure(title: title,
                                    icon: symbol(for: severity),
                                    iconTint: tint(for: severity),
                                    isExpanded: expanded) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(bucket) { issue in
                        row(for: issue)
                            .overlay(alignment: .bottom) { Divider() }
                            .contextMenu {
                                ForEach(issue.actions) { action in
                                    Button(actionLabel(for: action)) { perform(action) }
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if let primary = issue.actions.first {
                                    Button {
                                        perform(primary)
                                    } label: {
                                        Text(actionLabel(for: primary))
                                    }
                                    .tint(.accentColor)
                                }
                            }
                    }
                }
            }
        }
    }

    private func segmentLabel(_ segment: AlertsSegment, _ issues: [HealthIssue]) -> String {
        let (key, count): (String, Int)
        switch segment {
        case .alerts:    (key, count) = (L10n.Health.tabAlerts, issues.actionableCount)
        case .keybinds:  (key, count) = (L10n.Keybinds.title, issues.count { $0.source == .keybind })
        case .conflicts: (key, count) = (L10n.Conflicts.title, issues.count { $0.source == .modConflict })
        }
        let title = localization.L(key)
        return count > 0 ? "\(title) (\(count))" : title
    }

    // MARK: - Header & Status Bar

    private func alertsSubtitle(_ issues: [HealthIssue]) -> String {
        guard !issues.isEmpty else { return "" }
        return String(format: localization.L(L10n.Health.problemCount),
                      localization.plural(L10n.Health.problems, issues.actionableCount),
                      localization.plural(L10n.Health.criticals, issues.filter { $0.severity == .critical }.count))
    }

    private func symbol(for severity: HealthIssue.Severity) -> String {
        switch severity {
        case .critical: return AppDesign.Status.error.symbol
        case .warning: return AppDesign.Status.warning.symbol
        case .info: return AppDesign.Status.info.symbol
        }
    }

    private func tint(for severity: HealthIssue.Severity?) -> Color {
        switch severity {
        case .critical: return AppDesign.Color.error
        case .warning: return AppDesign.Color.warning
        case .info: return AppDesign.Color.info
        case nil: return AppDesign.Color.success
        }
    }

    @ViewBuilder
    private var logSourceStatusBar: some View {
        if let source = SmapiLogSource(logDate: viewModel.smapiLogDate, isStale: viewModel.smapiLogStale,
                                       locale: Locale.autoupdatingCurrent) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: AppDesign.Spacing.sm) {
                    Text(String(format: localization.L(L10n.Health.logSource), source.date)
                         + (source.staleAge.map { " — " + String(format: localization.L(L10n.Health.logStaleAge), $0) } ?? ""))
                        .font(.caption)
                        .foregroundStyle(source.staleAge == nil ? Color.secondary : AppDesign.Color.warning)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button(localization.L(L10n.Health.logOpenHealth)) {
                        viewModel.navigationStore.diagnosticsSegment = .health
                        currentTab = .logs
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
                .padding(.horizontal, AppDesign.Spacing.xl)
                .padding(.vertical, AppDesign.Spacing.xs)
            }
            .background(.bar)
        }
    }

    private func renameSheetContent(_ name: String) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                ModFolderRenameSection(vm: viewModel, localization: localization, folderName: name) { renameSheet = nil }
                    .padding(AppDesign.Spacing.lg)
            }
            Divider()
            HStack {
                Spacer()
                Button(localization.L(L10n.Main.ok)) { renameSheet = nil }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(AppDesign.Spacing.md)
        }
        .frame(minWidth: 560, idealWidth: 680, minHeight: 360, idealHeight: 480)
    }

    // MARK: - Rows

    private func row(for issue: HealthIssue) -> some View {
        HStack(spacing: AppDesign.Spacing.md) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(tint(for: issue.severity))
                .frame(width: 3)
                .padding(.vertical, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.titleKey.map { localization.L($0) } ?? issue.title)
                    .font(AppDesign.Font.body)
                if let detail = issue.detail {
                    Text(detail)
                        .font(AppDesign.Font.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: AppDesign.Spacing.sm)
            let mods = issue.actions.filter { if case .openMod = $0 { true } else { false } }
            if mods.count > 1 {
                ModPairDetailMenu(folders: mods.compactMap { if case .openMod(let f) = $0 { f } else { nil } },
                                  name: { ModFocusResolver.resolve($0, in: viewModel.scanStore.mods)?.name ?? $0 },
                                  navigation: viewModel.navigationStore, localization: localization)
            }
            ForEach(mods.count > 1 ? issue.actions.filter { !mods.contains($0) } : issue.actions) { action in
                actionButtons(for: action)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func actionButtons(for action: HealthIssue.Action) -> some View {
        let premiumNexusId: Int? = if case .reinstallFromNexus(let id) = action, viewModel.nexusDirectDownloadUnavailable { id } else { nil }
        Group {
            Button(actionLabel(for: action)) { perform(action) }
                .disabled(premiumNexusId != nil)
                .help(premiumNexusId != nil ? localization.L(L10n.Mods.premiumOnlyHint) : "")
            if let premiumNexusId {
                Button {
                    NSWorkspace.shared.open(MissingDependencies.filesPage(nexusId: premiumNexusId))
                } label: {
                    Label(localization.L(L10n.Mods.translationOpenNexus), systemImage: "arrow.up.right.square")
                }
            }
        }
        .lineLimit(1)
        .fixedSize()
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func actionLabel(for action: HealthIssue.Action) -> String {
        switch action {
        case .openMod, .openModDependencies: return localization.L(L10n.Health.actionOpenMod)
        case .openModConfig: return localization.L(L10n.Health.actionOpenSetting)
        case .openLogs: return localization.L(L10n.Health.actionOpenLogs)
        case .revealInFinder: return localization.L(L10n.Health.actionRevealInFinder)
        case .renameFolder: return localization.L(L10n.Health.actionRenameFolder)
        case .repairManifest: return localization.L(L10n.Health.actionRepairManifest)
        case .reinstallFromNexus: return localization.L(L10n.Health.actionReinstallNexus)
        case .setAsideStaleBinaries: return localization.L(L10n.Health.actionSetAsideBinaries)
        }
    }

    private func perform(_ action: HealthIssue.Action) {
        switch action {
        case .openMod(let query):
            viewModel.navigationStore.openModDetail(folderName: query, door: .alert(dependency: false))
        case .openModDependencies(let query):
            viewModel.navigationStore.openModDetail(folderName: query, door: .alert(dependency: true))
        case .openModConfig(let folderName, let keyPath):
            if viewModel.openModConfig(forFolder: folderName, keyPath: keyPath) { currentTab = .mods }
        case .openLogs(let searchText):
            viewModel.navigationStore.openLog(search: searchText)
        case .revealInFinder(let paths):
            NSWorkspace.shared.activateFileViewerSelecting(
                paths.map { URL(fileURLWithPath: $0) })
        case .renameFolder(let name):
            renameSheet = RenameFolderSheet(name: name)
        case .repairManifest(let folderName):
            viewModel.restoreManifest(folderName: folderName)
        case .reinstallFromNexus(let nexusId):
            viewModel.downloadModFromNexus(nexusId: nexusId)
        case .setAsideStaleBinaries(let saves):
            guard !viewModel.isGameRunning() else {
                viewModel.showModal(message: localization.L(L10n.Health.pureBinaryGameRunning))
                return
            }
            PureBinarySave.setAsideStale(saves)
            viewModel.reloadSaves()
        }
    }
}
