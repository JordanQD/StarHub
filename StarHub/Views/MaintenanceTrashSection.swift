import SwiftUI

/// Native grouped `Form` section for the deleted-mods trash.
struct MaintenanceTrashSection: View {
    var viewModel: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    let onPurgeAll: (Int) -> Void
    let onPurgeEntry: (_ event: String, _ entry: String) -> Void

    @State private var expandedTrashEvents: Set<String> = []
    private static let trashPreviewCount = 8

    var body: some View {
        if !viewModel.trashEvents.isEmpty {
            Section {
                ForEach(viewModel.trashEvents) { event in
                    eventRow(event)
                }
            } header: {
                HStack {
                    Text(localization.L(L10n.Maintenance.trashSectionTitle))
                    Spacer()
                    Button(role: .destructive) {
                        onPurgeAll(viewModel.trashEvents.count)
                    } label: {
                        Label(localization.L(L10n.Maintenance.trashPurgeAll), systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .foregroundStyle(AppDesign.Color.error)
                }
            } footer: {
                Text(localization.L(L10n.Maintenance.trashHint2))
            }
        }
    }

    private func eventRow(_ event: ModTrash.Event) -> some View {
        let expanded = expandedTrashEvents.contains(event.folderName)
        let shown = expanded ? event.entries : Array(event.entries.prefix(Self.trashPreviewCount))

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: AppDesign.Spacing.sm) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
                Text(event.date.map {
                    $0.formatted(date: .abbreviated, time: .shortened)
                } ?? event.folderName)
                    .font(AppDesign.Font.caption(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if event.entries.count > 1 {
                    let title = String(format: localization.L(L10n.Maintenance.trashRestoreEvent),
                                       Int64(event.entries.count))
                    Button {
                        viewModel.restoreTrashEvent(event.folderName)
                    } label: {
                        Label(title, systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            ForEach(shown, id: \.self) { entry in
                HStack(spacing: AppDesign.Spacing.sm) {
                    Text(entry)
                        .font(AppDesign.Font.monoCaption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button {
                        viewModel.restoreTrashEntry(event: event.folderName, entry: entry)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.borderless)
                    .help(localization.L(L10n.Maintenance.trashRestore))

                    Button(role: .destructive) {
                        onPurgeEntry(event.folderName, entry)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(AppDesign.Color.error)
                    }
                    .buttonStyle(.borderless)
                    .help(localization.L(L10n.Maintenance.trashPurgeOne))
                }
                .padding(.leading, AppDesign.Spacing.md)
            }

            if event.entries.count > Self.trashPreviewCount {
                Button(expanded
                       ? localization.L(L10n.Maintenance.trashShowLess)
                       : String(format: localization.L(L10n.Maintenance.trashShowMore),
                                Int64(event.entries.count - Self.trashPreviewCount))) {
                    if expanded {
                        expandedTrashEvents.remove(event.folderName)
                    } else {
                        expandedTrashEvents.insert(event.folderName)
                    }
                }
                .buttonStyle(.link)
                .controlSize(.small)
                .padding(.leading, AppDesign.Spacing.md)
            }
        }
        .padding(.vertical, 2)
    }
}
