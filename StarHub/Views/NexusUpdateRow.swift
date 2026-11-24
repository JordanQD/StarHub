import SwiftUI

private enum UpdateCardState {
    case available, snoozed, affirmed
}

private struct NexusUpdateRow: View {
    let row: PendingUpdateRow
    let detail: ModDetailRaw?
    let state: UpdateCardState
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    @State private var showNotes = false

    private var update: NexusUpdateChecker.ModUpdate { row.update }

    var body: some View {
        let extra = vm.nexusModExtras[update.nexusModId]
        let date = detail?.releaseDate(for: update.latestVersion) ?? update.uploadedTime ?? extraDate(extra)
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack(alignment: .center, spacing: 14) {
                thumbnail(detail?.pictureURL ?? extra?.pictureUrl)
                VStack(alignment: .leading, spacing: 2) {
                    title
                    if let date {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(AppDesign.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                    versions
                    if state == .snoozed {
                        Text(vm.snoozeExpiryLabel(for: update))
                            .font(AppDesign.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                actions
            }

            if let notes = detail?.notes(for: update.latestVersion) {
                HStack(alignment: .bottom, spacing: AppDesign.Spacing.sm) {
                    MarkdownText(notes)
                        .lineLimit(2)
                        .foregroundStyle(.primary.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(localization.L(L10n.Updates.moreNotes)) { showNotes = true }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .fixedSize()
                        .popover(isPresented: $showNotes, arrowEdge: .bottom) {
                            ScrollView {
                                DescriptionBlocksView(blocks: DescriptionBlockParser.parse(notes),
                                                      vm: vm, localization: localization)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                            }
                            .frame(idealHeight: 240, maxHeight: 390)
                            .frame(width: 380)
                        }
                }
                .font(.system(size: 13))
            } else {
                Text(localization.L(L10n.Updates.noReleaseNotes))
                    .font(AppDesign.Font.footnote)
                    .foregroundStyle(.secondary)
            }

            if state == .available && !row.isLogOnly {
                UpdateAlreadyInstalledNote(update: update, mods: vm.mods, localization: localization)
            }
        }
        .padding(.vertical, AppDesign.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(update.name)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            switch state {
            case .available:
                if let url = update.updateWebsite {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label(localization.L(L10n.Discovery.openNexus), systemImage: "arrow.up.forward.square")
                    }
                    .tint(.accentColor)
                }
            case .snoozed:
                Button {
                    vm.unsnoozeUpdate(uniqueId: row.id)
                } label: {
                    Label(localization.L(L10n.Updates.snoozedWake), systemImage: "bell")
                }
                .tint(.accentColor)
            case .affirmed:
                Button {
                    vm.revealAffirmedUpdate(uniqueId: row.id)
                } label: {
                    Label(localization.L(L10n.Updates.affirmedReveal), systemImage: "eye")
                }
                .tint(.accentColor)
            }
        }
    }

    private var title: some View {
        Group {
            if let mod = row.mod {
                Button(update.name) {
                    vm.navigationStore.openModDetail(folderName: mod.folderName,
                                                     door: state == .affirmed ? .affirmedUpdate : .nexusUpdate)
                }
                .buttonStyle(.plain)
                .clickableCursor()
                .focusRing(cornerRadius: 4)
            } else {
                Text(update.name)
            }
        }
        .font(AppDesign.Font.rowTitle(.semibold))
        .lineLimit(2)
        .multilineTextAlignment(.leading)
        .help(update.name)
    }

    @ViewBuilder
    private var actions: some View {
        switch state {
        case .available:
            NexusUpdateActions(update: update, vm: vm, localization: localization, isLogOnly: row.isLogOnly)
        case .snoozed:
            actionButton(L10n.Updates.snoozedWake, symbol: "bell") {
                vm.unsnoozeUpdate(uniqueId: row.id)
            }
        case .affirmed:
            actionButton(L10n.Updates.affirmedReveal, symbol: "eye", help: L10n.Updates.affirmedRevealHelp) {
                vm.revealAffirmedUpdate(uniqueId: row.id)
            }
        }
    }

    private func actionButton(_ key: String, symbol: String, help: String? = nil,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(localization.L(key))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 14)
                .frame(height: UpdatePillStyle.height)
                .background(UpdatePillStyle.background, in: Capsule())
        }
        .buttonStyle(.plain)
        .focusRing(cornerRadius: FocusRing.capsule)
        .help(localization.L(help ?? key))
        .fixedSize()
    }

    private var versions: some View {
        let installed = row.mod?.version ?? update.installedVersion
        let current = installed.isEmpty ? "—" : installed
        let installedLabel = localization.L(L10n.Updates.installedVersion)
        let latestLabel = localization.L(L10n.Updates.latestVersion)
        let versionAccessibility = state == .affirmed
            ? String(format: localization.L(L10n.Updates.affirmedVersion), update.latestVersion)
            : "\(latestLabel) \(update.latestVersion)"
        return WrapHStack(spacing: 5) {
            Text(current)
            if state != .affirmed || installed != update.latestVersion {
                Image(systemName: "arrow.right").accessibilityHidden(true)
                Text(update.latestVersion)
                    .foregroundStyle(state == .affirmed ? AppDesign.Color.warning : Color.accentColor)
            }
        }
        .font(AppDesign.Font.monoFootnote)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(installedLabel) \(current), \(versionAccessibility)")
    }

    private func thumbnail(_ link: String?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return InitialsAvatar(text: update.name, initialsCount: 2, size: 56,
                              fillColor: Color.accentColor.opacity(AppDesign.Opacity.light),
                              textColor: .accentColor, fontSize: 17)
            .overlay {
                if let link, let url = URL(string: link), url.scheme == "https" || url.scheme == "http" {
                    CachedAsyncImage(url: url).allowsHitTesting(false)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(shape)
            .overlay(shape.stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
            .accessibilityHidden(true)
    }

    private func extraDate(_ extra: NexusUpdateChecker.NexusModExtra?) -> Date? {
        guard let extra, let version = extra.version,
              NexusUpdateChecker.compare(version, update.latestVersion) == .orderedSame else { return nil }
        return extra.uploadedTime
    }
}

struct NexusUpdateList: View {
    let list: PendingUpdateList
    var viewModel: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    @AppStorage(UDKey.pausedUpdatesExpanded) private var pausedExpanded = false
    @State private var snoozedExpanded = false
    @State private var affirmedExpanded = false
    @State private var details: [Int: ModDetailRaw] = [:]

    var body: some View {
        let groups = list.groups
        let visibleRows = groups.active
            + (pausedExpanded ? groups.paused : [])
            + (snoozedExpanded ? list.snoozed : [])
            + (affirmedExpanded ? list.affirmed : [])
        let requests = visibleRows.map(ReleaseRequest.init)
        LazyVStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            if !groups.active.isEmpty {
                grid(groups.active, state: .available)
            }
            section(L10n.Updates.pausedGroup, rows: groups.paused, state: .available, expanded: $pausedExpanded)
            section(L10n.Updates.snoozedTitle, rows: list.snoozed, state: .snoozed, expanded: $snoozedExpanded)
            section(L10n.Updates.affirmedTitle, rows: list.affirmed, state: .affirmed, expanded: $affirmedExpanded)
        }
        .task(id: requests) {
            await loadDetails(for: requests)
        }
    }

    @ViewBuilder
    private func section(_ title: String, rows: [PendingUpdateRow], state: UpdateCardState,
                         expanded: Binding<Bool>) -> some View {
        if !rows.isEmpty {
            UpdateSectionDisclosure(title: String(format: localization.L(title), Int64(rows.count)),
                                    isExpanded: expanded) {
                grid(rows, state: state)
            }
        }
    }

    private func grid(_ rows: [PendingUpdateRow], state: UpdateCardState) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 350), spacing: 24, alignment: .topLeading)],
                  alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                NexusUpdateRow(row: row, detail: row.update.updatePageID.flatMap { details[$0] },
                               state: state, vm: viewModel, localization: localization)
            }
        }
    }

    private struct ReleaseRequest: Hashable {
        let id: Int?
        let version: String

        init(_ row: PendingUpdateRow) {
            id = row.update.updatePageID
            version = row.update.latestVersion
        }
    }

    private func loadDetails(for requests: [ReleaseRequest]) async {
        let releases = Dictionary(grouping: requests, by: \.id)
        var seen = Set<Int>()
        for request in requests {
            guard !Task.isCancelled else { return }
            guard let id = request.id, seen.insert(id).inserted else { continue }
            if let cached = details[id] ?? ModDetailCache.load(modId: id) {
                details[id] = cached
                if cached.releaseDates != nil,
                   releases[id]?.allSatisfy({ cached.releaseDate(for: $0.version) != nil }) == true { continue }
            }

            let result = await withCheckedContinuation { continuation in
                NexusSearchClient.modDetailRaw(modId: id) { continuation.resume(returning: $0) }
            }
            guard !Task.isCancelled else { return }
            switch result {
            case .success(let detail):
                ModDetailCache.save(modId: id, detail)
                details[id] = detail
            case .failure(.rateLimited):
                return
            case .failure:
                continue
            }
        }
    }
}
