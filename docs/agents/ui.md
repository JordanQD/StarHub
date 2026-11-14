# UI — contraintes fixes, détails

Déplacé d'`AGENTS.md` §6 le 2026-11-14 (allègement) : texte complet des règles de boutons, de rangées et du splash, avec leurs dates et leurs pièges. `AGENTS.md` §6 garde une ligne de règle par point. Lire avant de toucher à un bouton à libellé, une rangée, un sélecteur segmenté ou au splash de lancement.

- **Boutons à libellé, fenêtre minimale** (consigne de l'auteur, 2026-09-25) : un bouton textuel reste lisible au volet le plus étroit (560 pt) **ou** se réduit à son icône, titre en infobulle. Jamais de libellé tronqué ou replié. Outil : `AdaptiveLabels` (`Label(titre, systemImage:)` + `.help(titre)` sur chaque bouton) ; un sélecteur segmenté pose deux variantes dans un `ViewThatFits` (`ModScopePicker`). ⚠️ Un segment macOS (`Picker(.segmented)`) rend du texte **ou** une image, jamais les deux : ni l'icône d'un `Label` ni une `Image` interpolée dans un `Text` n'y survivent. Icône + texte = boutons faits main (`ModScopePicker`).
- **Rangée trop large, autres formes** (revue de tous les écrans, 2026-09-25) : `SplitRow { gauche } trailing: { droite }` remplace `HStack { … ; Spacer() ; … }` et passe la droite à la ligne ; `WrapHStack` (Layout) replie des puces ou des colonnes figées en gardant l'alignement d'une ligne à l'autre. Symptômes d'une rangée qui ne tient pas : un texte écrit lettre par lettre à la verticale, ou toute la colonne décentrée et coupée des deux côtés. Mesurer les libellés FR (`NSString.size(withAttributes:)`), pas à l'œil ; dans `WrapHStack`, un `Divider` est horizontal — tracer un `Rectangle` 1×16.
- **Splash de lancement** : fenêtre séparée (`NSPanel`, `Views/LaunchSplashWindow.swift`), cover art, progression par phases ; les menus natifs restent en place, la fenêtre principale n'étant pas à l'écran. Deux pièges AppKit ont tué l'app au lancement : `applicationShouldTerminateAfterLastWindowClosed` doit rendre `false`, et fenêtre principale masquée dans `applicationWillFinishLaunching`, pas `.onAppear`.

## Texte d'origine des trois premières règles

- **Sidebar** : pas de barre de recherche. « Mod Updates » **toujours visible** (badge caché si 0).
- **Pages de liste** (`ModListView`, `LogsView`) : pattern `VStack(spacing: 0)` — header fixe + Divider + ScrollView + footer/pagination fixe.
- **Pagination** : 12 mods/page (`ModListView.pageSize`), saut de page direct.
