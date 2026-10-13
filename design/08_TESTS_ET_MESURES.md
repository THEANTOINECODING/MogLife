# 08 — Tests et mesures

## Vérifications techniques obligatoires

- Spam réseau et entrées rapides : aucun gain au-delà de la cadence d'un mini-jeu.
- Qualité Parfait : impossible de l'obtenir en envoyant de faux timings (contrôles de plausibilité côté serveur).
- Exercices, aides, boss : impossibles à lancer s'ils ne sont pas débloqués, à distance, ou pendant une autre activité.
- Boss : la perte de Cash correspond à ce qui a été annoncé ; jamais de Cash négatif ; récompense de première victoire impossible à obtenir deux fois (y compris après reconnexion).
- Achats de style : pas de double dépense, objets conservés après reconnexion.
- Sauvegarde : pas de perte de progression ; un profil non chargé n'écrase jamais l'ancien ; migration via `schemaVersion`.
- Personnage : habits et coupes fonctionnent sur tous les corps ; le plus gros corps passe les portes et ne gêne pas la caméra.
- Parcours complet du MVP réalisable en mode auto, sans aucun achat.
- Traduction : tester l'interface en français et en allemand (textes longs) ; aucun texte coupé ni qui déborde ; aucun texte resté en dur hors de `Texts.luau`.

Tests de logique pour l'économie, scénarios dans Studio pour les mini-jeux. Si Studio n'est pas disponible, lister les étapes manuelles et ce qui reste non vérifié.

## Événements d'analytics

- first_rep, first_perfect, first_help, first_style_purchase, first_boss_attempt, first_boss_win
- minigame_series_completed (exercice, qualité moyenne, mode auto ou non)
- boss_attempt (boss, prêt ou non, résultat), stage_reached, zone_unlocked
- help_completed, style_item_bought, tutorial_completed
- session_started et quelques instantanés de progression espacés (pas un événement par répétition)

## À suivre

- Temps médian jusqu'au premier boss, premier achat, chaque nouveau stade.
- Abandon à chaque étape du tutoriel.
- Mini-jeux préférés et délaissés ; taux de mode auto par mini-jeu.
- Tentatives de boss trop tôt : combien, et le joueur revient-il ensuite ?
- Retours J1 et J7 par cohorte (analytics Roblox).
- Erreurs de sauvegarde, latence, FPS.

Dix testeurs révèlent des problèmes ; ils ne prouvent pas une rétention future.

## Questions de fin de test

- « Quel était ton prochain objectif ? »
- « Quel exercice as-tu préféré, et lequel t'a ennuyé ? »
- « Qu'est-ce qui t'a fait rire ? »
- « Quel objet de style voulais-tu ? »
- « Pourquoi inviterais-tu un ami ? »

## Lecture des résultats

- Un mini-jeu est massivement joué en mode auto → il est pénible ou pas assez récompensé : le retravailler.
- Les joueurs quittent après une défaite contre un boss trop fort → l'avertissement n'est pas clair ou la perte est trop forte.
- Personne n'achète de style → objets pas assez drôles ou trop chers, pas « plus de Cash ».

## Références Roblox (consultées le 13 octobre 2026)

- Boucles de jeu : https://create.roblox.com/docs/production/game-design/core-loops
- Rétention : https://create.roblox.com/docs/production/analytics/retention
- Monétisation : https://create.roblox.com/docs/production/monetization
- Standards de la communauté : https://about.roblox.com/community-standards
