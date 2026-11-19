# Analyse du jeu face aux meilleurs jeux Roblox — 19 novembre 2026

Demande d'Antoine : « une analyse du jeu plus poussée en te basant sur les meilleurs jeux qui existent pour voir les potentiels problèmes et améliorations qu'on pourrait mettre en place ».

Méthode : lecture du design (`00_VISION`, `01_BOUCLES`, `ANALYSE_VIRALE_2026-11-03`, `REVIEW_2026-11-10`, `ALPHA_PREPARATION`), recherche dans `src/`, simulation complète du 19/11 (`tools/simulate_economy.luau`, 8 profils), étude des prix du 15/11 (12 jeux à succès) et sources publiques sur l'algorithme de Roblox et les chiffres de rétention (liens en bas). Les points marqués **(vérifié)** ont été lus dans le code ou mesurés ; les autres sont des déductions. Les idées ne sont pas implémentées : Antoine choisit.

## 1. Ce que Roblox récompense en 2026

- **Juin 2026** : la recommandation « Recommended For You » mesure la rétention sur **28 jours** (jour 1, jours 2 à 7, jours 8 à 28) au lieu de 7. Les autres signaux : façon de jouer la première partie, qualité des sessions, dépenses, et **venir avec des amis** (co-play). Roblox dit vouloir éviter de favoriser les jeux à belle miniature qui ne retiennent pas.
- **Chiffres de référence** (GameAnalytics, jeux Roblox 2025) : pour des sessions de 19 à 24 minutes (la cible de MOG LIFE), rétention à J1 médiane **11,5 %**, 90ᵉ centile 18 %, meilleurs jeux **32 %** ; à J7 médiane 1,6 %, meilleurs jeux 3 à 8,5 %. Les jeux aux sessions longues gagnent aussi plus par joueur payant.
- **Les tubes de 2025** (Grow a Garden, Steal a Brainrot, 99 Nights in the Forest) ont explosé en quelques semaines, puis perdu une grande part de leurs visites en 4 à 6 mois. Leur point commun : une raison de revenir **plusieurs fois par jour** (plantes qui poussent hors ligne, magasin renouvelé toutes les 5 minutes, événements à heure fixe), un fort côté social (voler, échanger, survivre ensemble) et des mises à jour chaque semaine avec compte à rebours.

Conséquence pour nous : la nouvelle règle de Roblox pèse surtout sur **les jours 8 à 28**. C'est notre point le plus faible (partie 3, problème 1).

## 2. Ce qui est déjà au niveau des bons jeux

- **Une boucle claire et variée** : chaque activité a son mini-jeu, un boss par stade, une transformation visible du corps. Peu de jeux de musculation Roblox (Muscle Legends, Gym League, Strongman) font autre chose que cliquer.
- **Une durée de session dans la bonne zone** : la boucle de session vise 15 à 25 minutes, celle des meilleurs taux J1.
- **Un nom et un thème dans la tendance** (le mot « mog » est un mème) : un atout pour TikTok et les miniatures.
- **Une base sociale réelle (vérifié)** : pareur (+20 % de Mog), bras de fer contre n'importe qui, maisons à « J'aime » avec classement mondial, statues, défis de la semaine, bouton d'invitation.
- **Une monétisation propre (vérifié)** : produits et passes créés le 19/11 aux prix du marché, rien d'aléatoire.
- **Des mesures de base (vérifié)** : entonnoir des premières étapes (`Joined`, `LookCreated`, `TutorialDone`, `FirstRep`, `FirstHelp`, `FirstStylePurchase`, `FirstBossWin`, `SecondStage`).

## 3. Problèmes, du plus grave au moins grave

### 🔴 1. Rien à faire après environ 3 heures : la rétention de J8 à J28 va s'effondrer
La simulation donne le Dieu du Pump battu entre 2 h 36 et 3 h 30. Après, il reste la revanche, les défis de la semaine et le style. L'**Ascension** (proposée le 03/11) n'existe pas (vérifié : aucune trace dans `src/`). Avec la mesure sur 28 jours, un jeu fini en 3 heures est poussé moins longtemps par Roblox.

### 🔴 2. Le Dieu du Pump fait perdre environ une heure en défaites
Simulation (profils moyens) : 10 défaites, environ **83 000 Mog perdus**, de 39 à 55 minutes entre « prêt » et « battu ». Le joueur précis est même bloqué (le combat du Colisée est approximé par un Mog-off : chiffre à confirmer en test). Perdre 15 % du Mog à chaque défaite contre le dernier boss donne l'impression de reculer au moment où le joueur est le plus investi : c'est l'endroit typique des abandons. La question « garder ou limiter la perte de 15 % » est déjà ouverte depuis le 10/11.

### 🔴 3. Aucun vrai joueur n'a encore testé, et 80 % jouent sur iPhone
`ALPHA_PREPARATION.md` : pas de test sur vrai téléphone, pas de test à deux clients, pas de mesure des FPS. Aucun réglage ne vaut plus qu'un parcours réel noté minute par minute. C'est la priorité absolue avant la sortie.

### 🟠 4. Pas de raison de revenir plusieurs fois par jour
Le design refuse les obligations quotidiennes et les pénalités d'absence (à garder). Mais les tubes de 2025 donnent une **envie** de revenir sans punir : quelque chose a avancé pendant l'absence, ou un événement a lieu à heure fixe. Chez nous, seuls le coffre de la semaine (une case par jour) et les défis existent.

### 🟠 5. Venir à plusieurs ne rapporte presque rien
C'est désormais un signal de l'algorithme. Le bonus d'équipe par ami présent et la récompense d'invitation (proposés le 03/11) n'existent pas (vérifié : aucun appel aux listes d'amis dans `src/`). Le pareur et le bras de fer marchent avec n'importe qui, sans avantage à venir avec ses amis.

### 🟠 6. Les badges ne sont pas créés
`Badges.luau` : les 13 identifiants sont à 0 (vérifié). Le code est prêt, mais rien ne s'affiche sur le profil des joueurs, alors que c'est une vitrine gratuite vers leurs amis.

### 🟠 7. Les vitrines du jeu : page, communauté, mises à jour
À vérifier par Antoine : icône, miniatures, description, groupe Roblox. Le code n'a ni récompense de groupe, ni codes, ni panneau des nouveautés (vérifié). Les gros jeux annoncent chaque mise à jour avec un compte à rebours et des codes partagés sur Discord, TikTok et YouTube.

### 🟡 8. Les boosts en Cash avalent le Cash du style
Simulation : les profils qui achètent des boosts y mettent 9 000 à 10 000 Cash et finissent sans aucun look. Ça va contre la vision (« le Cash sert à ton style »). À confirmer en test : les vrais joueurs achètent peut-être moins de boosts que le profil simulé.

### 🟡 9. Le joueur maladroit bloque dès Kevin
Le profil faible (15 % de Perfect, sans progrès) perd contre le premier boss. En vrai, le joueur progresse, mais le premier boss doit être gagnable par presque tout le monde. Sinon, on perd le joueur à la troisième minute, au moment le plus important pour la rétention de J1. La victoire en Robux est proposée dès la défaite contre Kevin (vérifié : `BossService` et `PurchaseService.OfferBossWin`, aucune exception pour le premier boss ; active depuis la création du produit le 19/11) : elle risque de paraître « payer pour avancer » dès la troisième minute.

### 🟡 10. Rien à acheter une seule fois, à petit prix
Les jeux qui vendent le plus ont presque tous un **pack de départ** unique et bon marché (souvent entre 49 et 99 R$) : c'est souvent le premier achat d'un joueur, et un joueur qui a payé une fois rachète plus facilement. On n'en a pas. Les **serveurs privés** sont aussi un revenu simple, à activer dans le Creator Hub.

## 4. Améliorations proposées

Classées par rapport effet/effort. Chacune respecte la vision : pas de puissance vendue, pas de hasard payant, pas de pénalité d'absence.

### Rapides (moins d'une journée chacune)
1. **Créer les 13 badges** (stades, boss, premier S), puis renseigner leurs identifiants. Je peux les créer via Open Cloud si tu accordes l'autorisation des badges (au-delà du quota gratuit, un badge coûte des Robux : à vérifier avant).
2. **Activer les serveurs privés** dans le Creator Hub (prix courant : 50 à 100 R$ par mois). Rien à coder pour un premier temps.
3. **Pack de départ** unique (exemple : 79 R$ = 1 coupe exclusive + 3 000 Cash + 15 minutes de boost), proposé une seule fois après Kevin, jamais en surimpression pendant un mini-jeu.
4. **Récompense du groupe Roblox** : un titre ou un objet de style quand le joueur rejoint le groupe (vérifié par le serveur). Ça construit la communauté qui recevra les annonces de mise à jour.
5. **Panneau « Nouveautés » et codes** : un panneau sur la place qui liste la dernière mise à jour, et un champ de codes qui donnent du Cash ou un objet de style (les codes sont stockés côté serveur).

### Moyennes (quelques jours)
6. **Bonus d'équipe entre amis** : +10 % de Mog par ami Roblox présent sur le serveur (plafonné à +30 %), affiché à côté du Mog. Plus une récompense d'invitation : objet de style exclusif quand un ami invité fait sa première série.
7. **Limiter la perte de Mog contre le Dieu du Pump** (et les boss en général) : pas de perte au-delà de la 2ᵉ défaite d'affilée, ou une perte qui baisse à chaque défaite. Autre piste : un « entraînement contre l'ombre du dieu » pour apprendre ses attaques sans rien perdre.
8. **Kevin gagnable par presque tout le monde** : fenêtres de réussite plus larges au premier combat, ou un « second souffle » après une défaite (manche rejouée avec le mentor qui encourage). Et retirer la victoire en Robux contre Kevin, garder l'offre pour les boss suivants.
9. **Événements à heure fixe** : un événement de ville annoncé à l'avance (exemple : « Golden Pump Hour » chaque samedi à 18 h, avec Mog ×1,5 pour tout le serveur). Ça crée des rendez-vous sans punir les absents. Les notifications d'expérience de Roblox (accord du joueur) permettent de les annoncer.
10. **Quelque chose qui avance pendant l'absence, sans punir** : un « shaker de protéines » ou un banc dans la maison qui produit un peu de Cash ou un bonus de repos pendant l'absence (plafonné à 8 heures), à récupérer au retour. Les meubles et le bonus « bien reposé » (D111) existent déjà : c'est une extension naturelle.

### Grandes (une mise à jour entière)
11. **Ascension après le GOD MOGGER** (déjà proposée) : crans absurdes de plus en plus difficiles, chacun avec un titre, une aura et un badge, et un classement mondial du cran. C'est le contenu de fin de jeu qui répond directement au problème 1 et à la mesure sur 28 jours.
12. **Classement mondial du Mog** (semaine et total) sur un grand panneau, avec les statues des 3 premiers. La semaine se remet à zéro chaque lundi : tout le monde a une chance.
13. **Une mise à jour toutes les 2 à 3 semaines selon la même recette** (`00_VISION` : une zone, un boss, des exercices, des aides, du style), annoncée avec un compte à rebours dans le jeu et sur la page.
14. **Moments à partager** (déjà proposés le 03/11) : carte « avant / après » du corps à chaque stade, prête pour une capture d'écran ou TikTok.

## 5. Ordre conseillé

1. **Alpha réelle** : iPhone, PC, deux clients (problème 3). Rien d'autre n'a autant de valeur.
2. Rapides : badges, serveurs privés, groupe, pack de départ (1 à 4).
3. Kevin gagnable et perte de Mog limitée (7, 8) : là où les joueurs abandonnent.
4. Bonus entre amis (6) et événement à heure fixe (9) : les signaux « co-play » et « jours 2 à 7 ».
5. Ascension et classement mondial (11, 12) avant d'acheter de la publicité : pour tenir les jours 8 à 28.

## 6. Ce qu'on ne copie pas

Les pets et œufs aléatoires, le vol d'objets entre joueurs (Steal a Brainrot), les rebirths qui remettent à zéro, les passes ×2 permanents (vendre de la puissance) : tout ça est refusé par `00_VISION.md`. Les idées ci-dessus en reprennent l'effet (raison de revenir, social, fin de jeu) sans ces mécanismes.

## ❓ À décider par Antoine

- Quelles améliorations construire, et dans quel ordre ?
- La perte de 15 % du Mog : la limiter (et comment) ?
- Retirer la victoire en Robux contre Kevin ?
- Pack de départ : contenu et prix ?
- Accorder l'autorisation de créer les badges via Open Cloud ?

## Sources

- Roblox, juin 2026 : [Optimizing discovery so great games reach millions of players](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox)
- Documentation Roblox : [Discovery](https://create.roblox.com/docs/discovery.md)
- GameAnalytics : [2025 Roblox Report](https://www.gameanalytics.com/reports/2025-roblox-report)
- Dubit : [Roblox Top 20](https://dubit.io/blog/roblox-top-20-rfy) ; games.gg : [Roblox top games October 2025](https://games.gg/news/roblox-top-games-october-2025/)
- Deconstructor of Fun : [How to Build a Real Business on Roblox in 2026](https://www.deconstructoroffun.com/blog/how-to-build-a-real-business-on-roblox-in-2026)
- Étude des prix du 15/11/2026 : `06_MONETISATION.md` (« Grille de prix »)
