# UltraSmooth 2.9.2 et PureBinarySave 2.0.6 — décompilés du parc *(2026-11-18)*

Le parc a été mis à jour par l'app entre les relevés du 11 et du 18 novembre :
UltraSmooth **2.9.2** et PureBinarySave **2.0.6** y sont actifs, Radiance
2.4.9 en pause. Les deux DLL neuves ont été décompilées **depuis le parc** et
comparées aux décompilations gardées (UltraSmooth 2.8.4, PureBinarySave
1.0.10) ; au passage, Stardropium 0.3.0 a été re-décompilé (la passe du
2026-11-02 avait échoué et la remesure du catalogue reposait alors sur la
carte de la sonde) et Radiance 2.4.9 décompilée. Copies et notes de
mécaniques dans `~/Outils/analyses/{ultrasmooth-2.9.2,purebinarysave-2.0.6,
stardropium-0.3.0,radiance-2.4.9}/`. Rien exécuté.

## UltraSmooth 2.9.2

**225 appels de patch** (contre 228 en 2.8.4). Toutes les cibles du catalogue
A5-T7 côté UltraSmooth sont encore posées — les six qui ne se voient pas dans
les appels littéraux (`GetTilesByProperty` de Farm Type Manager, la traversée
SpaceCore `FindAndRemoveModNodes`, l'itérateur de sauvegarde, les deux setters
TMXTile, le balayage `Monster.update`) sont toutes présentes dans le code
(chaînes et balayages vérifiés).

### Le module Content Patcher réécrit (2.9.0)

L'ancien duo — préfixe sur `Condition.UpdateContext` de Content Patcher et
patch de `GameContentHelper.InvalidateCache` (SMAPI) — **disparaît**. Le
remplaçant : un nouveau préfixe sur `Condition.UpdateContext` plus des
accroches aux internes d'énumération des jetons CP (`GetToken`, `GetValues`,
`SplitValuesUnique`, `MoveNext`…), pour un filtrage d'assets et de conditions
« zéro allocation » pendant les mises à jour dynamiques. Conséquences pour
nous :

- la **seule commune avec PureBinarySave** (`InvalidateCache`, relevée
  « hors catalogue, sous le seuil » le 2026-11-11) tombe à **zéro** :
  PureBinarySave 2.0.6 garde son lot `EnableCpBatching` (23 mentions), mais
  UltraSmooth ne pose plus rien dessus ;
- les nouvelles cibles sont **internes à Content Patcher** : aucun autre mod
  du catalogue ne les touche, le catalogue ne bouge pas ;
- la ligne `us_frameworks` du rapport dit désormais les « skips » du
  pré-filtre et les hits du cache de conditions.

Autres cibles neuves : `PathFindController.isPositionImpassableForNPCSchedule`
et `returningToEndPoint` (horaires de PNJ, l'axe des festivals passifs des
journaux), `AddUnreadyToken` (synchronisation du prêt multijoueur).

### `us_trace` — ce que D2-T2 doit lire (format au 2.9.2)

Les cinq sections du rapport sont inchangées
(`[1. HARDWARE & DISPLAY ENVIRONMENT]` → `[5. AUTOMATIC ROOT CAUSE
ISOLATION & DIAGNOSIS]`), et les suffixes `| Menu: …` / `| Weather: …` de la
2.3.7 sont toujours là. Deux changements :

1. **Un quatrième type de pic** rejoint `Frame Render Hitch`,
   `Game Loop CPU Spike` et `Location Warp` : **`10-Minute In-Game Clock
   Tick`**, dont le `Details` porte la durée brute de
   `performTenMinuteClockUpdate`. Un parseur qui énumérait trois types doit
   en accepter quatre (ou ignorer l'inconnu avec compteur) ;
2. le `Details` du `Frame Render Hitch` **s'étoffe** (2.8.10) : après la
   durée et les FPS, il porte désormais
   `Upd:…ms Draw:…ms Ext:…ms | GC(+a/+b/+c) -> <mémoire>` — le découpage
   CPU/dessin/présentation et les comptes de collections par pic. Section
   [4] : les huit pires pics seulement, sur une liste roulante de cent
   évènements au-delà de 25 ms.

Le reste du rapport gagne en détail sans changer de forme (compteurs GC de
session en section [3], diagnostic d'horloge en section [5] désormais
alimenté aussi par les pics d'horloge).

### X139 et les réglages

`EnableLocationTimeSlicing` reste **vrai par défaut** en 2.9.2, et un
correctif 2.8.x empêche une copie de configuration de l'éteindre par
accident : l'étalement des lieux hors écran est toujours au programme, la
capture de confirmation demandée par X139 reste de mise. Les journaux
annoncent aussi la bascule à chaud du pacing `TimeChanged` sans redémarrage
et le retrait de clés i18n en double — les comptes `config.*` du corpus de
l'éditeur seront relus à la prochaine capture de sonde, sans changement
attendu de forme.

## PureBinarySave 2.0.6 — la garde X138 vérifiée en DLL

Le journal de la 2.0.4 annonçait un suivi de synchronisation `.bin.sync` ;
la décompilation le confirme, et voici exactement ce qu'il garantit.

**La mécanique.** À côté de chaque `<partie>.bin` vit un `<partie>.bin.sync`
de 16 octets : la date UTC et la **longueur** du XML principal au moment où
le binaire a été écrit ou relu. À chaque décision de lecture, le mod compare
l'état actuel du XML à cette empreinte :

- **divergence** (Windows : ticks exacts ; macOS : tolérance de 5 secondes,
  longueur égale exigée) et XML bien formé → statut « XML changé ou
  restauré » ;
- **pas de fichier de suivi** (sauvegardes d'avant la 2.0.4) → secours par
  dates : XML plus récent que le binaire de plus de 10 secondes → même
  verdict ;
- XML absent, tronqué ou mal formé → l'ancien chemin de récupération : le
  binaire reconstruit le XML.

**Ce que fait le verdict « XML changé ou restauré »** : ligne de journal
`[AutoHeal] Detected rolled-back or externally updated XML`, suppression du
`.bin` **et** de son suivi, puis re-migration **depuis le XML courant** —
c'est-à-dire exactement le scénario X138 dans le bon sens : une partie
modifiée par l'app (éditeur, traduction, retrait de mods absents) pendant
que le jeu était fermé **gagne à la lecture** ; le binaire périmé est jeté
et réécrit, jamais l'inverse.

**Ce qui reste vrai et ne change pas pour l'app** : pendant une session de
jeu ouverte, l'état en mémoire reste la seule vérité et le XML est
recopié ~6 secondes après le réveil puis au coucher — une écriture de l'app
**pendant que le jeu tourne** reste écrasée (inhérent, déjà documenté) ;
l'app lit elle-même le `.bin` depuis X138 et continue. L'alerte `.bin`
périmé de l'app reste posée comme filet : la garde est vérifiée en DLL mais
pas encore **en jeu** ; réévaluer à l'occasion d'une session guidée.

**Le reste du delta 2.0.x, vérifié dans la DLL** : protection explicite de
`spacecore-serialization.json` contre l'écrasement par le backup XML en
tâche de fond (2.0.2 — SpaceCore est actif sur le parc) ; priorité de
chargement des caches d'assets et de cartes passée à `Low` (2.0.3, les packs
Content Patcher ne rentrent plus en conflit de chargement) ; isolation et
contrôles d'intégrité du Centre communautaire et du Musée avec commande de
validation dédiée (2.0.4/2.0.5) ; support Android avec préchargements coupés
(2.0.6). DLL passée de 431 Ko de décompilation (1.0.10) à 570 Ko.

## Stardropium 0.3.0 et Radiance 2.4.9 — remesure du catalogue

Stardropium 0.3.0 re-décompilé intégralement (54 modules dans le projet) :
les cibles du catalogue sont inchangées. Radiance 2.4.9 : mêmes cibles
qu'en 2.4.7, les journaux ne décrivent que des correctifs de rendu. La seule
« commune de plus » sortie de l'intersection littérale — le champ des
textures de tuiles du périphérique d'affichage (`XnaDisplayDevice`) — est
**lu** par `AccessTools.Field` chez les deux mods, pas patché : ce n'est pas
un recouvrement.

**Verdict catalogue** : les 21 méthodes UltraSmooth × Stardropium, 15
UltraSmooth × Radiance et 5 Radiance × Stardropium tiennent toutes sur les
versions du parc ; aucune paire nouvelle, aucune retirée.
`PerformanceOverlap.swift` passe à UltraSmooth **2.9.2** et Radiance
**2.4.9**, sans changement de méthode.
