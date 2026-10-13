# 03 — Progression et économie

## Stats

| Donnée | Rôle | Règle |
|---|---|---|
| **Force** | Ouvre exercices, exploits, rangs et quartiers | Ne fait qu'augmenter ; jamais retirée |
| **Cash** | Kits et accessoires | Gagné surtout par les petits boulots ; dépensé explicitement |
| **Mog** | Réputation | Débloque poses, titres, effets ; aucune puissance |
| Rang | Palier dérivé de la Force | Pas une monnaie, jamais choisi par le client |

**Pas d'énergie dans le MVP.** Les pauses sont des choix d'activité, pas des attentes imposées.
Maîtrise d'exercice : extension ultérieure.

## Économie : d'où vient et où va l'argent

```
SOURCES                              DÉPENSES
Petits boulots  ───── (principal) ──►  Kits d'entraînement (accélèrent la Force)
Exploits d'histoire ─ (ponctuel) ───►  Accessoires cosmétiques
Entraînement  ─────── (faible) ❓ ──►
Galères du jour ───── (bonus) ──────►
```

Le choix entre **s'entraîner** (Force) et **travailler** (Cash) est la décision centrale de la boucle.

## Kits d'entraînement

| Kit | Coût | Multiplicateur | Condition |
|---|---:|---:|---|
| Kit bricolé | Gratuit | x1 | Départ |
| Kit correct | 60 | x1,15 | 30 Force |
| Kit solide | 180 | x1,35 | 120 Force + kit précédent |
| Kit de quartier | 450 | x1,60 | 600 Force + kit précédent |

- Un seul kit actif ; chaque prix est celui du passage au kit suivant, sans remboursement.
- Afficher le prix, le multiplicateur avant/après et un aperçu. Les kits accélèrent la Force, pas les revenus.
- Accessoires (bandeau, débardeur, lunettes cartoon) : prix calibrés **après** les kits ; la confirmation rappelle qu'un objet est purement cosmétique.
- Pas de vente de Force, pas de sac à vider, pas d'aller-retour vers un vendeur.

## Rangs

| Rang | Force | Récompense |
|---|---:|---|
| Normie (ou Rookie ❓) | 0 | Pose de départ |
| Gym Rat | 120 | Nouvelle posture |
| Bro | 600 | Assez fort pour la voiture du voisin → la rue |
| Alpha | 2 000 | Squat et pose |
| Chad | 6 000 | Accessoire et rival de chapitre |
| Gigachad | 12 000 | Assez fort pour le bus → teaser du centre-ville |

Les rangs sont alignés sur les exploits d'histoire : chaque rang important correspond à **une action concrète** devenue possible.

## Objectifs de rythme

- Feedback dès la première répétition.
- Premier exploit réussi (bocal) en moins de 90 s.
- Premier achat après environ une minute de jeu actif.
- Premier duel tutoriel dans les 3 premières minutes.
- Accès à la rue en 5 à 10 minutes.
- Au moins trois découvertes importantes dans les 20 premières minutes.
- Chad / Gigachad : cible de 20 à 45 minutes à tester ; ne pas l'imposer si les chiffres ne le permettent pas.

Les récompenses ne sont pas toutes des nombres : nouvel exploit, nouvel exercice, rival, quartier, pose, silhouette.

## Simulation à faire avant d'ajuster les chiffres

Profils à simuler :
1. Maintien gratuit, achats optimaux, sans duel.
2. Timing moyen, avec achats, trajets et petits boulots.
3. Joueur orienté boulots, qui s'entraîne peu.
4. Joueur orienté duels.
5. Joueur qui achète tôt un accessoire.
6. Joueur qui ne connaît pas le meilleur chemin.

Rapporter : temps jusqu'à chaque exploit d'histoire, rang et achat ; plus longue période sans nouveauté ; revenus et dépenses. Déclarer chaque hypothèse (cadence, précision, pauses, trajets).
Un calcul en continu est une borne, pas une vraie session. Ajuster un groupe de paramètres à la fois et garder l'ancienne configuration.

Pas de rebirth dans le MVP.
