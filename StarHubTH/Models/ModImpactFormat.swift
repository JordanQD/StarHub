import Foundation

/// D5-C — les nombres de l'impact par mod, tels que l'écran les écrit : séparateur
/// décimal des réglages régionaux de macOS, millisecondes sous la seconde (« −0,0 s »
/// pour 40 ms disait zéro), écart de note stable s'il s'arrondit à 0.
public enum ModImpactFormat {
    public enum Evolution: Equatable, Sendable { case gain, loss, stable }

    public static func score(_ value: Double) -> String { String(Int(value.rounded())) }

    public static func number(_ value: Double, digits: Int = 1, locale: Locale = .autoupdatingCurrent) -> String {
        value.formatted(.number.precision(.fractionLength(digits))
            .rounded(rule: .toNearestOrAwayFromZero).locale(locale))
    }

    public static func percent(_ share: Double, locale: Locale = .autoupdatingCurrent) -> String {
        share.formatted(.percent.precision(.fractionLength(share < 0.01 ? 2 : 1)).locale(locale))
    }

    /// « 40 ms », « 2,5 s », « 12 s », « 1 min 50 s ».
    public static func duration(_ ms: Double, locale: Locale = .autoupdatingCurrent) -> String {
        if ms < 1_000 { return "\(Int(ms.rounded())) ms" }
        let seconds = ms / 1_000
        if seconds < 10 { return "\(number(seconds, locale: locale)) s" }
        let whole = Int(seconds.rounded())
        return whole < 60 ? "\(whole) s" : "\(whole / 60) min \(String(format: "%02d", whole % 60)) s"
    }

    /// Négatif = gain ; |écart| < 0,5 s'affiche « 0 » : ni gain ni perte.
    public static func evolution(_ delta: Double) -> Evolution {
        abs(delta) < 0.5 ? .stable : delta < 0 ? .gain : .loss
    }

    public static func date(_ date: Date?) -> String? {
        date.map { $0.formatted(.dateTime.day().month(.twoDigits)) }
    }
}

/// Le processus du jeu tel que macOS le nomme — SMAPI compris, rattaché au
/// bundle par LaunchServices. Seule définition : `isGameRunning` et
/// l'écoute de la fermeture du jeu passent par ici.
public enum GameProcess {
    public static let name = "Stardew Valley"

    public static func isGame(localizedName: String?) -> Bool {
        localizedName?.caseInsensitiveCompare(name) == .orderedSame
    }
}
