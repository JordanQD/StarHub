import SwiftUI

/// Mod Translations hub: Worklist + Nexus sweep, following Apple HIG with
/// native `Form().formStyle(.grouped)`, `.toolbar(placement: .principal)`
/// segmented control, toolbar search, and unified `.bar` bottom status bar.
struct FrenchTranslationsView: View {
    var viewModel: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    @Binding var currentTab: SidebarDestination

    private var store: FrenchTranslationSweepStore { viewModel.translationSweep }

    @State private var mergeStore = TranslationLotMergeStore()
    @State private var showArbitration = false
    @State private var segment: Segment?
    @State private var searchText = ""
    @State private var searchPresented = false
    @AppStorage("frtrWorklistOrder") private var worklistOrder: TranslationWorklist.Order = .remainingKeys

    private enum Segment: Hashable { case worklist, nexus }

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool { !trimmedQuery.isEmpty }

    private var worklistState: ModListScoping.TranslationState {
        let model = viewModel
        return .init(coverage: model.frenchCoverageByMod, stale: model.staleTranslationMods,
                     outdatedKeys: model.outdatedKeysByMod)
    }

    private typealias Row = FrenchTranslationLine
    private var rows: [Row] { viewModel.frenchTranslationLines }

    private var linkProposals: [TranslationLinkProposal] {
        let all = viewModel.translationHub.proposedLinks.values
            .sorted { $0.packFolderName < $1.packFolderName }
        guard isSearching else { return all }
        return all.filter {
            $0.packName.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.packFolderName.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.hostFolderName.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    var body: some View {
        let all = rows
        let mods = viewModel.mods, state = worklistState
        let work = TranslationWorklist.items(in: mods, state: state)
        let untranslated = TranslationWorklist.untranslatedCount(in: mods, state: state)
        let unmeasured = TranslationWorklist.unmeasuredCount(in: mods, pass: viewModel.frenchCoverage)
        let shown = segment ?? (work.isEmpty && unmeasured == 0 ? .nexus : .worklist)

        Group {
            if shown == .worklist {
                worklistContent(items: work, untranslated: untranslated, unmeasured: unmeasured)
            } else {
                nexusContent(all, untranslated: untranslated)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            statusBar(all: all, shown: shown, unmeasured: unmeasured)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppDesign.Color.windowBg)
        .onAppear { if segment == nil { segment = shown } }
        .navigationSubtitle("\(viewModel.activeTranslationLanguage.nativeName) (\(viewModel.activeTranslationLanguage.smapiCode))")
        .searchable(text: $searchText, isPresented: $searchPresented,
                    placement: .toolbar, prompt: localization.L(L10n.Mods.searchMods))
        .background {
            Button(localization.L(L10n.Mods.searchMods)) { searchPresented = true }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker(localization.L(L10n.A11y.frTranslationsList), selection: Binding(
                    get: { shown },
                    set: { segment = $0 }
                )) {
                    Text(String(format: localization.L(L10n.FrTranslations.segmentWorklist), work.count))
                        .tag(Segment.worklist)
                    Text(String(format: localization.L(L10n.FrTranslations.segmentNexus), all.count))
                        .tag(Segment.nexus)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            if shown == .worklist {
                ToolbarItemGroup {
                    Menu {
                        Picker(localization.L(L10n.FrTranslations.sortLabel), selection: $worklistOrder) {
                            Text(localization.L(L10n.FrTranslations.sortKeys)).tag(TranslationWorklist.Order.remainingKeys)
                            Text(localization.L(L10n.FrTranslations.sortPercent)).tag(TranslationWorklist.Order.remainingPercent)
                            Text(localization.L(L10n.FrTranslations.sortName)).tag(TranslationWorklist.Order.name)
                        }
                        .pickerStyle(.inline)
                    } label: {
                        Label(localization.L(L10n.FrTranslations.sortLabel), systemImage: "arrow.up.arrow.down")
                    }
                    .help(localization.L(L10n.FrTranslations.sortLabel))
                    .disabled(work.isEmpty)

                    TranslationLotShuttleView(viewModel: viewModel, localization: localization,
                                              mergeStore: $mergeStore,
                                              onMergeReady: { showArbitration = $0 })
                }
            } else {
                ToolbarItemGroup {
                    if store.isRunning {
                        Button(localization.L(L10n.FrTranslations.cancel)) { store.cancel() }
                    } else {
                        Button {
                            store.run(all.map(\.candidate)) { viewModel.log($0) }
                        } label: {
                            Label(localization.L(L10n.FrTranslations.rescan), systemImage: "arrow.clockwise")
                        }
                        .disabled(all.isEmpty)
                        .help(localization.L(L10n.FrTranslations.rescanHint))
                    }

                    TranslationLotShuttleView(
                        viewModel: viewModel,
                        localization: localization,
                        mergeStore: $mergeStore,
                        onMergeReady: { showArbitration = $0 },
                        onForceRescan: {
                            store.run(all.map(\.candidate), forceAll: true) { viewModel.log($0) }
                        },
                        forceRescanDisabled: all.isEmpty || store.isRunning
                    )
                }
            }

            if #available(macOS 26.0, *) {
                DefaultToolbarItem(kind: .search, placement: .automatic)
            }
        }
        .sheet(isPresented: $showArbitration) {
            TranslationArbitrationSheet(store: mergeStore, viewModel: viewModel,
                                        localization: localization,
                                        freshRows: { mod in
                                            await viewModel.translationDiff(for: mod)
                                        },
                                        onWrote: { _ in },
                                        onClose: {
                                            showArbitration = false
                                            mergeStore.reset()
                                        })
        }
    }

    // MARK: - Worklist Tab

    @ViewBuilder
    private func worklistContent(items: [TranslationWorkItem],
                                 untranslated: Int,
                                 unmeasured: Int) -> some View {
        let filtered = isSearching
            ? items.filter {
                $0.name.localizedCaseInsensitiveContains(trimmedQuery)
                    || $0.folderName.localizedCaseInsensitiveContains(trimmedQuery)
            }
            : items

        if isSearching && filtered.isEmpty && linkProposals.isEmpty {
            searchEmptyState
        } else if !isSearching && items.isEmpty && unmeasured == 0 && linkProposals.isEmpty {
            ContentUnavailableView {
                Label(localization.L(L10n.FrTranslations.worklistEmpty), systemImage: "checkmark.circle")
            } description: {
                if untranslated > 0 {
                    Text(String(format: localization.L(L10n.FrTranslations.worklistUntranslated),
                                untranslated, viewModel.activeTranslationLanguage.nativeName))
                }
            } actions: {
                if untranslated > 0 {
                    Button {
                        segment = .nexus
                    } label: {
                        Label(localization.L(L10n.FrTranslations.worklistSearchNexus), systemImage: "globe")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Form {
                if !linkProposals.isEmpty {
                    linkProposalsSection
                }
                FrenchTranslationsWorklist(localization: localization,
                                           items: filtered,
                                           order: worklistOrder,
                                           untranslated: isSearching ? 0 : untranslated,
                                           unmeasured: isSearching ? 0 : unmeasured,
                                           targetLanguageName: viewModel.activeTranslationLanguage.nativeName,
                                           open: { openMod($0) },
                                           showNexus: { segment = .nexus })
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Nexus Tab

    @ViewBuilder
    private func nexusContent(_ all: [Row], untranslated: Int) -> some View {
        let filtered = isSearching
            ? all.filter {
                $0.candidate.name.localizedCaseInsensitiveContains(trimmedQuery)
                    || $0.mod.folderName.localizedCaseInsensitiveContains(trimmedQuery)
            }
            : all
        let groups = self.groups(filtered)
        let hasRows = groups.contains { !$0.rows.isEmpty }
        let hasDismissed = !isSearching && !viewModel.translationSweep.verdicts.dismissals.isEmpty
        let isNeverSearched = !all.isEmpty && all.allSatisfy { $0.status == .notSearched }

        if isSearching && !hasRows && linkProposals.isEmpty {
            searchEmptyState
        } else if !isSearching && all.isEmpty && linkProposals.isEmpty {
            ContentUnavailableView {
                Label(localization.L(L10n.FrTranslations.title), systemImage: "character.book.closed")
            } description: {
                Text(localization.L(L10n.FrTranslations.subtitle))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !isSearching && isNeverSearched && !store.isRunning
                    && store.stopReason == nil && linkProposals.isEmpty && !hasDismissed {
            ContentUnavailableView {
                Label(localization.L(L10n.FrTranslations.worklistSearchNexus), systemImage: "globe")
            } description: {
                VStack(spacing: AppDesign.Spacing.xs) {
                    if untranslated > 0 {
                        Text(String(format: localization.L(L10n.FrTranslations.worklistUntranslated),
                                    untranslated, viewModel.activeTranslationLanguage.nativeName))
                    }
                    Text(String(format: localization.L(L10n.FrTranslations.never), all.count))
                }
            } actions: {
                Button {
                    store.run(all.map(\.candidate)) { viewModel.log($0) }
                } label: {
                    Label(localization.L(L10n.FrTranslations.worklistSearchNexus), systemImage: "globe")
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Form {
                if let reason = store.stopReason {
                    Section {
                        if reason == .noApiKey {
                            NexusAccessNote(message: stopText(reason), navigation: viewModel.navigationStore,
                                            localization: localization)
                        } else {
                            Label(stopText(reason), systemImage: "exclamationmark.triangle.fill")
                                .font(AppDesign.Font.footnote)
                                .foregroundStyle(reason == .cancelled ? Color.secondary : AppDesign.Color.warning)
                        }
                    }
                }

                if !linkProposals.isEmpty {
                    linkProposalsSection
                }

                ForEach(groups, id: \.key) { group in
                    if !group.rows.isEmpty {
                        FrenchTranslationSection(title: String(format: localization.L(group.key), group.rows.count),
                                                 style: FrenchTranslationsOverview.style(for: group.key),
                                                 startsOpen: isSearching ? true : group.open) {
                            ForEach(group.rows) { row in
                                FrenchTranslationRow(viewModel: viewModel, localization: localization, mod: row.mod,
                                                     candidate: row.candidate, status: row.status,
                                                     entry: store.entry(for: row.candidate.folderName),
                                                     openMod: { openMod(row.mod.folderName) })
                            }
                        }
                        .id(group.key)
                    }
                }

                if hasDismissed {
                    DismissedTranslationHits(viewModel: viewModel, localization: localization)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Shared Sections & Status Bar

    private var linkProposalsSection: some View {
        Section(String(format: localization.L(L10n.Mods.translationLinkCounter), linkProposals.count)) {
            ForEach(linkProposals, id: \.packFolderName) { proposal in
                TranslationLinkProposalCard(vm: viewModel,
                                            localization: localization,
                                            proposal: proposal)
            }
        }
    }

    private var searchEmptyState: some View {
        ContentUnavailableView {
            Label(localization.L(L10n.Discovery.noMatch), systemImage: "magnifyingglass")
        } actions: {
            Button(localization.L(L10n.Discovery.clearSearch)) {
                withMotion(.snappy) { searchText = "" }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func statusBar(all: [Row], shown: Segment, unmeasured: Int) -> some View {
        if shown == .worklist {
            if unmeasured > 0 {
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: AppDesign.Spacing.sm) {
                        ProgressView().controlSize(.mini)
                        Text(String(format: localization.L(L10n.FrTranslations.worklistMeasuring), unmeasured))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, AppDesign.Spacing.xl)
                    .padding(.vertical, AppDesign.Spacing.xs)
                }
                .background(.bar)
            }
        } else if store.isRunning {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: AppDesign.Spacing.sm) {
                    ProgressView(value: Double(store.done), total: Double(max(store.total, 1)))
                        .frame(maxWidth: 160)
                    let progress = String(format: localization.L(L10n.FrTranslations.progress),
                                          store.done, store.total, store.currentNames.joined(separator: " · "))
                    Text(progress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .padding(.horizontal, AppDesign.Spacing.xl)
                .padding(.vertical, AppDesign.Spacing.xs)
            }
            .background(.bar)
        } else if let oldest = store.oldestSearch(among: all.map(\.candidate)) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: AppDesign.Spacing.sm) {
                    Text(summary(all))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Text(oldest.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, AppDesign.Spacing.xl)
                .padding(.vertical, AppDesign.Spacing.xs)
            }
            .background(.bar)
        }
    }

    // MARK: - Helpers

    private func summary(_ all: [Row]) -> String {
        let available = all.filter { if case .available = $0.status { return true }; return false }.count
        let none = all.filter { $0.status == .nothingFound }.count
        return String(format: localization.L(L10n.FrTranslations.summary), all.count, available, none)
    }

    private func stopText(_ reason: FrenchTranslationSweepStore.StopReason) -> String {
        switch reason {
        case .noApiKey:    return localization.L(L10n.FrTranslations.stopNoKey)
        case .rateLimited: return localization.L(L10n.FrTranslations.stopRateLimit)
        case .cancelled:   return localization.L(L10n.FrTranslations.stopCancelled)
        }
    }

    private func groups(_ all: [Row]) -> [(key: String, rows: [Row], open: Bool)] {
        [
            (L10n.FrTranslations.sectionUpdates, all.filter { if case .updateAvailable = $0.status { return true }; return false }, true),
            (L10n.FrTranslations.sectionAvailable, all.filter { if case .available = $0.status { return true }; return false }, true),
            (L10n.FrTranslations.sectionFailed, all.filter { $0.status == .failed }, true),
            (L10n.FrTranslations.sectionUnverified, all.filter { $0.status == .installedUnverified }, false),
            (L10n.FrTranslations.sectionInstalled, all.filter { $0.status == .installed }, false),
            (L10n.FrTranslations.sectionNone, all.filter { $0.status == .nothingFound }, false),
            (L10n.FrTranslations.sectionNotSearched, all.filter { $0.status == .notSearched }, false),
        ]
    }

    private func openMod(_ folderName: String) {
        viewModel.navigationStore.openModDetail(folderName: folderName, door: .frenchTranslations)
    }
}
