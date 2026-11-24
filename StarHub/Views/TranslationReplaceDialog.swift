import SwiftUI

/// C7-T2 — la confirmation Remplacer/Garder, présentée au niveau racine
/// (MainView) : le pending vit sur le VM et survit au changement d'onglet,
/// comme les autres états racine (A1-T8). Le message nomme ce qui existe
/// déjà — traduction posée (volet a), pack suivi (volet b, avec sa pause
/// annoncée), packs du parc ciblant le même mod (advisory c).
struct TranslationReplaceDialog: ViewModifier {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore

    private var dialogMessage: String {
        guard let conflict = vm.lastTranslationConflict else { return "" }
        var lines: [String] = []
        for existing in conflict.existing {
            switch existing {
            case .appManaged(let name):
                lines.append(String(format: localization.L(L10n.Mods.translationReplaceAppManaged), name))
            case .declaredPack(_, let name, let isEnabled):
                lines.append(String(format: localization.L(L10n.Mods.translationReplaceDeclared), name))
                if isEnabled {
                    lines.append(localization.L(L10n.Mods.translationReplacePackPause))
                }
            }
        }
        if conflict.parcCandidateCount > 0 {
            lines.append(String(format: localization.L(L10n.Mods.translationReplaceAdvisory),
                                conflict.parcCandidateCount))
        }
        return lines.joined(separator: "\n")
    }

    func body(content: Content) -> some View {
        content.confirmationDialog(
            localization.L(L10n.Mods.translationReplaceTitle),
            isPresented: Binding(
                get: { vm.pendingTranslationInstall != nil },
                set: { if !$0 { vm.cancelPendingTranslationReplace() } }
            ),
            titleVisibility: .visible
        ) {
            Button(localization.L(L10n.Mods.translationReplaceConfirm)) {
                vm.confirmPendingTranslationReplace()
            }
            Button(localization.L(L10n.Mods.translationReplaceKeep), role: .cancel) {
                vm.cancelPendingTranslationReplace()
            }
        } message: {
            Text(dialogMessage)
        }
    }
}
