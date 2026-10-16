# Idées en attente

Toute nouvelle idée arrive ici. Elle passe dans le design seulement après une décision dans `DECISIONS.md`.
Test de la vision : l'idée tient-elle dans les trois briques (mini-jeux, contenu en données, personnage) ?

## Multijoueur (après le MVP)

- **Duels de Mog entre joueurs** : Mog-off à chances égales sur une estrade, invitations consenties, récompenses plafonnées par paire de joueurs. Règles détaillées dans `archive/v3_exploits/02_MECANIQUES/MOG.md`. Réutilise directement le Mog-off des boss.
- **Aides géantes coopératives** : un objet énorme à déplacer à plusieurs (réutilise un mini-jeu, scores additionnés).
- **Galères du jour** : une aide spéciale apparaît sur le serveur pour tout le monde.

## Personnage et style

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
- **Vie dans la ville** : voitures qui roulent sur l'anneau, pigeons, joggeurs, jets d'eau de la fontaine, sons d'ambiance par zone.
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
