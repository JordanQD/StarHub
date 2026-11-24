import SwiftUI

struct ModListShareButton: View {
    let selected: [ModItem]
    var viewModel: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore

    var body: some View {
        let content = ModShareContent.make(for: selected, customIDs: viewModel.nexusCustomModIds,
                                           isPageUnavailable: { viewModel.nexusPageState(for: $0) != nil },
                                           describe: description)
        switch content {
        case .links(let urls):
            ShareLink(items: urls) { label }
                .help(localization.L(L10n.Mods.shareNexusLinks))
        case .text(let text):
            ShareLink(item: text) { label }
                .help(localization.L(L10n.Mods.shareDetails))
        case nil:
            Button {} label: { label }
                .disabled(true)
        }
    }

    private var label: some View {
        Label(localization.L(L10n.Mods.share), systemImage: "square.and.arrow.up")
    }

    private func description(for mod: ModItem) -> String {
        let fields = [mod.version == "Unknown" ? "" : mod.version,
                      mod.author == "Unknown" ? "" : mod.author,
                      mod.uniqueId].filter { !$0.isEmpty }
        return ([mod.name] + fields).joined(separator: " · ")
    }
}
