# Build, tests et cliquets — détails

Déplacé d'`AGENTS.md` §2 le 2026-11-14 (allègement) : le pourquoi et les détails des commandes. Les commandes et règles restent dans `AGENTS.md` §2. Lire quand un build ou un test échoue de façon inattendue, ou avant de toucher un cliquet.

## Build de l’application

- Ouvrir le schéma partagé StarHub dans Xcode, ou lancer `xcodebuild -project StarHub.xcodeproj -scheme StarHub build`.
- Le projet compile les sources de `StarHub/` et copie les ressources dans le produit. Le schéma conserve le mode Swift 5 du précédent build incrémental.
- L’icône `assets/StarHub.icon` est compilée par Xcode 26.3 ou ultérieur. En CI, cette version sert au build de l’application ; les tests SwiftPM utilisent Xcode 16.4.
- `swift scripts/check-localizations.swift` vérifie les trois tables `Localizable.strings`. Les tests du guide vérifient les sections et leurs liens.
- Pour la distribution, `./scripts/release.sh` requiert .NET et les DLL du jeu, compile la sonde et archive l’application. Pour une installation du jeu personnalisée, définissez `GamePath` sur le dossier `Contents/MacOS` du jeu.

## Tests SPM

- **`DEVELOPER_DIR` OBLIGATOIRE** : `Testing` (Swift Testing, `import Testing`) exige **Xcode.app complet**, pas Command Line Tools.
- Sans `DEVELOPER_DIR` : `no such module 'Testing'` — **limite d'environnement, pas régression**.
- 4 877 `@Test`, 213 `@Suite` explicites, 262 cibles (relevé 2026-11-05).
- CI GitHub (Xcode 16.4, Swift 6.0) = juge : chaîne locale plus récente, écart de mode de langage invisible en local.

## `swift build` (Core seulement)

- Compile seulement sous-ensemble `Package.swift` (`ModItem`, managers backup, `SaveManager`, `L10n`, etc.) — **pas** UI ni ViewModel complet.
- Check rapide logique Core ; ne remplace pas `xcodebuild`.

## Les deux cliquets

- **`check_standards.py`** / `.standards-baseline.json` — cliquet conventions
  Swift, lancé par la CI. Échoue seulement
  si compteur **augmente** (code viole massivement ces règles aujourd'hui).
  Baisser puis `--update` pour resserrer ; ajout délibéré = `--update`
  explicite, visible au diff.
  **Taille** verrouillée **par fichier** (clés `file:<chemin>`, une par
  fichier > 400 lignes) : les deux sommes se compensaient entre fichiers,
  ~16 000 lignes de marge muette au ViewModel (mesuré 2026-09-11 —
  `docs/REFACTORING.md` §3 bis).
- **`check_sources.py`** / `.sources-baseline.json` — pendant pour le **hors**
  dépôt : API appelées, dumps téléchargés, projets dont code repris. Carte +
  raisonnement : `docs/SOURCES.md`.
  ⚠️ **Écart ≠ échec** : nouvelle version SMAPI = chose à regarder, pas bug
  — l'expliquer, pas la taire ; `--update` jamais pour faire taire le script.
  Depuis agent : `--offline` (passe complète sonde smapi.io, GitHub raw,
  Nexus ; sources injoignables reportées à part, hors écarts).
