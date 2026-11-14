# 06 — Monétisation

**Décision : aucune boutique payante dans le prototype.** La monétisation s'ajoute à un jeu déjà amusant, jamais l'inverse.

## Pour la première version publique

À privilégier (tout est purement esthétique, comme la boutique en Cash) :
- Packs de style exclusifs en Robux (coupes, habits, bronzages), au contenu clairement affiché.
- Animations de victoire et poses, sans avantage.
- Effets visuels, avec un réglage pour que les autres joueurs puissent les atténuer.

Les objets en Cash restent toujours obtenables gratuitement ; les objets Robux s'y ajoutent, ils ne les remplacent pas.

À ne pas vendre au lancement : x2 Mog, protection contre la perte de Cash (Cash, Mog et victoire de boss : autorisés par D122, voir plus bas). Il n'y a plus de mode auto du tout (D79).
Exception en Cash (D111, choix d'Antoine) : la tenue (Drip, au plus +5 % contre les boss et au bras de fer) et les meubles (« bien reposé », au plus +15 % de Mog pendant 4 min) ont un petit effet en jeu. Ils ne s'achètent qu'en Cash, jamais en Robux.
Exception à cette exception (D121, choix d'Antoine « Drip au maximum ») : trois tenues Robux (Game Pass) valent chacune 12 000 pour le Drip (`Balance.Drip.FullValue`). À elles seules, elles donnent donc le plafond de +5 %. En Cash, ce plafond ne s'atteint qu'en cumulant plusieurs articles chers (la tenue en Cash la plus chère, GoldenHour, vaut 6 250). C'est un raccourci payant vers le plafond, jamais au-delà : aucun bonus n'existe en Robux qu'on ne puisse obtenir gratuitement. Elles se distinguent surtout par leurs effets, visibles par tous.
Changement D122 (choix d'Antoine) : on vend aussi des packs de Cash, des packs de Mog et la victoire contre le boss qui bloque le joueur (première victoire seulement, proposée sur l'écran de défaite). Une tenue Robux portée en entier donne +15 % contre les boss (`Balance.Drip.RobuxBossBonus`), au-delà du plafond gratuit. En revanche, **rien de ce qui s'achète ne compte entre vrais joueurs** : le bras de fer n'utilise plus le Drip.
Changement D128 (demande d'Antoine) : on vend aussi un **boost de Mog** (×2 aux exercices pendant 15 ou 60 minutes de jeu, `Products.Boost`). Le minuteur ne tourne que quand le joueur est connecté et un rachat ajoute du temps : ce qui est payé n'est jamais perdu. Il ne compte pas entre vrais joueurs. La boutique Robux est une fenêtre à onglets (Tenues, Boosts, Cash, Mog) ouverte par la case « Shop » ; les packs de Cash y sont montrés comme des coffres, au montant fixe et affiché (toujours pas de coffres au hasard).
Un éventuel accélérateur plus tard = décision séparée, parcours gratuit testé, plafonné, et **jamais** pris en compte dans les Mog-off.

## Règles d'interface

- Aucun achat proposé pendant les premières minutes. Exception D122 : la victoire contre le boss, proposée une fois après une défaite contre lui (carte discrète, « No thanks », disparaît d'elle-même).
- Prix et contenu exacts visibles ; aucune fausse promotion.
- Pas de faux compte à rebours, de pénalité d'absence, de popups répétés.
- Pas de coffres aléatoires payants.
- Un objet payé est toujours restauré après reconnexion.
- Seule la confirmation officielle de Roblox accorde un produit (vérifiée côté serveur, attribution idempotente).

Revérifier les règles de la plateforme au moment de publier.

## Grille de prix (D129, 15/11/2026)

Prix relevés le 15/11/2026 sur l'API publique de Roblox pour 12 jeux à succès (Blox Fruits, Pet Simulator 99, Gym League, Muscle Legends, Grow a Garden, Steal a Brainrot, Brookhaven, Adopt Me, Arm Wrestle Simulator, Strongman Simulator, 99 Nights in the Forest, Blade Ball) : environ 3 300 produits et 118 passes. Les catégories sont triées par mots-clés dans les noms : les médianes sont des ordres de grandeur, pas des mesures exactes.

| Produit | Ce que font les autres | Notre prix |
|---|---|---|
| Boost ×2, 15 min | Blox Fruits 25 ; Strongman 199 (30 min) ; Arm Wrestle 149 (30 min) | **49** |
| Boost ×2, 60 min | Blox Fruits 99 ; Arm Wrestle 249 ; Strongman 249 à 349 | **149** |
| Coffre de Cash, petit | Strongman 29 ; Gym League 37 ; Blox Fruits 50 ; Steal a Brainrot 59 | **49** (1 500 Cash) |
| Coffre de Cash, gros | Strongman 129 ; Gym League 150 ; Blox Fruits 199 | **149** (6 000 Cash) |
| Coffre de Cash, doré | Strongman 199 ; Steal a Brainrot 379 ; Gym League 412 ; Blox Fruits 499 | **399** (20 000 Cash) |
| Pack de Mog (10 %, 35 %, 100 % d'un boss) | « passer une étape » : médiane 99, quart supérieur 349 ; 99 Nights 290 et 400 ; Gym League « Skip All » 750 | **49 / 149 / 399** |
| Victoire contre le boss | « revivre » : 99 Nights 55 à 95 ; Pet Simulator 99 79 ; Blade Ball 99 | **99** |
| Tenue Robux (passe permanent, aura, +15 % contre les boss) | auras Blox Fruits 88 et 350 ; skins Strongman 499 et 599 ; passe « Cosmetics » de Gym League 549 ; lots Brookhaven 399 ; passes ×2 permanents : médiane 350 | **299 à 599** |

Tenues : Statue de Marbre et Fantôme Néon 299 ; Soleil Éternel et Mecha-Mogger 399 ; Dragon de la Salle et Démon des Enfers 499 ; Titan Doré et Empereur Cosmique 599 (les deux tenues à cape, les plus travaillées). ❓ Ce classement des tenues est une proposition : à ajuster par Antoine.

Règles retenues : trois marches par famille (49, 149, 399), le plus gros pack toujours plus avantageux à l'unité (30, 40 puis 50 Cash par Robux), prix d'entrée bas parce que le jeu n'a pas encore de public. Blade Ball (lots de skins à 1 500 et plus) et les passes à plus de 1 000 Robux sont écartés : ils reposent sur un public déjà acquis. À revoir avec l'outil « Price Optimization » du Creator Hub quand le jeu aura des joueurs.
