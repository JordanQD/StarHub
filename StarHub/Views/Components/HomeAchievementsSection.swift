import SwiftUI

/// Apple Games (macOS 27) style horizontal achievement showcase powered by
/// Stardew Valley's local save XML `<achievements>` list and official Steam icons.
struct HomeAchievementsSection: View {
    let unlockedIDs: Set<Int>
    @ObservedObject var localization: LocalizationStore

    @State private var showAllSheet = false

    private var languageCode: String { localization.currentLanguage }

    /// Unlocked achievements first, then locked in official order.
    private var orderedAchievements: [StardewAchievement] {
        let unlocked = StardewAchievement.all.filter { unlockedIDs.contains($0.id) }
        let locked = StardewAchievement.all.filter { !unlockedIDs.contains($0.id) }
        return unlocked + locked
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Button {
                    showAllSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Text(localization.L(L10n.Home.achievementsTitle))
                            .font(.system(size: 17, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointingHandCursor()

                Text(String(format: localization.L(L10n.Home.achievementsProgress),
                            Int64(unlockedIDs.count), Int64(StardewAchievement.all.count)))
                    .font(AppDesign.Font.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(orderedAchievements) { achievement in
                        AchievementCard(
                            achievement: achievement,
                            isUnlocked: unlockedIDs.contains(achievement.id),
                            languageCode: languageCode
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .sheet(isPresented: $showAllSheet) {
            AllAchievementsSheet(
                unlockedIDs: unlockedIDs,
                localization: localization
            )
        }
    }
}

// MARK: - Single Achievement Card

private struct AchievementCard: View {
    let achievement: StardewAchievement
    let isUnlocked: Bool
    let languageCode: String

    @Environment(\.colorScheme) private var colorScheme

    private var title: String { achievement.localizedTitle(languageCode: languageCode) }
    private var detail: String { achievement.localizedDescription(languageCode: languageCode) }

    var body: some View {
        let iconShape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        return VStack(spacing: 14) {
            // Rounded-rectangle icon well (72×72)
            ZStack {
                if isUnlocked {
                    if let iconURL = achievement.steamIconURL {
                        CachedAsyncImage(url: iconURL)
                            .frame(width: 72, height: 72)
                            .clipShape(iconShape)
                            .overlay(
                                iconShape.strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                            )
                            .shadow(color: Color.black.opacity(0.22), radius: 6, y: 2)
                    } else {
                        iconShape
                            .fill(Color.accentColor.opacity(0.14))
                            .frame(width: 72, height: 72)
                            .overlay {
                                Image(systemName: achievement.symbol)
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(.tint)
                            }
                    }
                } else {
                    iconShape
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.04))
                        .frame(width: 72, height: 72)

                    iconShape
                        .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.10), lineWidth: 1)
                        .frame(width: 72, height: 72)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.75))
                }
            }
            .padding(.top, 20)

            // Title & description
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(isUnlocked ? 1.0 : 0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 0)
        }
        .frame(width: 162, height: 192)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colorScheme == .dark
                      ? Color.white.opacity(isUnlocked ? 0.075 : 0.045)
                      : Color.primary.opacity(isUnlocked ? 0.055 : 0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.09), lineWidth: 1)
        )
        .help("\(title) — \(detail)")
    }
}

// MARK: - Full Achievements Sheet

private struct AllAchievementsSheet: View {
    let unlockedIDs: Set<Int>
    @ObservedObject var localization: LocalizationStore

    @Environment(\.dismiss) private var dismiss
    @State private var filter: Filter = .all

    private enum Filter: Hashable { case all, unlocked, locked }

    private var filtered: [StardewAchievement] {
        switch filter {
        case .all:
            let unlocked = StardewAchievement.all.filter { unlockedIDs.contains($0.id) }
            let locked = StardewAchievement.all.filter { !unlockedIDs.contains($0.id) }
            return unlocked + locked
        case .unlocked:
            return StardewAchievement.all.filter { unlockedIDs.contains($0.id) }
        case .locked:
            return StardewAchievement.all.filter { !unlockedIDs.contains($0.id) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppDesign.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(localization.L(L10n.Home.achievementsTitle))
                        .font(.title3.bold())
                    Text(String(format: localization.L(L10n.Home.achievementsProgress),
                                Int64(unlockedIDs.count), Int64(StardewAchievement.all.count)))
                        .font(AppDesign.Font.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer()

                Picker("", selection: $filter) {
                    Text(localization.L(L10n.Home.achievementsFilterAll)).tag(Filter.all)
                    Text(localization.L(L10n.Home.achievementsFilterUnlocked)).tag(Filter.unlocked)
                    Text(localization.L(L10n.Home.achievementsFilterLocked)).tag(Filter.locked)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                Button(localization.L(L10n.Main.close)) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(AppDesign.Spacing.lg)

            Divider()

            if filtered.isEmpty {
                ContentUnavailableView {
                    Label(localization.L(L10n.Home.achievementsTitle), systemImage: "trophy")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 158, maximum: 176), spacing: 14)],
                              spacing: 14) {
                        ForEach(filtered) { achievement in
                            AchievementCard(
                                achievement: achievement,
                                isUnlocked: unlockedIDs.contains(achievement.id),
                                languageCode: localization.currentLanguage
                            )
                        }
                    }
                    .padding(AppDesign.Spacing.xl)
                }
            }
        }
        .frame(minWidth: 740, idealWidth: 820, minHeight: 540, idealHeight: 620)
    }
}
