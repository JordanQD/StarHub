import SwiftUI

/// Finder-style expandable table for config backups grouped by mod.
struct ModConfigBackupsByMod: View {
    @ObservedObject var localization: LocalizationStore
    let groups: [ConfigBackupBrowser.ModGroup]
    @Binding var expanded: Set<String>
    let restore: (ModConfigBackup, ModConfigBackupItem) -> Void
    let compare: (ConfigBackupBrowser.Version) -> Void
    let showRecoverable: () -> Void

    @State private var selection: Set<String> = []

    private struct Row: Identifiable {
        enum Kind {
            case group(ConfigBackupBrowser.ModGroup)
            case version(ConfigBackupBrowser.Version)
        }
        let id: String
        let kind: Kind

        static func group(_ g: ConfigBackupBrowser.ModGroup) -> Self {
            Self(id: "group:\(g.id)", kind: .group(g))
        }
        static func version(_ v: ConfigBackupBrowser.Version) -> Self {
            Self(id: "ver:\(v.id.uuidString)", kind: .version(v))
        }
    }

    var body: some View {
        let versionById = Dictionary(
            uniqueKeysWithValues: groups.flatMap(\.versions).map { ("ver:\($0.id.uuidString)", $0) }
        )

        Table(of: Row.self, selection: $selection) {
            TableColumn(localization.L(L10n.Mods.tableName)) { row in
                switch row.kind {
                case .group(let group):
                    HStack(spacing: 7) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.tint)
                            .frame(width: 16, alignment: .center)
                        Text(group.displayName)
                            .font(AppDesign.Font.body(.medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .help(group.folderName)
                case .version(let version):
                    HStack(spacing: 7) {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                            .frame(width: 16, alignment: .center)
                        Text(version.backup.formattedDate)
                            .font(AppDesign.Font.body)
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                }
            }
            .width(min: 180, ideal: 260)

            TableColumn(localization.L(L10n.Mods.tableType)) { row in
                switch row.kind {
                case .group(let group):
                    Text(subtitle(group))
                        .font(AppDesign.Font.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                case .version(let version):
                    Text(version.item.files.joined(separator: ", "))
                        .font(AppDesign.Font.monoIconXS)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .width(min: 140, ideal: 220)

            TableColumn("") { row in
                if case .version(let version) = row.kind {
                    HStack(spacing: 6) {
                        Spacer(minLength: 0)
                        if version.item.configOnly != nil {
                            Button(localization.L(L10n.ModConfigBackups.compare)) {
                                compare(version)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button(localization.L(L10n.ModConfigBackups.restoreVersion)) {
                                restore(version.backup, version.item)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else {
                            Button(localization.L(L10n.ModConfigBackups.translationsOnly),
                                   action: showRecoverable)
                                .buttonStyle(.link)
                                .font(AppDesign.Font.footnote)
                        }
                    }
                }
            }
            .width(min: 120, ideal: 150)
        } rows: {
            ForEach(groups) { group in
                DisclosureTableRow(Row.group(group), isExpanded: Binding(
                    get: { expanded.contains(group.folderName) },
                    set: { isOpen in
                        if isOpen { expanded.insert(group.folderName) }
                        else { expanded.remove(group.folderName) }
                    }
                )) {
                    ForEach(group.versions) { version in
                        TableRow(Row.version(version))
                    }
                }
            }
        }
        .contextMenu(forSelectionType: String.self) { ids in
            if ids.count == 1, let id = ids.first {
                if let version = versionById[id] {
                    if version.item.configOnly != nil {
                        Button(localization.L(L10n.ModConfigBackups.compare)) { compare(version) }
                        Button(localization.L(L10n.ModConfigBackups.restoreVersion)) {
                            restore(version.backup, version.item)
                        }
                    } else {
                        Button(localization.L(L10n.ModConfigBackups.translationsOnly), action: showRecoverable)
                    }
                } else if id.hasPrefix("group:") {
                    let folder = String(id.dropFirst("group:".count))
                    let isOpen = expanded.contains(folder)
                    Button(localization.L(isOpen ? L10n.Main.collapse : L10n.Main.expand)) {
                        if isOpen { expanded.remove(folder) } else { expanded.insert(folder) }
                    }
                }
            }
        } primaryAction: { ids in
            guard ids.count == 1, let id = ids.first else { return }
            if id.hasPrefix("group:") {
                let folder = String(id.dropFirst("group:".count))
                if expanded.contains(folder) { expanded.remove(folder) } else { expanded.insert(folder) }
            } else if let version = versionById[id], version.item.configOnly != nil {
                compare(version)
            }
        }
    }

    private func subtitle(_ group: ConfigBackupBrowser.ModGroup) -> String {
        let versions = String(format: localization.L(L10n.ModConfigBackups.versions),
                              group.versions.count, group.versions.first?.backup.formattedDate ?? "—")
        guard let parent = group.parentFolderName else { return versions }
        return versions + " — " + String(format: localization.L(L10n.ModConfigBackups.partOfGroup), parent)
    }
}
