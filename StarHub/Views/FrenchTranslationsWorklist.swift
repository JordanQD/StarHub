import SwiftUI

/// Native grouped `Form` sections for the Worklist tab inside `FrenchTranslationsView`.
struct FrenchTranslationsWorklist: View {
    @ObservedObject var localization: LocalizationStore
    let items: [TranslationWorkItem]
    let order: TranslationWorklist.Order
    let untranslated: Int
    let unmeasured: Int
    let targetLanguageName: String
    let open: (String) -> Void
    let showNexus: () -> Void

    var body: some View {
        Group {
            if untranslated > 0 {
                Section {
                    HStack(spacing: AppDesign.Spacing.md) {
                        Image(systemName: "globe")
                            .foregroundStyle(.secondary)
                            .frame(width: 20, alignment: .center)
                        Text(String(format: localization.L(L10n.FrTranslations.worklistUntranslated),
                                    untranslated, targetLanguageName))
                            .font(AppDesign.Font.body)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: AppDesign.Spacing.sm)
                        Button(localization.L(L10n.FrTranslations.worklistSearchNexus), action: showNexus)
                            .buttonStyle(.bordered)
                    }
                }
            }

            if !items.isEmpty {
                Section {
                    ForEach(items.sorted(by: order.precedes)) { item in
                        row(item)
                    }
                }
            }
        }
    }

    private func row(_ item: TranslationWorkItem) -> some View {
        let openTitle = localization.L(L10n.Profiles.translationOpen)
        return HStack(alignment: .center, spacing: AppDesign.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AppDesign.Spacing.xs) {
                    Text(item.name)
                        .font(AppDesign.Font.body(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if !item.isEnabled { pill(localization.L(L10n.FrTranslations.paused), .secondary) }
                    if item.isStale { pill(localization.L(L10n.Mods.frTranslationStale), AppDesign.Color.warning) }
                }
                if let coverage = item.coverage {
                    Text(String(format: localization.L(L10n.Profiles.translationRowCounts),
                                Int64(coverage.translated), Int64(coverage.total), Int64(item.missingCount)))
                        .font(AppDesign.Font.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: AppDesign.Spacing.sm)

            if let coverage = item.coverage {
                Text("\(coverage.displayPercent)%")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tint)
            }

            Button(openTitle) { open(item.folderName) }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .fixedSize()
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button(openTitle) { open(item.folderName) }
        }
    }

    private func pill(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(AppDesign.Font.iconXS(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(AppDesign.Opacity.medium), in: RoundedRectangle(cornerRadius: 4))
    }
}
