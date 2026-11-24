import SwiftUI

/// « Diagnostic & Performances » : Santé · Journal · Performances.
/// Segmented control and per-tab actions live in the native window `.toolbar`;
/// secondary tabs stay mounted after first visit so filters, scroll position,
/// and performance comparison selections survive tab switches.
struct DiagnosticsView: View {
    var viewModel: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    @State private var performance = ProbePerformanceStore()
    @State private var environment = SessionEnvironmentStore()
    @State private var sloDiagnostic: SloDiagnosticSessionStore
    @State private var stardropiumDiagnostic: SloDiagnosticSessionStore
    @State private var mounted: Set<DiagnosticsSegment>

    // Journal toolbar state
    @State private var logSearchText = ""
    @State private var logSearchPresented = false
    @State private var logAutoScroll = true
    @State private var logGroupByMod = false
    @State private var logShowClearConfirm = false
    @State private var logCopyTrigger = 0

    // Performance toolbar state
    @State private var perfComparing = false
    @State private var perfShowBenchmark = false

    init(viewModel: StarHubTHViewModel, localization: LocalizationStore) {
        self.viewModel = viewModel
        self.localization = localization
        _sloDiagnostic = State(initialValue: SloDiagnosticSessionStore(
            applicationSupport: AppSupport.directory,
            logURL: URL(fileURLWithPath: viewModel.smapiLogPath), probeFiles: ProbeFiles()))
        _stardropiumDiagnostic = State(initialValue: SloDiagnosticSessionStore(
            applicationSupport: AppSupport.directory,
            logURL: URL(fileURLWithPath: viewModel.smapiLogPath), probeFiles: ProbeFiles(), kind: .stardropium))
        var initiallyMounted = Set([viewModel.navigationStore.diagnosticsSegment])
        if SloDiagnosticExclusion.blocksOtherPerformanceWork(snapshotDirectory: AppSupport.directory) {
            initiallyMounted.insert(.performance)
        }
        _mounted = State(initialValue: initiallyMounted)
    }

    private var segment: Binding<DiagnosticsSegment> {
        Binding(get: { viewModel.navigationStore.diagnosticsSegment },
                set: { viewModel.navigationStore.diagnosticsSegment = $0 })
    }

    var body: some View {
        let activeSegment = viewModel.navigationStore.diagnosticsSegment
        ZStack {
            tab(.health) {
                DiagnosticsHealthView(viewModel: viewModel, localization: localization)
            }
            tab(.journal) {
                LogsView(viewModel: viewModel,
                         localization: localization,
                         searchText: $logSearchText,
                         searchPresented: $logSearchPresented,
                         autoScroll: $logAutoScroll,
                         groupByMod: $logGroupByMod,
                         showClearConfirm: $logShowClearConfirm,
                         copyTrigger: logCopyTrigger)
            }
            tab(.performance) {
                PerformanceView(viewModel: viewModel,
                                localization: localization,
                                store: performance,
                                environment: environment,
                                sloDiagnostic: sloDiagnostic,
                                stardropiumDiagnostic: stardropiumDiagnostic,
                                comparing: $perfComparing,
                                showBenchmark: $perfShowBenchmark)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppDesign.Color.windowBg)
        .navigationSubtitle(headerSummary)
        .searchable(text: $logSearchText,
                    isPresented: $logSearchPresented,
                    placement: .toolbar,
                    prompt: localization.L(L10n.Logs.searchPlaceholder))
        .background {
            if activeSegment != .performance {
                Button(localization.L(L10n.Logs.searchPlaceholder)) {
                    if activeSegment == .health {
                        viewModel.navigationStore.diagnosticsSegment = .journal
                    }
                    logSearchPresented = true
                }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
                .accessibilityHidden(true)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker(localization.L(L10n.A11y.diagnosticsSegment), selection: segment) {
                    ForEach(DiagnosticsSegment.allCases, id: \.self) { value in
                        Text(label(value)).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            switch activeSegment {
            case .health:
                ToolbarItemGroup {
                    healthToolbarItems
                }
            case .journal:
                ToolbarItemGroup {
                    journalToolbarItems
                }
            case .performance:
                ToolbarItemGroup {
                    performanceToolbarItems
                }
            }

            if #available(macOS 26.0, *) {
                DefaultToolbarItem(kind: .search, placement: .automatic)
            }
        }
        .onChange(of: viewModel.navigationStore.diagnosticsSegment) { _, newValue in
            mounted.insert(newValue)
        }
        .onChange(of: logSearchText) { _, newValue in
            if !newValue.isEmpty, viewModel.navigationStore.diagnosticsSegment == .health {
                viewModel.navigationStore.diagnosticsSegment = .journal
            }
        }
    }

    // MARK: - Toolbar Actions

    @ViewBuilder
    private var healthToolbarItems: some View {
        Button {
            viewModel.refreshSmapiLog()
        } label: {
            if viewModel.isRefreshingSmapiLog {
                ProgressView().controlSize(.small)
            } else {
                Label(localization.L(L10n.Updates.recheckLog), systemImage: "arrow.clockwise")
            }
        }
        .disabled(viewModel.isRefreshingSmapiLog)
        .help(localization.L(L10n.Updates.recheckLog))

        Button {
            viewModel.revealSmapiLogInFinder()
        } label: {
            Label(localization.L(L10n.Logs.healthReveal), systemImage: "folder")
        }
        .help(localization.L(L10n.Logs.healthReveal))

        ModlistReportMenu(vm: viewModel, localization: localization)
    }

    @ViewBuilder
    private var journalToolbarItems: some View {
        Toggle(isOn: $logGroupByMod) {
            Label(localization.L(L10n.Logs.groupByMod),
                  systemImage: logGroupByMod ? "rectangle.grid.1x2.fill" : "rectangle.grid.1x2")
        }
        .help(localization.L(L10n.Logs.groupByMod))

        Toggle(isOn: $logAutoScroll) {
            Label(localization.L(L10n.Logs.autoScrollHint),
                  systemImage: logAutoScroll ? "arrow.down.to.line" : "arrow.down.to.line.compact")
        }
        .help(localization.L(L10n.Logs.autoScrollHint))

        Button {
            logCopyTrigger += 1
        } label: {
            Label(localization.L(L10n.Logs.copyAll), systemImage: "doc.on.clipboard")
        }
        .help(localization.L(L10n.Logs.copyAll))

        Button {
            viewModel.loadSmapiLog()
        } label: {
            Label(localization.L(L10n.Logs.refreshHint), systemImage: "arrow.clockwise")
        }
        .help(localization.L(L10n.Logs.refreshHint))

        Button(role: .destructive) {
            logShowClearConfirm = true
        } label: {
            Label(localization.L(L10n.Logs.clearLogs), systemImage: "trash")
        }
        .help(localization.L(L10n.Logs.clearLogs))
    }

    @ViewBuilder
    private var performanceToolbarItems: some View {
        Picker(localization.L(L10n.Performance.inGameTitle), selection: $perfComparing) {
            Text(localization.L(L10n.PerformanceEvidence.lastSession)).tag(false)
            Text(localization.L(L10n.PerformanceEvidence.compare)).tag(true)
        }
        .pickerStyle(.menu)
        .fixedSize()

        Button {
            perfShowBenchmark = true
        } label: {
            Label(localization.L(L10n.Benchmark.title), systemImage: "gauge.with.dots.needle.67percent")
        }
        .help(localization.L(L10n.Benchmark.title))
    }

    // MARK: - Helpers

    private var headerSummary: String {
        let smapi = viewModel.smapiInstalledVersion.map { "SMAPI \($0)" }
            ?? localization.L(L10n.Logs.headerNoSmapi)
        guard let source = SmapiLogSource(logDate: viewModel.smapiLogDate, isStale: false,
                                          locale: Locale.autoupdatingCurrent) else {
            return "\(smapi) · \(localization.L(L10n.Logs.headerNoLog))"
        }
        return "\(smapi) · " + String(format: localization.L(L10n.Logs.headerLogDate), source.date)
    }

    @ViewBuilder
    private func tab<Content: View>(_ value: DiagnosticsSegment,
                                    @ViewBuilder content: () -> Content) -> some View {
        if !mounted.contains(value) {
            EmptyView()
        } else {
            let shown = viewModel.navigationStore.diagnosticsSegment == value
            content()
                .zIndex(shown ? 1 : 0)
                .opacity(shown ? 1 : 0)
                .allowsHitTesting(shown)
                .disabled(!shown)
                .accessibilityHidden(!shown)
        }
    }

    private func label(_ value: DiagnosticsSegment) -> String {
        switch value {
        case .health:      return localization.L(L10n.Logs.segmentHealth)
        case .journal:     return localization.L(L10n.Logs.segmentJournal)
        case .performance: return localization.L(L10n.Logs.segmentPerformance)
        }
    }
}
