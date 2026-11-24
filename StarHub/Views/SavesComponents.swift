import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// Presets shared by both save-avatar renderers below (identifier → SF Symbol name).
private let saveAvatarPresets: [(String, String)] = [
    ("preset:person", "person.crop.circle.fill"),
    ("preset:star", "star.fill"),
    ("preset:leaf", "leaf.fill"),
    ("preset:heart", "heart.fill"),
    ("preset:cat", "cat.fill"),
    ("preset:dog", "dog.fill"),
    ("preset:hare", "hare.fill"),
    ("preset:ant", "ant.fill"),
]

// MARK: - SaveAvatarViewLocal (renders a resolved iconPath, no vm needed)
struct SaveAvatarViewLocal: View {
    let iconPath: String
    let size: CGFloat

    /// Le chemin tel qu'il vaut **aujourd'hui**. Celui qui dort dans
    /// `SaveNotes_v2` est absolu : le déplacement du dossier de données (F5)
    /// l'a périmé, et `NSImage(contentsOfFile:)` retombait alors en silence
    /// sur le pictogramme générique — l'avatar disparaissait sans un mot.
    private var resolvedPath: String {
        SaveHeroPortrait.resolvedImagePath(iconPath,
                                           avatarsDirectory: AppSupport.avatarsDirectory)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.15))

            if iconPath.hasPrefix("preset:") {
                let sfName = saveAvatarPresets.first(where: { $0.0 == iconPath })?.1 ?? "person.crop.circle.fill"
                Image(systemName: sfName)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(Color.accentColor.opacity(0.8))
                    .padding(size * 0.18)
            } else if !iconPath.isEmpty, let img = NSImage(contentsOfFile: resolvedPath) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundColor(Color.accentColor.opacity(0.8))
                    .frame(width: size * 0.8, height: size * 0.8)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - SaveAvatarView (resolves iconPath from the save's note, then
// delegates rendering to SaveAvatarViewLocal so the two can't drift apart)
struct SaveAvatarView: View {
    let folderName: String
    let size: CGFloat
    var vm: StarHubTHViewModel

    var body: some View {
        SaveAvatarViewLocal(iconPath: vm.getNote(for: folderName).customIconPath ?? "", size: size)
    }
}

/// Renders the save's real Stardew farmer portrait (`SaveFarmerAvatar`) by default,
/// honoring a user-chosen custom image or preset icon when configured.
struct SavePreviewAvatar: View {
    let save: SaveGameInfo
    let size: CGFloat
    var vm: StarHubTHViewModel

    var body: some View {
        let iconPath = vm.getNote(for: save.folderName).customIconPath ?? ""
        if SaveHeroPortrait.prefersCustomIcon(iconPath) || iconPath.hasPrefix("preset:") {
            SaveAvatarViewLocal(iconPath: iconPath, size: size)
        } else {
            EquatableView(content: SaveFarmerAvatar(
                isFemale: save.isFemale,
                hairStyle: save.hairStyle,
                hairColor: SaveFarmerPalette.hairColor(from: save.hairColor),
                skinIndex: save.skinIndex,
                size: size
            ))
        }
    }
}

// MARK: - SaveGameInfo · sous-titre de rangée et de hero
extension SaveGameInfo {
    /// « Ferme · An 3 Printemps 14 » — le sous-titre commun à la rangée de
    /// liste et au hero de la fiche : une seule écriture, pas deux qui
    /// divergent. Le format et la saison localisée viennent de l'appelant,
    /// qui seul connaît la langue.
    /// Interne : `SaveRow` (ici) et `SaveEditorView` (`SaveEditorView.swift`)
    /// l'utilisent — l'ancien `fileprivate` était lié au fichier d'avant la
    /// coupe T3.
    func farmDayLine(format: String, localizedSeason: String) -> String {
        "\(farmName) · \(String(format: format, year, localizedSeason, day))"
    }
}

// MARK: - Grid View

private struct SaveCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(Motion.animation(.easeOut(duration: 0.1)), value: configuration.isPressed)
    }
}

struct SavesGridView: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    let saves: [SaveGameInfo]
    let onDelete: (SaveGameInfo) -> Void
    let columns = [GridItem(.adaptive(minimum: 130, maximum: 170), spacing: 16)]

    var body: some View {
        BackToTopScrollView(localization) {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(saves) { save in
                    SaveCardView(vm: vm, localization: localization, save: save) {
                        onDelete(save)
                    }
                }
            }
            .padding(20)
        }
    }
}

struct SaveCardView: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    let save: SaveGameInfo
    let onDelete: () -> Void

    var body: some View {
        Button(action: { vm.navigationStore.setEditingSave(save) }) {
            VStack(spacing: AppDesign.Spacing.md) {
                SavePreviewAvatar(save: save, size: 64, vm: vm)

                VStack(spacing: 2) {
                    let note = vm.getNote(for: save.folderName)
                    HStack(spacing: AppDesign.Spacing.xs) {
                        if !note.tag.isEmpty {
                            Text(note.tag).font(AppDesign.Font.body)
                        }
                        Text(save.playerName)
                            .font(AppDesign.Font.caption(.semibold))
                            .truncatedHelp(save.playerName, mode: .middle)
                    }
                    Text(save.farmName)
                        .font(AppDesign.Font.footnote)
                        .foregroundStyle(.secondary)
                        .truncatedHelp(save.farmName, mode: .middle)
                    Text(String(format: localization.L(L10n.Saves.yearDayFormat), save.year, localization.L(save.seasonName), save.day))
                        .font(AppDesign.Font.iconXS)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .cardSurface(padding: AppDesign.Spacing.sm)
        }
        .buttonStyle(SaveCardButtonStyle())
        .focusRing(cornerRadius: AppDesign.Radius.lg)
        .contextMenu {
            SaveActionItems(save: save, viewModel: vm, localization: localization, onDelete: onDelete)
        }
    }
}

// MARK: - Save Row (Native List)
struct SaveRow: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    let save: SaveGameInfo
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: AppDesign.Spacing.sm) {
            SaveAvatarView(folderName: save.folderName, size: 36, vm: vm)

            VStack(alignment: .leading, spacing: 2) {
                let note = vm.getNote(for: save.folderName)
                HStack(spacing: 6) {
                    if !note.tag.isEmpty {
                        Text(note.tag)
                            .font(AppDesign.Font.rowTitle)
                    }
                    Text(save.playerName)
                        .font(AppDesign.Font.rowTitle(.medium))
                        .foregroundStyle(.primary)
                }
                let farmDay = save.farmDayLine(format: localization.L(L10n.Saves.yearDayFormat),
                                               localizedSeason: localization.L(save.seasonName))
                Text(farmDay)
                    .font(AppDesign.Font.caption)
                    .foregroundStyle(.secondary)
                    .truncatedHelp(farmDay)
            }

            Spacer()

            moneyColumns

            Menu {
                SaveActionItems(save: save, viewModel: vm, localization: localization, onDelete: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
                    .font(AppDesign.Font.rowTitle)
                    .frame(width: AppDesign.Metrics.minControlTarget, height: AppDesign.Metrics.minControlTarget)
                    .contentShape(.rect)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .focusRing(cornerRadius: 4)
            .iconHelp(localization.L(L10n.Mods.moreActions))
            .fixedSize()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    /// Argent et total gagné, en colonnes tenues : ce qui se compare d'une
    /// sauvegarde à l'autre se lit aligné, pas noyé dans une phrase.
    private var moneyColumns: some View {
        HStack(alignment: .top, spacing: AppDesign.Spacing.xl) {
            StatColumn(label: localization.L(L10n.Saves.money),
                       value: Self.moneyText(save.money))
            StatColumn(label: localization.L(L10n.Saves.totalMoneyEarned),
                       value: Self.moneyText(save.totalMoneyEarned))
        }
        .fixedSize()
    }

    /// Format monétaire localisé, comme l'ancienne phrase le faisait.
    /// Interne : la fiche l'utilise pour son `StatStrip`.
    static func moneyText(_ value: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }
}
