import Foundation
import Observation

/// L'état d'une alerte de fenêtre : le message affiché et la présentation.
///
/// Le ViewModel appelle `show` ; SwiftUI repose le binding à `false` quand
/// l'utilisateur ferme l'alerte. Extrait du ViewModel (P8, famille « alertes »,
/// 2026-09-12) : l'état ne décide de rien, il porte deux champs et une
/// transition.
@MainActor @Observable
final class AlertStore {
    /// Le message affiché. Posé par `show(_:)` ; rester après la fermeture est
    /// sans effet tant que `shown` est `false`.
    private(set) var message = ""
    /// `true` présente l'alerte ; le binding de la vue l'éteint à la fermeture.
    var shown = false

    func show(_ message: String) {
        self.message = message
        shown = true
    }
}
