import SwiftUI

/// Short ISO date label for the Pathoschild dump ("2026-08-30").
enum PathoschildDateLabel {
    static func string(from date: Date?) -> String {
        guard let date else { return "—" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

/// Unified macOS System Settings–style grouped diagnostic list for SMAPI health.
/// Each diagnostic category renders as a crisp row inside a single grouped card,
/// showing a 1-line mod preview while collapsed and expanding inline on click.
struct SmapiHealthCard: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore

    @State private var expanded: [String: Bool] = [:]

    var diagnostics: SmapiDiagnostics { vm.smapiDiagnostics ?? SmapiDiagnostics() }

    var showBlock: (String) -> Void = { _ in }
    var showBisection: () -> Void = {}
    private var suggestions: [HealthSuggestion] {
        HealthSuggestion.list(from: diagnostics, localized: localization.L)
    }

    func isExpanded(_ key: String, defaultOpen: Bool) -> Bool {
        expanded[key] ?? defaultOpen
    }

    func toggleExpanded(_ key: String, defaultOpen: Bool) {
        withMotion(.snappy) {
            expanded[key] = !isExpanded(key, defaultOpen: defaultOpen)
        }
    }

    private var hasCompatibilityRow: Bool {
        !vm.compatibilityFlaggedMods.isEmpty || vm.compatibilityUnknownCount > 0
    }

    private var logSectionMenuItems: [(titleKey: String, logHeader: String)] {
        var items: [(String, String)] = []
        if !diagnostics.brokenMods.isEmpty { items.append((L10n.Logs.healthBroken, "Broken mods")) }
        if !diagnostics.saveSerializerMods.isEmpty { items.append((L10n.Logs.healthSaveSerializer, "Changed save serializer")) }
        if !diagnostics.patchedMods.isEmpty { items.append((L10n.Logs.healthPatched, "Patched game code")) }
        if !diagnostics.consoleMods.isEmpty { items.append((L10n.Logs.healthConsole, "Direct console access")) }
        return items
    }

    private var hasAnyDiagnosticRow: Bool {
        !diagnostics.skipped.isEmpty
            || !diagnostics.failed.isEmpty
            || !diagnostics.brokenMods.isEmpty
            || hasCompatibilityRow
            || !diagnostics.externalConflicts.isEmpty
            || !diagnostics.topErrorMods.isEmpty
            || !diagnostics.recurringWarnings.isEmpty
            || !diagnostics.saveSerializerMods.isEmpty
            || !diagnostics.patchedMods.isEmpty
            || !diagnostics.consoleMods.isEmpty
            || !diagnostics.benignNotices.isEmpty
    }

    var body: some View {
        Group {
            if !suggestions.isEmpty {
                Section(localization.L(L10n.Logs.healthSuggestionsTitle)) {
                    HealthSuggestionsList(viewModel: vm, localization: localization, suggestions: suggestions,
                                          showBlock: showBlock,
                                          showBisection: showBisection)
                }
                .id("suggestions")
            }

            if hasAnyDiagnosticRow {
                Section {
                    if !diagnostics.skipped.isEmpty {
                        issueRow(L10n.Logs.healthSkipped, key: "skipped",
                                 items: diagnostics.skipped, severity: AppDesign.Color.error)
                            .id("blocking")
                    }
                    if !diagnostics.failed.isEmpty {
                        issueRow(L10n.Logs.healthFailed, key: "failed",
                                 items: diagnostics.failed, severity: AppDesign.Color.error)
                    }
                    if !diagnostics.brokenMods.isEmpty {
                        modCategoryRow(L10n.Logs.healthBroken, key: "broken",
                                       explanation: L10n.Logs.healthExpBroken,
                                       mods: diagnostics.brokenMods,
                                       icon: "xmark.octagon.fill",
                                       tint: AppDesign.Color.error,
                                       defaultOpen: true)
                    }
                    if hasCompatibilityRow {
                        compatibilityRow
                    }
                    if !diagnostics.externalConflicts.isEmpty {
                        externalConflictsRow
                    }
                    if !diagnostics.topErrorMods.isEmpty {
                        topErrorsRow
                    }
                    if !diagnostics.recurringWarnings.isEmpty {
                        recurringWarningsRow
                    }
                    if !diagnostics.saveSerializerMods.isEmpty {
                        modCategoryRow(L10n.Logs.healthSaveSerializer, key: "saveSerializer",
                                       explanation: L10n.Logs.healthExpSave,
                                       mods: diagnostics.saveSerializerMods,
                                       icon: "exclamationmark.triangle.fill",
                                       tint: AppDesign.Color.warning,
                                       defaultOpen: false)
                            .id("advisory")
                    }
                    if !diagnostics.patchedMods.isEmpty {
                        modCategoryRow(L10n.Logs.healthPatched, key: "patched",
                                       explanation: L10n.Logs.healthExpPatched,
                                       mods: diagnostics.patchedMods,
                                       icon: "exclamationmark.triangle.fill",
                                       tint: AppDesign.Color.warning,
                                       defaultOpen: false)
                    }
                    if !diagnostics.consoleMods.isEmpty {
                        modCategoryRow(L10n.Logs.healthConsole, key: "console",
                                       explanation: L10n.Logs.healthExpConsole,
                                       mods: diagnostics.consoleMods,
                                       icon: "exclamationmark.triangle.fill",
                                       tint: AppDesign.Color.warning,
                                       defaultOpen: false)
                    }
                    if !diagnostics.benignNotices.isEmpty {
                        benignRow
                            .id("benign")
                    }
                } header: {
                    HStack(alignment: .center, spacing: AppDesign.Spacing.sm) {
                        Text(localization.L(L10n.Logs.logsShort))
                        Spacer()
                        if !logSectionMenuItems.isEmpty {
                            Menu {
                                ForEach(logSectionMenuItems, id: \.logHeader) { item in
                                    Button(localization.L(item.titleKey)) {
                                        vm.navigationStore.openLog(section: item.logHeader)
                                    }
                                }
                            } label: {
                                Label(localization.L(L10n.Logs.healthShowSection), systemImage: "doc.text")
                            }
                            .menuStyle(.borderedButton)
                            .controlSize(.small)
                            .fixedSize()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Grouped Row Container

    func groupedRow<Content: View>(key: String,
                                   icon: String,
                                   tint: Color,
                                   title: String,
                                   count: Int? = nil,
                                   subtitle: String? = nil,
                                   preview: String? = nil,
                                   defaultOpen: Bool,
                                   @ViewBuilder content: () -> Content) -> some View {
        let open = isExpanded(key, defaultOpen: defaultOpen)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                toggleExpanded(key, defaultOpen: defaultOpen)
            } label: {
                HStack(alignment: .center, spacing: AppDesign.Spacing.md) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(tint)
                        .frame(width: 22, alignment: .center)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: AppDesign.Spacing.xs) {
                            Text(title)
                                .font(AppDesign.Font.body(.medium))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: true, vertical: false)
                            if let count {
                                Text("\(count)")
                                    .font(AppDesign.Font.body(.medium))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            if let subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(AppDesign.Font.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .padding(.leading, AppDesign.Spacing.xs)
                                    .help(subtitle)
                            }
                        }
                        if !open, let preview, !preview.isEmpty {
                            Text(preview)
                                .font(AppDesign.Font.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }

                    Spacer(minLength: AppDesign.Spacing.sm)

                    Image(systemName: open ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                    content()
                }
                .padding(.leading, 34)
                .padding(.top, AppDesign.Spacing.sm)
                .padding(.bottom, 2)
            }
        }
    }

    // MARK: - Rows

    private var externalConflictsRow: some View {
        groupedRow(key: "externalConflicts",
                   icon: "bolt.trianglebadge.exclamationmark.fill",
                   tint: AppDesign.Color.warning,
                   title: localization.L(L10n.Logs.healthConflicts),
                   count: diagnostics.externalConflicts.count,
                   preview: diagnostics.externalConflicts.first,
                   defaultOpen: true) {
            VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                ForEach(diagnostics.externalConflicts, id: \.self) { conflict in
                    Text(conflict)
                        .font(AppDesign.Font.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var topErrorsRow: some View {
        let preview = diagnostics.topErrorMods.prefix(3).map(\.name).joined(separator: " · ")
        return groupedRow(key: "topErrors",
                          icon: "chart.bar.fill",
                          tint: AppDesign.Color.error,
                          title: localization.L(L10n.Logs.healthTopErrors),
                          count: diagnostics.topErrorMods.count,
                          preview: preview,
                          defaultOpen: true) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(diagnostics.topErrorMods) { entry in
                    HStack(spacing: AppDesign.Spacing.sm) {
                        Text(entry.name)
                            .font(AppDesign.Font.body)
                            .lineLimit(1).truncationMode(.tail)
                        Text(String(format: localization.L(L10n.Logs.healthErrorsCount), Int64(entry.count)))
                            .font(AppDesign.Font.iconXS(.medium))
                            .foregroundStyle(AppDesign.Color.error)
                            .padding(.horizontal, AppDesignCore.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(AppDesign.Color.error.opacity(AppDesignCore.Opacity.light),
                                        in: RoundedRectangle(cornerRadius: 4))
                        Spacer(minLength: AppDesign.Spacing.sm)
                        modActions(entry.name)
                    }
                    .padding(.vertical, AppDesign.Spacing.xs)
                    .contextMenu { modContextMenu(entry.name) }
                }
            }
        }
    }

    private var benignRow: some View {
        let preview = diagnostics.benignNotices.compactMap(\.mod).prefix(3).joined(separator: " · ")
        return groupedRow(key: "benign",
                          icon: "checkmark.circle.fill",
                          tint: AppDesign.Color.success,
                          title: localization.L(L10n.Logs.healthBenign),
                          count: diagnostics.benignNotices.count,
                          preview: preview,
                          defaultOpen: false) {
            Text(localization.L(L10n.Logs.healthExpBenign))
                .font(AppDesign.Font.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                ForEach(diagnostics.benignNotices) { notice in
                    VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                        if let mod = notice.mod {
                            HStack(spacing: AppDesign.Spacing.sm) {
                                Text(mod)
                                    .font(AppDesign.Font.body(.medium))
                                    .lineLimit(1).truncationMode(.tail)
                                if notice.count > 1 {
                                    Text("×\(notice.count)")
                                        .font(AppDesign.Font.iconXS(.medium))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.secondary.opacity(AppDesignCore.Opacity.light),
                                                    in: RoundedRectangle(cornerRadius: 4))
                                }
                                Spacer(minLength: AppDesign.Spacing.sm)
                                modActions(mod)
                            }
                        }
                        Text(benignText(notice))
                            .font(AppDesign.Font.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if !notice.sample.isEmpty {
                            Text(notice.sample)
                                .font(AppDesign.Font.monoFootnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .padding(AppDesign.Spacing.xs)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: AppDesign.Radius.sm))
                        }
                    }
                    .contextMenu {
                        if let mod = notice.mod { modContextMenu(mod) }
                    }
                }
            }
        }
    }

    private func modCategoryRow(_ titleKey: String,
                                key: String,
                                explanation: String,
                                mods: [String],
                                icon: String,
                                tint: Color,
                                defaultOpen: Bool) -> some View {
        let preview = mods.prefix(3).joined(separator: " · ")
        return groupedRow(key: key,
                          icon: icon,
                          tint: tint,
                          title: localization.L(titleKey),
                          count: mods.count,
                          subtitle: localization.L(explanation),
                          preview: preview,
                          defaultOpen: defaultOpen) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(mods.prefix(Self.maxListedMods), id: \.self) { mod in
                    HStack(spacing: AppDesign.Spacing.sm) {
                        Text(mod)
                            .font(AppDesign.Font.body)
                            .lineLimit(1).truncationMode(.tail)
                        Spacer(minLength: AppDesign.Spacing.sm)
                        modActions(mod)
                    }
                    .padding(.vertical, AppDesign.Spacing.xs)
                    .contextMenu { modContextMenu(mod) }
                }
            }

            if mods.count > Self.maxListedMods {
                Text(String(format: localization.L(L10n.Logs.healthAndMore), Int64(mods.count - Self.maxListedMods)))
                    .font(AppDesign.Font.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func issueRow(_ titleKey: String,
                          key: String,
                          items: [SmapiDiagnostics.Issue],
                          severity: Color) -> some View {
        let preview = items.prefix(3).map(\.name).joined(separator: " · ")
        return groupedRow(key: key,
                          icon: "xmark.octagon.fill",
                          tint: severity,
                          title: localization.L(titleKey),
                          count: items.count,
                          preview: preview,
                          defaultOpen: true) {
            VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                ForEach(items) { issue in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: AppDesign.Spacing.sm) {
                            Text(issue.name)
                                .font(AppDesign.Font.body(.medium))
                                .lineLimit(1).truncationMode(.tail)
                            Spacer(minLength: AppDesign.Spacing.sm)
                            modActions(issue.name)
                        }
                        Text(issue.reason)
                            .font(AppDesign.Font.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .contextMenu { modContextMenu(issue.name) }
                }
            }
        }
    }

    private static let maxListedMods = 8

    func modActions(_ mod: String) -> some View {
        HStack(spacing: AppDesign.Spacing.xs) {
            actionButton(AppDesign.openDetailSymbol, help: L10n.Logs.healthOpenMod) {
                NotificationCenter.default.post(name: .jumpToMod, object: mod)
            }
            actionButton("text.magnifyingglass", help: L10n.Logs.healthShowInLog) {
                vm.navigationStore.openLog(search: mod)
            }
        }
    }

    @ViewBuilder
    func modContextMenu(_ mod: String) -> some View {
        Button(localization.L(L10n.Logs.healthOpenMod)) {
            NotificationCenter.default.post(name: .jumpToMod, object: mod)
        }
        Button(localization.L(L10n.Logs.healthShowInLog)) {
            vm.navigationStore.openLog(search: mod)
        }
    }

    func actionButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .iconHelp(localization.L(help))
    }

    private func benignText(_ notice: SmapiDiagnostics.BenignNotice) -> String {
        switch notice.kind {
        case .galaxyAuth:         return localization.L(L10n.Logs.healthBenignGalaxy)
        case .apiIntegration:     return localization.L(L10n.Logs.healthBenignApiGeneric)
        case .optionalModMissing: return localization.L(L10n.Logs.healthBenignOptionalGeneric)
        case .modContentParse:    return localization.L(L10n.Logs.healthBenignParseGeneric)
        }
    }
}
