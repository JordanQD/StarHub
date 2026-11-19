import Foundation
import Combine

/// Résout les ressources dans la langue choisie par macOS au lancement.
/// Le bundle est injectable pour que les tests puissent lire leurs propres ressources.
final class LocalizationStore: ObservableObject, Sendable {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    /// Identifiant de la langue de l'interface, pour les fonctionnalités qui
    /// choisissent aussi des libellés dans les ressources d'un mod.
    var currentLanguage: String {
        bundle.preferredLocalizations.first ?? bundle.developmentLocalization ?? "fr"
    }

    var guideURL: URL? {
        bundle.url(forResource: "Guide", withExtension: "md")
    }

    func L(_ key: String) -> String {
        localized(key)
    }
}

extension LocalizationStore: L10nResolver {
    func localized(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
