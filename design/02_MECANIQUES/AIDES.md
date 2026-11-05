# Aider la ville

> **D80, D81 : cette fiche fait foi.** La refonte de Codex (D76 à D79) est abandonnée (archive : `design/archive/PLAYGROUND_codex_abandonne.md`). Le geste exact de chaque mini-jeu, ses surprises et les règles communes (téléphone d'abord, main fantôme, plus de mode Auto) sont décrits dans [MINIJEUX.md](MINIJEUX.md).

Les habitants ont des problèmes absurdes. Les aider **rapporte du Cash**, la seule façon d'en gagner régulièrement.

## Règles

- Chaque aide demande un **stade minimum** (le Mog n'est pas dépensé, c'est un seuil).
- Chaque aide a **son propre mini-jeu**, utilisé nulle part ailleurs (décision D23, voir MINIJEUX.md).
- Une aide dure 15 à 25 secondes.
- Les aides sont **répétables**, avec un court délai par aide ❓ (ex. : 2 min) pour donner envie d'alterner avec l'entraînement et d'essayer les autres aides.
- La première réussite de chaque aide donne une petite scène ou une réplique unique.
- Les PNJ réagissent quand on revient beaucoup plus fort (répliques différentes selon le stade).
- Une aide ratée ne coûte rien : on réessaie.
- Indicateur au-dessus des PNJ : **!** quand une aide est disponible, cadenas avec le stade requis sinon.

## Aides du MVP

| Aide | PNJ | Mini-jeu | Stade requis | Cash ❓ |
|---|---|---|---|---:|
| Ouvrir le bocal de cornichons | Maman | Twist (taper vite, s'arrêter au rouge) | Normie | 5 |
| Gonfler le pneu du vélo | Le livreur dépassé | Pressure (pomper dans le vert, pas dans le rouge) | Normie | 8 |
| Planter les clous de la cabane | Le petit voisin | Hammer (frapper quand le marteau passe au-dessus du clou) | Gym Rat | 15 |
| Pousser la voiture du voisin | Le voisin | Steer (rester sur la route, éviter les obstacles) | Bro | 30 |
| Porter le piano de Mme Do-Ré | Mme Do-Ré | Lanes (glisser vers la voie libre) | Bro | 50 |
| Empiler les transats | Le maître-nageur débordé | Stack (ce qui dépasse tombe) | Alpha | 80 |
| Rattraper les courses | L'épicier maladroit | Catch (panier, éviter chaussures et cailloux) | Chad | 120 |
| Indiquer le chemin | Le touriste perdu | Sequence (retenir le chemin sur le plan, le glisser) | Gigachad | 180 |

Le Cash d'une aide augmente avec le stade requis. Les anciennes aides restent faisables mais rapportent moins que les récentes.

**Le Cash dépend de la réussite (D57).** Chaque répétition rapporte selon sa qualité (Perfect 100 %, Good 60 %, raté 0, mode auto 30 %), multipliée par le combo et par la chaîne de Perfect (+10 % par Perfect d'affilée, jusqu'à +50 %). Une aide jouée entièrement à la main sans aucun raté est « sans faute » : ×1,25 sur le total. Tout raté = 0 Cash (l'habitant remercie quand même, poliment) et pas de délai d'attente. Le joueur qui arrête en cours de route garde ce qu'il a gagné. Ordres de grandeur : sans faute ≈ 1,75 × le Cash du tableau, partie moyenne ≈ 1 ×. Réglages : `Balance.Helps.Reward`.

## Exemples de répliques

- Maman : « Ça fait trois ans que ce bocal me nargue. »
- Mme Do-Ré, quand on porte son piano avec un doigt : « Faites attention, il est accordé ! »
- Le voisin : « Normalement elle démarre. Normalement. »

## Habitants qui réagissent au look (D112)

- En passant près d'un habitant, il commente la tenue selon le palier de Drip (`Balance.Drip.Tiers`) et rappelle son dress code.
- Pourboire à la fin d'une aide réussie : jusqu'à `Balance.Drip.TipMax` (+30 %) du Cash, proportionnel au Drip.
- Dress code (`Helps.luau`, champ `dressCode`) : +50 % (`Balance.Drip.DressCodeBonus`) si l'on porte ce que l'habitant aime. ❓ Choix des dress codes à valider.
