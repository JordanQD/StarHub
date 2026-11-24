import SwiftUI

/// Combined Conflicts tab content inside `SystemAlertsView`.
/// Unifies Content Patcher conflicts, known/predicted/declared incompatibilities,
/// performance overlaps, and restorable dismissed pairs into collapsible
/// `UpdateSectionDisclosure` groups with toolbar search and native empty states.
struct ModConflictsTabContent: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    var searchQuery: String = ""
    var onClearSearch: () -> Void = {}

    @AppStorage(UDKey.dismissedPerformanceOverlaps) private var dismissedOverlapsRaw = ""

    private var isSearching: Bool { !searchQuery.isEmpty }

    private var installedMods: [ModItem] {
        vm.scanStore.mods.flattenedMods
    }

    private func displayName(_ folderName: String) -> String {
        installedMods.first(where: { $0.folderName == folderName })?.name ?? folderName
    }

    private func matches(_ text: String) -> Bool {
        text.localizedCaseInsensitiveContains(searchQuery)
    }

    private func matchesPair(_ pair: ModConflictPair) -> Bool {
        !isSearching || matches(pair.first) || matches(pair.second)
            || matches(displayName(pair.first)) || matches(displayName(pair.second))
    }

    private func matchesConflict(_ conflict: LoadConflict) -> Bool {
        guard isSearching else { return true }
        if matches(conflict.asset) { return true }
        return vm.conflictFolderNames(conflict).contains { folder in
            matches(folder) || matches(displayName(folder))
        }
    }

    private var filteredPerformanceMatches: [PerformanceOverlapMatch] {
        let all = PerformanceOverlapSection.activeMatches(in: installedMods, dismissedRaw: dismissedOverlapsRaw)
        guard isSearching else { return all }
        return all.filter { m in
            matches(m.firstMod.name) || matches(m.secondMod.name)
                || matches(m.firstMod.folderName) || matches(m.secondMod.folderName)
        }
    }

    var body: some View {
        let dismissedSet = Set(vm.modConflictVerdicts.dismissed)
        let liveBetween = vm.contentPatcherConflicts.filter { conflict in
            guard conflict.kind == .betweenPacks else { return false }
            if let p = vm.conflictPair(for: conflict), dismissedSet.contains(p) { return false }
            return matchesConflict(conflict)
        }
        let liveWithin = vm.contentPatcherConflicts.filter { conflict in
            guard conflict.kind == .withinOnePack else { return false }
            if let p = vm.conflictPair(for: conflict), dismissedSet.contains(p) { return false }
            return matchesConflict(conflict)
        }
        let known = vm.modConflictVerdicts.knownPairs(installed: installedMods).filter(matchesPair)
        let predicted = vm.contentPatcherLoadIndex.conflictPairs
            .filter { vm.modConflictVerdicts.verdict(for: $0) == nil }
            .filter(matchesPair)
        let declared = vm.modConflictVerdicts.declared.filter(matchesPair)
        let dismissed = vm.modConflictVerdicts.dismissed.filter(matchesPair)
        let overlaps = filteredPerformanceMatches

        let hasAnyActiveConflict = !liveBetween.isEmpty || !liveWithin.isEmpty
            || !known.isEmpty || !predicted.isEmpty || !declared.isEmpty
        let hasAnyVisibleItem = hasAnyActiveConflict || !overlaps.isEmpty || !dismissed.isEmpty

        if isSearching && !hasAnyVisibleItem {
            ContentUnavailableView {
                Label(localization.L(L10n.Discovery.noMatch), systemImage: "magnifyingglass")
            } actions: {
                Button(localization.L(L10n.Discovery.clearSearch), action: onClearSearch)
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !isSearching && !hasAnyVisibleItem && dismissedOverlapsRaw.isEmpty {
            emptyState
        } else {
            BackToTopScrollView(localization) {
                LazyVStack(alignment: .leading, spacing: AppDesign.Spacing.lg) {
                    ModConflictSection(vm: vm,
                                       localization: localization,
                                       searchQuery: searchQuery)
                    PerformanceOverlapSection(viewModel: vm,
                                              localization: localization,
                                              searchQuery: searchQuery)
                }
                .padding(AppDesign.Spacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .optionalSwipeActionsContainer()
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if vm.smapiLogDate == nil {
            ContentUnavailableView {
                Label(localization.L(L10n.Conflicts.title), systemImage: "doc.text.magnifyingglass")
            } description: {
                Text(localization.L(L10n.Conflicts.noLogRead))
            } actions: {
                Button {
                    vm.refreshSmapiLog()
                } label: {
                    Label(localization.L(L10n.Updates.recheckLog), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView {
                Label {
                    Text(localization.L(L10n.Conflicts.noneObserved))
                } icon: {
                    Image(systemName: AppDesign.Status.ok.symbol)
                        .foregroundStyle(AppDesign.Status.ok.tint)
                }
            } description: {
                Text(localization.L(L10n.PerformanceOverlaps.none))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Content Patcher, known, predicted, declared, and dismissed mod conflicts.
struct ModConflictSection: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    var searchQuery: String = ""

    @State private var cpExpanded = true
    @State private var knownExpanded = true
    @State private var predictedExpanded = true
    @State private var declaredExpanded = true
    @State private var dismissedExpanded = false

    private var isSearching: Bool { !searchQuery.isEmpty }

    private func expandedBinding(_ binding: Binding<Bool>) -> Binding<Bool> {
        isSearching ? .constant(true) : binding
    }

    // MARK: - Derived Data

    var installedMods: [ModItem] {
        vm.scanStore.mods.flattenedMods
    }

    func displayName(_ folderName: String) -> String {
        installedMods.first(where: { $0.folderName == folderName })?.name ?? folderName
    }

    private func folders(_ conflict: LoadConflict) -> [String] {
        vm.conflictFolderNames(conflict)
    }

    private func pair(_ conflict: LoadConflict) -> ModConflictPair? {
        vm.conflictPair(for: conflict)
    }

    private var dismissedPairs: Set<ModConflictPair> {
        Set(vm.modConflictVerdicts.dismissed)
    }

    private func matches(_ text: String) -> Bool {
        text.localizedCaseInsensitiveContains(searchQuery)
    }

    private func matchesPair(_ pair: ModConflictPair) -> Bool {
        !isSearching || matches(pair.first) || matches(pair.second)
            || matches(displayName(pair.first)) || matches(displayName(pair.second))
    }

    private func matchesConflict(_ conflict: LoadConflict) -> Bool {
        guard isSearching else { return true }
        if matches(conflict.asset) { return true }
        return folders(conflict).contains { matches($0) || matches(displayName($0)) }
    }

    private func liveConflicts(kind: LoadConflict.Kind) -> [LoadConflict] {
        vm.contentPatcherConflicts.filter { conflict in
            guard conflict.kind == kind else { return false }
            if let p = pair(conflict), dismissedPairs.contains(p) { return false }
            return matchesConflict(conflict)
        }
    }

    private var betweenPacksConflicts: [LoadConflict] { liveConflicts(kind: .betweenPacks) }
    private var withinOnePackConflicts: [LoadConflict] { liveConflicts(kind: .withinOnePack) }
    private var declaredPairs: [ModConflictPair] { vm.modConflictVerdicts.declared.filter(matchesPair) }
    private var knownPairs: [ModConflictPair] { vm.modConflictVerdicts.knownPairs(installed: installedMods).filter(matchesPair) }
    private var predictedPairs: [ModConflictPair] {
        vm.contentPatcherLoadIndex.conflictPairs
            .filter { vm.modConflictVerdicts.verdict(for: $0) == nil }
            .filter(matchesPair)
    }
    private var filteredDismissedPairs: [ModConflictPair] {
        vm.modConflictVerdicts.dismissed.filter(matchesPair)
    }

    private func activeBadgeLabel(for conflict: LoadConflict) -> String? {
        let names = folders(conflict)
        guard !names.isEmpty else { return nil }
        let enabledFolders = Set(installedMods.filter(\.isEnabled).map(\.folderName))
        guard Set(names).isSubset(of: enabledFolders) else { return nil }
        return names.count == 2 ? localization.L(L10n.Conflicts.bothActive) : localization.L(L10n.Conflicts.allActive)
    }

    // MARK: - Body

    var body: some View {
        let cpCount = betweenPacksConflicts.count + withinOnePackConflicts.count
        let noActiveConflicts = cpCount == 0 && declaredPairs.isEmpty && knownPairs.isEmpty && predictedPairs.isEmpty

        VStack(alignment: .leading, spacing: AppDesign.Spacing.lg) {
            if !isSearching && noActiveConflicts {
                statusBanner
            }

            if cpCount > 0 {
                UpdateSectionDisclosure(title: "\(localization.L(L10n.Conflicts.title)) (\(cpCount))",
                                        icon: AppDesign.Status.error.symbol,
                                        iconTint: AppDesign.Color.error,
                                        isExpanded: expandedBinding($cpExpanded)) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(betweenPacksConflicts, id: \.self) { conflict in
                            betweenPacksRow(conflict)
                                .padding(.vertical, AppDesign.Spacing.xs)
                                .overlay(alignment: .bottom) { Divider() }
                                .modifier(ConflictRowInteractions(
                                    folders: folders(conflict),
                                    displayName: displayName,
                                    navigation: vm.navigationStore,
                                    localization: localization,
                                    dismissAction: pair(conflict).map { p in { vm.dismissConflict(p) } }
                                ))
                        }
                        ForEach(withinOnePackConflicts, id: \.self) { conflict in
                            withinOnePackRow(conflict)
                                .padding(.vertical, AppDesign.Spacing.xs)
                                .overlay(alignment: .bottom) { Divider() }
                                .modifier(ConflictRowInteractions(
                                    folders: folders(conflict),
                                    displayName: displayName,
                                    navigation: vm.navigationStore,
                                    localization: localization,
                                    dismissAction: pair(conflict).map { p in { vm.dismissConflict(p) } }
                                ))
                        }
                    }
                }
            }

            if !knownPairs.isEmpty {
                UpdateSectionDisclosure(title: "\(localization.L(L10n.Conflicts.knownBadge)) (\(knownPairs.count))",
                                        icon: "xmark.octagon.fill",
                                        iconTint: AppDesign.Color.error,
                                        isExpanded: expandedBinding($knownExpanded)) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(knownPairs, id: \.self) { p in
                            knownRow(p)
                                .padding(.vertical, AppDesign.Spacing.xs)
                                .overlay(alignment: .bottom) { Divider() }
                                .modifier(ConflictRowInteractions(
                                    folders: [p.first, p.second],
                                    displayName: displayName,
                                    navigation: vm.navigationStore,
                                    localization: localization,
                                    dismissAction: { vm.dismissConflict(p) }
                                ))
                        }
                    }
                }
            }

            if !predictedPairs.isEmpty {
                UpdateSectionDisclosure(title: "\(localization.L(L10n.Conflicts.predictedBadge)) (\(predictedPairs.count))",
                                        icon: AppDesign.Status.warning.symbol,
                                        iconTint: AppDesign.Color.warning,
                                        isExpanded: expandedBinding($predictedExpanded)) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(predictedPairs, id: \.self) { p in
                            predictedRow(p)
                                .padding(.vertical, AppDesign.Spacing.xs)
                                .overlay(alignment: .bottom) { Divider() }
                                .modifier(ConflictRowInteractions(
                                    folders: [p.first, p.second],
                                    displayName: displayName,
                                    navigation: vm.navigationStore,
                                    localization: localization,
                                    dismissAction: { vm.dismissConflict(p) }
                                ))
                        }
                    }
                }
            }

            if !declaredPairs.isEmpty {
                UpdateSectionDisclosure(title: "\(localization.L(L10n.Conflicts.declaredByYou)) (\(declaredPairs.count))",
                                        icon: "flag.fill",
                                        iconTint: AppDesign.Color.info,
                                        isExpanded: expandedBinding($declaredExpanded)) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(declaredPairs, id: \.self) { p in
                            declaredRow(p)
                                .padding(.vertical, AppDesign.Spacing.xs)
                                .overlay(alignment: .bottom) { Divider() }
                                .modifier(ConflictRowInteractions(
                                    folders: [p.first, p.second],
                                    displayName: displayName,
                                    navigation: vm.navigationStore,
                                    localization: localization,
                                    dismissAction: { vm.dismissConflict(p) }
                                ))
                        }
                    }
                }
            }

            if !filteredDismissedPairs.isEmpty {
                let dismissedTitle = String(format: localization.L(L10n.Conflicts.dismissedCount),
                                            filteredDismissedPairs.count)
                UpdateSectionDisclosure(title: dismissedTitle,
                                        icon: "eye.slash",
                                        iconTint: .secondary,
                                        isExpanded: expandedBinding($dismissedExpanded)) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredDismissedPairs, id: \.self) { p in
                            dismissedRow(p)
                                .padding(.vertical, AppDesign.Spacing.xs)
                                .overlay(alignment: .bottom) { Divider() }
                        }
                    }
                }
            }

            if !isSearching {
                let orphanPairs = vm.modConflictVerdicts.orphans(among: installedMods.map(\.folderName))
                if !orphanPairs.isEmpty {
                    Text(String(format: localization.L(L10n.Conflicts.orphans), orphanPairs.count))
                        .font(AppDesign.Font.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        let (icon, tint, text): (String, Color, String) = {
            if vm.smapiLogDate == nil {
                return (AppDesign.Status.info.symbol, .secondary, localization.L(L10n.Conflicts.noLogRead))
            } else if vm.contentPatcherConflicts.isEmpty {
                return (AppDesign.Status.ok.symbol, AppDesign.Status.ok.tint, localization.L(L10n.Conflicts.noneObserved))
            } else {
                return (AppDesign.Status.info.symbol, AppDesign.Color.info, localization.L(L10n.Conflicts.allDismissed))
            }
        }()

        HStack(spacing: AppDesign.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(text)
                .font(AppDesign.Font.body(.medium))
            Spacer()
        }
        .padding(.horizontal, AppDesign.Spacing.md)
        .padding(.vertical, AppDesign.Spacing.sm)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: AppDesign.Radius.md))
    }

    // MARK: - Buttons & Badges

    func dismissButton(for pair: ModConflictPair) -> some View {
        Button(localization.L(L10n.Conflicts.dismissButton)) {
            vm.dismissConflict(pair)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .lineLimit(1)
        .fixedSize()
    }

    func detailMenu(_ folders: [String]) -> some View {
        ModPairDetailMenu(folders: folders, name: displayName, navigation: vm.navigationStore, localization: localization)
    }

    func badge(_ text: String, tint: Color = .secondary) -> some View {
        Text(text)
            .font(AppDesign.Font.iconXS(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, AppDesign.Spacing.xs)
            .padding(.vertical, 2)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Rows

    private func betweenPacksRow(_ conflict: LoadConflict) -> some View {
        let names = folders(conflict).map(displayName)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: AppDesign.Spacing.sm) {
                Text(names.joined(separator: " × "))
                    .font(AppDesign.Font.body(.medium))
                    .lineLimit(1).truncationMode(.middle)
                if let label = activeBadgeLabel(for: conflict) {
                    badge(label, tint: AppDesign.Color.error)
                }
                Spacer(minLength: AppDesign.Spacing.sm)
                detailMenu(folders(conflict))
                if let p = pair(conflict) {
                    dismissButton(for: p)
                }
            }
            Text(String(format: localization.L(L10n.Conflicts.asset), conflict.asset))
                .font(AppDesign.Font.caption).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
            if !conflict.affectedPatches.isEmpty {
                Text(String(format: localization.L(L10n.Conflicts.affectedPatches),
                            conflict.affectedPatches.joined(separator: ", ")))
                    .font(AppDesign.Font.footnote).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
        }
    }

    private func withinOnePackRow(_ conflict: LoadConflict) -> some View {
        let name = displayName(folders(conflict).first ?? "")
        return HStack(spacing: AppDesign.Spacing.sm) {
            Text(String(format: localization.L(L10n.Conflicts.withinOne), name))
                .font(AppDesign.Font.body(.medium))
                .lineLimit(1).truncationMode(.middle)
            Spacer(minLength: AppDesign.Spacing.sm)
            detailMenu(folders(conflict))
            if let p = pair(conflict) {
                dismissButton(for: p)
            }
        }
    }

    private func declaredRow(_ pair: ModConflictPair) -> some View {
        HStack(spacing: AppDesign.Spacing.sm) {
            Text("\(displayName(pair.first)) × \(displayName(pair.second))")
                .font(AppDesign.Font.body(.medium))
                .lineLimit(1).truncationMode(.middle)
            Spacer(minLength: AppDesign.Spacing.sm)
            detailMenu([pair.first, pair.second])
            dismissButton(for: pair)
        }
    }

    private func knownRow(_ pair: ModConflictPair) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: AppDesign.Spacing.sm) {
                Text("\(displayName(pair.first)) × \(displayName(pair.second))")
                    .font(AppDesign.Font.body(.medium))
                    .lineLimit(1).truncationMode(.middle)
                Spacer(minLength: AppDesign.Spacing.sm)
                detailMenu([pair.first, pair.second])
                dismissButton(for: pair)
            }
            if let key = KnownIncompatibilities.reasonKey(for: pair, in: installedMods) {
                Text(localization.L(key))
                    .font(AppDesign.Font.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func dismissedRow(_ pair: ModConflictPair) -> some View {
        let title = pair.first == pair.second
            ? displayName(pair.first)
            : "\(displayName(pair.first)) × \(displayName(pair.second))"
        let folders = pair.first == pair.second ? [pair.first] : [pair.first, pair.second]
        return HStack(spacing: AppDesign.Spacing.sm) {
            Text(title)
                .font(AppDesign.Font.body)
                .foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
            Spacer(minLength: AppDesign.Spacing.sm)
            detailMenu(folders)
            Button(localization.L(L10n.PerformanceOverlaps.restore)) {
                vm.restoreConflict(pair)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .lineLimit(1)
            .fixedSize()
        }
        .contextMenu {
            ForEach(folders, id: \.self) { folder in
                Button(displayName(folder)) {
                    vm.navigationStore.openModDetail(folderName: folder, door: .alert(dependency: false))
                }
            }
            Divider()
            Button(localization.L(L10n.PerformanceOverlaps.restore)) {
                vm.restoreConflict(pair)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(localization.L(L10n.PerformanceOverlaps.restore)) {
                vm.restoreConflict(pair)
            }
            .tint(.accentColor)
        }
    }
}

private struct ConflictRowInteractions: ViewModifier {
    let folders: [String]
    let displayName: (String) -> String
    let navigation: NavigationStore
    @ObservedObject var localization: LocalizationStore
    let dismissAction: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .contextMenu {
                ForEach(folders, id: \.self) { folder in
                    Button(displayName(folder)) {
                        navigation.openModDetail(folderName: folder, door: .alert(dependency: false))
                    }
                }
                if let dismissAction {
                    Divider()
                    Button(localization.L(L10n.Conflicts.dismissButton), action: dismissAction)
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if let dismissAction {
                    Button(localization.L(L10n.Conflicts.dismissButton), action: dismissAction)
                        .tint(.secondary)
                }
            }
    }
}
