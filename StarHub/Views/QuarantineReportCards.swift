import SwiftUI

/// Quarantined items currently on disk, grouped by quarantine rule/reason so
/// repetitive OS metadata entries (such as `.DS_Store` across many mods) collapse
/// into a single clean disclosure row inside a native grouped `Form` section.
struct QuarantineOnDiskCard: View {
    let entries: [ModTrash.QuarantineEntry]
    @ObservedObject var localization: LocalizationStore

    private struct RuleGroup: Identifiable {
        let id: String
        let rule: String
        let entries: [ModTrash.QuarantineEntry]

        var fileCount: Int {
            entries.reduce(0) { $0 + max(1, $1.removedItems.count) }
        }

        var anyStillInMods: Bool {
            entries.contains(where: \.stillInMods)
        }

        /// Deduplicated compact preview of affected mods/items while collapsed.
        var preview: String {
            var seen = Set<String>()
            var uniqueNames: [String] = []
            for entry in entries {
                if seen.insert(entry.name).inserted {
                    uniqueNames.append(entry.name)
                }
            }
            let shown = uniqueNames.prefix(4).joined(separator: " · ")
            if uniqueNames.count > 4 {
                return "\(shown) …"
            }
            return shown
        }
    }

    private var groupedByRule: [RuleGroup] {
        var order: [String] = []
        var buckets: [String: [ModTrash.QuarantineEntry]] = [:]
        for entry in entries {
            let key = Self.primaryRule(for: entry)
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(entry)
        }
        return order.map { key in
            RuleGroup(id: key.isEmpty ? "__other__" : key,
                      rule: key,
                      entries: buckets[key] ?? [])
        }
    }

    private static func primaryRule(for entry: ModTrash.QuarantineEntry) -> String {
        for reason in entry.reasons {
            let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return ""
    }

    var body: some View {
        Section {
            ForEach(groupedByRule) { group in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                        ForEach(group.entries) { entry in
                            entryRow(entry)
                        }
                        if group.anyStillInMods {
                            Text(localization.L(L10n.Quarantine.entryStillInMods))
                                .font(AppDesign.Font.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.top, AppDesign.Spacing.xs)
                        }
                    }
                    .padding(.vertical, AppDesign.Spacing.xs)
                } label: {
                    HStack(alignment: .center, spacing: AppDesign.Spacing.md) {
                        Image(systemName: "archivebox.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .frame(width: 20, alignment: .center)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: AppDesign.Spacing.xs) {
                                Text(group.rule.isEmpty ? localization.L(L10n.Quarantine.onDiskTitle) : group.rule)
                                    .font(AppDesign.Font.body(.medium))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Text("\(group.fileCount)")
                                    .font(AppDesign.Font.body(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            if !group.preview.isEmpty {
                                Text(group.preview)
                                    .font(AppDesign.Font.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            Text(localization.L(L10n.Quarantine.onDiskTitle))
        }
    }

    private func entryRow(_ entry: ModTrash.QuarantineEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppDesign.Spacing.sm) {
            Text(entry.name)
                .font(AppDesign.Font.body)
                .lineLimit(1)
                .truncationMode(.middle)
            if !entry.removedItems.isEmpty {
                Text(removedSummary(entry.removedItems))
                    .font(AppDesign.Font.monoFootnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: AppDesign.Spacing.sm)
            Text(entry.date.map { DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short) }
                 ?? entry.folder)
                .font(AppDesign.Font.footnote)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    private func removedSummary(_ items: [String]) -> String {
        let shown = items.prefix(3).joined(separator: ", ")
        guard items.count > 3 else { return shown }
        return shown + " " + String(format: localization.L(L10n.Quarantine.andNMore), items.count - 3)
    }
}

/// Last in-memory repair report rendered as native `Form` sections:
/// quarantined items (grouped by rule), duplicates, and folders to review.
struct RepairReportCard: View {
    let report: ModFolderRepairer.Report
    @ObservedObject var localization: LocalizationStore
    let gameDir: String

    private struct DuplicateRow: Identifiable {
        let id: String
        let duplicate: ModFolderRepairer.Duplicate
    }

    private struct QuarantinedRuleGroup: Identifiable {
        let id: String
        let reason: String
        let paths: [String]
    }

    private var quarantinedGroups: [QuarantinedRuleGroup] {
        var order: [String] = []
        var buckets: [String: [String]] = [:]
        for item in report.quarantined {
            let key = item.reason.trimmingCharacters(in: .whitespacesAndNewlines)
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(item.relativePath)
        }
        return order.map { key in
            QuarantinedRuleGroup(id: key.isEmpty ? "__other__" : key,
                                 reason: key,
                                 paths: buckets[key] ?? [])
        }
    }

    private func duplicateRows(from duplicates: [ModFolderRepairer.Duplicate]) -> [DuplicateRow] {
        Array(duplicates.prefix(20).enumerated()).map { offset, dup in
            DuplicateRow(id: "\(offset)-\(dup.uniqueId)-\(dup.enabledFolder)-\(dup.disabledFolder)", duplicate: dup)
        }
    }

    var body: some View {
        Group {
            if !report.quarantined.isEmpty { quarantinedSection }
            if !report.duplicates.isEmpty { duplicatesSection }
            if !report.reviewItems.isEmpty { reviewSection }
        }
    }

    private var quarantinedSection: some View {
        Section(String(format: localization.L(L10n.Quarantine.itemsQuarantined), Int64(report.quarantined.count))) {
            ForEach(quarantinedGroups) { group in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                        ForEach(group.paths.prefix(20), id: \.self) { path in
                            Text(path)
                                .font(AppDesign.Font.monoFootnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if group.paths.count > 20 {
                            Text(String(format: localization.L(L10n.Quarantine.andNMore), Int64(group.paths.count - 20)))
                                .font(AppDesign.Font.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, AppDesign.Spacing.xs)
                } label: {
                    HStack(spacing: AppDesign.Spacing.md) {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .frame(width: 20, alignment: .center)
                        Text(group.reason.isEmpty ? localization.L(L10n.Quarantine.tileQuarantined) : group.reason)
                            .font(AppDesign.Font.body(.medium))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text("\(group.paths.count)")
                            .font(AppDesign.Font.body(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .id(RepairReportSection.quarantined)
    }

    private var duplicatesSection: some View {
        Section(String(format: localization.L(L10n.Quarantine.duplicatesFound), Int64(report.duplicates.count))) {
            ForEach(duplicateRows(from: report.duplicates)) { row in
                HStack(alignment: .center, spacing: AppDesign.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppDesign.Color.warning)
                        .frame(width: 20, alignment: .center)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.duplicate.uniqueId)
                            .font(AppDesign.Font.monoCaption)
                        Text("\(row.duplicate.enabledFolder)  ⇄  \(row.duplicate.disabledFolder)")
                            .font(AppDesign.Font.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            if report.duplicates.count > 20 {
                Text(String(format: localization.L(L10n.Quarantine.andNMore), Int64(report.duplicates.count - 20)))
                    .font(AppDesign.Font.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .id(RepairReportSection.duplicates)
    }

    private var reviewSection: some View {
        Section {
            ForEach(report.reviewItems, id: \.relativePath) { item in
                HStack(spacing: AppDesign.Spacing.md) {
                    Image(systemName: "folder.badge.questionmark")
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .center)
                    Text(item.relativePath)
                        .font(AppDesign.Font.monoCaption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: AppDesign.Spacing.sm)
                    Button(localization.L(L10n.ModInstall.revealInFinder)) {
                        let full = URL(fileURLWithPath: gameDir)
                            .appendingPathComponent("Mods")
                            .appendingPathComponent(item.relativePath)
                        NSWorkspace.shared.activateFileViewerSelecting([full])
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text(localization.L(L10n.Quarantine.reviewTitle))
        } footer: {
            Text(localization.L(L10n.Quarantine.reviewNote))
        }
        .id(RepairReportSection.review)
    }
}

enum RepairReportSection: Hashable { case quarantined, duplicates, review }
