# Conventions de code et checklist — texte complet

Déplacé d'`AGENTS.md` §4 et §8 le 2026-11-14 (allègement) : texte d'origine, mot pour mot, avec les raisons et précisions qu'`AGENTS.md` résume en une ligne. Les numéros sont ceux d'`AGENTS.md`, cités dans le code et les skills (`AGENTS §4.3`, « point 10 de la checklist »). Lire quand la ligne d'`AGENTS.md` ne suffit pas à trancher un cas.

## 4. Conventions de code — PIÈGES CRITIQUES

### 4.0 Traps détaillés — rappel par sujet (cavemem)

Pièges techniques détaillés, **chers à retrouver**, vivent dans cavemem. **Rappeler bloc AVANT toucher domaine**, pas après accident :

- SwiftUI / AppKit → `caveman mem recall "starhubfr traps swiftui"`
- Process, Pipe, système de fichiers → `caveman mem recall "starhubfr traps process"`
- Concurrence, caches, threads → `caveman mem recall "starhubfr traps concurrence"`
- Manifestes, i18n, Nexus, smapi.io, parsing → `caveman mem recall "starhubfr traps parsing"`
- Build, release, tests, cliquets → `caveman mem recall "starhubfr traps build"`
- UI, listes, sidebar, toggles de mods → `caveman mem recall "starhubfr traps ui"`
- Sonde, parc, HUD en jeu, mesure guidée → `caveman mem recall "starhubfr traps sonde"`

Sur hit, sortie = forme compacte ; `caveman mem recover <handle>` rend original octet pour octet.

### 4.1 Toggle de mods = préfixe point (DEPUIS juillet 2026)
- **Mod désactivé vit dans `Mods/` préfixé d'un point** : `Mods/.CJBCheats` (SMAPI ignore dossiers pointés).
- **`ModItem.folderName` est LOGIQUE** (jamais de point) — clé du registre, profils, timestamps, backups.
- **`ModItem.physicalFolderName`** (computed) = nom disque : `.` + folderName si désactivé.
- Toggle = **rename atomique même-parent** O(1), pas déplacement.
- **Tout chemin disque** utilise `physicalFolderName`, pas `folderName`.
- **`Mods_disabled/` n'existe plus** sauf legacy (migration one-shot + avertissement permanent).

### 4.2 Parsing de manifest.json
- **Jamais `.allowFragments`** : manifest DOIT être objet JSON ; accepter scalaire masquerait fichier corrompu.
- Options : `.json5Allowed` (macOS 12+) — mods Stardew ont commentaires/trailing commas.
- Stripper commentaires bloc `/* ... */` avant parsing : `rawString.replacingOccurrences(of: "/\\*[\\s\\S]*?\\*/", with: "", options: .regularExpression)`.

### 4.3 UserDefaults — clés centralisées
- **Toutes clés dans `UDKey.swift`** — jamais string littérale dans le code.
- Clé de migration one-shot **retirée à version N+1** (commentaire dans UDKey.swift).

### 4.4 Appels réseau Nexus
- **Tous via `NexusRequestBuilder.makeRequest(...)`** (`Models/NexusRequestBuilder.swift`).
- Source unique : `apiBase`, `gameDomain`, `appName`, headers.
- Requêtes **sérielles** (pas de parallélisme) : rate limit.

### 4.5 Parsing des uniqueIds SMAPI
- Format `Author.ModName`. Centralisé `Extensions/SmapiUniqueId.swift` : `.smapiModName`, `.smapiAuthor`.

### 4.6 Concurrency / DispatchQueue
- **`weak self` obligatoire** dans toute closure passée à `DispatchQueue.global().async`.
- ViewModel + stores = `@MainActor @Observable` : **pas de `@Published`** (ne compile plus chez eux) — `var` stockée déjà suivie, état observable `private(set)`. Mutations d'état observé **toujours sur main thread**. Cinq types restent `ObservableObject` (`SmapiInstaller`, `BisectionRunner`, `KeybindScanService`, `LocalizationStore`, `ModListFilters`).
- **Méthode `@MainActor` appelée depuis fil de fond tue l'app** : mode Swift 6 vérifie à l'exécution. Ni gate ni tests ne le voient.
- **Structure mutable partagée entre scans** (cache manifests, registre) protégée par `NSLock` dédié. `scanMods()` tourne en background et peut tourner **en concurrence avec lui-même** (refresh + initial load, activation de profil vs refresh). Sans lock, subscript setter d'un `Dictionary` → `EXC_BAD_ACCESS` (crash confirmé juillet 2026 sur `manifestCache`).

### 4.7 `Process()` (sous-processus)
- Toujours **setter locale** `en_US_POSIX` : parsing indépendant de la langue système (unzip, etc.).

### 4.8 Force-unwrap
- **Interdit dans `CodeEditorView`**, à éviter partout. Préférer `guard let` / `if let`.

### 4.9 Symlink `/tmp` → `/private/tmp` (PIÈGE macOS)
- `FileManager.enumerator` rend chemins **résolus** (`/private/tmp/...`) même si root `/tmp/...`.
- **Toujours résoudre `fileURL.path`** via `resolvingSymlinksInPath()` avant `replacingOccurrences(of: resolvedRoot)`.
- Sinon chemin relatif corrompu (`private/.X/...` au lieu de `.X/...`).

### 4.10 `findExistingMod` — group-aware
- Chercher dans `children` des groupes (packs), en-têtes à `uniqueId` vide, pour détecter conflits sur mods installés en pack.

## 8. Résumé — checklist avant de valider un changement

1. [ ] `python3 build_app.py` passe (compile + parité L10n).
2. [ ] `./run_tests.sh` passe (~4 900 tests).
3. [ ] Touché un catalogue de l’interface : mêmes clés et arguments de format dans les trois langues.
4. [ ] Touché chemin disque de mod : `physicalFolderName`, pas `folderName`.
5. [ ] Nouveau code réseau : via `NexusRequestBuilder`.
6. [ ] Nouveau code asynchrone : `weak self` + mutations sur main ; aucune méthode `@MainActor` appelée depuis fil de fond.
7. [ ] Nouvelle fonctionnalité : store ou type pur, pas ViewModel (F1-T2).
8. [ ] Parsing de manifest : pas de `.allowFragments`, strip commentaires.
9. [ ] Énumération de fichiers : résoudre symlinks avant comparaison de chemins.
10. [ ] Touché URL, chemin d'API, en-tête ou constante de contrat externe :
       `python3 check_sources.py --offline` — **expliquer** l'écart, pas le
       taire (écart ≠ échec ; `--update` ne fait pas taire le script).
11. [ ] CHANGELOG à jour si changement visible par l'utilisateur.
12. [ ] Pas de lancement d'app ni capture depuis l'agent.
