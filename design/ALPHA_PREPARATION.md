# Préparation de l'alpha — 18 octobre 2026

Ce document prépare l'étape 8 de `07_ROADMAP.md`. Les cibles de temps sont des hypothèses du design, pas des résultats de joueurs. Aucun chiffre d'équilibrage n'a été changé.

## État vérifié

- Dans Studio, le bras de fer contre le mannequin démarre en espace ouvert et près d'une maison. Près du mur, la table se tourne maintenant pour montrer les deux adversaires de profil. Le duel **entre deux clients** reste à tester.
- Au miroir de la maison, les six titres exclusifs sont visibles et lisibles. Avec 1 trophée et 5 victoires temporairement placés dans les données de test, les deux titres correspondants se débloquent ; « Wrist Wrecker » se sélectionne dans l'aperçu. Les données ont été restaurées.
- Le simulateur d'économie a été relancé en mode édition, sans sauvegarde joueur. Il produit des parcours théoriques ; le toucher, les trajets réels, les abandons et la concurrence entre joueurs ne sont pas mesurés.
- Recherche dans `src/` : aucun appel aux événements d'analytics demandés par `08_TESTS_ET_MESURES.md`. La collecte chiffrée de l'alpha reste donc à mettre en place ou à remplacer provisoirement par une fiche de test manuelle. Selon la [documentation Roblox](https://create.roblox.com/docs/production/analytics/custom-events), les événements personnalisés sont envoyés par le serveur dans un jeu publié ; Studio ne peut pas confirmer leur réception dans le tableau de bord.

## Avant d'inviter les testeurs

1. Lancer dans Studio **Test → Serveur et 2 clients**. Vérifier : invitation « Arm Wrestle », acceptation, refus et délai sans réponse ; table entre les joueurs ; bras des deux côtés ; résultat identique sur les deux écrans ; trois duels récompensés avec la même paire puis duel sans récompense ; réglage « Duel invites » coupé. Refaire un duel près d'un mur. Cette vérification n'est pas encore faite.
2. Faire un parcours neuf complet sur un vrai téléphone, puis sur PC : création du personnage, tutoriel, premier curl, bocal, premier look, Kevin, nouveau stade. Noter les minutes réelles et les moments de confusion. Ne pas modifier l'économie à partir de la simulation seule.
3. Vérifier le tactile sur les mini-jeux, les combats et la jauge du bras de fer. Relever les FPS sur le téléphone choisi pour référence ; la cible du design est **au moins 30 FPS** (`05_ART_SON.md`).
4. Refaire les vérifications techniques de `08_TESTS_ET_MESURES.md` : cadence serveur, prérequis et distances, achats et récompenses uniques, sauvegarde après reconnexion, tous les corps et habits, mode auto, français et allemand. Tout ce qui n'est pas essayé reste « non vérifié ».
5. Décider comment relever les mesures pendant l'alpha. L'instrumentation prévue par `08_TESTS_ET_MESURES.md` manque actuellement dans le code. En attendant, utiliser la fiche ci-dessous et noter l'heure des étapes, sans supposer que les tableaux Roblox contiennent déjà ces événements.

## Fiche à remplir pour chaque testeur

Conserver un identifiant de testeur sans son nom réel. Noter appareil, type de commandes, langue du compte et date. Pour chaque étape, relever l'heure depuis l'entrée en jeu : premier Mog, première aide, premier Cash, premier look essayé et acheté, premier boss tenté et battu, chaque nouveau stade. Noter aussi les mini-jeux joués en auto, les échecs de boss, les achats, les bugs, les coupures de texte et les FPS observés.

À la fin, demander sans suggérer de réponse : « Quel était ton prochain objectif ? », « Quel exercice as-tu préféré, et lequel t'a ennuyé ? », « Qu'est-ce qui t'a fait rire ? », « Quel objet de style voulais-tu ? », « Pourquoi inviterais-tu un ami ? » (`08_TESTS_ET_MESURES.md`). Dix testeurs peuvent révéler des problèmes ; ils ne prouvent pas la rétention future.

## Comparaison d'économie, simulation du 18 octobre

Profils 2, 6, 7 et 8 de `tools/simulate_economy.luau` : mêmes tirages aléatoires initiaux, joueur moyen qui progresse après une défaite, aides et événements. Les effets changent ensuite le rythme du parcours, donc les événements rencontrés peuvent différer. « Seuil Pump God » est un objectif annoncé, pas un boss jouable.

| Parcours simulé | Coach Turbo battu | Seuil Pump God | Cash restant | Boosts achetés |
|---|---:|---:|---:|---:|
| Moyen, sans boost ni pareur | 20:23 | 76:14 | 3 712 | 0 |
| Même profil, boosts seuls | 15:38 | 50:51 | 770 | 9 |
| Même profil, pareur seul | 18:11 | 70:12 | 3 537 | 0 |
| Même profil, boosts et pareur | 14:34 | 45:20 | 555 | 9 |

Les boosts expliquent la plus grande part du raccourcissement dans ce scénario. Le simulateur suppose notamment deux séries entre aides, 6 s de trajet et un pareur une série sur deux. Ce tableau ne démontre ni la durée réelle ni l'équité perçue.

## Décisions à demander à Antoine après les essais humains

- Garder ou revoir les cibles de `03_PROGRESSION.md` (Kevin en 3–5 min, Coach Turbo en 25–40 min) ? La simulation moyenne actuelle donne 1:41 et 20:23.
- Le gain de temps des boosts, seuls puis avec un pareur, convient-il ? Vérifier d'abord si les joueurs trouvent ces aides et les comprennent.
- Souhaite-t-on garder le Cash abondant pour le style, ou créer plus tard des choix de dépense ? Ne pas fixer de nouveaux prix à partir de ce tableau.
- Si le mode auto reste bloqué à Coach Turbo, aider par l'apprentissage ou envisager la règle ouverte D19 après observation des joueurs ?

Ces questions restent ouvertes dans `IDEES.md`. Ne changer aucune valeur avant la réponse du créateur.
