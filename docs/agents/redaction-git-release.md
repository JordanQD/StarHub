# Rédaction française, signature des commits et release — détails

Déplacé d'`AGENTS.md` §3 et §7 le 2026-11-14 (allègement) : texte complet, avec les dates des consignes et l'historique. `AGENTS.md` garde la règle en une ligne. Lire avant de rédiger un texte affiché, un CHANGELOG ou des notes de version, avant de signer un commit, ou avant une release (procédure : skill `release`).

## §3 — Français naturel

**Français naturel, pas calqué sur l'anglais** (consigne de l'auteur, 2026-10-18) : libellés, aide, README, CHANGELOG et notes de version se rédigent en français, pas en traduction littérale. La tournure est visée, pas le vocabulaire déjà affiché par l'app (« Configs », « benchmark ») : ne pas le changer sans demande. Avant chaque release, relire le CHANGELOG de la version, le README et les notes pour éviter les tournures de phrases anglaises (consigne de l'auteur, 2026-11-05). Exemples dans le skill `localization`.

## §7 — Git, texte d'origine

- Travailler sur `main`.
- **Pousser uniquement sur demande explicite de l'utilisateur.** Fetch + rebase avant : d'autres sessions poussent aussi sur `main`.
- Commits : style conventional (`feat:`, `fix:`, `chore:`, `docs:`).
- Terminer messages commit par trailer nommant **modèle ayant réellement écrit commit** — jamais nom figé :
  - Claude : `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>` (ou `Claude Sonnet 5`, `Claude Haiku 4.5`… selon modèle actif).
  - GLM : `Co-Authored-By: GLM 5.3 <noreply@z.ai>`.

## §7 — Modèle qui signe

⚠️ Dépôt travaillé par **plusieurs modèles**, dont GLM via `glm.sh` (route Claude Code vers API z.ai : modèle *actif* = GLM, quel que soit alias `sonnet`/`opus` affiché). Vérifier modèle actif avant signer. Historique avant 2026-07-30 porte `Claude Sonnet 5` sur 167 commits, y compris ceux d'autres modèles : pas source de vérité.

## §7 — Release

Release : version affichée (`CFBundleShortVersionString`) et section du CHANGELOG changées **à la main** ; `python3 release.py` incrémente `CFBundleVersion`, construit et zippe dans `bundles/StarHubFR_v<version>.zip`, sans rien publier ; commit d'`Info.plist`, tag signé, notes écrites à la main puis `gh release create --verify-tag`. → skill `release`.
