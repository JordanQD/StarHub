import Foundation

/// Configurable target language for mod translations (i18n scanning, coverage,
/// Nexus search, C7-T1 link proposals, DeepL / local AI, and update preservation).
///
/// Stored in `UserDefaults` under `UDKey.translationTargetLanguage`.
/// `.auto` follows the active StarHub UI language / macOS system locale.
public enum TranslationTargetLanguage: String, CaseIterable, Codable, Sendable, Identifiable {
    case auto
    case zh
    case fr
    case ja
    case ko
    case de
    case es
    case pt
    case ru
    case it
    case tr
    case hu

    public var id: String { rawValue }

    /// Concrete (non-auto) language metadata used across disk, Nexus, and AI layers.
    public enum Resolved: String, CaseIterable, Codable, Sendable, Identifiable {
        case zh, fr, ja, ko, de, es, pt, ru, it, tr, hu

        public var id: String { rawValue }

        /// Primary SMAPI i18n file code (`i18n/<smapiCode>.json`).
        public var smapiCode: String { rawValue }

        /// All lowercased SMAPI file stem variants treated as this language.
        public var acceptedFileCodes: [String] {
            switch self {
            case .zh: return ["zh", "zh-cn", "zh-hans"]
            case .fr: return ["fr", "fr-fr"]
            case .pt: return ["pt", "pt-br"]
            case .es: return ["es", "es-es", "es-419"]
            case .ja: return ["ja", "ja-jp"]
            case .ko: return ["ko", "ko-kr"]
            case .de: return ["de", "de-de"]
            case .ru: return ["ru", "ru-ru"]
            case .it: return ["it", "it-it"]
            case .tr: return ["tr", "tr-tr"]
            case .hu: return ["hu", "hu-hu"]
            }
        }

        /// Lowercased file names (`"zh.json"`, `"zh-cn.json"`, …).
        public var acceptedFileNames: Set<String> {
            Set(acceptedFileCodes.map { "\($0).json" })
        }

        /// Primary file name (`"zh.json"`, `"fr.json"`, …).
        public var primaryFileName: String { "\(smapiCode).json" }

        /// Compact badge label for mod cards / filters (`"ZH"`, `"FR"`, …).
        public var badgeLabel: String { rawValue.uppercased() }

        /// Native display name shown in pickers alongside the SMAPI code.
        public var nativeName: String {
            switch self {
            case .zh: return "简体中文"
            case .fr: return "Français"
            case .ja: return "日本語"
            case .ko: return "한국어"
            case .de: return "Deutsch"
            case .es: return "Español"
            case .pt: return "Português"
            case .ru: return "Русский"
            case .it: return "Italiano"
            case .tr: return "Türkçe"
            case .hu: return "Magyar"
            }
        }

        /// Official Nexus Mods translation tag (used by `NexusModSearch`).
        public var nexusTag: String {
            switch self {
            case .zh: return "Chinese"
            case .fr: return "French"
            case .ja: return "Japanese"
            case .ko: return "Korean"
            case .de: return "German"
            case .es: return "Spanish"
            case .pt: return "Portuguese"
            case .ru: return "Russian"
            case .it: return "Italian"
            case .tr: return "Turkish"
            case .hu: return "Hungarian"
            }
        }

        /// Case-insensitive title markers used when filtering Nexus hits or C7-T1 packs.
        public var titleMarkers: [String] {
            switch self {
            case .zh: return ["chinese", "中文", "汉化", "漢化", "简体", "簡體", "chs", "zh-cn", "cn"]
            case .fr: return ["french", "français", "francais", "traduction", "vf"]
            case .ja: return ["japanese", "日本語", "jp"]
            case .ko: return ["korean", "한국어", "한글", "kr"]
            case .de: return ["german", "deutsch"]
            case .es: return ["spanish", "español", "espanol", "traducción"]
            case .pt: return ["portuguese", "português", "portugues", "pt-br", "tradução"]
            case .ru: return ["russian", "русский", "перевод"]
            case .it: return ["italian", "italiano", "traduzione"]
            case .tr: return ["turkish", "türkçe", "turkce", "çeviri"]
            case .hu: return ["hungarian", "magyar", "fordítás"]
            }
        }

        /// DeepL API `target_lang` code.
        public var deepLCode: String {
            switch self {
            case .zh: return "ZH-HANS"
            case .fr: return "FR"
            case .ja: return "JA"
            case .ko: return "KO"
            case .de: return "DE"
            case .es: return "ES"
            case .pt: return "PT-BR"
            case .ru: return "RU"
            case .it: return "IT"
            case .tr: return "TR"
            case .hu: return "HU"
            }
        }

        /// English language name used in LLM/local-AI translation prompts.
        public var aiLanguageName: String {
            switch self {
            case .zh: return "Simplified Chinese"
            case .fr: return "French"
            case .ja: return "Japanese"
            case .ko: return "Korean"
            case .de: return "German"
            case .es: return "Spanish"
            case .pt: return "Brazilian Portuguese"
            case .ru: return "Russian"
            case .it: return "Italian"
            case .tr: return "Turkish"
            case .hu: return "Hungarian"
            }
        }

        /// Whether a `ModItem.languages` list contains this target language.
        public func matchesModLanguages(_ languages: [String]) -> Bool {
            let folded = Set(languages.map { $0.lowercased() })
            return acceptedFileCodes.contains { folded.contains($0) }
        }

        /// Whether a file name (e.g. `"zh.json"` or `"fr.json"`) belongs to this language.
        public func matchesFileName(_ fileName: String) -> Bool {
            acceptedFileNames.contains(fileName.lowercased())
        }

        /// Whether a mod / pack title looks like a translation for this language.
        public func matchesTitle(_ name: String) -> Bool {
            let lower = name.lowercased()
            if titleMarkers.contains(where: { lower.contains($0) }) { return true }
            let code = smapiCode.uppercased()
            let pattern = "(?i)(^|[\\s\\-_\\[(:])\(code)(?:$|[\\s\\-_\\]) :])|(?<=[a-z])\(code)$"
            return name.range(of: pattern, options: .regularExpression) != nil
        }

        /// Lightweight script/content heuristic for C7-T1 link proposals.
        public func matchesSampleValues(_ values: [String]) -> Bool {
            guard !values.isEmpty else { return false }
            switch self {
            case .fr:
                return TranslationLinkMatcher.isFrench(values: values)
            case .zh:
                return Self.containsScript(values, ranges: [0x4E00...0x9FFF, 0x3400...0x4DBF])
            case .ja:
                return Self.containsScript(values, ranges: [0x3040...0x309F, 0x30A0...0x30FF, 0x4E00...0x9FFF])
            case .ko:
                return Self.containsScript(values, ranges: [0xAC00...0xD7AF, 0x1100...0x11FF])
            case .ru:
                return Self.containsScript(values, ranges: [0x0400...0x04FF])
            case .de, .es, .pt, .it, .tr, .hu:
                return values.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            }
        }

        private static func containsScript(_ values: [String], ranges: [ClosedRange<UInt32>]) -> Bool {
            var hits = 0
            for value in values.prefix(80) {
                if value.unicodeScalars.contains(where: { scalar in
                    ranges.contains { $0.contains(scalar.value) }
                }) {
                    hits += 1
                    if hits >= 2 { return true }
                }
            }
            return hits >= 1 && values.count <= 3
        }
    }

    /// Concrete selectable languages (excluding `.auto`).
    public static var selectableLanguages: [Resolved] { Resolved.allCases }

    /// Resolves `.auto` from StarHub's active app language and macOS preferred languages.
    public func resolve(appLanguage: String,
                        systemLocales: [String] = Locale.preferredLanguages) -> Resolved {
        if let explicit = Resolved(rawValue: rawValue) {
            return explicit
        }
        if let fromApp = Self.mapLocale(appLanguage) {
            return fromApp
        }
        for locale in systemLocales {
            if let fromSystem = Self.mapLocale(locale) {
                return fromSystem
            }
        }
        return .zh
    }

    private static func mapLocale(_ identifier: String) -> Resolved? {
        let lower = identifier.lowercased()
        let prefix = lower.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? lower
        return Resolved(rawValue: prefix)
    }

    /// Reads the current preference from `UserDefaults`.
    public static func currentPreference(in defaults: UserDefaults = .standard) -> TranslationTargetLanguage {
        guard let raw = defaults.string(forKey: UDKey.translationTargetLanguage),
              let parsed = TranslationTargetLanguage(rawValue: raw) else {
            return .auto
        }
        return parsed
    }

    /// Convenience for non-UI layers reading the currently active resolved language.
    public static func currentResolved(appLanguage: String? = nil,
                                       defaults: UserDefaults = .standard) -> Resolved {
        let lang = appLanguage ?? defaults.string(forKey: "appLanguage") ?? ""
        return currentPreference(in: defaults).resolve(appLanguage: lang)
    }
}
