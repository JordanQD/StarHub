import Foundation

/// C7-T1 — le type pur des propositions de lien « pack-traduction posé
/// comme un mod → son hôte ».
///
/// **Le calibre repose sur la mesure du 2026-11-18** (script jetable sur le
/// parc réel, voir `docs/SOURCES.md` §5) : 598 traductions posées — l'hôte
/// vrai sort en tête pour 97,6 % d'entre elles, sans ex-æquo pour 95,6 % —
/// mais les 44 recouvrements forts « non-self » du parc sont presque tous
/// des **fratries** (mod ↔ son pack compagnon `[CP]`, séries de packs
/// sociaux, variantes `.old`/`Alt`), pas des couples hôte/traduction. D'où
/// les trois signaux obligatoires — marqueur de nom, langue française du
/// candidat, recouvrement fort non-self — et l'exclusion des jumeaux d'
/// `uniqueId` égal. **Limite assumée** : un mod français marqué FR qui
/// recouvre une variante sœur passerait les trois signaux ; la confirmation
/// de l'utilisateur tranche, et le retrait de la déclaration (sans écriture
/// disque) défait le lien.
///
/// **Le type ne lit pas le disque et ne parse pas** : les ensembles de clés
/// arrivent prêts (lecture lenient `I18nLenientParser.parse(Data)` du côté
/// de l'appelant — JSONC, UTF-16, jeux 8 bits ; 313 traductions du parc
/// sont du JSONC, strict JSON en perd 300+).
public struct TranslationLinkProposal: Equatable, Sendable {
    /// La force de la preuve : `.keys` = l'empreinte seule désigne l'hôte ;
    /// `.nameAndKeys` = l'empreinte était un ex-æquo que le nom du dossier a
    /// tranché (le niveau « nom + clés » de Translation Hub).
    public enum Evidence: Equatable, Sendable { case keys, nameAndKeys }

    public let packFolderName: String
    /// Le nom du **manifeste** du candidat — c'est lui que porte la
    /// déclaration, pas une relecture au moment de la confirmation.
    public let packName: String
    public let packVersion: String?
    /// L'identité Nexus **du candidat** (son `UpdateKeys`), `nil` s'il n'en
    /// porte pas — la déclaration créée sera alors sans suivi de version.
    public let nexusId: Int?
    public let hostFolderName: String
    /// La part des clés du candidat recouvertes par l'origine de l'hôte.
    public let coverage: Double
    public let evidence: Evidence
    /// Les hôtes à l'ex-æquo non tranché par le nom, du second au dernier —
    /// l'UI en offre le choix ; vide, l'hôte est sans ambiguïté.
    public let alternates: [String]
}

/// Un pack vu par le calcul des propositions. `keySet` arrive prêt (clés de
/// `i18n/default.json`, à défaut `fr.json`) ; `nil` = illisible → jamais
/// candidat ni hôte.
public struct TranslationLinkPack: Equatable, Sendable {
    public let folderName: String
    public let physicalFolderName: String
    public let name: String
    /// Vide si le manifeste n'en porte pas — un jumeau d'`uniqueId` identique
    /// non vide est exclu du pool des hôtes (copies, variantes `.old`).
    public let uniqueId: String
    public let isMarked: Bool
    public let isFrench: Bool
    public let keySet: Set<String>?
    public let nexusId: Int?

    public init(folderName: String, physicalFolderName: String, name: String,
                uniqueId: String, isMarked: Bool, isFrench: Bool,
                keySet: Set<String>?, nexusId: Int?) {
        self.folderName = folderName
        self.physicalFolderName = physicalFolderName
        self.name = name
        self.uniqueId = uniqueId
        self.isMarked = isMarked
        self.isFrench = isFrench
        self.keySet = keySet
        self.nexusId = nexusId
    }
}

/// Les règles pures du rattachement : marqueur de nom, langue du candidat,
/// empreinte des clés. Rien de réseau, rien de disque.
public enum TranslationLinkMatcher {
    /// Le marqueur de nom de traduction. Les frontières ont été relues après
    /// la mesure : le cas **collé** `EasyAccessButtonsFR` (camelCase) doit
    /// matcher comme les formes séparées (`-FR`, « FR de », `Français`).
    private static let marker = try! NSRegularExpression(
        pattern: "(?i)(^|[\\s\\-_\\[(:])FR(?:$|[\\s\\-_\\]) :])|(?<=[a-z])FR$|fran[çc]ais|french|traduction|translation")

    /// Un marqueur de traduction dans le nom du dossier **ou** du manifeste.
    public static func isMarked(name: String) -> Bool {
        marker.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) != nil
    }

    private static let accents = Set("éèêëàâçùûüôîïœ")
    private static let stopwords = ["le", "la", "les", "une", "des", "est",
                                    "pour", "avec", "dans", "vous", "votre"]

    /// La leçon Transtar (`docs/SOURCES.md` §5) : juger la **langue du
    /// texte**, pas le nom du fichier. Français si ≥ 20 % des valeurs de ≥
    /// 15 caractères (non numériques) portent un accent français ou un
    /// mot-outil (mot entier, casse ignorée).
    public static func isFrench(values: [String]) -> Bool {
        let long = values.filter { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 15,
                  trimmed.rangeOfCharacter(from: .letters) != nil
            else { return false }
            return true
        }
        guard !long.isEmpty else { return false }
        let hits = long.filter { value in
            if value.contains(where: { accents.contains($0) }) { return true }
            let padded = " \(value.lowercased()) "
            return stopwords.contains { padded.contains(" \($0) ") }
        }
        return Double(hits.count) / Double(long.count) >= 0.20
    }

    /// L'identifiant Nexus porté par des `UpdateKeys` (« Nexus:55410 », la
    /// variante `Nexus:55410@Main` tolérée) — le premier qui parse ; `nil`
    /// si aucun ne parse (pack sans page : lien sans suivi de version).
    public static func nexusId(fromUpdateKeys keys: [String]) -> Int? {
        for key in keys where key.lowercased().hasPrefix("nexus:") {
            let digits = key.dropFirst("nexus:".count).prefix(while: { $0.isNumber })
            if let id = Int(digits) { return id }
        }
        return nil
    }

    /// Une proposition au plus par candidat — le meilleur hôte non-self au
    /// dessus du seuil, l'ex-æquo tranché par le nom ou porté en
    /// `alternates`. Les packs non marqués ne sont jamais candidats ; les
    /// jumeaux d'`uniqueId` identique non vide ne sont jamais hôtes ; une
    /// paire **réciproquement marquée** ne propose rien automatiquement.
    public static func propose(packs: [TranslationLinkPack],
                               coverageThreshold: Double = 0.70) -> [TranslationLinkProposal] {
        let pool = packs.filter { ($0.keySet?.count ?? 0) > 0 }
        var out: [TranslationLinkProposal] = []
        for candidate in packs {
            guard candidate.isMarked, candidate.isFrench,
                  let ck = candidate.keySet, ck.count >= 5
            else { continue }
            var scored: [(coverage: Double, pack: TranslationLinkPack)] = []
            for host in pool where host.folderName != candidate.folderName {
                if !candidate.uniqueId.isEmpty, host.uniqueId == candidate.uniqueId {
                    continue
                }
                guard let hk = host.keySet else { continue }
                let coverage = Double(ck.intersection(hk).count) / Double(ck.count)
                if coverage >= coverageThreshold {
                    scored.append((coverage, host))
                }
            }
            scored.sort {
                ($0.coverage != $1.coverage)
                    ? $0.coverage > $1.coverage
                    : $0.pack.folderName < $1.pack.folderName
            }
            guard let top = scored.first else { continue }
            // Réciprocité marquée : l'hôte est lui aussi un candidat, et son
            // meilleur non-self est le candidat — deux traductions de la
            // même série se désigneraient l'une l'autre à l'infini.
            if top.pack.isMarked, bestNonSelf(of: top.pack, in: pool) == candidate.folderName {
                continue
            }
            let ties = scored.filter { top.coverage - $0.coverage < 0.001 }
            // Le nom ne tranche qu'un ex-æquo : un meilleur hôte seul reste
            // une preuve par clés, même quand le nom correspondrait aussi.
            let resolved = ties.count > 1
                ? ties.first { folded(candidate.name).contains(folded($0.pack.name)) }
                : nil
            let host = resolved?.pack ?? top.pack
            let alternates = ties.map(\.pack.folderName).filter { $0 != host.folderName }
            out.append(TranslationLinkProposal(
                packFolderName: candidate.folderName,
                packName: candidate.name,
                packVersion: nil,
                nexusId: candidate.nexusId,
                hostFolderName: host.folderName,
                coverage: top.coverage,
                evidence: resolved != nil ? .nameAndKeys : .keys,
                alternates: alternates))
        }
        return out
    }

    /// Le meilleur non-self de l'hôte — par nom de dossier.
    private static func bestNonSelf(of host: TranslationLinkPack,
                                    in pool: [TranslationLinkPack]) -> String? {
        guard let hk = host.keySet, !hk.isEmpty else { return nil }
        var best: (coverage: Double, folder: String)?
        for pack in pool where pack.folderName != host.folderName {
            guard let pk = pack.keySet, !pk.isEmpty else { continue }
            let coverage = Double(hk.intersection(pk).count) / Double(hk.count)
            if best == nil || coverage > (best?.coverage ?? 0) {
                best = (coverage, pack.folderName)
            }
        }
        return best?.folder
    }

    private static func folded(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                     locale: nil)
    }
}
