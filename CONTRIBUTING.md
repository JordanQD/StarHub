# Contribuer à StarHubFR

*[English version below](#contributing-to-starhubfr).*

Merci de votre intérêt pour StarHubFR, gestionnaire de mods Stardew Valley natif pour macOS. Ce guide dit comment signaler un problème, proposer une idée et faire accepter un changement de code.

## Signaler, proposer, demander

Ouvrez une [issue](../../issues/new/choose) et choisissez le modèle qui correspond :

- **Bug de l'app** — un écran, un bouton ou une donnée qui ne va pas.
- **SMAPI ou installation de mod** — une archive qui ne s'installe pas, un jeu qui ne démarre plus.
- **Mod non détecté** — un mod absent de la liste, ou avec un mauvais nom, une mauvaise version.
- **Idée** — une fonction qui manque.
- **Question** — tout le reste.

Cherchez d'abord dans les [issues existantes](../../issues?q=is%3Aissue) : un doublon fait perdre du temps à tout le monde.

**Une faille de sécurité ne s'ouvre jamais en issue publique** : voir [SECURITY.md](SECURITY.md).

## Traductions

Deux choses distinctes portent ce nom :

- **L'interface de l'app** vit dans `assets/{en,fr,zh-Hans}.json`. Chaque langue a les mêmes clés et conserve les arguments de format.
- **Les traductions de mods** ne sont pas hébergées ici. L'onglet Traduction de l'app écrit le `fr.json` d'un mod sur votre Mac ; pour partager une traduction, publiez-la sur Nexus Mods avec l'accord de l'auteur du mod.

## Préparer l'environnement

- L’application fonctionne à partir de macOS 14.
- **Xcode 26.3 ou ultérieur** sur un Mac compatible pour compiler l’application et son icône Icon Composer. La CI utilise Xcode 26.3 pour l’application et Xcode 16.4 pour les tests SwiftPM. Les seuls Command Line Tools ne suffisent pas.
- Python 3 pour les outils de maintenance, notamment le contrôle de conventions exécuté en CI.

Si `xcode-select -p` pointe sur `/Library/Developer/CommandLineTools`, la compilation échoue sur `external macro implementation type 'SwiftUIMacros.StateMacro' could not be found`, répété sur chaque `@State`. Ce n'est pas une erreur de code. Préfixez la commande :

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project StarHub.xcodeproj -scheme StarHub build
```

## Compiler et tester

```bash
xcodebuild -project StarHub.xcodeproj -scheme StarHub build
swift scripts/check-localizations.swift
./run_tests.sh                         # tests du cœur (Swift Testing)
./run_tests.sh --filter Keybind        # une seule famille de tests
```

- Ouvrez `StarHub.xcodeproj` et choisissez le schéma StarHub pour compiler puis lancer l’application.
- `Package.swift` ne décrit que le **cœur** testable (modèles, magasins, analyseurs). Les vues et le ViewModel ne s'y compilent pas, donc ne se testent pas.

## Règles du code

- **Une logique pure va dans le cœur** (`StarHub/Models/`, déclarée dans `Package.swift`), avec ses tests. Un état partagé va dans son propre magasin (`StarHub/Stores/`). Rien de neuf n'entre dans `StarHubTHViewModel`.
- **Cliquet des conventions** : `check_standards.py`, lancé en CI, échoue si un compteur augmente — fichier de plus de 400 lignes (taille verrouillée fichier par fichier), abréviation `vm`, nouveau `DispatchQueue`, nouveau singleton `.shared`. `python3 check_standards.py --report` donne l'état.
- **Localisation** : chaque libellé passe par `L10n.swift` et existe sous la même clé dans les trois catalogues. La CI vérifie les clés et les arguments de format.
- **Vocabulaire métier** : lisez [`docs/DOMAINE.md`](docs/DOMAINE.md) avant de toucher aux mods, profils, sauvegardes ou traductions. Un mod en pause est un dossier préfixé d'un point (`Mods/.X`), jamais un dossier déplacé.
- **Les tests n'écrivent jamais dans le vrai dossier de l'app** (`~/Library/Application Support/StarHubFR/`) : un magasin testé reçoit un dossier temporaire.
- Pas de nouvelle dépendance externe sans en discuter d'abord dans une issue.
- **Le guide utilisateur fait partie de l'app** : la fenêtre d'aide affiche le guide dans la langue de l’interface. Si un libellé ou un geste change, mettez à jour les trois guides. Chaque section garde son marqueur `<!-- help: id -->`, sinon le build échoue.

La carte du code — couches, flux, données sur disque, outillage — est dans [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). Les pièges techniques connus (SwiftUI, processus, concurrence, analyse des manifestes) sont consignés dans [`AGENTS.md`](AGENTS.md), section 4.

## Proposer une pull request

1. Pour un changement important, ouvrez d'abord une issue : on se met d'accord avant que vous écriviez le code.
2. Forkez, puis créez une branche depuis `main`.
3. Un commit par changement logique, au format `type(portée): description` — par exemple `fix(raccourcis): …`, `feat(performances): …`, `docs(readme): …`. Français ou anglais.
4. Ajoutez une ligne au `CHANGELOG.md`, sous `## [Unreleased]`, en français : ce qui change pour l'utilisateur, en moins de 300 caractères.
5. Joignez une capture d'écran si l'interface change, en français et à la largeur minimale de la fenêtre si possible.
6. La CI doit être verte. Elle compile l’application et le cœur, lance les tests et vérifie les conventions.

Si un assistant IA a écrit un commit, terminez son message par un trailer `Co-Authored-By:` qui nomme le modèle réellement utilisé.

## Comportement

Soyez bienveillant et patient : les personnes qui ouvrent une issue ont des niveaux techniques très variés. Une critique porte sur le code, jamais sur la personne.

---

# Contributing to StarHubFR

Thanks for your interest in StarHubFR, a native macOS mod manager for Stardew Valley. The French section above is the reference; this is a summary.

## Report, suggest, ask

Open an [issue](../../issues/new/choose) and pick a template: **App bug**, **SMAPI or mod install**, **Mod not detected**, **Feature idea** or **Question**. Search [existing issues](../../issues?q=is%3Aissue) first. **Never report a security flaw in a public issue**: see [SECURITY.md](SECURITY.md).

## Translations

- **The app's interface** lives in `assets/{en,fr,zh-Hans}.json`. Keep the same localization keys and format arguments in all three catalogs.
- **Mod translations** are not hosted here. The app's Translation tab writes a mod's `fr.json` on your Mac; to share one, publish it on Nexus Mods with the mod author's consent.

## Set up, build, test

The app runs on macOS 14 or later. Building the app and its Icon Composer icon requires full **Xcode 26.3 or later** on a compatible Mac. CI uses Xcode 26.3 for the app and Xcode 16.4 for the SwiftPM tests. The maintenance tools use Python 3.

```bash
xcodebuild -project StarHub.xcodeproj -scheme StarHub build
swift scripts/check-localizations.swift
./run_tests.sh                         # core tests (Swift Testing)
```

If the build fails on `external macro implementation type 'SwiftUIMacros.StateMacro' could not be found`, the active toolchain is the Command Line Tools: prefix the command with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Open `StarHub.xcodeproj` to run the app. `Package.swift` covers the testable core.

## Code rules

- Pure logic goes into the core (`StarHub/Models/`, listed in `Package.swift`) with tests; shared state gets its own store (`StarHub/Stores/`). Nothing new goes into `StarHubTHViewModel`.
- `check_standards.py` fails when a counter grows: files over 400 lines (locked per file), the `vm` abbreviation, new `DispatchQueue`, new `.shared` singletons.
- Every UI string uses the same key and format arguments in all three catalogs. CI checks both.
- Read [`docs/DOMAINE.md`](docs/DOMAINE.md) before touching mods, profiles, saves or translations. A paused mod is a dot-prefixed folder (`Mods/.X`).
- Tests never write to the real `~/Library/Application Support/StarHubFR/`.
- The code map (layers, flows, on-disk data, tooling) is in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), in French; known pitfalls are in [`AGENTS.md`](AGENTS.md), section 4.
- The user guide is part of the app: the help window shows the guide in the app’s language. When an interface label or action changes, update all three guides and keep each section’s `<!-- help: id -->` marker.

## Pull requests

Discuss large changes in an issue first. Branch from `main`, one commit per logical change (`type(scope): description`), add a line under `## [Unreleased]` in `CHANGELOG.md` (in French, user-facing), attach a screenshot for UI changes, and make sure CI is green. CI builds the app and the core, runs the tests, and checks conventions. If an AI assistant wrote a commit, end it with a `Co-Authored-By:` trailer naming the model actually used.
