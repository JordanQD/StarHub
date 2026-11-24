import Foundation

/// C7-T1 — ce que le manifeste d'un candidat dit de sa nature. Vérif écran
/// du 2026-11-19 : un fork complet (`EasyAccessButtonsFR`, DLL propre) porte
/// les trois signaux d'un pack de traduction ; seul son `EntryDll` le trahit.
public enum TranslationLinkManifest {
    /// Le manifeste déclare un `EntryDll` non vide (lecture JSONC tolérante,
    /// BOM et UTF-16 compris). Manifeste absent ou illisible : `false`.
    public static func hasCode(manifestAt path: String) -> Bool {
        guard let data = FileManager.default.contents(atPath: path),
              let decoded = I18nFileDecoder.decode(data),
              let object = I18nLenientParser.lenientObject(decoded.text),
              let dll = object["EntryDll"] as? String
        else { return false }
        return !dll.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
