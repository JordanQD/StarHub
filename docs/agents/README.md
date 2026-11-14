# docs/agents — détails des consignes d'`AGENTS.md`

`AGENTS.md` est chargé à chaque message par les agents : il garde les commandes, les règles et une ligne par piège. Le 2026-11-14, le détail, le pourquoi et ce qui est daté sont passés ici. Les numéros de section suivent ceux d'`AGENTS.md`.

| Fichier | Sections d'`AGENTS.md` | Lire quand |
|---|---|---|
| ce fichier | §1, §1 bis | pour le détail de l'identité du projet et des sources à consulter |
| [`conventions-code.md`](conventions-code.md) | §4, §8 | la ligne d'un piège ou d'un point de checklist ne suffit pas |
| [`build-et-cliquets.md`](build-et-cliquets.md) | §2 | un build ou un test échoue de façon inattendue ; avant de toucher un cliquet |
| [`architecture.md`](architecture.md) | §4.6, §5 | avant de toucher au ViewModel, au scan, au registre, au cache, à l'installation ou aux sauvegardes |
| [`ui.md`](ui.md) | §6 | avant de toucher à un bouton à libellé, une rangée, un segment ou au splash |
| [`redaction-git-release.md`](redaction-git-release.md) | §3, §7 | avant de rédiger un texte affiché ou un CHANGELOG, de signer un commit, de couper une release |

## En-tête d'origine

> **LIRE OBLIGATOIREMENT avant toute modification de ce projet.**
> Conventions, pièges techniques, commandes validées. **Source unique** des
> consignes pour tous agents : `CLAUDE.md` l'importe (`@AGENTS.md`) et ne
> garde que le propre à Claude Code. *Procédures* détaillées → skills
> (`.claude/skills/`, copiés dans `.agents/skills/`) ; sources → §1 bis.

## §1 — Identité du projet, texte complet

- **StarHubFR** — gestionnaire mods Stardew Valley macOS (SwiftUI, macOS 14+).
- Fork de **StarHubTH** (AppleBoiy). Source : `StarHubTH/`. Bundle : `StarHubFR.app` (exécutable `StarHubFR`).
- Bundle ID `com.mrbabilo.StarHubFR` (F5, 2026-09-10) : préférences + Trousseau séparés de l'upstream. Ancien `com.appleboiy.StarHubTH` lu **en secours** (`KeychainSecret.legacyService`, `DefaultsMigration`).
- Données sous `~/Library/Application Support/StarHubFR/` (`Backups/` compris, depuis X105).
- UI **bilingue** : `en` + `fr`. Thaï UI retiré, « Thai Translation Hub » aussi (C5-T1, 2026-09-24) : remplacé par page « Traductions FR ».

## §1 bis — Sources à consulter, texte complet

Ordre d'utilité (chaque doc porte ce que code ne dit pas) :

- **`docs/DOMAINE.md`** — vocabulaire métier (« pack », « profil », « sauvegarde » ≠ sens upstream).
- **`docs/ROADMAP.md`** — ce qui **reste** à faire. ⚠️ Cases en retard sur code livré : vérifier `git log` avant tâche « à faire ». Identifiant absent roadmap = livré : chercher dans `docs/roadmap-archive.md` (mesures à ne pas refaire).
- **`docs/SOURCES.md`** — carte hors-dépôt : API interrogées, dumps, code repris. Obligatoire avant client réseau (Nexus, smapi.io, DeepL, IA locale) ou parseur format externe. Valeurs relevées par `check_sources.py`.
- **`docs/REFACTORING.md`** — plan refacto ViewModel (règle F1-T2, §5.1). État en retard : vérifier `git log`.
- **`docs/archive/kilo-plans/`** — archives ère Kilo : **raisonnement** derrière choix en place. Lire pour « pourquoi », jamais comme consigne (cases sans valeur, partie livrée autrement). Reste de `.kilo/` ignoré.
- **`docs/superpowers/`** — specs + plans récents, gitignorés (absents d'un clone frais).

## §4.6 — Types restés `ObservableObject`

Cinq types restent `ObservableObject` (`SmapiInstaller`, `BisectionRunner`, `KeybindScanService`, `LocalizationStore`, `ModListFilters`) ; ViewModel et stores sont `@MainActor @Observable` (`var` stockée déjà suivie, état observable `private(set)`).
