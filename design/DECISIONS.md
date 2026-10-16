# Journal des décisions

Format : date — décision — raison. La plus récente en haut.

## 2026-10-16 (améliorations validées par le créateur)

- **D54 — Musique par ambiance** (demande du créateur : la musique de la ville était trop forte et lassante). Ville : 3 morceaux acoustiques doux joués à la suite, volume bas. Pendant ses exercices et ses aides : musique d'entraînement (gardée 8 s après une série pour enchaîner). Combat de boss et sa présentation : musique de combat, repart du début à chaque combat. Fondus entre ambiances, reprise où on s'était arrêté, musique baissée pendant les jingles (transformation, victoire, défaite). Tout dans `Config/Sounds.luau`.
- **D53 — Cinématiques aux moments clés** (demande du créateur) : bandes noires, plans de caméra, légendes, bouton « Skip » ; le reste de l'interface est masqué pendant la scène. (1) Intro de Muscle City à la première arrivée (survol de la ville puis descente au garage), le tutoriel démarre après. (2) Présentation de chaque boss à la première approche (« A WILD BOSS APPEARS », son stade, sa réplique), une seule fois par joueur. (3) Entrée en scène à chaque défi : tour de caméra en contre-plongée, le boss se gonfle, puis caméra de duel.
- **D52 — Objectif toujours visible et ressenti des séries** : carte « Next goal » (boss prêt, exercice jamais essayé, sinon meilleur exercice) ; son des répétitions qui monte avec le combo ; sueur qui coule de plus en plus fort ; gros plan de caméra sur son personnage pendant une série ou une aide.
- **D51 — Note de fin de série (S/A/B/C, étoiles) et record par exercice** : précision moyenne des répétitions jouées à la main (Perfect 100, Good 70, Miss 20), pas de note si la série est surtout en auto. Records sauvegardés.

## 2026-10-16 (décisions du créateur, étape 6 : le gameplay)

- **D50 — Mog-off mis en scène** : écran VS avec la réplique du boss, compte à rebours, caméra de duel, jauge de Mog (toi contre lui) au lieu d'un texte, pastilles des manches, annonce de chaque manche (« plus rapide »), le boss qui nargue ou panique, « MOGGED! » à la victoire. Les règles du combat ne changent pas (D24).
- **D49 — Combo** (choix du créateur : « améliorer les mécaniques ») : les répétitions réussies d'affilée multiplient le Mog des exercices (×1,2 dès 5, ×1,5 dès 10, ×2 « ON FIRE » dès 15) ; un raté remet à zéro, le mode auto ne compte pas. Ne touche pas aux aides (récompense fixe) ni au score des boss (équité). ❓ Paliers à régler pendant l'alpha.
- **D48 — Le bocal de Maman rapporte 25 Cash la première fois** (5 ensuite) : le tutoriel peut faire acheter un premier look, comme le prévoit le design. Lève le ❓ de D46.
- **D47 — Boosts temporaires plutôt qu'une énergie** (choix du créateur) : 4 aliments comiques (shake protéiné, jus de kale turbo, steak démesuré, œufs dorés) vendus en Cash au camion à shakes et au distributeur, ×1,25 à ×2 de Mog pendant 3 à 5 minutes, débloqués avec les stades. Jamais obligatoires, rien ne bloque sans eux. Un seul actif ; racheter le même prolonge (15 min max). ❓ Prix et effets à régler pendant l'alpha.
- **Sons** : le créateur écoute et choisit parmi une liste proposée (`design/SONS_CANDIDATS.md`, priorité à la bibliothèque APM sous licence).

## 2026-10-16 (étape 5 : le guide et le tutoriel, nuit en autonomie)

- **D46 — Tutoriel guidé par le mentor** (Config/Tutorial.luau) : 4 étapes (série de curls dans son garage → bocal de Maman → essayer un look chez le coiffeur → 50 Mog et Kevin), une carte d'objectif, un trait lumineux vers la cible, le mentor qui parle en bas de l'écran. Quittable (« Passer »), rejouable (le mentor le relance : « Show me the ropes »). Les joueurs qui ont déjà progressé ne le voient pas d'office. Conseils du mentor la première fois qu'on ouvre chaque boutique, et à chaque nouveau stade (exercices et aides débloqués, prochain boss).
  Écart avec 01_BOUCLES.md : le design prévoit un **premier achat** à 2–3 min, mais la première aide rapporte 5 Cash et l'objet le moins cher en coûte 25. Le tutoriel fait donc **essayer** un look (gratuit). ❓ Faut-il un objet de départ à 5 Cash, ou plus de Cash pour le bocal de Maman ?

## 2026-10-16 (étape 4 : les PNJ, nuit en autonomie)

- **D45 — Habitants, vendeurs et mentor modélisés dans le style des boss** (`build_townsfolk.py`, 12 personnages). L'humour passe par les costumes, accessoires et expressions (bigoudis et bocal de Maman, colis du livreur, carte à l'envers du touriste…), jamais par le corps des gens. Les vendeurs (Coco la styliste… noms provisoires, modifiables) ouvrent la boutique de leur magasin ; miroirs et comptoir restent en place tant que le ❓ de D38 n'est pas tranché. Le mentor attend près du podium et livre des proverbes absurdes ; ses missions viendront avec le guide (étape 5).

## 2026-10-16 (étape 3 : le style, nuit en autonomie)

- **D42 — Règle d'art : jamais deux sphères de pectoraux sous un vêtement.** Sous un tissu, elles se lisent comme une poitrine (inacceptable pour un jeu tous publics) : un torse habillé a une seule poitrine large et bombée. Les pectoraux sculptés restent réservés aux torses nus, où la texture les fait lire comme des muscles.
- **D44 — Catégorie Visage** (sourcils froncés, sourire éclatant, méga-mâchoire), listée dans le design, vendue chez le coiffeur. ❓ Prix (25 à 120 Cash) : hypothèses. Le bronzage (design) reste à faire : il demande une texture de peau par teinte et par corps.
- **D43 — Catégorie Bas** (short fluo, jogging en velours, pantalon de cuir), listée dans le design (PERSONNAGE.md) et ajoutée au magasin de vêtements. ❓ Prix (35 à 110 Cash) : hypothèses. Boutique adaptée à l'écran (mobile d'abord) avec essayage 3D.
- **D41 — Objets de style modélisés pour chaque corps de stade** (même pipeline que les corps : `build_style.py`), soudés pièce par pièce, ils suivent animations, pump et croissance. Ajout de la catégorie **Barbes** (4 barbes, vendues chez le coiffeur) : prévue dans le plan validé (étape 3 « coiffures, barbes et tenues »). ❓ Prix des barbes (30 à 65 Cash) : hypothèses à calibrer comme les autres prix. Présentoirs : 4 mannequins au magasin de vêtements, 5 têtes chez le coiffeur, qui portent les vrais articles.

## 2026-10-15 (suite du plan)

- **D40 — Le personnage prend du muscle à chaque séance** (choix du créateur), en trois effets visibles par tous :
  1. **Pump** : chaque répétition validée gonfle les muscles travaillés (plus si Perfect), cumulé pendant la série, puis redescend en ~20 s.
  2. **Croissance permanente dans le stade** : le corps grossit avec la progression du Mog vers le boss suivant (0 % = corps du stade, 100 % = presque le corps suivant). Le Mog ne baisse jamais : la croissance non plus.
  3. **Transformation** en battant le boss : passage au corps suivant avec un effet visuel.
  Le serveur calcule tout (taille des pièces de la coque) ; aucun avantage en Mog-off.

- **D39 — Corps des stades dans le style des boss** (choix du créateur) : low poly PS1, anatomie réaliste mais exagérée, texture « éclairage cuit ». Un corps par stade, découpé selon les 15 parties du squelette R15 pour suivre les animations (D28, D37).
- **D38 — Des vendeurs dans les magasins** (choix du créateur) : chaque magasin (vêtements, coiffeur, meubles, épicerie) a un vendeur PNJ derrière son comptoir ; c'est lui qu'on aborde pour acheter (il ouvre la boutique, commente les achats, réagit au stade du joueur). Réalisé avec les PNJ (étape 4). ❓ Le miroir et le comptoir actuels deviennent-ils le vendeur, ou restent-ils en plus ?

- **D37 — Les activités se jouent vraiment dans le monde** (choix du créateur) : pendant un mini-jeu, le personnage réalise réellement l'activité dans Roblox, et le mouvement suit la façon dont le joueur joue. Exemple : aux pompes, chaque répétition réussie fait une vraie pompe, une répétition parfaite est ample et propre, une ratée est une pompe molle ou un effondrement comique. S'applique à tout : exercices (le personnage et l'agrès bougent), aides (le bocal se dévisse, le piano avance, les transats s'empilent) et boss (le boss fait son mouvement en direct, face au joueur). Le serveur décide toujours du résultat de chaque répétition ; l'animation ne fait que l'illustrer.
- **D36 — Plan de production en 9 étapes** (validé par le créateur) : ville → personnage → style → PNJ → guide → gameplay → son → alpha → rétention. Voir `07_ROADMAP.md`. Pas de « drogues » (règles Roblox, tous publics) : boissons et aliments comiques à la place. ❓ Énergie : le design refuse une énergie qui bloque (D2) ; proposition = boosts temporaires, à trancher par le créateur.

## 2026-10-15 (décors)

- **D35 — Décors générés par script dans Blender, une texture palette partagée, remplacement automatique des blocs** : chaque décor est décrit en Python (reproductible, modifiable), exporté en FBX par catégorie ; le jeu remplace les blocs de la carte par les modèles importés (`PropService`) et garde les blocs si un modèle manque. Les drapeaux et enseignes n'ont aucun texte et n'imitent aucun vrai drapeau (emblème haltère du jeu).

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

- ~~**D22 — Aucun essayage gratuit au miroir pour l'instant.**~~ → Fait le 16/10 : la boutique montre un aperçu 3D de son propre corps de stade avec l'article touché (essayage gratuit, comme prévu par le design).
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
