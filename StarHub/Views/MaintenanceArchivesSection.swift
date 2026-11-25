import SwiftUI

/// Native grouped `Form` section for kept Nexus archives, grouped by mod.
struct MaintenanceArchivesSection: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    let keepNexusArchives: Bool
    let onPurgeAll: () -> Void
    let onDelete: (NexusArchiveEntry) -> Void

    var body: some View {
        if keepNexusArchives || !vm.nexusArchives.isEmpty {
            Section {
                if vm.nexusArchives.isEmpty {
                    Text(localization.L(keepNexusArchives
                              ? L10n.Maintenance.archivesEmptyOn
                              : L10n.Maintenance.archivesEmptyOff))
                        .font(AppDesign.Font.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(NexusArchiveGroups.group(vm.nexusArchives)) { group in
                        groupRow(group)
                    }
                }
            } header: {
                HStack(spacing: AppDesign.Spacing.sm) {
                    Text(localization.L(L10n.Maintenance.archivesTitle))
                    Spacer()
                    if !vm.nexusArchives.isEmpty {
                        Text(String(format: localization.L(L10n.Maintenance.archivesCount),
                                    vm.nexusArchives.count,
                                    SharedFormatters.bytes(vm.nexusArchives.reduce(0) { $0 + $1.byteSize })))
                            .font(AppDesign.Font.footnote)
                            .foregroundStyle(.secondary)
                            .textCase(nil)

                        Button(role: .destructive, action: onPurgeAll) {
                            Label(localization.L(L10n.Maintenance.archivesPurge), systemImage: "trash")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .foregroundStyle(AppDesign.Color.error)
                        .textCase(nil)
                    }
                }
            }
        }
    }

    private func groupRow(_ group: NexusArchiveGroup) -> some View {
        let installed = group.entries.first.flatMap { vm.scanStore.mods.mod(withUniqueId: $0.uniqueId) }
        return DisclosureGroup {
            ForEach(group.entries) { entry in
                HStack(spacing: AppDesign.Spacing.sm) {
                    Text("\(entry.version) · \(SharedFormatters.bytes(entry.byteSize)) · "
                         + entry.timestamp.formatted(date: .abbreviated, time: .omitted))
                        .font(AppDesign.Font.monoIconXS)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        vm.reinstallFromArchive(entry)
                    } label: {
                        Label(localization.L(L10n.Maintenance.archivesReinstall), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(role: .destructive) {
                        onDelete(entry)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(AppDesign.Color.error)
                    }
                    .buttonStyle(.borderless)
                    .help(localization.L(L10n.Maintenance.archivesDelete))
                }
                .padding(.vertical, 2)
            }
        } label: {
            HStack(spacing: AppDesign.Spacing.sm) {
                Text(group.modName)
                    .font(AppDesign.Font.body(.medium))
                if let installed {
                    Button {
                        vm.navigationStore.openModDetail(folderName: installed.folderName, door: .nexusUpdate)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderless)
                    .help(localization.L(L10n.Health.actionOpenMod))
                }
                Spacer()
                if group.entries.count > 1 {
                    Text(String(format: localization.L(L10n.Maintenance.archivesVersions),
                                Int64(group.entries.count), SharedFormatters.bytes(group.totalBytes)))
                        .font(AppDesign.Font.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
