# Ce qui a fait percer les jeux Roblox en 2026, et la suite de MOG LIFE — 20 novembre 2026

Demande d'Antoine : « analyse les choses qui ont bien marché dans les autres jeux qui ont percé et prépare la suite de notre travail ».

Ce document **complète** [ANALYSE_JEU_2026-11-19.md](ANALYSE_JEU_2026-11-19.md) (algorithme sur 28 jours, rétention, 14 améliorations, dont 1 à 10 et le classement mondial sont faits depuis : D131, D132). Ici : les tubes **de 2026** (pas ceux de 2025), ce qu'ils ont en commun, une règle de Roblox qui nous concerne directement, et un plan de travail concret.

Méthode : sources publiques (liens en bas), recoupées entre elles. Les chiffres de joueurs viennent de sites de suivi non officiels qui ne sont pas d'accord entre eux : ce sont des ordres de grandeur. Ce qui concerne notre code a été vérifié dans `src/` **(vérifié)**. Rien de ce document n'est implémenté : Antoine choisit.

## 1. Les tubes de 2026

| Jeu | Sortie / pic | Boucle | Ce qui l'a fait percer (selon les sources) |
|---|---|---|---|
| **Steal an Egg** | pic ≈ 14 millions de joueurs simultanés (19/09/2026) | voler et garder des œufs, mélange de mécaniques à succès | reprise de plusieurs boucles éprouvées ; **retiré par Roblox le 25/08** pour une mécanique qui récompensait le fait de regarder un flux de vidéos (revenu sans), puis nouvelle règle pour tout Roblox |
| **Throw Food For Animals** | sorti le 18/09/2026, pic ≈ 1,6 million (07/11) | lancer de la nourriture pour attirer des animaux, les ramener à sa base qui rapporte | **s'entraîner sur une barre de traction augmente la portée du lancer**, et un lancer « parfait » ajoute de la portée : la force du personnage change ce qu'il peut faire dans le monde |
| **Ride A Pet** | sorti en avril 2026, pic ≈ 1,6 million | monter son animal pour aller chercher des œufs loin, les ramener avant qu'ils éclosent | plus la monture est rapide, plus on va loin, plus les œufs sont rares : **le progrès se voit et se ressent dans le déplacement** |
| **99 Nights in the Forest** | toujours ≈ 2,2 millions (17/10) | survivre à plusieurs dans la forêt | coopération, peur partagée, sessions longues |
| **Murder Mystery 2**, **Adopt Me!** | anciens jeux remontés (2,2 et 1,4 millions en octobre) | jeux de groupe et d'échange | rendez-vous, événements de saison, communauté |
| **Dead Rails** (2025, étudié par GameAnalytics) | de quelques centaines à plus de 600 000 joueurs | défendre un train dans un western de zombies | **une base connue + une touche surprenante** ; mis en avant par les comptes officiels de Roblox puis par de très gros YouTubers ; vu partout à la fois (TikTok, YouTube, accueil de Roblox) |

Dans les jeux de musculation, aucun gros succès en 2026 : le genre est encombré de simulateurs « clique pour grossir » (Strongman Simulator, Gym Star Simulator, Untitled Gym Game…). La place d'un jeu de muscu **drôle et à mini-jeux** reste libre.

## 2. Sept leçons, et où en est MOG LIFE

### 🔴 Leçon 1 — Sans l'accès aux moins de 16 ans, le jeu est invisible pour son public
Depuis le **16 juin 2026**, les moins de 16 ans ont des comptes **Roblox Kids** (5-8 ans) et **Roblox Select** (9-15 ans). Un jeu n'y est visible **qu'après une évaluation** ; avant, il n'est proposé qu'aux joueurs de 16 ans et plus vérifiés. Conditions officielles (documentation Roblox) :
- créateur au compte vérifié par l'âge, double authentification ;
- questionnaire de classification rempli (Kids : Minimal ou Mild ; Select : jusqu'à Moderate) ;
- abonnement Roblox Plus ou Premium depuis 2 mois **ou** frais remboursable par jeu ;
- période d'essai : **100 parties uniques de joueurs « très engagés » de 16 ans et plus vérifiés, en 60 jours** (progression visible dans Creator Hub > le jeu > Publish Settings > Manage Audience) ;
- revue accélérée possible contre un dépôt remboursable de 50 000 R$.

Pour un jeu de gym bro humoristique, l'essentiel des joueurs a moins de 16 ans. **C'est la première chose à vérifier avant toute publicité ou toute sortie.** Notre contenu vise « Minimal » ou « Mild » (aucun sang, aucune violence réaliste, humour sans insulte, discussion Roblox standard) : il n'y a rien à retirer a priori. Conséquence pour l'alpha : les testeurs de 16 ans et plus servent aussi à atteindre les 100 parties nécessaires.

### 🟠 Leçon 2 — Une base connue, une touche surprenante, compréhensible en 5 secondes
Dead Rails = défense de base connue + train western de zombies. Chez nous : simulateur de muscu (connu) + **corps absurdes qui gonflent, un mini-jeu par exercice, boss en direct** (surprenant). C'est bon, à condition que la touche se voie **dans les 30 premières secondes et sur la miniature** : un corps qui gonfle d'un coup est notre meilleure image. Manque : rien ne fabrique ce moment pour le partager (la carte « avant / après » proposée le 03/11 n'existe pas, vérifié).

### 🟠 Leçon 3 — La force doit changer ce qu'on peut faire dans le monde
Les deux nouveaux tubes de l'automne relient le progrès à une action visible : la traction augmente la portée du lancer (Throw Food For Animals), la vitesse de la monture ouvre les œufs lointains (Ride A Pet). Chez nous, le Mog fait grossir le corps et ouvre les boss et les aides (seuils), rien d'autre dans le monde. Le joueur ne **sent** pas sa force en se promenant. Pistes (dans `IDEES.md`) : objets du monde qu'on ne peut soulever ou pousser qu'à partir d'un stade (une voiture garée, un rocher qui bloque un raccourci, un coffre secret), saut plus haut et atterrissage qui fait trembler le sol selon le gabarit (l'animation D134 en pose la base).

### 🟢 Leçon 4 — Des raisons de revenir plusieurs fois par jour, sans punir
Faites depuis hier (vérifié) : Golden Pump Hour (samedi 18 h UTC), gain pendant l'absence (plafond 8 h), **Mog Rush toutes les 30 minutes**, défis de la semaine. Il manque l'annonce à l'extérieur du jeu : les **notifications d'expérience** de Roblox (avec l'accord du joueur) pour la Golden Hour et le début d'un Mog Rush.

### 🟠 Leçon 5 — Les créateurs de vidéos et la mise en avant font le décollage
Dead Rails a décollé quand Roblox et de gros YouTubers l'ont montré, puis l'algorithme a pris le relais au-delà d'un seuil de joueurs. Ce qu'on peut préparer sans payer : un **mode photo / caméra libre** (pour les clips), la carte avant/après, des **codes** à donner aux créateurs (le système existe, D131), une page du jeu avec un clip de transformation, et une courte bande-annonce tournée dans le jeu. Ce qu'on ne maîtrise pas : être choisi par Roblox ou par un YouTuber.

### 🟢 Leçon 6 — Ce que Roblox sanctionne maintenant
Steal an Egg a été retiré pour une boucle qui payait les enfants à regarder un flux de contenu. Roblox surveille désormais les jeux qui récompensent une consommation sans fin. Notre design refuse déjà les obligations quotidiennes, le hasard payant et la puissance vendue ; le gain d'absence est plafonné (8 h) ; une série s'arrête d'elle-même quand le joueur ne joue plus (vérifié : `MinigameService`, `Balance.RunIdle`). **À garder tel quel.**

### 🟠 Leçon 7 — Une fin de jeu qui relance (sans remise à zéro)
Ride A Pet et la plupart des simulateurs à succès ont une « renaissance » (rebirth) et des variantes rares. Nous refusons la remise à zéro, mais l'**Ascension** (crans absurdes après le GOD MOGGER, proposée le 03/11) en joue le rôle. Elle n'existe toujours pas (vérifié). Avec la mesure de rétention sur 28 jours, c'est le plus gros manque de contenu.

## 3. La suite : plan de travail proposé

Une étape à la fois, dans cet ordre. Chaque étape dit ce qu'elle demande à Antoine.

1. **Antoine, sans code (cette semaine)**
   - Enregistrer la place (Ctrl+S) : meubles v3 (D133).
   - Creator Hub > Publish Settings > Manage Audience : remplir le questionnaire, vérifier l'éligibilité Kids / Select (leçon 1).
   - Créer les 8 badges restants (5 gratuits par jour) et me donner les numéros.
   - Me dire si je pousse les commits sur GitHub.
2. **Alpha réelle** (déjà la priorité n°1 hier) : iPhone, PC, deux clients, fiche de test d'`ALPHA_PREPARATION.md`. À ajouter : regarder les **nouvelles animations** (D134), les **meubles v3** et le **tableau Mog Rush** à l'écran (jamais vus en image, la capture de Studio étant en panne). Les testeurs de 16 ans et plus comptent aussi pour les 100 parties Kids / Select.
3. **Moments à partager** (quelques jours) : carte avant / après à chaque stade, mode photo (caméra libre, interface cachée, poses), bouton de partage Roblox. Leçons 2 et 5.
4. **La force dans le monde** (quelques jours, à choisir parmi les pistes de la leçon 3) : 3 à 5 objets de la ville qu'on ne soulève qu'à partir d'un stade, chacun avec un petit mini-jeu propre et une récompense (Cash, secret, raccourci). Respecte la règle « chaque activité a son mini-jeu ».
5. **Ascension** (une mise à jour entière) : crans après le GOD MOGGER, titre, aura et badge par cran, classement mondial du cran. Questions de design à trancher avant de coder (❓ ci-dessous).
6. **Notifications d'expérience** (une journée) : Golden Pump Hour et Mog Rush, avec l'accord du joueur.
7. **Rythme de mises à jour** : la recette de `07_ROADMAP.md` (une zone, un boss, des exercices, des aides, du style), annoncée avec un compte à rebours et un code.

## ❓ À décider par Antoine

- Le jeu est-il déjà proposé aux moins de 16 ans (Manage Audience) ? Abonnement Premium ou frais par jeu ?
- Ordre des étapes 3 à 6.
- La force dans le monde : quels objets (voiture, rocher, coffre, autre) et quelle récompense ?
- Ascension : combien de crans, quel coût en Mog, le corps continue-t-il de grossir visiblement, une récompense par cran ?
- Récompense du champion du Mog Rush (titre, aura de 30 minutes ?) — déjà posée en D132.

## Sources

- TechCrunch, 13/04/2026 : [Roblox introduces 'Kids' and 'Select' accounts](https://techcrunch.com/2026/04/13/roblox-introduces-kids-and-select-accounts-for-age-appropriate-access-to-games-and-chat/)
- Documentation Roblox : [Roblox Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select)
- Roblox, 05/2026 : [What families need to know about Roblox Kids and Select](https://about.roblox.com/newsroom/2026/05/what-families-should-know-roblox-kids-select)
- TechSpot : [Roblox is cracking down on games that reward kids for doomscrolling](https://www.techspot.com/news/113630-roblox-cracking-down-games-reward-kids-doomscrolling.html) ; MassivelyOP : [Roblox clamps down after Steal an Egg goes viral](https://massivelyop.com/2026/08/29/roblox-clamps-down-on-gen-ai-brainrot-scrolling-games-after-steal-an-egg-goes-viral/)
- RoStats : [Records](https://rostats.io/records) ; Statroblox : [Top 100 2026](https://statroblox.com/top-100/2026)
- Pro Game Guides : [Throw Food For Animals beginner's guide](https://progameguides.com/roblox/complete-throw-food-for-animals-beginners-guide-roblox/) ; Beebom : [Ride A Pet wiki](https://beebom.com/ride-a-pet-wiki/)
- GameAnalytics : [How Dead Rails became a Roblox hit](https://www.gameanalytics.com/blog/dead-rails-and-the-hit-makers-formula)
- Documentation Roblox : [Retention](https://create.roblox.com/docs/production/analytics/retention), [Onboarding](https://create.roblox.com/docs/production/game-design/onboarding)
