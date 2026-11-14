# AGENTS.md — StarHubFR (fork de StarHubTH)

> **LIRE OBLIGATOIREMENT avant toute modification de ce projet.**
> **Source unique** des consignes pour tous agents : `CLAUDE.md` l'importe (`@AGENTS.md`), garde seulement le propre à Claude Code. Procédures → skills (`.claude/skills/`, copiés dans `.agents/skills/`) ; détail et pourquoi des règles → `docs/agents/` (index `docs/agents/README.md`, renvoi dans chaque section).

---

## 1. Identité du projet

- **StarHubFR** — gestionnaire mods Stardew Valley macOS (SwiftUI, macOS 14+), fork de **StarHubTH** (AppleBoiy). Source `StarHubTH/`, bundle `StarHubFR.app`, ID `com.mrbabilo.StarHubFR` (ancien `com.appleboiy.StarHubTH` lu en secours). Données : `~/Library/Application Support/StarHubFR/`. UI `en` + `fr` seulement. Détail : `docs/agents/README.md`.

**Avant toucher mods, SMAPI, Nexus, profils, sauvegardes ou fichiers traduction : lire `docs/DOMAINE.md`.**

## 1 bis. Sources à consulter — au-delà de ce fichier

- `docs/DOMAINE.md` — vocabulaire métier (≠ sens upstream).
- `docs/ROADMAP.md` — ce qui **reste** ; cases en retard : vérifier `git log`. Identifiant absent = livré → `docs/roadmap-archive.md`.
- `docs/SOURCES.md` — obligatoire avant client réseau ou parseur de format externe.
- `docs/REFACTORING.md` — plan refacto ViewModel (§5.1) ; état en retard : `git log`.
- `docs/archive/kilo-plans/` — pourquoi des choix, jamais consigne. `docs/superpowers/` — specs récentes, gitignorées.
- Texte complet : `docs/agents/README.md`.

---

## 2. Build & test — COMMANDES EXACTES

```bash
python3 build_app.py                     # vrai gate : swiftc mode Swift 6 + parité en/fr
./run_tests.sh                           # = DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
python3 check_standards.py --report      # cliquet conventions Swift
python3 check_sources.py --offline       # cliquet sources externes (agent : --offline)
```

- **Toujours `python3`**, jamais `python` (absent du PATH).
- **`DEVELOPER_DIR` obligatoire** pour tests ; `no such module 'Testing'` ou `StateMacro could not be found` = Command Line Tools, pas régression.
- Code de sortie : `python3 build_app.py | tail` rend celui de `tail`.
- `swift build` = Core seulement, ne remplace pas `build_app.py`. Sans `swift test` → skill `build-app`. CI GitHub (Swift 6.0) = juge.
- Cliquets : échec seulement si compteur **augmente** ; `--update` explicite, visible au diff, **jamais pour faire taire** ; écart de `check_sources.py` ≠ échec : l'expliquer (skill `check-sources`).
- Détail : `docs/agents/build-et-cliquets.md` (échec inattendu, avant toucher un cliquet).

### Règle absolue
**Ne jamais lancer l'app ni prendre de capture depuis un agent.** Vérif GUI déléguée à l'humain ; agents valident par build + tests.

---

## 3. Localisation — RÈGLES STRICTES

- **Source de vérité** : `assets/{en,fr}.json` ; `assets/*.lproj/Localizable.strings` générés par `build_app.py` (relancer après édition JSON), **jamais édités**.
- **Parité obligatoire** : `en.json` et `fr.json` = **exactement mêmes clés** (build valide). Clés via `L10n.swift` (`static let`) ; clé absente → clé brute, pas crash.
- **Français naturel, pas calqué sur anglais** (libellés, aide, README, CHANGELOG, notes) ; vocabulaire déjà affiché gardé sauf demande ; relire avant release → `docs/agents/redaction-git-release.md`, skill `localization`.

---

## 4. Conventions de code — PIÈGES CRITIQUES

### 4.0 Traps détaillés — rappel par sujet (cavemem)
Rappeler bloc **AVANT** toucher domaine : `caveman mem recall "starhubfr traps <sujet>"` — `swiftui` (SwiftUI/AppKit), `process` (Process, Pipe, fichiers), `concurrence` (caches, threads), `parsing` (manifestes, i18n, Nexus, smapi.io), `build` (release, tests, cliquets), `ui` (listes, sidebar, toggles), `sonde` (parc, HUD, mesure guidée). Hit compact ; `caveman mem recover <handle>` rend original octet pour octet.

### 4.1 Toggle de mods = préfixe point (DEPUIS juillet 2026)
- Mod désactivé = `Mods/.CJBCheats` (SMAPI ignore dossiers pointés) ; toggle = **rename atomique même-parent**.
- **`ModItem.folderName` LOGIQUE** (jamais de point : clé registre, profils, timestamps, backups) ; **tout chemin disque** via `physicalFolderName`.
- `Mods_disabled/` = legacy seulement (migration one-shot + avertissement).

### 4.2 Parsing de manifest.json
- **Jamais `.allowFragments`** (manifest = objet JSON) ; `.json5Allowed` ; stripper `/* ... */` avant : `rawString.replacingOccurrences(of: "/\\*[\\s\\S]*?\\*/", with: "", options: .regularExpression)`.

### 4.3 UserDefaults — clés centralisées
- **Toutes clés dans `UDKey.swift`**, jamais littérale ; clé de migration one-shot **retirée à version N+1**.

### 4.4 Appels réseau Nexus
- **Tous via `NexusRequestBuilder.makeRequest(...)`** (`apiBase`, `gameDomain`, `appName`, headers) ; requêtes **sérielles** (rate limit).

### 4.5 Parsing des uniqueIds SMAPI
- `Author.ModName` via `Extensions/SmapiUniqueId.swift` (`.smapiModName`, `.smapiAuthor`).

### 4.6 Concurrency / DispatchQueue
- **`weak self` obligatoire** dans closure passée à `DispatchQueue.global().async`.
- ViewModel + stores = `@MainActor @Observable` : **pas de `@Published`** ; mutations d'état observé **toujours sur main thread** (cinq `ObservableObject` restants : `docs/agents/README.md`).
- **Méthode `@MainActor` appelée depuis fil de fond tue l'app** (vérif à l'exécution, invisible au gate et aux tests).
- Structure partagée entre scans (cache manifests, registre) sous `NSLock` dédié : `scanMods()` concurrent avec lui-même (crash confirmé → `docs/agents/architecture.md`).

### 4.7 `Process()` (sous-processus)
- Toujours locale `en_US_POSIX` (parsing indépendant de la langue système).

### 4.8 Force-unwrap
- **Interdit dans `CodeEditorView`**, à éviter partout : `guard let` / `if let`.

### 4.9 Symlink `/tmp` → `/private/tmp` (PIÈGE macOS)
- `FileManager.enumerator` rend chemins **résolus** : `resolvingSymlinksInPath()` sur `fileURL.path` avant `replacingOccurrences(of: resolvedRoot)`, sinon `private/.X/...`.

### 4.10 `findExistingMod` — group-aware
- Chercher aussi dans `children` des packs (en-têtes à `uniqueId` vide).

---

## 5. Architecture — points sensibles

Détail : `docs/agents/architecture.md` (avant toucher VM, scan, registre, cache, install, backups) ; carte : `docs/ARCHITECTURE.md`.

### 5.1 `StarHubTHViewModel` = god-object
- Règle F1-T2 : fonctionnalité neuve dans son store (`Stores/`) ou type pur (`Models/`), jamais VM (taille verrouillée par cliquet).

### 5.2 Registre des mods installés
- `Stores/InstalledModRegistryStore.swift` ; secours `installedModRegistryBackup` = **mêmes octets** (pas génération précédente).

### 5.3 Cache de manifests (DEPUIS juillet 2026)
- `ModScanner.manifestCache` sous `manifestCacheLock` ; hit = mtime identique.

### 5.4 Scanner — énumération à deux niveaux
- Niveau 1 sans `skipsHiddenFiles`, niveau 2 avec ; `relativePath` relatif au **physicalRoot**.

### 5.5 Drag-and-drop install
- **Garder toujours** `config.json` et `fr.json` d'un mod existant (seule exception : X136). Nouveau mod → désactivé ; update d'un activé → reste activé.

### 5.6 Backups
- Managers install et config **distincts** ; `restoreBackup` restaure en **désactivé**.

---

## 6. UI — contraintes fixes

- **Sidebar** : pas de barre de recherche. « Mod Updates » **toujours visible** (badge caché si 0).
- **Pages de liste** (`ModListView`, `LogsView`) : `VStack(spacing: 0)` — header fixe + Divider + ScrollView + footer fixe. **Pagination** : 12 mods/page, saut direct.
- Bouton textuel lisible à 560 pt **ou** icône seule + infobulle, jamais tronqué (`AdaptiveLabels`) ; rangée trop large → `SplitRow`, `WrapHStack`.
- Détail (segments, mesure des libellés, splash `NSPanel` et ses deux pièges AppKit) : `docs/agents/ui.md`.

---

## 7. Git & release

- Travailler sur `main`. **Pousser uniquement sur demande explicite** ; fetch + rebase avant (autres sessions poussent).
- Commits conventional (`feat:`, `fix:`, `chore:`, `docs:`), trailer nommant **modèle ayant réellement écrit** : `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>` (ou Sonnet, Haiku… selon modèle actif) ; GLM : `Co-Authored-By: GLM 5.3 <noreply@z.ai>`. Vérifier modèle actif (GLM via `glm.sh` affiche `sonnet`/`opus`).
- `CHANGELOG.md` : Keep a Changelog ; `[Unreleased]` **intégrée à la prochaine release, jamais supprimée**.
- Release → skill `release`. Détail signature et release : `docs/agents/redaction-git-release.md`.

---

## 8. Résumé — checklist avant de valider un changement

1. [ ] `python3 build_app.py` passe (compile + parité L10n).
2. [ ] `./run_tests.sh` passe.
3. [ ] Touché `en.json`/`fr.json` : parité + messages cohérents.
4. [ ] Chemin disque de mod : `physicalFolderName`.
5. [ ] Réseau : via `NexusRequestBuilder`.
6. [ ] Asynchrone : `weak self`, mutations sur main, aucune `@MainActor` depuis fil de fond.
7. [ ] Nouvelle fonctionnalité : store ou type pur (F1-T2).
8. [ ] Manifest : pas de `.allowFragments`, strip commentaires.
9. [ ] Énumération : symlinks résolus avant comparaison.
10. [ ] Touché URL, chemin d'API, en-tête ou constante de contrat externe : `python3 check_sources.py --offline`, **expliquer** l'écart.
11. [ ] CHANGELOG à jour si visible par l'utilisateur.
12. [ ] Pas de lancement d'app ni capture.

<!-- caveman-begin -->
Respond terse like smart caveman. All technical substance stay. Only fluff die.

Rules:
- Drop: articles (a/an/the), filler (just/really/basically), pleasantries, hedging
- Fragments OK. Short synonyms. Technical terms exact. Code unchanged.
- Pattern: [thing] [action] [reason]. [next step].
- Not: "Sure! I'd be happy to help you with that."
- Yes: "Bug in auth middleware. Fix:"

Switch level: /caveman lite|full|ultra|wenyan-lite|wenyan-full|wenyan-ultra
Stop: "stop caveman" or "normal mode"

Auto-Clarity: drop caveman for security warnings, irreversible actions, user confused. Resume after.

Boundaries: code/commits/PRs written normal.
<!-- caveman-end -->


## Mémoire agent (mise à jour : 2026-11-14)

Contexte global, valable pour tous les projets de David :

- OpenCode est l'agent principal : MCP globaux actifs — context7, deepwiki, chrome-devtools, notion, browse, crawl4ai (14 novembre 2026 : playwright désactivé, doublon de chrome-devtools et browse ; github désactivé, gh CLI connecté en remplacement). Claude Code : 4 MCP (caveman, chrome-devtools, leann-server, rea ; caveman-cloud retiré le 14 novembre 2026) et 12 plugins (plugin playwright désactivé). 25 skills globaux dans ~/.agents/skills (copie dans ~/.claude/skills ; usage dans ce projet : section « Skills à utiliser »). Les conventions de ce projet priment sur les skills génériques.
- Préférences : travail en français ; recommandations vérifiées (installations, étoiles, réputation de la source, scans de sécurité) avant d'installer un outil ; jamais de secret en clair dans les fichiers de config (variables d'environnement uniquement, syntaxe {env:VAR}) ; diagnostic de la cause avant de corriger.
- GitHub : compte mrbabilo. Clones locaux : /Volumes/BABILODONNEES/GitHub.
- Mémoire complète : page Notion « Mémoire agent — OpenCode (David) » — https://app.notion.com/p/4149fa0959e381cd944dfe54e3838b9d

### Ce projet
- Gestionnaire de mods Stardew Valley (Swift, Swift Package Manager, cible StarHubTHCore, macOS 14+ — cohérent avec Info.plist LSMinimumSystemVersion). 6 suites de tests SPM.
- Copie locale de StarHubFR (dépôt public github.com/mrbabilo/StarHubFR) — garder les deux noms en tête lors des échanges.

## Skills à utiliser

Noms des skills : OpenCode les lit dans `~/.agents/skills`. Claude Code les voit dans `~/.claude/skills`, sauf `brainstorming`, `writing-plans`, `test-driven-development` et `systematic-debugging`, qu'il appelle `superpowers:<nom>`. « Claude Code seul » marque un skill de plugin absent d'OpenCode. Les règles de ce fichier priment sur celles d'un skill.

- Méthode : `brainstorming` avant une fonction nouvelle, `writing-plans` avant un chantier en plusieurs étapes, `systematic-debugging` avant de corriger un bug, `test-driven-development` pour le code couvert par des tests.
- Skills du dépôt (`.claude/skills/`, copiés dans `.agents/skills/`) : `build-app` (vérifier un changement Swift, gate scindé), `localization` (ajouter ou modifier un texte affiché), `release` (couper une version), `audit-code` (audit du code fichier par fichier), `audit-ux` (audit ou refonte UX/UI), `caveman-learn` (réduire le coût en jetons d'un agent).
- `check-sources` : tout changement d'une source externe (API appelée, dump téléchargé, code repris), avec le cliquet `check_sources.py`.
- `swift-expert` : ingénierie Swift (concurrence, SPM, tests).
- `swiftui-design-skill` : esthétique des vues SwiftUI, dans les contraintes de la section 6.
