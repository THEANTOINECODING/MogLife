# Journal des décisions

Format : date — décision — raison. La plus récente en haut.

## 2026-10-14 (carte)

- **D34 — Un seul Kevin pour toute la ville** (choix du créateur) : il traîne sur son canapé dans le square nord-est, à côté de la salle de quartier, au lieu d'un Kevin dans chaque garage. Les garages gardent le curl et les pompes.

- **D33 — Ville carrée et compacte, déplacements rapides** : tout se passe au centre, les maisons sont autour, les boutiques et la salle donnent sur la route juste en face des maisons. Bouton « Maison », bus entre 5 arrêts, icônes au-dessus des bâtiments, guide vers le prochain boss quand le joueur est prêt, statues des 3 meilleurs moggers du serveur, cycle jour/nuit. Raison : 20 joueurs par serveur et des allers-retours fréquents entre la maison et le centre.
- **D32 — Une maison de maman par joueur** (choix du créateur) : serveur de 20 joueurs max, maison attribuée à l'arrivée ; elle contient le garage (curl, pompes) et maman (Kevin : voir D34). Décoration sur 8 emplacements fixes, meubles achetés en Cash au magasin de meubles, certains réservés à un stade ; maisons ouvertes aux visiteurs. Le miroir est remplacé par la boutique de vêtements (hauts, accessoires) et le coiffeur (coupes).

- **D31 — Carte hybride** : la structure (bâtiments, rue, sols) est faite de blocs Roblox générés par `tools/build_map.py` et versionnés via Rojo ; les objets de décor détaillés seront modélisés dans Blender ensuite. Raison : agencement rapide à modifier et testable tout de suite, détails low poly ajoutés une fois le plan validé.
- **D30 — La ville s'appelle Muscle City** (choix du créateur).

## 2026-10-14 (lancement de l'étape E — visuels)

- **D29 — Le coach est un mentor mystérieux** (lunettes de soleil, proverbes absurdes, apparaît de nulle part).
- **D28 — Personnages : squelette R15 standard + coque visuelle modélisée dans Blender** (une par stade et par PNJ). Raison : les animations Roblox fonctionnent sans rigging complexe, les habits restent compatibles, et c'est ce que l'IA produit le plus sûrement.
- **D27 — Ambiance évolutive** : chaque zone a sa propre ambiance (garage bricolé → rue pastel → plage ensoleillée → montagne années 80 → Lune → Olympe doré). L'étape E commence par les personnages (choix du créateur).

## 2026-10-14 (retour du créateur après avoir joué)

- **D26 — Quota de rythme côté serveur** au lieu d'un écart fixe entre répétitions : jamais plus de répétitions que le temps écoulé ne le permet (+1). Raison : les jeux de réaction peuvent produire deux réponses rapprochées sans permettre d'aller plus vite en moyenne.
- **D25 — Le MVP va jusqu'à Gigachad** : 5 boss (Kevin → Le Roi du Quartier), 6 exercices, 8 aides. Le Dieu du Pump est annoncé « coming soon ». Raison : le jeu se terminait trop vite.
- **D24 — Les combats de boss peuvent vraiment être perdus** : le boss joue en direct avec son propre niveau, chaque manche est plus rapide et plus exigeante, et perdre un Mog-off coûte 5 % du Cash (annoncé, plafonné ; rien en revanche). Remplace « défaite sans perte » de D13 pour le Mog-off.
- **D23 — Chaque activité a son propre mini-jeu** (exercices, aides, boss), aucune réutilisation. Remplace D9. Raison : demande du créateur, la réutilisation rendait les activités répétitives. La simplicité est conservée grâce à `MinigameKit`.

## 2026-10-14 (nuit, implémentation autonome — choix PROVISOIRES à valider par le créateur)

- **D22 — Aucun essayage gratuit au miroir pour l'instant.** Le design le prévoit ; à faire avec le vrai personnage (étape E).
- **D21 — Une aide ne peut pas « rater » : terminer les 12 répétitions suffit à être payé.** Le design dit « une aide ratée ne coûte rien » sans définir l'échec. ❓ Faut-il un score minimum ?
- **D20 — Le mode auto est autorisé pendant les aides, interdit pendant les combats de boss.** Raison : la récompense d'une aide est fixe ; un combat mesure l'habileté. ❓ À confirmer.
- **D19 — « Le boss devient moins exigeant après 3 défaites » n'est pas implémenté** (marqué ❓ dans le design).
- **D18 — Défier un boss d'un stade supérieur (sans avoir battu le précédent) = défaite automatique, avec la même perte de Cash annoncée** (« Bats d'abord Kevin ! »). Un boss déjà battu peut être revu pour le plaisir : ni récompense ni perte.
- **D17 — Une manche de boss non jouée se termine d'elle-même** (répétitions manquantes = 0 point), pour qu'un joueur inactif ne bloque pas le combat.

## 2026-10-13 (session 3)

- **D16 — Jeu multilingue via la localisation Roblox.** Textes du jeu écrits en anglais (langue source), français relu à la main, autres langues en traduction automatique Roblox. Le design reste en français. Raison : chaque joueur voit le jeu dans la langue de son compte ; l'anglais touche le plus de joueurs et se traduit le mieux automatiquement ; l'humour exige une relecture humaine au moins en français.

## 2026-10-13 (session 2)

- **D15 — Les objets de style sont purement esthétiques.** Raison : simple, équitable, et compatible avec une future vente en Robux sans déséquilibre.
- **D14 — Les aides demandent un seuil de Mog/stade ; le Mog n'est jamais dépensé.** Raison : plus simple, jamais punitif.
- **D13 — Défier un boss trop tôt = défaite comique automatique et perte de 10 % du Cash (plafonnée), annoncée avant.** Pas de perte de Mog. Raison : vrai enjeu sans faire redescendre de stade.
- **D12 — Personnage cartoon propre au jeu (un corps par stade), pas l'avatar Roblox.** Raison : l'avatar Roblox ne permet pas les traits exagérés voulus ; donne du sens à la boutique de coupes et d'habits.
- **D11 — Direction artistique très absurde, « à la Douchebag Workout », traits toujours exagérés** (designs originaux).
- **D10 — Un boss par stade.** Le battre fait monter de stade et débloque la suite.
- ~~**D9 — Chaque exercice a une mécanique de mini-jeu différente ; aides et boss réutilisent ces mini-jeux.**~~ → Remplacée par D23. Raison : variété pour le joueur, coût de production faible.
- **D8 — Deux ressources : Mog (gagné par les exercices) et Cash (gagné en aidant la ville, dépensé en style). La Force disparaît.** Raison : demande du créateur ; plus simple à comprendre et à produire.
- **D7bis — Priorité à la simplicité : un petit noyau (mini-jeux + contenu en données + personnage), puis des mises à jour à recette fixe.**
- Remplace : D3, D4, D5, D6 ci-dessous (design « exploits », archivé dans `archive/v3_exploits/`).

## 2026-10-13 (session 1)

- **D7 — Design réorganisé en dossier `design/`, un fichier par sujet.**
- ~~D6 — Le duel de pose devient un mode secondaire.~~ → Duels entre joueurs reportés (IDEES.md).
- ~~D5 — Idée centrale : la force agit sur la ville.~~ → Remplacée par D8–D10.
- ~~D4 — Cash par les petits boulots, Force par l'entraînement.~~ → Remplacée par D8.
- ~~D3 — Quartiers ouverts par des exploits d'histoire.~~ → Zones ouvertes par les boss (D10).
- **D2 — Base de la V2 du 13/10/2026** (`archive/GAME_DESIGN_V2.md`) : on garde pas d'énergie, pas de boutique payante en prototype, pas de rebirth, sécurité serveur, monétisation honnête, mode auto gratuit, tests.
- **D1 — Titre : « MOG LIFE : become a GOD MOGGER 💪🗿 ».**
