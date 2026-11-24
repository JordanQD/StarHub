# Architecture — points sensibles, détails

Déplacé d'`AGENTS.md` §4.6 et §5 le 2026-11-14 (allègement). Les numéros de section suivent ceux d'`AGENTS.md`, qui garde une ligne de règle par point. Lire avant de toucher au ViewModel, au scan de `Mods/`, au registre, au cache de manifests, à l'installation ou aux sauvegardes. Carte générale du code : `docs/ARCHITECTURE.md`.

## 4.6 Structure mutable partagée entre scans

**Structure mutable partagée entre scans** (cache manifests, registre) protégée par `NSLock` dédié. `scanMods()` tourne en background et peut tourner **en concurrence avec lui-même** (refresh + initial load, activation de profil vs refresh). Sans lock, subscript setter d'un `Dictionary` → `EXC_BAD_ACCESS` (crash confirmé juillet 2026 sur `manifestCache`).

## 5.1 `StarHubTHViewModel` = god-object

- ~7 800 lignes (7 843 au 2026-11-05). `scanMods()`, `performToggle`, `applyProfileToFilesystem`, `toggleAllMods`, `deleteMod`, `cleanDisabledMods`, `syncInstalledModRegistry` y vivent encore.
- Scan de `Mods/` (dont `parseModFolder`) dans `Models/ModScanner.swift`, détenu par VM (`private let scanner`).
- Refacto **en cours** (`docs/REFACTORING.md`) : état sort vers `StarHub/Stores/` (64 fichiers). Règle F1-T2 : fonctionnalité neuve naît dans son type (store ou type pur dans `Models/`), jamais dans VM. Taille VM verrouillée par cliquet.

## 5.2 Registre des mods installés

- Porté par `Stores/InstalledModRegistryStore.swift`. Clé UserDefaults `installedModRegistry` (blob JSON, ~90 Ko).
- Clé de secours `installedModRegistryBackup` + **restauration auto si corruption** + **reconstruction depuis disque**. ⚠️ Secours reçoit **mêmes octets** à chaque écriture : couvre clé illisible, pas retour à génération précédente.
- Cache mémoire (thread-safe, NSLock) — un decode par session au lieu de 100+ par scan.
- Sync fin de chaque `scanMods()` : capture installs par tous moyens (drag-drop, copie manuelle, installer).

## 5.3 Cache de manifests (DEPUIS juillet 2026)

- `manifestCache: [String: (mtime: Date, manifest: [String: Any])]` dans `ModScanner` (`Models/ModScanner.swift`), sous `manifestCacheLock`. Classe, pas valeur : deux scans concurrents partagent même cache.
- Key = chemin absolu du manifest.json. Hit = mtime identique → reuse JSON décodé.
- Rescan sans changement = ~N `stat()` + 0 decode.

## 5.4 Scanner — énumération à deux niveaux

- **Niveau 1 (top-level)** : `contentsOfDirectory` **sans** `skipsHiddenFiles` → voit les `.X`.
- Classification manuelle : `.X` = désactivé, `X` = activé, OS junk = skip.
- **Niveau 2 (sous-scan récursif)** : `enumerator` **avec** `.skipsHiddenFiles` → cache junk imbriqué (`.DS_Store`, `.git/`, `._Foo`).
- `relativePath` calculé **relativement au physicalRoot** (dossier entry), pas à `modsPath` — sinon point fuit dans `folderName`.

## 5.5 Drag-and-drop install

- **NE JAMAIS écraser** `config.json` ni `fr.json` d'un mod existant (conflit signalé).
  **Seule exception (X136)** : à la mise à jour, un `config.json` identique octet pour octet à celui d'une version de l'auteur (empreinte Nexus ou journal local de l'archive livrée), quand l'archive neuve en livre un autre — jamais modifié, il ne porte aucun réglage ; le neuf le remplace, le bilan le dit, l'ancien reste dans la sauvegarde d'installation. Sans preuve d'empreinte : gardé.
- Nouveau mod → désactivé par défaut (`Mods/.X`).
- Update d'un mod **activé** → reste activé (`Mods/X`).

## 5.6 Backups

- `ModInstallBackupManager` (install) et `ModConfigBackupManager` (config) **distincts, non consolidés**.
- Rétention hybride 3 niveaux pour backups d'installation.
- `restoreBackup` restaure en **désactivé** (`Mods/.X`).
