import SwiftUI

extension ModDetailView {
    @ToolbarContentBuilder
    var nexusToolbarItem: some ToolbarContent {
        if let url = URL(string: vm.nexusLink(for: mod)),
           url.scheme == "https" || url.scheme == "http",
           let host = url.host?.lowercased(), host == "www.nexusmods.com" || host == "nexusmods.com",
           vm.nexusPageState(for: mod) == nil {
            ToolbarItem {
                let title = localization.L(L10n.Mods.nexusOpenPage)
                Link(destination: url) {
                    Label(title, systemImage: "arrow.up.right.square")
                }
                .help(title)
            }
        }
    }
}
