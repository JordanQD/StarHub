import SwiftUI

/// Keybind diagnostics segment inside `SystemAlertsView`.
/// Uses collapsible `UpdateSectionDisclosure` groups, native `ContentUnavailableView`
/// states, toolbar-driven actions (Plan / Export / Rescan), and live search filtering.
struct KeybindReportSection: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    @ObservedObject var service: KeybindScanService
    @Binding var currentTab: SidebarDestination
    @Binding var showsPlan: Bool
    var searchText: String = ""
    var onClearSearch: () -> Void = {}

    init(vm: StarHubTHViewModel,
         localization: LocalizationStore,
         currentTab: Binding<SidebarDestination>,
         showsPlan: Binding<Bool>,
         searchText: String = "",
         onClearSearch: @escaping () -> Void = {}) {
        self.localization = localization
        self.vm = vm
        self.service = vm.keybindScanService
        self._currentTab = currentTab
        self._showsPlan = showsPlan
        self.searchText = searchText
        self.onClearSearch = onClearSearch
    }

    private static let autoExpandThreshold = 10

    @State private var expanded: [String: Bool] = [:]
    var noGameDir: Bool { vm.gameDir.isEmpty }

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool { !trimmedQuery.isEmpty }

    private func expansion(_ key: String, defaultOpen: Bool) -> Binding<Bool> {
        if isSearching { return .constant(true) }
        return Binding(get: { expanded[key] ?? defaultOpen }, set: { expanded[key] = $0 })
    }

    var body: some View {
        Group {
            if noGameDir {
                ContentUnavailableView {
                    Label(localization.L(L10n.Keybinds.title), systemImage: "folder.badge.questionmark")
                } description: {
                    Text(localization.L(L10n.Keybinds.noGameDir))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if service.isScanning {
                VStack(spacing: AppDesign.Spacing.md) {
                    ProgressView()
                    Text(localization.L(L10n.Keybinds.scanning))
                        .font(AppDesign.Font.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let report = service.report {
                reportContent(report)
            } else {
                Color.clear
            }
        }
        .onAppear {
            consumePlanFocus()
            service.scanIfNeeded(mods: vm.scanStore.mods, gameDir: vm.gameDir)
        }
        .onChange(of: planFocusPending) { _, _ in consumePlanFocus() }
    }

    // MARK: - Report Content

    @ViewBuilder
    private func reportContent(_ report: KeybindScanner.KeybindReport) -> some View {
        if report.scannedMods == 0 {
            ContentUnavailableView {
                Label(localization.L(L10n.Keybinds.title), systemImage: "keyboard")
            } description: {
                Text(localization.L(L10n.Keybinds.noModsScanned))
            } actions: {
                Button(localization.L(L10n.Keybinds.rescan)) {
                    service.scan(mods: vm.scanStore.mods, gameDir: vm.gameDir)
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let collisions = filteredCollisions(report.collisions)
            let gamepadCollisions = filteredCollisions(report.gamepadCollisions)
            let gameConflicts = filteredGameConflicts(report.gameConflicts)
            let unrecognized = filteredUnrecognized(report.unrecognized)
            let subsetOverlaps = filteredSubsetOverlaps(report.subsetOverlaps)
            let latentCollisions = filteredCollisions(report.latentCollisions)
            let overviewMatches = KeybindScanner.overview(report.settings, filter: .all, query: trimmedQuery)

            let hasAnyMatch = !collisions.isEmpty || !gamepadCollisions.isEmpty
                || !gameConflicts.isEmpty || !unrecognized.isEmpty
                || !subsetOverlaps.isEmpty || !latentCollisions.isEmpty
                || !overviewMatches.isEmpty

            if isSearching && !hasAnyMatch {
                ContentUnavailableView {
                    Label(localization.L(L10n.Keybinds.noMatch), systemImage: "magnifyingglass")
                } actions: {
                    Button(localization.L(L10n.Discovery.clearSearch), action: onClearSearch)
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                BackToTopScrollView(localization) {
                    LazyVStack(alignment: .leading, spacing: AppDesign.Spacing.lg) {
                        if !isSearching && report.problemCount == 0
                            && report.unrecognized.isEmpty && report.subsetOverlaps.isEmpty {
                            HStack(spacing: AppDesign.Spacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppDesign.Color.success)
                                Text(localization.L(L10n.Keybinds.empty))
                                    .font(AppDesign.Font.body(.medium))
                                Spacer()
                            }
                            .padding(.horizontal, AppDesign.Spacing.md)
                            .padding(.vertical, AppDesign.Spacing.sm)
                            .background(AppDesign.Color.success.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: AppDesign.Radius.md))
                        }

                        if !collisions.isEmpty {
                            collisionsGroup(collisions, key: "collisions",
                                            header: L10n.Keybinds.collisionsHeader,
                                            icon: KeybindConflictStyle.glyph,
                                            tint: KeybindConflictStyle.color(.mods))
                                .id("collisions")
                        }
                        if !gamepadCollisions.isEmpty {
                            collisionsGroup(gamepadCollisions, key: "gamepad",
                                            header: report.gamepadOff ? L10n.Keybinds.gamepadOffHeader
                                                : L10n.Keybinds.gamepadHeader,
                                            icon: "gamecontroller",
                                            tint: KeybindConflictStyle.color(.mods))
                                .id("gamepad")
                        }
                        if !gameConflicts.isEmpty {
                            gameConflictsGroup(gameConflicts, caveatKey: report.gameControlsSource.caveatKey)
                                .id("game")
                        }
                        if !unrecognized.isEmpty {
                            unrecognizedGroup(unrecognized)
                                .id("unrecognized")
                        }
                        if !subsetOverlaps.isEmpty {
                            subsetOverlapsGroup(subsetOverlaps)
                        }
                        if !latentCollisions.isEmpty {
                            latentCollisionsGroup(latentCollisions)
                        }

                        if !report.settings.isEmpty {
                            if !isSearching {
                                KeybindKeyboardGroup(localization: localization,
                                                     settings: report.settings,
                                                     isExpanded: expansion("keyboard", defaultOpen: true),
                                                     openConfig: { openConfig($0, $1) })
                            }
                            KeybindOverviewGroup(localization: localization,
                                                 bindings: report.settings,
                                                 isExpanded: expansion("overview", defaultOpen: false),
                                                 externalQuery: trimmedQuery,
                                                 openConfig: { openConfig($0, $1) })
                        }

                        if !isSearching {
                            KeybindExclusionNotes(report: report, localization: localization)
                        }
                    }
                    .padding(AppDesign.Spacing.xl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Search Filtering

    private func matches(_ text: String) -> Bool {
        text.localizedCaseInsensitiveContains(trimmedQuery)
    }

    private func filteredCollisions(_ items: [KeybindScanner.KeybindCollision]) -> [KeybindScanner.KeybindCollision] {
        guard isSearching else { return items }
        return items.filter { c in
            matches(c.combo.display) || c.uses.contains { u in
                matches(u.modName) || matches(u.keyPath.joined(separator: "."))
            }
        }
    }

    private func filteredGameConflicts(_ items: [KeybindScanner.GameControlConflict]) -> [KeybindScanner.GameControlConflict] {
        guard isSearching else { return items }
        return items.filter { c in
            matches(c.control.name)
                || c.control.buttons.contains(where: matches)
                || c.uses.contains { u in matches(u.modName) || matches(u.keyPath.joined(separator: ".")) }
        }
    }

    private func filteredUnrecognized(_ items: [KeybindScanner.UnrecognizedKeybind]) -> [KeybindScanner.UnrecognizedKeybind] {
        guard isSearching else { return items }
        return items.filter { u in
            matches(u.modName) || matches(u.raw) || matches(u.keyPath.joined(separator: "."))
        }
    }

    private func filteredSubsetOverlaps(_ items: [KeybindScanner.SubsetOverlap]) -> [KeybindScanner.SubsetOverlap] {
        guard isSearching else { return items }
        return items.filter { o in
            matches(o.subset.display) || matches(o.superset.display) || o.uses.contains { u in
                matches(u.modName) || matches(u.keyPath.joined(separator: "."))
            }
        }
    }

    // MARK: - Rows & Actions

    private func groupedUseLine(_ use: KeybindScanner.GroupedUse) -> some View {
        let keyPathsText = use.keyPaths.map { $0.joined(separator: ".") }.joined(separator: ", ")
        return HStack(spacing: AppDesign.Spacing.sm) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: AppDesign.Spacing.xs) {
                    Text(use.modName)
                        .font(AppDesign.Font.caption(.medium))
                        .lineLimit(1).truncationMode(.tail)
                    if !use.isActive {
                        Text(localization.L(L10n.Keybinds.pausedSuffix))
                            .font(AppDesign.Font.iconXS(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, AppDesign.Spacing.xs)
                            .padding(.vertical, 1)
                            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                Text(keyPathsText)
                    .font(AppDesign.Font.monoFootnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: AppDesign.Spacing.sm)
            configButton(modID: use.modID, keyPath: use.keyPaths.first)
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button(localization.L(L10n.Settings.configModSettings)) {
                openConfig(use.modID, use.keyPaths.first)
            }
            Button(localization.L(L10n.Health.actionOpenMod)) {
                vm.navigationStore.openModDetail(folderName: use.modID, door: .alert(dependency: false))
            }
        }
    }

    private func configButton(modID: String, keyPath: [String]? = nil) -> some View {
        KeybindConfigButton(localization: localization) { openConfig(modID, keyPath) }
    }

    private func openConfig(_ modID: String, _ keyPath: [String]?) {
        if vm.openModConfig(forFolder: modID, keyPath: keyPath) {
            currentTab = .mods
        }
    }

    // MARK: - Disclosure Groups

    private func collisionsGroup(_ collisions: [KeybindScanner.KeybindCollision],
                                 key: String,
                                 header: String,
                                 icon: String,
                                 tint: Color) -> some View {
        let title = String(format: localization.L(header), collisions.count)
        return UpdateSectionDisclosure(title: title,
                                       icon: icon,
                                       iconTint: tint,
                                       isExpanded: expansion(key, defaultOpen: collisions.count <= Self.autoExpandThreshold)) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(collisions, id: \.combo) { collision in
                    VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                        KeybindKeyChip(text: collision.combo.display)
                        ForEach(KeybindScanner.groupedUses(collision.uses)) { use in
                            groupedUseLine(use)
                        }
                    }
                    .padding(.vertical, AppDesign.Spacing.xs)
                    .overlay(alignment: .bottom) { Divider() }
                }
            }
        }
    }

    private func subsetOverlapsGroup(_ overlaps: [KeybindScanner.SubsetOverlap]) -> some View {
        let title = String(format: localization.L(L10n.Keybinds.subsetsHeader), overlaps.count)
        return UpdateSectionDisclosure(title: title,
                                       icon: AppDesign.Status.info.symbol,
                                       iconTint: AppDesign.Color.info,
                                       isExpanded: expansion("subsets", defaultOpen: overlaps.count <= Self.autoExpandThreshold)) {
            VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                Text(localization.L(L10n.Keybinds.subsetsHint))
                    .font(AppDesign.Font.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, AppDesign.Spacing.xs)
                ForEach(overlaps, id: \.self) { overlap in
                    VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                        HStack(spacing: AppDesign.Spacing.xs) {
                            KeybindKeyChip(text: overlap.subset.display)
                            Text("⊂").foregroundStyle(.secondary)
                            KeybindKeyChip(text: overlap.superset.display)
                        }
                        ForEach(KeybindScanner.groupedUses(overlap.uses)) { use in
                            groupedUseLine(use)
                        }
                    }
                    .padding(.vertical, AppDesign.Spacing.xs)
                    .overlay(alignment: .bottom) { Divider() }
                }
            }
        }
    }

    private func latentCollisionsGroup(_ collisions: [KeybindScanner.KeybindCollision]) -> some View {
        let title = String(format: localization.L(L10n.Keybinds.latentHeader), collisions.count)
        return UpdateSectionDisclosure(title: title,
                                       icon: "pause.circle",
                                       iconTint: .secondary,
                                       isExpanded: expansion("latent", defaultOpen: false)) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(collisions, id: \.combo) { collision in
                    VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                        KeybindKeyChip(text: collision.combo.display)
                        ForEach(KeybindScanner.groupedUses(collision.uses)) { use in
                            groupedUseLine(use)
                        }
                    }
                    .padding(.vertical, AppDesign.Spacing.xs)
                    .overlay(alignment: .bottom) { Divider() }
                }
            }
        }
    }

    private func gameConflictsGroup(_ conflicts: [KeybindScanner.GameControlConflict],
                                    caveatKey: String) -> some View {
        let title = String(format: localization.L(L10n.Keybinds.gameHeader), conflicts.count)
        return UpdateSectionDisclosure(title: title,
                                       icon: KeybindConflictStyle.glyph,
                                       iconTint: KeybindConflictStyle.color(.game),
                                       isExpanded: expansion("game", defaultOpen: conflicts.count <= Self.autoExpandThreshold)) {
            VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                Text(localization.L(caveatKey))
                    .font(AppDesign.Font.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, AppDesign.Spacing.xs)
                ForEach(conflicts, id: \.control.name) { conflict in
                    VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                        HStack(spacing: AppDesign.Spacing.xs) {
                            ForEach(Array(conflict.control.buttons.enumerated()), id: \.offset) { index, button in
                                if index > 0 {
                                    Text("/")
                                        .font(AppDesign.Font.caption)
                                        .foregroundStyle(.secondary)
                                }
                                KeybindKeyChip(text: button)
                            }
                            Text(conflict.control.name)
                                .font(AppDesign.Font.footnote)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(KeybindScanner.groupedUses(conflict.uses)) { use in
                            groupedUseLine(use)
                        }
                    }
                    .padding(.vertical, AppDesign.Spacing.xs)
                    .overlay(alignment: .bottom) { Divider() }
                }
            }
        }
    }

    private func unrecognizedGroup(_ items: [KeybindScanner.UnrecognizedKeybind]) -> some View {
        let title = String(format: localization.L(L10n.Keybinds.unrecognizedHeader), items.count)
        return UpdateSectionDisclosure(title: title,
                                       icon: "questionmark.circle",
                                       iconTint: AppDesign.Color.warning,
                                       isExpanded: expansion("unrecognized", defaultOpen: items.count <= Self.autoExpandThreshold)) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(items, id: \.self) { u in
                    HStack(spacing: AppDesign.Spacing.sm) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(u.modName)
                                .font(AppDesign.Font.caption(.medium))
                                .lineLimit(1).truncationMode(.tail)
                            Text("\(u.keyPath.joined(separator: ".")) = \(u.raw)")
                                .font(AppDesign.Font.monoFootnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.middle)
                        }
                        Spacer(minLength: AppDesign.Spacing.sm)
                        configButton(modID: u.modID, keyPath: u.keyPath)
                    }
                    .padding(.vertical, AppDesign.Spacing.xs)
                    .overlay(alignment: .bottom) { Divider() }
                    .contextMenu {
                        Button(localization.L(L10n.Settings.configModSettings)) {
                            openConfig(u.modID, u.keyPath)
                        }
                        Button(localization.L(L10n.Health.actionOpenMod)) {
                            vm.navigationStore.openModDetail(folderName: u.modID, door: .alert(dependency: false))
                        }
                    }
                }
            }
        }
    }
}
