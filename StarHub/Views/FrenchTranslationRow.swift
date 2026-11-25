import SwiftUI

/// Native grouped `Form` collapsible section for a Nexus translation status bucket.
struct FrenchTranslationSection<Content: View>: View {
    let title: String
    let style: (color: Color, icon: String)
    let startsOpen: Bool
    @ViewBuilder let content: () -> Content
    @State private var isOpen: Bool?

    private var expanded: Bool { isOpen ?? startsOpen }

    var body: some View {
        Section {
            if expanded {
                content()
            }
        } header: {
            Button {
                withMotion(.snappy) { isOpen = !expanded }
            } label: {
                HStack(spacing: AppDesign.Spacing.xs) {
                    Image(systemName: style.icon)
                        .foregroundStyle(style.color)
                    Text(title)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

/// Native grouped `Form` row for one mod and its Nexus translation hits.
struct FrenchTranslationRow: View {
    var viewModel: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    let mod: ModItem
    let candidate: FrenchTranslationSweep.Candidate
    let status: FrenchTranslationSweep.Status
    let entry: FrenchTranslationSweep.Entry?
    let openMod: () -> Void
    @State private var showLowConfidence = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            HStack(alignment: .center, spacing: AppDesign.Spacing.sm) {
                Text(candidate.name)
                    .font(AppDesign.Font.body(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !candidate.isActive {
                    Text(localization.L(L10n.FrTranslations.paused))
                        .font(AppDesign.Font.iconXS(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(AppDesign.Opacity.medium),
                                    in: RoundedRectangle(cornerRadius: 4))
                }
                if viewModel.translationHub.isBusy(mod.folderName) {
                    ProgressView().controlSize(.small)
                }
                Spacer(minLength: AppDesign.Spacing.sm)
                Button(localization.L(L10n.FrTranslations.openMod), action: openMod)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .fixedSize()
            }

            switch status {
            case .available(let hits):
                availableHitsList(hits)
            case .updateAvailable(let newer):
                hitLine(newer, action: L10n.FrTranslations.update, dismissable: false)
            case .installed, .installedUnverified, .failed, .nothingFound, .notSearched:
                EmptyView()
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button(localization.L(L10n.FrTranslations.openMod), action: openMod)
        }
    }

    @ViewBuilder
    private func availableHitsList(_ hits: [NexusModSearch.Hit]) -> some View {
        let sorted = hits.sorted { rank($0) < rank($1) }
        let confirmed = sorted.filter { confidence($0) == .confirmed }
        let primary = confirmed.isEmpty ? Array(sorted.prefix(2)) : confirmed
        let primaryIds = Set(primary.map(\.id))
        let secondary = sorted.filter { !primaryIds.contains($0.id) }

        VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
            ForEach(Array(primary.enumerated()), id: \.element.id) { index, hit in
                if index > 0 {
                    Divider().padding(.leading, AppDesign.Spacing.md)
                }
                hitLine(hit, action: L10n.FrTranslations.install, dismissable: confidence(hit) != .confirmed)
            }

            if !secondary.isEmpty {
                Divider().padding(.leading, AppDesign.Spacing.md)
                DisclosureGroup(isExpanded: $showLowConfidence) {
                    VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                        ForEach(Array(secondary.enumerated()), id: \.element.id) { index, hit in
                            if index > 0 {
                                Divider().padding(.leading, AppDesign.Spacing.md)
                            }
                            hitLine(hit, action: L10n.FrTranslations.install, dismissable: true)
                        }
                    }
                    .padding(.top, AppDesign.Spacing.xs)
                } label: {
                    Text(String(format: localization.L(L10n.Quarantine.andNMore), Int64(secondary.count)))
                        .font(AppDesign.Font.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, AppDesign.Spacing.md)
            }
        }
    }

    private func confidence(_ hit: NexusModSearch.Hit) -> FrenchTranslationSweep.Confidence {
        entry?.confidence(of: hit, hostName: candidate.name) ?? .nameOnly
    }

    private func rank(_ hit: NexusModSearch.Hit) -> Int {
        switch confidence(hit) {
        case .confirmed: return 0
        case .linkedOnly: return 1
        case .nameOnly: return 2
        }
    }

    @ViewBuilder private func caution(_ hit: NexusModSearch.Hit) -> some View {
        switch confidence(hit) {
        case .confirmed:
            EmptyView()
        case .linkedOnly:
            cautionBadge(localization.L(L10n.FrTranslations.linkedOnly),
                         help: localization.L(L10n.FrTranslations.linkedOnlyHelp))
        case .nameOnly:
            cautionBadge(localization.L(L10n.FrTranslations.byName),
                         help: localization.L(L10n.FrTranslations.byNameHelp))
        }
    }

    private func cautionBadge(_ text: String, help: String) -> some View {
        Text(text)
            .font(AppDesign.Font.iconXS(.medium))
            .foregroundStyle(AppDesign.Color.warning)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(AppDesign.Color.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            .fixedSize()
            .help(help)
    }

    private func hitLine(_ hit: NexusModSearch.Hit, action: String, dismissable: Bool) -> some View {
        let actionTitle = localization.L(action)
        let nexusTitle = localization.L(L10n.Mods.translationOpenNexus)
        let premiumOnly = viewModel.nexusDirectDownloadUnavailable
        return HStack(alignment: .center, spacing: AppDesign.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AppDesign.Spacing.xs) {
                    Text(hit.name)
                        .font(AppDesign.Font.footnote(.medium))
                        .lineLimit(2)
                        .truncationMode(.tail)
                    caution(hit)
                }
                Text(String(format: localization.L(L10n.Mods.translationFromNexus), hit.uploader,
                            hit.updatedAt.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "—"))
                    .font(AppDesign.Font.iconXS)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: AppDesign.Spacing.sm)

            HStack(spacing: AppDesign.Spacing.xs) {
                if !premiumOnly {
                    Button { viewModel.installTranslation(hit, into: mod) } label: {
                        Label(actionTitle, systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.translationHub.isBusy(mod.folderName))
                    .help(actionTitle)

                    Button {
                        if let url = URL(string: "https://www.nexusmods.com/stardewvalley/mods/\(hit.modId)?tab=files") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .iconHelp(nexusTitle)
                } else {
                    Button {
                        if let url = URL(string: "https://www.nexusmods.com/stardewvalley/mods/\(hit.modId)?tab=files") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label(nexusTitle, systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(localization.L(L10n.Mods.premiumOnlyHint))
                }

                if dismissable {
                    Button {
                        if !viewModel.translationSweep.dismiss(hit, for: candidate) {
                            viewModel.log("Translation dismiss failed for « \(hit.name) »", level: .warning)
                        }
                    } label: {
                        Image(systemName: "hand.thumbsdown")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .iconHelp(localization.L(L10n.FrTranslations.notThisOne))
                }
            }
            .fixedSize()
        }
        .padding(.leading, AppDesign.Spacing.md)
    }
}

/// Dismissed Nexus translation hits, collapsible inside `Form().formStyle(.grouped)`.
struct DismissedTranslationHits: View {
    var viewModel: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    @State private var isOpen = false

    var body: some View {
        let dismissals = viewModel.translationSweep.verdicts.dismissals
        if !dismissals.isEmpty {
            Section {
                if isOpen {
                    ForEach(dismissals) { dismissal in
                        let rowTitle = String(format: localization.L(L10n.FrTranslations.dismissedRow),
                                              dismissal.hitName, dismissal.modName)
                        let restoreTitle = localization.L(L10n.FrTranslations.dismissedRestore)
                        HStack(spacing: AppDesign.Spacing.sm) {
                            Text(rowTitle)
                                .font(AppDesign.Font.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: AppDesign.Spacing.sm)
                            Button(restoreTitle) {
                                if !viewModel.translationSweep.restore(dismissal) {
                                    viewModel.log("Translation restore failed for « \(dismissal.hitName) »", level: .warning)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .fixedSize()
                        }
                    }
                }
            } header: {
                Button {
                    withMotion(.snappy) { isOpen.toggle() }
                } label: {
                    HStack(spacing: AppDesign.Spacing.xs) {
                        Image(systemName: "hand.thumbsdown")
                            .foregroundStyle(.secondary)
                        Text(String(format: localization.L(L10n.FrTranslations.dismissedTitle), Int64(dismissals.count)))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } footer: {
                if isOpen {
                    Text(localization.L(L10n.FrTranslations.dismissedExplanation))
                }
            }
        }
    }
}
