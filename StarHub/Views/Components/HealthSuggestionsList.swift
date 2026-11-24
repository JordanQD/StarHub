import SwiftUI

/// Actionable suggestions derived from `SmapiDiagnostics`.
struct HealthSuggestionsList: View {
    var viewModel: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    let suggestions: [HealthSuggestion]
    let showBlock: (String) -> Void
    let showBisection: () -> Void

    @State private var showsMissingDependencies = false

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                HStack(alignment: .center, spacing: AppDesign.Spacing.sm) {
                    Text("\(index + 1)")
                        .font(AppDesign.Font.iconXS(.semibold))
                        .foregroundStyle(.tint)
                        .frame(width: 18, height: 18)
                        .background(Color.accentColor.opacity(0.12), in: Circle())
                    Text(suggestion.text)
                        .font(AppDesign.Font.body)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: AppDesign.Spacing.sm)
                    if let action = suggestion.action {
                        gesture(action)
                    }
                }
                .padding(.vertical, AppDesign.Spacing.xs)
                .overlay(alignment: .bottom) { Divider() }
            }
        }
        .sheet(isPresented: $showsMissingDependencies) {
            MissingDependenciesSheet(vm: viewModel, localization: localization,
                                     isPresented: $showsMissingDependencies)
        }
    }

    @ViewBuilder
    private func gesture(_ action: HealthSuggestion.Action) -> some View {
        switch action {
        case .installDependency(let missing):
            let available = HealthSuggestion.isStillMissing(missing, in: viewModel.missingDependenciesPlan)
            actionControl(L10n.HealthSuggestion.install, refusal: available ? nil : L10n.HealthSuggestion.depResolved) {
                showsMissingDependencies = true
            }
        case .openMod(let name):
            let found = ModFocusResolver.resolve(name, in: viewModel.scanStore.mods) != nil
            actionControl(L10n.HealthSuggestion.openMod, refusal: found ? nil : L10n.HealthSuggestion.modGone) {
                NotificationCenter.default.post(name: .jumpToMod, object: name)
            }
        case .showBlock(let anchor):
            actionControl(L10n.HealthSuggestion.showMods, refusal: nil) { showBlock(anchor) }
        case .showBisection:
            actionControl(L10n.Bisect.title, refusal: nil, action: showBisection)
        }
    }

    private func actionControl(_ title: String, refusal: String?, action: @escaping () -> Void) -> some View {
        HStack(spacing: AppDesign.Spacing.xs) {
            if let refusal {
                Text(localization.L(refusal))
                    .font(AppDesign.Font.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Button(localization.L(title), action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .fixedSize()
                .disabled(refusal != nil)
        }
    }
}
