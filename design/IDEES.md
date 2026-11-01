# Idées en attente

Toute nouvelle idée arrive ici. Elle passe dans le design seulement après une décision dans `DECISIONS.md`.
Test de la vision : l'idée tient-elle dans les trois briques (mini-jeux, contenu en données, personnage) ?

## Le Dieu du Pump : un vrai combat (demande d'Antoine du 22/10/2026, à faire plus tard)

Pour le dernier boss, Antoine veut **un vrai combat** et non un mini-jeu : se battre contre le Dieu du Pump,
esquiver ses attaques (éclairs, etc.). À concevoir avec lui au moment de la mise à jour de l'Olympe. **Rien n'est fait
pour l'instant.** Le mini-jeu Gravity Gauntlet préparé par Codex a été supprimé avec son système (D80).

### Proposition v2 du 28/10/2026 : le Colisée du Pump (choix d'Antoine intégrés, reste à valider ❓)

**Choix d'Antoine** : combat solo ; arène dans le style des images envoyées (amphithéâtre de grès, arches à bordure
de marbre blanc, auvents rouges, étendards, piste de sable entourée d'un haut mur) ; 5 minutes ; une défaite fait
perdre du Mog ; les spectateurs aident sans que le combattant voie leur jauge ; le joueur a d'autres attaques que le
renvoi des éclairs ; zones au sol pour esquiver ; boss excessivement bien animé ; arène à côté de la carte et
rejoignable par les joueurs.

**Où mettre l'arène (recommandé)** : sur un plateau juste au-delà du coin sud-ouest de la ville, derrière le temple
du Dieu du Pump, relié à lui par un grand escalier de marbre (et un arrêt de bus « Colisée »). Toujours visible depuis
la ville (repère qui donne envie), même serveur (pas de chargement, spectateurs faciles). Le combattant y est
téléporté par le pilier de lumière du temple et entre par la porte des gladiateurs ; les spectateurs montent à pied
dans les gradins ; un mur haut et une barrière invisible empêchent d'entrer sur la piste. Écartés : île dans le ciel
(moins visible, accès seulement par téléporteur) et lieu séparé (chargement, spectateurs presque impossibles).

**Contrôles (téléphone d'abord)** : joystick + 3 boutons : SAUTER (Roblox), ROULADE (esquive rapide, invincible un
court instant) et FLEX (bouton d'action selon la situation : frapper, renvoyer, ramasser, lancer, charger).
Vie : une jauge de 100 ; les coups enlèvent 15 à 30 ; des amphores de shake rendent de la vie.

**Attaquer le boss (4 façons)** :
1. **Punir** : après ses grosses attaques, il est essoufflé 2 à 3 s (étoiles, genou à terre) ; courir à lui et FLEX
   en rythme : combo de 3 coups (le 3e au bon moment = coup de Mog puissant).
2. **Renvoyer la foudre** : son javelot d'éclair, FLEX au bon moment le renvoie (parade).
3. **Lancer des disques** : ses attaques font tomber des disques d'haltère dorés ; FLEX pour ramasser, FLEX pour
   lancer (visée automatique vers lui).
4. **Pose sacrée** : des cercles dorés apparaissent ; rester dedans en maintenant FLEX charge un rayon de Mog. Gros
   dégâts, mais on reste immobile pendant que les attaques continuent (risque choisi).

**Lisibilité des zones** : cercles, bandes, cônes et anneaux au sol qui se remplissent jusqu'à l'impact ; contour épais,
couleur franche, son d'alerte ; au moins 0,8 s pour lire (moins vers la fin) ; jamais d'attaque sans zone.

**Déroulé (environ 5 minutes)** :
- **Entrée** (30 s, passable après la 1re fois) : pilier de lumière, la foule rugit, Coach Turbo annonce au mégaphone,
  le dieu descend de son nuage et pose, la piste tremble.
- **Manche 1 — L'échauffement divin** (~1 min 15) : éclairs sur cercles, haltère qui roule (sauter ou rouler), coup de
  poing au sol en cône (puis il est essoufflé : punir), javelot à renvoyer. Le joueur apprend chaque façon d'attaquer.
- **Manche 2 — Les douze travaux** (~1 min 30) : l'arène change : des colonnes tombent (bandes), les dalles de
  mosaïque s'allument par motifs (cases sûres), un char de shake traverse la piste, il saute et retombe sur le joueur
  (grand cercle qui le suit). Option : les statues des boss battus s'animent pour l'aider.
- **Manche 3 — L'Olympe en colère** (~1 min 15) : il devient géant au bord de l'arène ; attaques qui couvrent toute la
  piste avec des zones sûres, anneaux à sauter, regard brûlant qui balaie (se cacher derrière les colonnes).
- **Finale — Le dernier pose-off** (~30 s) : choc de rayons Mog contre foudre, FLEX en rythme pendant que la foule
  scande. Victoire : il est éjecté dans le ciel et devient une constellation qui pose ; laurier, titre GOD MOGGER,
  statue dorée au Panthéon du colisée. Défaite : il nargue, le joueur est renvoyé au temple et perd du Mog.

**Spectateurs** : bouton « Encourager » dans les gradins ; la jauge de la foule est cachée au combattant. À chaque
palier, la foule agit dans l'arène et le combattant le voit sans interface : une amphore de shake lancée sur la piste,
des pétales qui ralentissent le dieu une seconde, un chant qui rend le prochain renvoi plus facile. Limité par
spectateur (pas d'abus), et bien plus utile qu'indispensable.

**Animation du boss** : modèle refait et articulé dans Blender (comme les autres boss) avec de vraies animations
images clés pour chaque attaque (préparation lisible, frappe, retombée, essoufflement) et des couches calculées en
jeu : il regarde le joueur, respire, sa cape et ses cheveux suivent avec un ressort, réactions aux coups, tremblements
de la piste à chaque pas. Les animations images clés doivent être publiées sur Roblox par le compte d'Antoine.

**Mise en place (serveur maître)** : `PumpGodService` (serveur) déroule le combat comme une suite d'attaques tirées
d'une graine, avec l'heure exacte de chaque impact ; il vérifie les touches d'après la position du joueur à l'impact
(petite marge pour la latence), l'invincibilité de la roulade, les parades et les coups. `PumpGodController` (client)
dessine les zones à l'heure du serveur, anime le dieu, gère la caméra et les boutons. Toutes les valeurs dans
`Config/PumpGod.luau`. Arène modulaire en Blender (grès, marbre, auvents rouges, étendards), découpée en pièces de
moins de 10 000 triangles.

**Tranches jouables** :
1. Arène, accès (escalier, bus, pilier de lumière) et gradins.
2. Boss articulé, système de zones, 3 attaques, vie du joueur, roulade.
3. Les 4 façons d'attaquer ; manche 1 complète, victoire et défaite (perte de Mog).
4. Manches 2 et 3, finale, spectateurs.
5. Sons, effets, caméra, essais sur téléphone, réglages.

**Améliorations proposées après l'audit du 29/10/2026 (Claude, à valider ❓)** :
- **Reprise** : après une défaite en manche 3 ou en finale, une seule reprise au début de la manche atteinte (moins frustrant sur 5 min de combat).
- **Ralenti de victoire** : 1 s au ralenti quand le choc touche le dieu, avant l'éjection.
- **Indicateur hors écran** : une flèche au bord de l'écran quand une zone ou le javelot arrive hors du champ de la caméra (utile sur téléphone, écran étroit).
- **Vibration** au toucher (réglage existant `Vibration`) sur les coups reçus et chaque battement réussi de la finale.
- **Spectateurs** : petit écran « qui combat » à l'entrée du Colisée (manche, vie) et téléport direct aux gradins.
- **Classement** du temps de victoire (le plus rapide), affiché au Panthéon.
- **Laurier** : option pour le cacher dans le créateur de personnage.

**Questions restantes (❓)** : combien de Mog perdu (proposition : 3 % du Mog, plafonné) ? Bouton ROULADE d'accord ?
Les statues des boss battus en manche 2 ? Une reprise au début de la manche atteinte (une fois par combat) ?

## (Archivé) Proposition de recherche du 20/10/2026 — adoptée en D76, abandonnée en D80

À la demande du créateur : étudier les mini-jeux Roblox et d'autres plateformes, la motivation et le ressenti
visuel, puis proposer une liste entièrement nouvelle avant toute intervention dans Roblox.

Le [rapport de recherche et la proposition complète](../MINIGAME_MAKEOVER_PROPOSAL_2026-10-20.md) proposent
six nouvelles activités d'entraînement, huit aides repensées, cinq combats propres aux boss et un nouveau
bras de fer. Une proposition pour le Dieu du Pump reste une extension future, à décider séparément.

Direction proposée : un terrain de jeu de force absurde, fondé sur des objets que l'on comprime, roule,
attire, balance, découpe ou transforme. Les thèmes des six exercices et plusieurs tâches des habitants
changeraient ; les boss auraient des objectifs propres. Ces divergences avec le design actuel sont
explicitement soumises à validation. Premiers prototypes recommandés après accord : Scrap Press,
Tire Domino, Peel Good et Snack Volley.

**Statut : adopté par Antoine (D76), mis en place.** La publication publique et le déblocage du futur Dieu du Pump ne font pas partie de cette livraison.

## (Archivé) Refonte complète des mini-jeux — D75 du 20/10/2026, abandonnée en D80

**Direction.** Faire de chaque activité une petite scène physique jouée dans le décor : le joueur lit un signe clair,
agit avec un doigt, puis voit immédiatement le corps, l'objet et le PNJ réagir. Les gestes restent simples, mais les
règles et les situations changent d'une activité à l'autre. Chaque série commence par une action facile, introduit une
variation, puis se termine par un coup final comique. Les échecs sont courts et amusants. Pas de multitouch, de spam,
de gyroscope obligatoire, de nouvelle monnaie ou de minuteur de présence.

### Six exercices proposés

| Exercice | Nouveau jeu | Geste et spectacle |
|---|---|---|
| Curl haltère | **Pastèque sous tension** | Faire pivoter l'haltère autour du coude en suivant une résistance qui change d'angle ; au sommet, la pastèque se fend et le biceps gonfle. |
| Pompes | **Catapulte de poitrine** | Maintenir pour comprimer la descente, relâcher pour bondir et retomber sur une marque au sol ; combo de pompes claquées de plus en plus absurdes. |
| Développé couché | **Sauvetage de barre** | Intercepter la barre qui descend par un toucher, puis la pousser d'un court geste jusqu'au verrouillage ; les disques font tanguer le banc. |
| Squat | **Plancher fissuré** | Déplacer son appui vers la dalle intacte pendant la descente ; à la remontée, le sol se craquelle sous la charge. |
| Tractions | **Barre voyageuse** | Faire glisser une prise de main vers le prochain appui pendant que le corps monte ; la barre s'allonge et les prises se dérobent. |
| Corde à sauter | **Corde de spectacle** | Lire le type de passage de corde, puis faire un petit ou un grand geste vers le haut ; la série finit par un double tour spectaculaire. |

### Huit aides proposées

| Aide | Nouveau jeu | Geste et spectacle |
|---|---|---|
| Bocal de Maman | **Le joint secret** | Repérer la bulle d'air sous le couvercle, appuyer dessus pour casser le vide, puis tirer d'un geste ; les cornichons jaillissent quand le joint cède. |
| Pneu du livreur | **Chasse aux fuites** | Repérer et boucher les bulles autour du pneu, puis actionner la pompe ; le pneu reprend sa forme sous les yeux du joueur. |
| Clous du voisin | **Le bon angle** | Dessiner la trajectoire du marteau vers chaque clou ; un beau coup enfonce le clou droit, un coup raté le tord sans arrêter la partie. |
| Voiture du voisin | **Lance-voiture** | Tirer une sangle élastique pour choisir angle et puissance, puis relâcher ; la voiture roule et rebondit jusqu'à sa place. |
| Piano de Mme Do-Ré | **Déménagement impossible** | Choisir le bon point de pivot à chaque obstacle tandis que le piano avance ; chaque manœuvre réussie joue une note juste. |
| Transats | **Le coin parfait** | Glisser chaque transat dans la zone d'ombre ou de soleil demandée avant la vague ; l'installation finale ressemble à une plage de star. |
| Courses de l'épicier | **Sac impossible** | Choisir l'ordre des objets pour mettre le lourd au fond et le fragile en haut ; le sac prend une forme absurde sans casser. |
| Chemin du touriste | **Carte postale vivante** | Faire tourner un petit panorama jusqu'à retrouver le monument montré sur la carte postale ; le touriste part dans la bonne direction. |

### Cinq boss et le duel proposés

| Adversaire | Nouveau jeu | Geste et spectacle |
|---|---|---|
| Kevin | **Éjection du canapé** | Anticiper sa fuite vers le frigo, la télé ou le canapé et poser un équipement de sport sur sa trajectoire d'un toucher ; il trébuche dans une pose athlétique malgré lui. |
| Brayan | **Miroir de bronzage** | Orienter un miroir pour renvoyer son propre rayon de soleil sur lui ; sa pose et son bronzage s'emballent. |
| Coach Turbo | **Rébellion au mégaphone** | Maintenir pour encaisser l'onde annoncée, relâcher dans l'accalmie pour poser ; son mégaphone finit par se retourner contre lui. |
| Monsieur Pas-Les-Jambes | **Balayage des cure-dents** | Lire quelle jambe tremble, puis glisser un tapis sous le bon pied ; son énorme torse bascule au ralenti. |
| Roi du Quartier | **Vent contraire** | Tirer son appui dans le sens opposé aux rafales du ventilateur ; son manteau et son ventilateur se retournent contre lui. |
| Bras de fer entre joueurs | **Prise et contre** | À chaque échange, choisir une prise parmi trois positions lisibles, tenir pour résister, relâcher sur l'engagement adverse pour contrer ; le bras et la table bougent à chaque décision. Même règle pour les deux joueurs, sans bonus de Mog. |

**Plus tard, hors MVP :** Le Dieu du Pump pourrait demander de relier des points de foudre sur une silhouette pour
former la pose finale. Ne pas l'ajouter tant que le boss reste annoncé « coming soon ».

**Répétition sans lassitude :** plusieurs motifs visuels par jeu, record personnel et note déjà existants, première
réussite avec réaction unique du PNJ, défis hebdomadaires qui invitent à revisiter les activités. Faire varier les
situations et les choix plutôt que réduire sans cesse les fenêtres de timing. Le mode auto reste accessible pour les
exercices et aides, avec la récompense de base ; le plaisir et la meilleure note viennent du jeu manuel.

**Jeux à valider d'abord sur appareils réels :** Pastèque sous tension, Le joint secret et Éjection du canapé. Ces trois
jeux forment la première boucle du tutoriel. Vérifier compréhension, plaisir de répétition et lisibilité sur vrai
téléphone, puis étendre les essais aux 17 autres. Les effets attendus sont des hypothèses, pas des résultats de joueurs.

## Économie actuelle — simulation du 17/10/2026, à décider pendant l'alpha

`tools/simulate_economy.luau` a été exécuté dans Studio en mode Édition avec les Config actuels, sans toucher à une sauvegarde. Le calcul applique le combo aux exercices et aux aides, le paiement D57 (qualité, chaîne de Perfect et bonus sans faute), les événements de ville, les achats de boosts, le pareur et les pertes des Mog-off. Il s'arrête au seuil de Pump God, encore « coming soon ».

| Parcours simulé | Kevin battu | Brayan battu | Coach Turbo battu | No-Legs battu | King of the Block battu | Seuil Pump God |
|---|---:|---:|---:|---:|---:|---:|
| Auto, aucune aide | 2:11 | 6:29 | bloqué à 21:04 | — | — | — |
| Moyen, aides + événements | 1:41 | 6:28 | 20:23 | 38:09 | 59:20 | 76:14 |
| Précis, aides + événements | 1:41 | 5:17 | 16:24 | 31:30 | 49:01 | 68:03 |
| Moyen, boosts + pareur | 1:41 | 5:23 | 14:34 | 25:11 | 37:16 | 45:20 |
| Moyen, un look acheté par stade | 1:41 | 6:42 | 20:35 | 38:45 | 60:30 | 77:30 |

**Style et Cash.** Dans le parcours moyen, le premier look à 25 Cash devient accessible à 2:57 (45 Cash en poche). Après Brayan : 108 Cash et 19 looks payants accessibles ; après Coach Turbo : 354 Cash et les 25 looks payants accessibles ; au seuil de Pump God : 3 712 Cash, dont 3 042 gagnés par les aides, 155 par les événements et 255 perdus en Mog-off. Le parcours qui achète un look par stade en possède cinq pour 145 Cash dépensés et garde 3 524 Cash au seuil final. Avec boosts et pareur, neuf boosts coûtent 1 700 Cash ; 421 Cash restent au seuil de Pump God, et le pareur reçoit 6 527 Mog au total. Le parcours auto n'a que 70 Cash après Brayan (14 looks accessibles) et reste bloqué à Coach Turbo avec sa précision supposée.

**Hypothèses et limites.** Départ à 0 Mog/0 Cash sur un serveur neuf ; meilleur exercice disponible, deux séries entre aides, 4 s entre séries, 6 s de trajet, 3 s de relance d'aide, 10 s de marge par défi. Précision moyenne : 30 % Perfect, 50 % Good ; précise : 60 % Perfect, 32 % Good. Le profil moyen gagne 5 points de probabilité Perfect après chaque défaite. Les événements arrivent à l'intervalle moyen de 10 min 30, leurs trois types alternent et le joueur en saisit une partie ; en jeu, type et intervalle sont aléatoires et le serveur peut déjà tourner lors de l'arrivée. Le pareur aide une série sur deux ; le profil boosté achète le meilleur boost disponible quand le précédent expire. Les mini-jeux, trajets, achats et réflexes réels d'un joueur, la contention des événements entre joueurs, le téléphone et les échecs d'aide ne sont pas mesurés ici. Ce sont cinq parcours déterministes, pas une moyenne de joueurs.

**Questions au créateur avant tout réglage :**

- Kevin à 1:41 et Coach Turbo vers 16–20 min sont plus rapides que les cibles de `03_PROGRESSION.md` (3–5 min et 25–40 min). Veux-tu garder ces cibles après un test humain sur téléphone ?
- Le parcours boosts + pareur atteint Pump God en 45:20 contre 76:14 pour le moyen sans eux. Ce gain combiné te convient-il ? Pour isoler chaque effet, faire une simulation « boosts seuls » et « pareur seul » avant de toucher aux valeurs.
- Tous les looks payants actuels sont accessibles dès Coach Turbo dans le parcours moyen. Souhaites-tu conserver ce Cash abondant pour favoriser l'expression du style, ou ajouter plus tard des looks haut de gamme et des choix de dépense ?
- Le joueur auto bloqué à Coach Turbo doit-il être aidé par un apprentissage des mini-jeux ou par la règle encore ouverte « boss moins exigeant après trois défaites » (D19) ? À trancher après des essais humains, sans décider ici.

## Multijoueur (après le MVP)

- ~~**Duels de Mog entre joueurs**~~ → fait (D67, puis D68 : bras de fer n'importe où), voir `02_MECANIQUES/DUELS.md`.
- **Aides géantes coopératives** : un objet énorme à déplacer à plusieurs (réutilise un mini-jeu, scores additionnés).
- **Galères du jour** : une aide spéciale apparaît sur le serveur pour tout le monde.

## Personnage et style

- **Refonte complète de la garde-robe Blender et ensembles coordonnés** (demande d'Antoine le 18/10/2026) : acceptée en D70 ; modèles préparés, import Studio et prix des nouveaux articles encore à finaliser.

- Poses de victoire à collectionner et choisir.
- Aura cartoon débloquée aux hauts stades, qui fait réagir les PNJ (ils s'écartent, les vitres vibrent).
- Album de transformations (photo automatique à chaque nouveau stade).
- Casier ou chambre à décorer.

## Contenu

- Exercices : voir la liste « mises à jour suivantes » dans `02_MECANIQUES/MINIJEUX.md`.
- Boss bonus de la Lune ; boss d'événements (boss déguisé pour Halloween).
- Retour au garage en GOD MOGGER : Kevin a « enfin commencé » et propose une revanche.
- La force qui agit sur la ville (design archivé dans `archive/v3_exploits/`) : surpuissance comique, objets à soulever dans le monde. Peut enrichir les aides plus tard.
- Maîtrise d'exercice (badges quand on enchaîne les Parfait).
- Défis hebdomadaires sur plusieurs sessions.

## Ville de Muscle City (analyse de la carte du 14/10/2026)

Déjà fait : plusieurs stations par exercice, bouton Maison et bus, icônes et guide vers le boss, statues des meilleurs moggers, routes détaillées, cycle jour/nuit, ville compacte. Reste à décider :

- **Boss personnels** : chaque joueur voit son propre exemplaire du boss pendant son combat (aujourd'hui, plusieurs joueurs face au même boss voient les mêmes animations).
- **Maman visible seulement chez soi** (ou pour les visiteurs qui entrent) au lieu de 20 mamans dans la ville (Kevin est déjà unique, D34).
- **Mini-carte** et flèche de guidage vers l'objectif quand le joueur n'est pas encore prêt (vers les stations utiles).
- **Objet de déplacement** à acheter (trottinette, rollers) : cosmétique et un peu plus rapide.
- **Maisons** : le panneau affiche le stade et le Mog du propriétaire ; bouton « J'aime » et classement des maisons ; personnalisation de l'extérieur (façade, porte de garage, drapeau, boîte aux lettres) ; garage qui s'équipe à chaque stade ; 3 à 5 modèles de maisons différents.
- **Classement mondial** (tous serveurs) en plus des statues du serveur.
- **Arène avec gradins** pour regarder les combats de boss des autres, projecteurs et ambiance de match.
- **Haltères dorés cachés** dans la ville (toits, recoins) à collectionner, petite récompense.
- **Coins vides du centre** : salle en plein air « Muscle Beach », camion à shakes protéinés (nouvel habitant ou nouvelle aide), terrain de basket.
- **Prochaines zones visibles au loin** derrière la bordure de la ville (plage, montagne) avec un panneau honnête « Bientôt ».
- **Vie dans la ville** : voitures qui roulent sur l'anneau, pigeons, joggeurs, sons d'ambiance par zone (jets d'eau de la fontaine : fait, D97).
- **Objets de décor dans Blender** (canapés, voitures, piano, fontaine, temple, arbres) pour remplacer les blocs.
- **Performance mobile** : réduire le nombre de lumières si les tests sur téléphone le demandent.

- **Bronzage** (catégorie du design) : demande une texture de peau par teinte et par corps (7 × 4), à importer comme images puis à échanger sur les pièces du corps.
- **Vendeurs bavards** : une réplique différente selon le stade du joueur (« Un Gigachad dans ma boutique ! »), comme les habitants.
- **Le mentor surgit de nulle part** (D29) : apparaître près de la cible de l'étape du tutoriel (derrière une poubelle, dans un frigo), visible seulement du joueur guidé.
- **Le pneu qui gonfle** pendant l'aide du livreur (le vélo est un seul modèle aujourd'hui).
- **Miniature 3D de chaque article** dans la liste de la boutique (en plus de l'essayage).
- **Réglage du son** (musique / effets) dans un petit menu.

## Liste d'améliorations du 16/10 (proposée par Claude, validée par le créateur)

Mises en place (D51 à D58) : note de fin de série et records, objectif toujours visible, son qui monte avec le
combo, sueur et gros plan pendant les séries, coups spéciaux et sorties des boss, émotes et pareur, événements de
ville, animations (intro de la ville, présentation des boss, entrée en scène du défi). Le reste, pour plus tard :
- Ralenti d'une demi-seconde au passage « ON FIRE » ; vibration du téléphone sur les Perfect ; veines pendant un gros pump.
- Répétition dorée (x3) ; rythme qui accélère avec le combo ; maîtrise des exercices (bronze/argent/or) ; options d'accessibilité (fenêtres plus larges, daltoniens).
- Boss en mode difficile (revanche renforcée, objet exclusif) ; indice du mentor avant un boss ; spectateurs et foule qui applaudit.
- Paliers dans un stade (25/50/75 %) ; titres au-dessus de la tête ; succès Roblox ; livre de collection ; garage qui s'équipe à chaque stade.
- Bonus de groupe à la salle en plein air ; classement des maisons.
- Habitants qui se promènent, voitures qui roulent ; haltères dorés cachés ; histoires en 3 épisodes par habitant ; ambiance de nuit à la salle.
- Variantes de couleur des vêtements ; tenues enregistrées ; pose de victoire au choix ; aura du God Mogger ; extérieur de maison ; lettres de Maman.
- Menu de réglages (volumes, effets réduits) ; mini-carte ; relecture du français ; vérification téléphone.
- Mesures de jeu ; optimisation mobile (chargement progressif) ; revue anti-triche.

## Idées pour rendre les mini-jeux plus satisfaisants (proposées par Claude le 17/10, à valider)

Ressenti de chaque répétition :
- **Arrêt sur image** de 60 ms sur un Perfect, et secousse d'écran qui grandit avec le combo.
- **Gerbe d'étincelles** et éclaboussure de sueur sur un Perfect ; contour doré du mini-jeu à partir de 10 d'affilée.
- **« Trop tôt ! / Trop tard ! »** sous un Good ou un raté, pour apprendre le bon moment.
- **Accord musical** à chaque palier de combo, et « drop » de basse au passage ON FIRE.
- **Vibration du téléphone** sur les Perfect.

Rythme d'une série :
- **Répétition dorée** au hasard (elle brille) : un Perfect dessus rapporte ×3.
- **Mode FEVER** à 15 d'affilée : 5 secondes de fenêtres plus larges et de gains doublés, écran qui pulse.
- **Coup final** : la dernière répétition se joue au ralenti, caméra en gros plan, gain bonus si Perfect.
- **Motifs de rythme** qui changent tous les 5 répétitions (accélération, pause, double) pour casser la monotonie.
- **Exercices payés selon la réussite** comme les aides (aujourd'hui un raté rapporte autant de Mog qu'une répétition
  en auto) : raté à 50 %, à décider.

Spécifique à chaque activité :
- Pastèque (curl) qui se fend un peu plus à chaque Perfect et explose à la fin d'une série parfaite.
- Pneu du livreur qui gonfle vraiment et éclate (comique) si on pompe trop.
- Piano : les Perfect jouent les vraies notes d'une mélodie ; les ratés font des fausses notes.
- Clous : le clou s'enfonce d'un coup sur un Perfect, se tord sur un raté.
- Transats : la pile tangue physiquement, et s'écroule en fin de partie si elle est trop bancale.
- Courses : les sacs s'empilent dans les bras du personnage au fil des réussites.

Combats de boss :
- **Contre** : un Perfect pile sur une répétition du boss fait « MOG BACK » (bonus de score, le boss recule).
- Jauge de « rage » du boss qui annonce son coup spécial.

Rejouabilité :
- **Maîtrise** par exercice (bronze, argent, or selon le record) qui change l'apparence du matériel.
- **Défi du jour** (« 20 curls Perfect d'affilée ») pour un petit bonus ; **classement** par exercice.

## Questions ouvertes

- ~~Comment déformer légèrement le corps à l'intérieur d'un stade (os, formes) ?~~ → Mise à l'échelle des pièces de la coque (D40).
- ~~Habits en couches ou accessoires rigides : quelle technique fonctionne sur 7 corps très différents ?~~ → Chaque objet modélisé pour chaque corps (D41).
