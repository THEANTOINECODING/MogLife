# 06 — Monétisation

**Décision : aucune boutique payante dans le prototype.** La monétisation s'ajoute à un jeu déjà amusant, jamais l'inverse.

## Pour la première version publique

À privilégier (tout est purement esthétique, comme la boutique en Cash) :
- Packs de style exclusifs en Robux (coupes, habits, bronzages), au contenu clairement affiché.
- Animations de victoire et poses, sans avantage.
- Effets visuels, avec un réglage pour que les autres joueurs puissent les atténuer.

Les objets en Cash restent toujours obtenables gratuitement ; les objets Robux s'y ajoutent, ils ne les remplacent pas.

À ne pas vendre au lancement : x2 Mog, Cash, victoire contre un boss, protection contre la perte de Cash. Il n'y a plus de mode auto du tout (D79).
Exception en Cash (D111, choix d'Antoine) : la tenue (Drip, au plus +5 % contre les boss et au bras de fer) et les meubles (« bien reposé », au plus +15 % de Mog pendant 4 min) ont un petit effet en jeu. Ils ne s'achètent qu'en Cash, jamais en Robux.
Exception à cette exception (D121, choix d'Antoine « Drip au maximum ») : trois tenues Robux (Game Pass) valent chacune 12 000 pour le Drip (`Balance.Drip.FullValue`). À elles seules, elles donnent donc le plafond de +5 %. En Cash, ce plafond ne s'atteint qu'en cumulant plusieurs articles chers (la tenue en Cash la plus chère, GoldenHour, vaut 6 250). C'est un raccourci payant vers le plafond, jamais au-delà : aucun bonus n'existe en Robux qu'on ne puisse obtenir gratuitement. Elles se distinguent surtout par leurs effets, visibles par tous.
Un éventuel accélérateur plus tard = décision séparée, parcours gratuit testé, plafonné, et **jamais** pris en compte dans les Mog-off.

## Règles d'interface

- Aucun achat proposé pendant les premières minutes ni après une défaite.
- Prix et contenu exacts visibles ; aucune fausse promotion.
- Pas de faux compte à rebours, de pénalité d'absence, de popups répétés.
- Pas de coffres aléatoires payants.
- Un objet payé est toujours restauré après reconnexion.
- Seule la confirmation officielle de Roblox accorde un produit (vérifiée côté serveur, attribution idempotente).

Revérifier les règles de la plateforme au moment de publier.
