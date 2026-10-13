# 08 — Tests et mesures

## Vérifications techniques obligatoires

- Spam réseau et clics rapides : aucun gain au-delà de la cadence.
- Exploits : impossible de les déclencher à distance, sans la Force requise, ou deux fois pour les récompenses de première réussite (y compris après reconnexion).
- Objets portés : pas de téléportation, de lancer exploitable ou de blocage d'autres joueurs.
- Achats : pas de Cash négatif, pas de double dépense.
- Duel : impossible de changer le résultat en envoyant un faux score ; gérer refus, déconnexion, égalité, latence élevée, serveur sans adversaire.
- Sauvegarde : pas de perte de progression ; un profil non chargé n'écrase jamais l'ancien.
- Taille maximale de l'avatar : portes, caméra, collisions et objets portés fonctionnent.
- Parcours gratuit en maintien terminé sans aucun achat.
- Récompenses PvP : pas de remise à zéro en changeant de serveur.

Tests de logique pour l'économie, scénarios dans Studio pour les interactions. Si Studio n'est pas disponible, lister les étapes manuelles et ce qui reste non vérifié.

## Événements d'analytics

- first_rep, first_feat, first_upgrade, first_rank, first_job, first_npc_duel, first_pvp_duel
- feat_attempted (impossible / réussi), story_feat_completed, district_unlocked, tutorial_completed
- server_event_spawned, server_event_joined, giant_feat_completed
- duel_invited, duel_accepted, duel_declined, duel_completed
- session_started et quelques instantanés de progression espacés (pas un événement par clic)

## À suivre

- Temps médian jusqu'au premier exploit, premier achat, premier duel, accès à la rue.
- Abandon à chaque étape du tutoriel.
- Répartition du temps entre entraînement, boulots, exploits et duels.
- Participation aux galères du jour et aux exploits géants.
- Retours J1 et J7 par cohorte (analytics Roblox).
- Erreurs de sauvegarde, latence, FPS.

Dix testeurs révèlent des problèmes ; ils ne prouvent pas une rétention future. Comparer des versions sur des groupes comparables.

## Questions de fin de test

- « Quel était ton prochain objectif ? »
- « À quel moment t'es-tu ennuyé ? »
- « Quel exploit voulais-tu faire et ne pouvais pas encore ? »
- « Qu'est-ce qui t'a fait rire ? »
- « Pourquoi inviterais-tu un ami ? »

## Lecture des résultats

- Les joueurs aiment l'idée mais abandonnent avant le premier vrai exploit → raccourcir le chemin jusqu'à la voiture.
- Ils font les boulots mais évitent la salle → revoir le rôle et le rythme de l'entraînement.
- Ils ignorent les galères du jour → les rendre plus visibles ou plus drôles, pas plus rentables.

## Références Roblox (consultées le 13 octobre 2026)

- Boucles de jeu : https://create.roblox.com/docs/production/game-design/core-loops
- Rétention : https://create.roblox.com/docs/production/analytics/retention
- Monétisation : https://create.roblox.com/docs/production/monetization
- Standards de la communauté : https://about.roblox.com/community-standards
