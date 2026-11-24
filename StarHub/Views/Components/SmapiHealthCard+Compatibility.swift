import SwiftUI

extension SmapiHealthCard {

    @ViewBuilder
    var compatibilitySourceBadge: some View {
        switch vm.compatibilitySource {
        case .live:
            pill(text: localization.L(L10n.Mods.compatSourceLive), color: AppDesign.Color.success)
        case .pathoschildDump:
            pill(text: String(format: localization.L(L10n.Mods.compatSourcePathoschild),
                              PathoschildDateLabel.string(from: vm.pathoschildDumpDate)),
                 color: AppDesign.Color.warning)
        case .diskCache:
            pill(text: String(format: localization.L(L10n.Mods.compatSourceCache),
                              PathoschildDateLabel.string(from: vm.pathoschildDumpDate)),
                 color: .secondary)
        case .smapiMetadata:
            pill(text: localization.L(L10n.Mods.compatSourceSmapiLocal), color: .secondary)
        case .none:
            EmptyView()
        }
    }

    private func pill(text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(AppDesign.Font.iconXXS)
            Text(text)
                .font(AppDesign.Font.iconXS(.medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(AppDesignCore.Opacity.medium), in: RoundedRectangle(cornerRadius: AppDesignCore.Radius.sm))
        .foregroundStyle(color)
    }

    @ViewBuilder
    var compatibilityRow: some View {
        let flagged = vm.compatibilityFlaggedMods
        let unknown = vm.compatibilityUnknownCount
        if !flagged.isEmpty || unknown > 0 {
            let title = String(format: localization.L(L10n.Mods.compatHealthFlagged), flagged.count)
            let preview = flagged.isEmpty ? nil : flagged.prefix(3).map(\.name).joined(separator: " · ")
            groupedRow(key: "compatibility",
                       icon: flagged.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                       tint: flagged.isEmpty ? AppDesign.Color.success : AppDesign.Color.error,
                       title: title,
                       preview: preview,
                       defaultOpen: !flagged.isEmpty) {
                compatibilitySourceBadge

                if !flagged.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(flagged.prefix(8), id: \.name) { entry in
                            HStack(alignment: .center, spacing: AppDesign.Spacing.sm) {
                                Text(entry.name)
                                    .font(AppDesign.Font.body(.medium))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(CompatibilityWarning.label(entry.verdict.status, localization))
                                    .font(AppDesign.Font.iconXS(.semibold))
                                    .foregroundStyle(CompatibilityWarning.tint(entry.verdict.status))
                                    .padding(.horizontal, AppDesignCore.Spacing.xs)
                                    .padding(.vertical, 2)
                                    .background(CompatibilityWarning.tint(entry.verdict.status).opacity(0.12),
                                                in: RoundedRectangle(cornerRadius: 4))
                                if let brokeIn = entry.verdict.brokeIn {
                                    Text(String(format: localization.L(L10n.Mods.compatBrokeIn), brokeIn))
                                        .font(AppDesign.Font.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: AppDesign.Spacing.sm)
                                compatActions(entry.folderName, name: entry.name, links: entry.verdict.links)
                            }
                            .padding(.vertical, AppDesign.Spacing.xs)
                            .contextMenu {
                                Button(localization.L(L10n.Logs.healthOpenMod)) {
                                    vm.navigationStore.openModDetail(folderName: entry.folderName, door: .compatibilityCard)
                                }
                                Button(localization.L(L10n.Logs.healthShowInLog)) {
                                    vm.navigationStore.openLog(search: entry.name)
                                }
                                if let link = entry.verdict.links.first, let url = URL(string: link.url) {
                                    Divider()
                                    Button(link.label) { NSWorkspace.shared.open(url) }
                                }
                            }
                        }
                    }
                }

                if unknown > 0 {
                    Text(String(format: localization.L(L10n.Mods.compatHealthUnknown), unknown))
                        .font(AppDesign.Font.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .help(localization.L(L10n.Mods.compatHealthUnknownHelp))
                }
            }
        }
    }

    func compatActions(_ folderName: String, name: String,
                       links: [ModCompatibility.Link]) -> some View {
        HStack(spacing: AppDesign.Spacing.xs) {
            actionButton(AppDesign.openDetailSymbol, help: L10n.Logs.healthOpenMod) {
                vm.navigationStore.openModDetail(folderName: folderName, door: .compatibilityCard)
            }
            if let link = links.first, let url = URL(string: link.url) {
                Button { NSWorkspace.shared.open(url) } label: {
                    Image(systemName: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .iconHelp(link.label)
            }
            actionButton("text.magnifyingglass", help: L10n.Logs.healthShowInLog) {
                vm.navigationStore.openLog(search: name)
            }
        }
    }
}
