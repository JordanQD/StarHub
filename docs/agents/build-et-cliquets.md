# Build, tests et cliquets — détails

Déplacé d'`AGENTS.md` §2 le 2026-11-14 (allègement) : le pourquoi et les détails des commandes. Les commandes et règles restent dans `AGENTS.md` §2. Lire quand un build ou un test échoue de façon inattendue, ou avant de toucher un cliquet.

## Build de l'app (`python3 build_app.py`, le vrai gate)

- `swiftc` brut sur **tous** `.swift` sous `StarHubTH/` (un module), **mode Swift 6** (`-swift-version 6`). Incrémental ; `--whole-module` = ancien chemin.
- Si `xcode-select -p` pointe sur Command Line Tools : échec `external macro implementation type 'SwiftUIMacros.StateMacro' could not be found` — pas erreur de code. Préfixer `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- Valide la **parité des clés** d’interface entre les langues (build en erreur sinon).
- Génère `assets/*.lproj/Localizable.strings` + `compile_commands.json` (racine, gitignoré : alimente SourceKit-LSP sur *tous* fichiers ; seul : `python3 build_app.py --gen-compile-commands`).

## Tests SPM

- **`DEVELOPER_DIR` OBLIGATOIRE** : `Testing` (Swift Testing, `import Testing`) exige **Xcode.app complet**, pas Command Line Tools.
- Sans `DEVELOPER_DIR` : `no such module 'Testing'` — **limite d'environnement, pas régression**.
- 4 877 `@Test`, 213 `@Suite` explicites, 262 cibles (relevé 2026-11-05).
- CI GitHub (Xcode 16.4, Swift 6.0) = juge : chaîne locale plus récente, écart de mode de langage invisible en local.

## `swift build` (Core seulement)

- Compile seulement sous-ensemble `Package.swift` (`ModItem`, managers backup, `SaveManager`, `L10n`, etc.) — **pas** UI ni ViewModel complet.
- Check rapide logique Core ; ne remplace pas `build_app.py`.

## Les deux cliquets

- **`check_standards.py`** / `.standards-baseline.json` — cliquet conventions
  Swift, lancé par `build_app.py` après compilation réussie. Échoue seulement
  si compteur **augmente** (code viole massivement ces règles aujourd'hui).
  Baisser puis `--update` pour resserrer ; ajout délibéré = `--update`
  explicite, visible au diff. `--skip-standards` débloque build ponctuel.
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
