# MOG LIFE 💪 — Document de conception

> Ce document est **ton** travail. L'IA implémente ce qui est écrit ici.
> Les parties marquées ✅ sont déjà codées. Les parties ❓ sont à décider.

## 1. Concept

**En une phrase :** Tu commences en Normie maigrichon et tu t'entraînes jusqu'à devenir le Gigachad du serveur, capable de « mog » n'importe quel joueur d'un seul regard.

**Ton :** parodie gym bro absurde et exagérée, adaptée à tous les âges.

**Ce qui nous différencie des autres jeux de muscu Roblox :** ❓ (ex. : le système de Mog entre joueurs, voir section 6)

## 2. Boucle principale

1. ✅ Le joueur clique pour faire une répétition de l'exercice en cours
2. ✅ Il gagne de la **Force** et du **Cash**
3. ✅ Son corps s'élargit visuellement avec la force
4. ✅ Il monte en **rang** (Normie → Gigachad)
5. ❓ Il dépense son Cash pour progresser plus vite (compléments, équipements, salles)
6. ❓ Il affronte d'autres joueurs (Mog)

## 3. Stats

| Stat | Rôle | Statut |
|---|---|---|
| Force | Stat principale, débloque exercices et rangs, taille du corps | ✅ |
| Cash | Monnaie, gagnée en s'entraînant | ✅ |
| Mog | Score de domination (aura) — ❓ comment on le gagne ? | ❓ |
| Énergie | ❓ Limite l'entraînement et oblige à se reposer / manger ? | ❓ |

## 4. Exercices

Valeurs dans `src/shared/Config/Exercises.luau`.

| Exercice | Force/rép | Cash/rép | Force requise | Équipement |
|---|---|---|---|---|
| Curl haltère | 1 | 1 | 0 | non |
| Pompes | 3 | 2 | 100 | non |
| Développé couché | 10 | 5 | 1 000 | oui |
| Squat | 35 | 15 | 10 000 | oui |

❓ Autres idées : traction, soulevé de terre, pneu de tracteur, porter une voiture…

## 5. Rangs

Valeurs dans `src/shared/Config/Ranks.luau`.

Normie (0) → Gym Rat (500) → Bro (5 000) → Alpha (50 000) → Chad (250 000) → Gigachad (1 000 000)

## 6. Le Mog ❓

Idée : un joueur s'approche d'un autre et lance un « Mog ». Les deux font une pose, on compare les stats, le gagnant obtient des points de Mog et le perdant rétrécit brièvement de façon comique.

À décider :
- Ce qui compte dans le duel (Force seule ? Force + Mog + tenue ?)
- Le perdant perd-il quelque chose ?
- Délai entre deux Mog, protection contre le harcèlement des nouveaux joueurs

## 7. Boutique ❓

- **Compléments** (temporaires) : shaker de protéines (x2 force pendant 5 min), pré-workout…
- **Tenues** (cosmétiques) : débardeur, lunettes de soleil, chaîne en or…
- **Équipements** (permanents) : haltères plus lourds = plus de force par répétition

## 8. Salles / zones ❓

| Salle | Condition | Particularité |
|---|---|---|
| Garage de maman | Départ | Haltères rouillés |
| Salle de quartier | ? Force | ? |
| Muscle Beach | ? Force | ? |
| ❓ | | |

## 9. PNJ et humour ❓

- Le coach qui hurle des encouragements absurdes
- Le rival qui vous défie à chaque nouveau rang
- ❓

## 10. Monétisation ❓

- Game pass x2 Force
- Game pass auto-entraînement
- Produits : boosts temporaires, Cash
- Règle : rien qui rende le jeu injouable sans payer.

## 11. Rythme de progression ❓

Objectif : le joueur débloque quelque chose (rang, exercice, objet) **toutes les 2 à 5 minutes** pendant la première demi-heure.
