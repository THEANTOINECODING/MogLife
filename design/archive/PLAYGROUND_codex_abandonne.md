# Le terrain de force : les mini-jeux actuels

Décisions D76 (refonte adoptée par Antoine), D77 (révision après son essai), D78 (place du joueur face aux boss) et
D79 (plus d'Auto, plus de victoire au hasard, priorité au téléphone). Les anciennes fiches (`MINIJEUX.md`, `AIDES.md`,
`BOSS.md`, `DUELS.md`) gardent l'historique ; c'est cette fiche qui fait foi pour les mécaniques.

## Les 21 jeux

Les identifiants de progression (records, déblocages, récompenses) n'ont pas changé : seul le mini-jeu est nouveau.

| Catégorie | Identifiant | Jeu | Geste | Pourquoi on ne gagne pas au hasard (D79) |
|---|---|---|---|---|
| Entraînement | Curl | Scrap Press | Comprimer, relâcher au bon niveau | 4 niveaux tirés au sort, zone étroite |
| Entraînement | PushUp | Tire Domino | Viser, lancer le pneu | 3 tirs ; colonnes tirées au sort |
| Entraînement | BenchPress | Magnet Haul | Ramasser, livrer | Le chargement ralentit, le butoir fait tout tomber |
| Entraînement | Squat | Swing King | Lâcher pour attraper la barre suivante | Le saut part dans le sens du balancement ; barres tirées au sort ; 3 vies |
| Entraînement | PullUp | Rope Rave | Taper au rythme | Rythme tiré au sort ; 4 vies (taper sans arrêt fait perdre) |
| Entraînement | JumpRope | Atlas Stack | Placer, lâcher | Il faut viser, la pièce dérive |
| Aide | OpenJar | Peel Good | Décoller l'opercule | Suivre le tracé sans déchirer |
| Aide | PumpTire | Airway Express | Tourner les tuyaux | Nombre de tours limité |
| Aide | Nails | Chop Shop | Tracer une coupe | 5 coupes tirées au sort ; 3 vies |
| Aide | PushCar | Parking Knot | Glisser les voitures | 8 casse-têtes de 6 à 8 coups minimum ; budget = minimum + 3 |
| Aide | Piano | Piano Polish | Essuyer la poussière | Tout nettoyer dans le temps |
| Aide | BeachChairs | Towel Fold | Plier les coins | Pliages précis |
| Aide | Groceries | Produce Parade | Tracer un groupe de fruits en entier | Groupes de formes tirées au sort ; 3 vies |
| Aide | Directions | Shortcut Chalk | Tracer un chemin | Labyrinthe, longueur limitée |
| Boss | Kevin | Snack Volley | Renvoyer le pop-corn | Vies, balles de plus en plus rapides |
| Boss | Brayan | Sunbed Slalom | Esquiver les plots | Aucun couloir sûr sans bouger |
| Boss | CoachTurbo | Treadmill Takeover | Inverser après la charge | Inverser trop tôt ou trop tard échoue |
| Boss | NoLegs | Leg Day Landgrab | Fermer un territoire avant le piétinement | Vies, trace limitée |
| Boss | BlockKing | Crown Sneak | Avancer et se figer | Repéré en bougeant sous le projecteur |
| Duel | Bras de fer | Read & Rip | Pousser, récupérer, punir l'épuisement | Simulation du serveur, chances égales |
| Futur boss | PumpGod | Gravity Gauntlet | Inverser la gravité | ❓ À valider par Antoine ; verrouillé (« coming soon ») |

## Règles communes

- **Le serveur décide de tout.** Il simule le jeu (30 pas par seconde) à partir des gestes du joueur (appuyer,
  glisser, relâcher) et envoie l'état toutes les 0,15 s ; le client prédit pour que le geste réponde tout de suite. Une
  note envoyée par le client est refusée. Chaque partie a un jeton, des numéros de gestes croissants et un débit limité.
- **Plus de mode Auto (D79).** Ni pour les entraînements, ni pour les aides, ni pour les boss. Le solveur automatique
  (`Shared/Playground/Autoplay.luau`) ne sert qu'aux tests, pour prouver que chaque jeu se gagne.
- **Pas de victoire au hasard (D79).** Les essais ratés coûtent des vies là où réessayer était gratuit. Un test
  permanent vérifie qu'un joueur qui clique au hasard gagne au plus 10 % des parties.
- **Variété (D79).** Là où c'est sûr, les cibles sont tirées au sort à chaque partie (presse, pneus, clous, rythme,
  fruits, barres du squat) ; ailleurs, plusieurs plateaux vérifiés (parking, tuyaux, labyrinthe, pliages).
- **Récompenses.** Entraînement : Mog selon le temps de récompense du jeu, la réussite, la qualité et les boosts
  (attendre ne rapporte pas plus). Aide : Cash seulement si l'objectif est réussi ; une aide ratée se rejoue. Records :
  `Playground2.<exerciseId>`.
- **Boss (D78).** Le joueur se tient devant le boss, tourné vers lui, la table du jeu entre eux, à la première distance
  libre calculée par le serveur.

## Téléphone d'abord (D79)

La grande majorité des joueurs jouent sur téléphone, en paysage.
- **Paysage** : la zone de jeu prend presque toute la hauteur de l'écran ; les infos (titre, consigne, vies, précision)
  tiennent dans une colonne étroite à sa gauche ; le personnage reste visible à gauche de l'écran.
- **Grilles** : elles occupent 88 % du plateau. Plus petites cases mesurées : 42 pixels sur un iPhone SE en paysage,
  48 à 54 sur un téléphone récent (le doigt a besoin d'environ 44).
- **Consignes** : lisibles entre 15 et 21 pixels dans la colonne étroite (en anglais ; le français et l'allemand,
  plus longs, réduiront un peu la taille).
- **Commandes** : toucher, souris, clavier (flèches, ZQSD/WASD, Espace) et manette donnent les mêmes gestes ; les
  grilles se parcourent case par case au clavier et à la manette.

## Tests

À lancer avec `execute_luau` dans Studio (aucune donnée de joueur touchée) :
- `tests/playground.luau` : chaque jeu se gagne sur plusieurs graines, perd si l'on ne fait rien, l'état est figé
  après la fin ; pas d'Auto pour les boss ;
- `tests/playground_review.luau` : régressions de l'audit (couloir de Brayan, visée d'Atlas, rythme tout Good, Coach,
  paiement, annulation, tracés rapides, variantes) ;
- `tests/playground_random.luau` : personne ne gagne au hasard ;
- `tests/playground_poses.luau` : les poses du personnage pour chaque jeu.

## Reste à faire

Ressenti au doigt sur de vrais téléphones et images par seconde, bras de fer avec un deuxième vrai joueur, validation
artistique des décors (des maquettes générées par le code, pas encore des modèles Blender), mini-jeu du Dieu du Pump
(❓ Antoine).
