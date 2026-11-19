import Foundation

/// C7-T2 — l'orchestration de la confirmation Remplacer/Garder, hors du
/// ViewModel (règle F1-T2 : le god-object ne grossit pas). L'état publié
/// reste sur le VM (`pendingTranslationInstall`), muté ici via
/// `storePendingTranslation`.
extension StarHubTHViewModel {

    /// Le conflit que la garde voit pour ce dépôt (identité entrante = la
    /// même sonde que le dépôt, `DepositIdentity.resolve`).
    func translationConflict(for host: ModItem, incomingSourceName: String,
                             nexus: NexusModSearch.Hit?,
                             downloadedModId: Int?) -> TranslationDuplicateConflict? {
        let incoming = DepositIdentity.resolve(nexus: nexus, sourceName: incomingSourceName,
                                               downloadedModId: downloadedModId, at: Date())
            .entry(hostFolderName: host.folderName, sourceName: incomingSourceName,
                   installedAt: Date(), files: [], replacedFiles: [:])
        let hostPath = URL(fileURLWithPath: gameDir)
            .appendingPathComponent("Mods")
            .appendingPathComponent(host.physicalFolderName).path
        let declaredFolder = translationHub.installed
            .declaredTranslation(forHost: host.folderName)?.packFolderName
        let declaredPackEnabled = declaredFolder.flatMap { folder in
            mods.flattenedMods.first { $0.folderName == folder }?.isEnabled
        } ?? false
        return TranslationDuplicateGuard.conflict(
            hostFolderName: host.folderName, incoming: incoming,
            registry: translationHub.installed, proposedLinks: translationHub.proposedLinks,
            hostPath: hostPath, declaredPackEnabled: declaredPackEnabled)
    }

    /// Le chemin déposé (glisser-déposer, `nxm://`) passe ici avant
    /// `depositIntoMod` : `nil` = demande différée au dialogue (l'appelant
    /// garde son extrait temporaire en vie), sinon le résultat du dépôt
    /// direct, inchangé.
    @discardableResult
    func requestTranslationDeposit(plan: ManifestlessArchive.Plan, extractedRoot: URL,
                                   sourceName: String, downloadedModId: Int?,
                                   host: ModItem) -> (outcome: ManifestlessInstaller.Outcome?,
                                                      message: String?)? {
        if isPendingTranslationPrompt {
            showModal(message: localization.L(L10n.Mods.translationReplaceBusy))
            return nil
        }
        if let conflict = translationConflict(for: host, incomingSourceName: sourceName,
                                              nexus: nil, downloadedModId: downloadedModId) {
            storePendingTranslation(
                .dropped(plan: plan, extractedRoot: extractedRoot, sourceName: sourceName,
                         downloadedModId: downloadedModId, host: host),
                conflict: conflict)
            log("Traduction déjà en place : confirmation demandée", level: .info)
            return nil
        }
        return depositIntoMod(plan: plan, extractedRoot: extractedRoot, host: host,
                              sourceName: sourceName, nexus: nil,
                              downloadedModId: downloadedModId)
    }

    /// « Remplacer » : le consentement est donné — **court-circuit de la
    /// garde**, sinon le conflit se re-déclencherait avant que
    /// `depositIntoMod` n'ait désinstallé l'incumbent (boucle de dialogue).
    /// Ordre imposé : dépôt d'abord ; oubli de déclaration, pause du pack et
    /// refus C7-T1 **sur succès seulement** — un dépôt qui échoue ne doit
    /// rien dégrader autour de lui.
    func confirmPendingTranslationReplace() {
        guard let pending = pendingTranslationInstall else { return }
        storePendingTranslation(nil, conflict: nil)
        let host = pending.host
        let result: (outcome: ManifestlessInstaller.Outcome?, message: String?)
        switch pending {
        case .nexus(let archive, let hit, let hostMod):
            do {
                let extracted = try ModZipInstaller().extractToTemp(zipUrl: archive)
                defer { try? FileManager.default.removeItem(at: extracted) }
                let paths = ManifestlessArchive.paths(under: extracted)
                let plan: ManifestlessArchive.Plan
                switch ManifestlessArchive.classify(paths: paths,
                                                    installedFolderNames: [hostMod.folderName]) {
                case .plan(let p): plan = p
                case .needsHost(_, _, let found):
                    plan = ManifestlessArchive.Plan(hostFolderName: hostMod.folderName,
                                                    kind: .translation, entries: found)
                case .unrecognised:
                    showModal(message: localization.L(L10n.Mods.translationUnrecognised))
                    return
                }
                result = depositIntoMod(plan: plan, extractedRoot: extracted, host: hostMod,
                                        sourceName: hit.name, nexus: hit)
            } catch {
                showModal(message: localization.L(L10n.Mods.translationInstallFailed))
                log("Dépôt de traduction : \(error)", level: .error)
                return
            }
            NexusFileDownload.discardDownloaded(at: archive) // consommée ou abandonnée
        case .dropped(let plan, let extractedRoot, let sourceName,
                      let downloadedModId, let hostMod):
            result = depositIntoMod(plan: plan, extractedRoot: extractedRoot, host: hostMod,
                                    sourceName: sourceName, nexus: nil,
                                    downloadedModId: downloadedModId)
        }
        if let message = result.message { showModal(message: message) }
        guard result.outcome != nil else { return }
        applyDeclaredSideEffects(forHost: host.folderName)
        log(String(format: localization.L(L10n.Mods.translationInstalled),
                   pendingDescription(pending), host.name))
        refresh()
    }

    /// « Garder » : rien n'a été écrit. L'archive Nexus non consommée est
    /// purgée ; l'extrait du chemin déposé reste à sa vue (nettoyage à sa
    /// fermeture habituelle).
    func cancelPendingTranslationReplace() {
        guard let pending = pendingTranslationInstall else { return }
        storePendingTranslation(nil, conflict: nil)
        if case .nexus(let archive, _, _) = pending {
            NexusFileDownload.discardDownloaded(at: archive)
        }
    }

    /// Le volet b, après un dépôt réussi : oublier la déclaration C7-T1,
    /// mettre le pack en pause (réversible, jamais une suppression — et pas
    /// de re-bascule s'il est déjà en pause), et mémoriser le refus C7-T1
    /// du pack — sinon le recompute re-proposerait aussitôt le pack fraîchement
    /// pausé vers cet hôte.
    private func applyDeclaredSideEffects(forHost hostFolderName: String) {
        guard let declared = translationHub.installed.declaredTranslation(forHost: hostFolderName),
              let folder = declared.packFolderName, !folder.isEmpty else { return }
        translationHub.mutateInstalled { _ = $0.undeclare(forHost: hostFolderName) }
        if InstalledTranslationStore.save(installedTranslations) {
            log("Déclaration de traduction retirée pour \(hostFolderName)", level: .info)
        }
        if let pack = mods.flattenedMods.first(where: { $0.folderName == folder }) {
            if pack.isEnabled { toggleMod(pack) }
        } else {
            showModal(message: localization.L(L10n.Mods.translationReplacePackGone))
        }
        rememberDismissedProposal(packFolderName: folder)
    }

    /// Un libellé pour le journal — le nom porteur d'identité du pending.
    private func pendingDescription(_ pending: PendingTranslationInstall) -> String {
        switch pending {
        case .nexus(_, let hit, _): return hit.name
        case .dropped(_, _, let sourceName, _, _): return sourceName
        }
    }
}
