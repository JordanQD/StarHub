import Foundation

/// C7-T1 — les règles d'appariement entre une **proposition de lien**
/// (pack-traduction posé comme un mod → son hôte) et le registre des
/// déclarations. Le calcul des propositions vit dans
/// `TranslationLinkProposal.swift` ; ce fichier porte ce qui décide si un
/// lien est **déjà posé** et comment le créer — jamais d'accès disque ni de
/// réseau : tout passe par le registre reçu en paramètre.
///
/// Deux clés d'appariement, par ordre de fiabilité : le **dossier du pack**
/// (`packFolderName`, porté par les déclarations créées depuis une
/// proposition) puis l'**identifiant Nexus** de la traduction. Un pack
/// rattaché ne doit jamais être re-proposé — le refus de la proposition
/// sans lien créé est, lui, mémorisé ailleurs (clé `UDKey`, voir la spec).

// MARK: - La déclaration

extension DeclaredTranslation {
    /// Cette déclaration couvre-t-elle déjà la liaison proposée ? Vrai par
    /// dossier de pack identique (la preuve la plus directe), sinon par
    /// identifiant Nexus égal **non nul** — les deux côtés désignent alors
    /// la même page, donc la même traduction.
    public func matchesLink(packFolderName: String, nexusId: Int?) -> Bool {
        if self.packFolderName == packFolderName {
            return true
        }
        if let nexusId, nexusModId == nexusId {
            return true
        }
        return false
    }
}

// MARK: - Le registre

extension InstalledTranslationRegistry {
    /// Un lien équivalent à la proposition est-il déjà posé ? C'est le filtre
    /// qui empêche la re-proposition d'un pack déjà rattaché, au recompute
    /// comme après redémarrage.
    public func isLinkDeclared(packFolderName: String, nexusId: Int?) -> Bool {
        declaredTranslations.values.contains {
            $0.matchesLink(packFolderName: packFolderName, nexusId: nexusId)
        }
    }

    /// Les hôtes qui portent une déclaration — le pool des « déjà liés »,
    /// pour l'UI (la carte dit alors que l'hôte suit déjà une traduction).
    public func declaredLinkHosts() -> Set<String> {
        Set(declaredTranslations.keys)
    }
}

// MARK: - La confirmation

public enum TranslationLinkConfirmation {
    /// Crée la déclaration que la confirmation de la carte propose, pour
    /// l'hôte de la proposition, en portant le dossier du pack.
    ///
    /// Le `name`, la `version` et le `nexusId` viennent du **manifeste du
    /// candidat relu au moment de la confirmation** (paramètres, pas champs
    /// de la proposition) : le manifeste peut avoir changé depuis le
    /// recompute, et c'est la réalité du disque qui doit gagner. `nexusId`
    /// `nil` = pack sans page (option B) : le lien existe, **sans suivi de
    /// version** — l'UI le dit avant le clic.
    ///
    /// Zéro accès disque ici : la mutation du registre est pure, la
    /// persistance reste à l'appelant (contrat du store).
    @discardableResult
    public static func apply(proposal: TranslationLinkProposal,
                             name: String, version: String?, nexusId: Int?,
                             to registry: inout InstalledTranslationRegistry,
                             declaredAt: Date) -> DeclaredTranslation {
        let declaration = DeclaredTranslation(
            nexusModId: nexusId, nexusName: name, version: version,
            updatedAt: nil, declaredAt: declaredAt,
            packFolderName: proposal.packFolderName)
        registry.declare(declaration, forHost: proposal.hostFolderName)
        return declaration
    }
}
