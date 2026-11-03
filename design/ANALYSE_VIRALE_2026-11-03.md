# Analyse : ce qui rendra MOG LIFE viral, et ce qui l'en empêche — 3 novembre 2026

Demande d'Antoine : prendre du recul, lister tous les bons et les mauvais points pour créer un jeu viral, commencer à
proposer des solutions aux mauvais. Sources : tout le dossier `design/`, le code de `src/`, les rendus Blender et les
tests dans Studio de cette session. **Aucune donnée de vrais joueurs n'existe encore** : ce qui suit est une analyse,
pas une mesure. Ce qui est vérifié dans le code est marqué ✔ ; ce qui est une hypothèse, 💭.

## Résumé

Le concept est très bon pour la viralité : « du spaghetti au dieu du muscle », un mot à la mode (« mog »), un humour
absurde qui se comprend sans texte, et un vrai jeu derrière (20 mini-jeux, des boss qui jouent en direct). Ce qui
manque n'est pas le contenu, c'est **tout ce qui fait circuler le jeu** : rien n'invite un ami, rien ne se partage,
rien ne s'affiche sur le profil du joueur, aucun classement au-delà du serveur, aucune mesure. Et la récompense
centrale, la transformation du corps, n'est pas encore assez spectaculaire pour faire un clip.

**Les 5 priorités** : (1) le corps (voir `PROPOSITION_CORPS_V2.md`) ; (2) les mesures, puis un vrai test sur iPhone ;
(3) inviter ses amis et jouer avec eux ; (4) badges et classements mondiaux ; (5) une fin de jeu qui ne finit pas.

## Les bons points (à garder et à mettre en avant)

| Point fort | Constat | Pourquoi c'est viral |
|---|---|---|
| **Un concept qui se lit en une image** | Normie → GOD MOGGER, 7 stades (✔ `Stages.luau`) | Une miniature avant/après se comprend en une demi-seconde, dans toutes les langues |
| **Le mot « mog »** dans le titre | Titre : MOG LIFE : become a GOD MOGGER 💪🗿 | Mot et emoji 🗿 de la culture mème des ados ; recherche et partage naturels 💭 |
| **Chaque activité a son mini-jeu** | 20 mini-jeux (✔ `src/client/Minigames/`), 6 exercices, 8 aides, 6 boss | La grande différence avec les simulateurs de clics : on ne s'ennuie pas, et chaque mini-jeu est une petite surprise à filmer |
| **Les boss jouent en direct** | Mog-off en manches, coups spéciaux, scènes de victoire (✔ `BossService`, D85) | Moments forts réguliers ; « je veux voir le prochain boss » |
| **Moments signatures** | Kevin éjecté par le toit, le Colisée du Pump avec spectateurs, statues des meilleurs | Ce sont des clips tout faits |
| **Humour absurde, tous publics** | Règles du projet, textes en anglais centralisés | Partageable sans risque ; les parents laissent jouer |
| **Social déjà présent** | Pareur (+20 % de Mog), bras de fer n'importe où, émotes, défis de la semaine, spectateurs du Colisée (✔ `SocialService`, `DuelService`, `WeeklyService`, `ColosseumService`) | Raisons de jouer à côté des autres |
| **Retour sans culpabilité** | Défis et coffre de la semaine, jamais de pénalité (✔ D67) | Rétention saine, conforme aux règles Roblox |
| **Premier boss très tôt** | Kevin vers 1 min 41 (simulation, `ALPHA_PREPARATION.md`) | Le joueur vit une victoire dans les 2 premières minutes |
| **Technique solide** | Serveur qui décide de tout, ProfileStore, plafond anti-triche, limites des remotes (✔ D108) | Pas de triche visible qui ruine les classements ; pas de perte de sauvegarde |
| **Prêt pour le monde entier** | Tous les textes dans `Texts.luau`, phrases complètes, marges de 30 % | La traduction automatique Roblox ouvre les marchés non anglophones |
| **Pas de « payer pour gagner »** | Monétisation prévue purement esthétique (`06_MONETISATION.md`) | Confiance et bouche-à-oreille positif |
| **Ville lisible** | Icônes au-dessus des magasins et de sa maison, guide vers le boss, Mur des Colosses qui ferme l'horizon | On sait où aller sans tutoriel |

## Les mauvais points, et ce que je propose

Gravité : 🔴 bloque la viralité · 🟠 la freine · 🟡 à améliorer.

### 🔴 1. La transformation n'est pas assez spectaculaire
Constat : voir `PROPOSITION_CORPS_V2.md` (facettes, raccords, stades qui se ressemblent, GOD MOGGER pas absurde).
C'est la récompense principale et l'image de la page du jeu.
Proposition : le corps « Bro v2 » (prototype fait), le t-shirt qui craque, l'avant/après à chaque stade.

### 🔴 2. Rien ne fait venir les amis
Constat ✔ : aucun appel à l'invitation Roblox (`SocialService:PromptGameInvite`) dans `src/`, aucun bonus pour jouer
avec des amis. Le pareur et le bras de fer existent, mais il faut que quelqu'un soit déjà là.
Propositions :
- Bouton **« Invite a bro »** (menu et fin de série) qui ouvre l'invitation Roblox.
- **Bonus d'équipe** : +10 % de Mog par ami Roblox présent sur le serveur (plafonné), affiché à côté du Mog.
- **Récompense d'invitation** : un objet de style exclusif quand un ami invité joue pour la première fois (vérifié par
  le serveur).
- **Défis à deux** : « parez un ami 5 fois », « gagnez un bras de fer contre un ami ».

### 🔴 3. Aucune mesure : on ne saura pas ce qui marche
Constat ✔ : aucune mesure n'était envoyée (`ALPHA_PREPARATION.md`). Sans elles, impossible de savoir où les joueurs
abandonnent, alors que la découverte sur Roblox dépend de la rétention et du temps de jeu 💭.
**Commencé dans cette session (D109)** : funnel des premières minutes (arrivée, création du look, première répétition,
première aide, premier achat, premier boss battu, tutoriel fini, 2e boss) et événements clés (séries finies, aides
payées, achats, boss gagnés ou perdus, stade atteint, tutoriel passé). Vérifié dans Studio : les appels à l'API
partent sans erreur. Non vérifié : la réception dans le tableau de bord (seulement dans le jeu publié).

### 🟠 4. Rien ne s'affiche hors du serveur : pas de badges, pas de classement mondial
Constat ✔ : aucun `BadgeService`, aucun classement persistant (`OrderedDataStore`) ; seulement les statues du top 3
**du serveur** et le tableau des joueurs.
Propositions :
- **Badges** : un par stade atteint, un par boss battu, quelques badges rares et drôles (« Skipped leg day forever »,
  1 000 Perfect). Ils apparaissent sur le profil Roblox du joueur, que ses amis voient.
- **Classement mondial** du Mog (toute la semaine et depuis toujours) sur un grand panneau de la place, et les
  statues de la place prises dans ce classement.
- Les statues reprennent aujourd'hui **l'avatar Roblox** du joueur (✔ `StatueService`) : les montrer avec **le bro du
  jeu à sa vraie taille**, c'est la meilleure publicité du corps.

### 🟠 5. La fin de jeu s'arrête vite
Constat : un joueur moyen atteint le seuil de Mog du Dieu du Pump en 45 à 76 minutes (simulation du 18/10,
`ALPHA_PREPARATION.md`, avant le Colisée). Ensuite, le
Mog ne sert plus à rien et le corps ne change plus. La vision refuse les rebirths (`00_VISION.md`).
Proposition **sans rebirth** : **l'Ascension**. Après le GOD MOGGER, le Mog continue d'agrandir le corps par crans
absurdes (« Cosmic », « Planetary », « Multiversal »…) avec un trait nouveau à chaque cran (aura, veines d'or, petites
planètes en orbite autour des biceps). Chaque cran donne un badge et un titre, et le classement mondial donne une
raison de continuer. Rien n'est perdu, rien n'est remis à zéro. 💭 Le corps doit rester jouable : plafonner la taille
physique et exagérer seulement les muscles et les effets.

### 🟠 6. Le Cash s'accumule sans rien à acheter
Constat : environ 3 700 Cash restants en fin de parcours simulé (`ALPHA_PREPARATION.md`).
Propositions : des objets de prestige très chers et absurdes (couronne de haltères, cape de serviettes en or), la
décoration de la maison (meubles déjà prévus, ✔ `FurnitureService`), des poses de victoire à collectionner
(`IDEES.md`). Les décisions de prix restent pour après l'alpha.

### 🟠 7. Pas de « moment à partager »
Constat : rien n'aide à faire une capture ou un clip ; la carte avant/après n'existe pas.
Propositions : à chaque nouveau stade, une **carte avant/après** (ancien corps, nouveau corps, nom du stade, surnom)
et le bouton de capture de Roblox (CaptureService, à vérifier au moment de coder) ; un **mode photo** simple au
miroir (poses, fond de la ville).

### 🟠 8. Le téléphone n'est pas encore testé pour de vrai
Constat : environ 80 % des joueurs sont sur iPhone ; aucun test sur vrai téléphone n'a encore été fait
(`ALPHA_PREPARATION.md`). Le mur des colosses représente environ 1 million de triangles (allégé en D108).
Proposition : avant toute publicité, une partie complète sur un iPhone ancien, en mesurant le nombre d'images par
seconde (objectif ≥ 30), la lisibilité des 20 mini-jeux au doigt et les temps de chargement.

### 🟠 9. La page du jeu n'est pas prête
Constat : Studio affiche le titre en français (« devenez un MOGGER DIVIN ») ; aucune icône ni miniature dans le dépôt.
Sur Roblox, c'est l'icône qui décide si l'on clique 💭.
Propositions : une icône **avant/après** (spaghetti à gauche, GOD MOGGER à droite, l'emoji 🗿), trois miniatures
honnêtes (transformation, un boss, un mini-jeu), une description courte en anglais. À faire avec le nouveau corps.

### 🟡 10. Aucune monétisation (volontaire pour l'instant)
Constat ✔ : aucun `MarketplaceService`. Le design la repousse après un jeu amusant, à raison.
Proposition pour la publication, dans les règles de `06_MONETISATION.md` : serveurs privés (gratuits à proposer),
packs de style en Robux, poses et effets. Jamais de Mog payant.

### 🟡 11. Les premières secondes
Constat : à l'arrivée, le créateur de personnage s'ouvre avant tout (D55). C'est bien pour l'attachement, mais un
joueur venu d'une vidéo veut bouger tout de suite 💭.
Proposition : un gros bouton « Random & GO! » en premier plan du créateur (le reste reste accessible au miroir), et
mesurer l'abandon à cette étape grâce au funnel (étape « LookCreated »).

## Plan proposé (dans l'ordre)

1. **Le corps** : choix d'Antoine sur `PROPOSITION_CORPS_V2.md`, puis un stade de bout en bout dans le jeu.
2. **Les mesures** (✔ commencées) + **test sur iPhone**.
3. **Amis** : invitation, bonus d'équipe, récompense d'invitation.
4. **Badges et classement mondial**, statues avec le bro du jeu.
5. **Moments à partager** : t-shirt qui craque, carte avant/après.
6. **Ascension** après le GOD MOGGER.
7. **Page du jeu** (icône, miniatures, description), puis monétisation esthétique.

## ❓ À décider par Antoine

Chaque proposition ci-dessus (sauf les mesures, déjà prévues par `08_TESTS_ET_MESURES.md`) est une idée nouvelle :
elle est rangée dans `IDEES.md` et attend ton choix. Rien de tout cela n'est codé.
