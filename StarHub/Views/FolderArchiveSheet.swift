import AppKit
import SwiftUI

/// Ce qu'une feuille d'archive doit savoir de sa source, préparé par le
/// bouton qui l'ouvre.
struct FolderArchiveRequest: Identifiable {
    let kind: FolderArchiveStore.Kind
    let source: URL
    let filePrefix: String
    /// « 966 mods, dont 809 en pause » — déjà traduit.
    let summary: String
    /// Le poids déjà mesuré au scan, `nil` s'il faut le mesurer.
    let knownBytes: Int64?

    var id: String { kind.rawValue }

    /// Tout `Mods/`, mods en pause compris : un mod en pause est un dossier
    /// `.X` dans `Mods/`, et `zip -r .` l'emporte comme les autres.
    @MainActor
    static func mods(from viewModel: StarHubTHViewModel, _ localization: LocalizationStore) -> FolderArchiveRequest? {
        guard !viewModel.gameDir.isEmpty else { return nil }
        let mods = viewModel.mods
        let paused = mods.filter { !$0.isEnabled }.count
        return FolderArchiveRequest(
            kind: .mods,
            source: URL(fileURLWithPath: viewModel.gameDir).appendingPathComponent("Mods", isDirectory: true),
            filePrefix: "StardewMods",
            summary: String(format: localization.L(L10n.Archive.modsSummary), Int64(mods.count), Int64(paused)),
            knownBytes: viewModel.modsFolderSizes?.totalBytes)
    }

    static func saves(_ localization: LocalizationStore) -> FolderArchiveRequest {
        let source = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".config/StardewValley/Saves", isDirectory: true)
        let names: [String]
        do { names = try FileManager.default.contentsOfDirectory(atPath: source.path) } catch { names = [] }
        // E13 — les parties et leurs copies de secours, comptées à part : seul
        // le libellé change, l'archive emporte tout `Saves/` comme avant.
        let content = FolderArchive.savesContent(names: names)
        let games = localization.plural(L10n.Archive.savesSummary, content.games)
        return FolderArchiveRequest(
            kind: .saves, source: source, filePrefix: "StardewSaves",
            summary: content.backups == 0 ? games
                : String(format: localization.L(L10n.Archive.savesWithBackups), games,
                         localization.plural(L10n.Archive.savesBackups, content.backups)),
            knownBytes: nil)
    }
}

/// Feuille « Sauvegarder… » : ce qui part, où, si la place suffit, combien de
/// temps — puis l'avancement, l'annulation, le résultat.
struct FolderArchiveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var localization: LocalizationStore
    let request: FolderArchiveRequest

    @State private var store = FolderArchiveStore()
    @State private var destination: URL?
    @State private var sourceBytes: Int64?
    @State private var available: Int64?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppDesign.Spacing.sm) {
                IconTile(icon: "archivebox.fill", tint: AppDesign.Color.accent, size: 28)
                Text(localization.L(request.kind == .mods ? L10n.Archive.modsTitle : L10n.Archive.savesTitle))
                    .font(AppDesign.Font.headline(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.top, AppDesign.Spacing.lg)
            .padding(.bottom, AppDesign.Spacing.sm)

            switch store.phase {
            case .idle: plan
            case .running(let progress, let startedAt): running(progress, startedAt: startedAt)
            case .finished(let archive, let bytes, let seconds): finished(archive, bytes: bytes, seconds: seconds)
            case .failed(let message): ended(localization.L(L10n.Archive.failed) + "\n" + message, color: AppDesign.Color.error)
            case .cancelled: ended(localization.L(L10n.Archive.cancelled), color: .secondary)
            }
        }
        .frame(minWidth: 440, idealWidth: 480)
        .interactiveDismissDisabled(store.isRunning)
        .task { await prepare() }
    }

    // MARK: - Avant de lancer

    @ViewBuilder
    private var plan: some View {
        let enough = sourceBytes.map { FolderArchive.hasEnoughSpace(sourceBytes: $0, available: available) } ?? false
        let inside = destination.map { FolderArchive.destination($0, isInside: request.source) } ?? false
        Form {
            Section {
                formRow("shippingbox", request.summary + " · " + bytesText(sourceBytes),
                        color: .primary, monospacedDigits: true)

                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                        .frame(width: 18, alignment: .center)
                    Text(destination?.path ?? "—")
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(localization.L(L10n.Archive.choose)) { chooseDestination() }
                        .controlSize(.small)
                }

                if inside {
                    formRow("exclamationmark.triangle.fill", localization.L(L10n.Archive.insideSource),
                            color: AppDesign.Color.error)
                }
            }

            if let sourceBytes {
                Section {
                    spaceRow(sourceBytes: sourceBytes, enough: enough)
                    formRow("clock", String(format: localization.L(L10n.Archive.estimate),
                                            durationText(FolderArchive.estimatedSeconds(
                                                bytes: sourceBytes, bytesPerSecond: store.bytesPerSecond))),
                            color: .secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)

        Divider()
        HStack {
            Spacer()
            Button(localization.L(L10n.Saves.cancel), role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(localization.L(L10n.Archive.start)) { start() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!enough || inside || destination == nil)
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.vertical, AppDesign.Spacing.md)
    }

    @ViewBuilder
    private func spaceRow(sourceBytes: Int64, enough: Bool) -> some View {
        let needed = FolderArchive.requiredBytes(sourceBytes: sourceBytes)
        if enough {
            formRow("internaldrive", String(format: localization.L(L10n.Archive.spaceOK),
                                            bytesText(available), bytesText(needed)),
                    color: .secondary, monospacedDigits: true)
        } else {
            formRow("exclamationmark.triangle.fill", String(format: localization.L(L10n.Archive.spaceShort),
                                                            bytesText(needed), bytesText(available)),
                    color: AppDesign.Color.error, monospacedDigits: true)
        }
    }

    // MARK: - Pendant

    @ViewBuilder
    private func running(_ progress: FolderArchive.Progress?, startedAt: Date) -> some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                    ProgressView(value: progress?.fraction ?? 0)
                    TimelineView(.periodic(from: startedAt, by: 1)) { context in
                        Text(statusText(progress, elapsed: context.date.timeIntervalSince(startedAt)))
                            .font(AppDesign.Font.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, AppDesign.Spacing.xs)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)

        Divider()
        HStack {
            Spacer()
            Button(localization.L(L10n.Archive.stop), role: .cancel) { store.cancel() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.vertical, AppDesign.Spacing.md)
    }

    private func statusText(_ progress: FolderArchive.Progress?, elapsed: Double) -> String {
        guard let progress else { return localization.L(L10n.Archive.starting) }
        let remaining = FolderArchive.remainingSeconds(progress: progress, elapsed: elapsed)
        return String(format: localization.L(L10n.Archive.progress),
                      Int64(progress.entriesDone), Int64(progress.entriesTotal),
                      bytesText(progress.bytesDone), bytesText(progress.bytesTotal),
                      remaining.map(durationText) ?? "—")
    }

    // MARK: - Après

    @ViewBuilder
    private func finished(_ archive: URL, bytes: Int64, seconds: Double) -> some View {
        Form {
            Section {
                Label(String(format: localization.L(L10n.Archive.done), bytesText(bytes), durationText(seconds)),
                      systemImage: "checkmark.circle.fill")
                    .foregroundStyle(AppDesign.Color.success)
                    .fixedSize(horizontal: false, vertical: true)
                Text(archive.path)
                    .font(AppDesign.Font.monoCaption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)

        Divider()
        HStack {
            Spacer()
            Button(localization.L(L10n.Archive.reveal)) {
                NSWorkspace.shared.activateFileViewerSelecting([archive])
            }
            Button(localization.L(L10n.Saves.cleanupClose)) { dismiss() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.vertical, AppDesign.Spacing.md)
    }

    @ViewBuilder
    private func ended(_ message: String, color: Color) -> some View {
        Form {
            Section {
                Text(message)
                    .foregroundStyle(color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)

        Divider()
        HStack {
            Spacer()
            Button(localization.L(L10n.Saves.cleanupClose)) { dismiss() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.vertical, AppDesign.Spacing.md)
    }

    // MARK: - Actions

    private func prepare() async {
        let kind = request.kind
        let fallback = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop", isDirectory: true)
        let chosen = store.lastDestination(for: kind)
            .flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil } ?? fallback
        destination = chosen
        available = ModsFolderSizer.availableBytes(on: chosen)
        if let known = request.knownBytes {
            sourceBytes = known
            return
        }
        let source = request.source
        // ~3 s sur un parc de 100 000 fichiers : hors du fil principal.
        sourceBytes = await Task.detached(priority: .userInitiated) {
            ModsFolderSizer.measure(modsFolder: source)?.totalBytes ?? 0
        }.value
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = destination
        panel.prompt = localization.L(L10n.Archive.choose)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        destination = url
        available = ModsFolderSizer.availableBytes(on: url)
    }

    private func start() {
        guard let destination, let sourceBytes else { return }
        store.start(kind: request.kind, source: request.source, destinationFolder: destination,
                    archiveName: FolderArchive.archiveName(prefix: request.filePrefix, date: Date()),
                    sourceBytes: sourceBytes)
    }

    // MARK: - Mise en forme

    private func formRow(_ symbol: String, _ text: String,
                         color: Color = .primary, monospacedDigits: Bool = false) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(color == AppDesign.Color.error ? color : .secondary)
                .frame(width: 18, alignment: .center)
            Text(text)
                .foregroundStyle(color)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func bytesText(_ bytes: Int64?) -> String {
        guard let bytes else { return "…" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func durationText(_ seconds: Double) -> String {
        let minutes = Int64((seconds / 60).rounded(.up))
        if seconds < 60 { return localization.L(L10n.Archive.underAMinute) }
        if minutes < 60 { return String(format: localization.L(L10n.Archive.minutes), minutes) }
        return String(format: localization.L(L10n.Archive.hoursMinutes), minutes / 60, minutes % 60)
    }
}

extension L10n {
    enum Archive {
        static let modsTitle    = "archive_mods_title"
        static let savesTitle   = "archive_saves_title"
        static let modsSummary  = "archive_mods_summary"
        static let savesSummary = "archive_saves_summary"
        static let savesBackups = "archive_saves_backups"          // E13
        static let savesWithBackups = "archive_saves_with_backups"
        static let choose       = "archive_choose"
        static let spaceOK      = "archive_space_ok"
        static let spaceShort   = "archive_space_short"
        static let estimate     = "archive_estimate"
        static let start        = "archive_start"
        static let stop         = "archive_stop"
        static let starting     = "archive_starting"
        static let progress     = "archive_progress"
        static let done         = "archive_done"
        static let reveal       = "archive_reveal"
        static let failed       = "archive_failed"
        static let cancelled    = "archive_cancelled"
        static let underAMinute = "archive_under_a_minute"
        static let minutes      = "archive_minutes"
        static let hoursMinutes = "archive_hours_minutes"
        static let insideSource = "archive_inside_source"
    }
}
