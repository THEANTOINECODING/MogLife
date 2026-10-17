# 01 — Boucles de jeu

## La boucle principale

```
Exercices (mini-jeux) ──► Mog ──► Stade atteint ──► Boss du stade
                           │                            │ victoire
                           ▼                            ▼
              Aides débloquées en ville ◄── Nouvelle zone, exercice, aides
                           │
                           ▼
                         Cash ──► Coupes, habits, accessoires
```

## Boucle courte (30 à 90 secondes)

Choisir un exercice → jouer une série de son mini-jeu → gagner du Mog → voir le corps et la jauge du prochain stade avancer.

## Boucle moyenne (3 à 8 minutes)

Alterner exercices (Mog) et aides en ville (Cash) → acheter un objet de style → atteindre un stade → affronter son boss → débloquer la suite.

## Boucle de session (15 à 25 minutes)

Battre un boss, découvrir le nouvel exercice ou la nouvelle zone, se refaire un look, repartir avec le prochain boss en tête.

## Boucle de retour

Le prochain boss, les objets de style qu'on veut, et les **mises à jour** (nouvelle zone, nouveau boss, nouveaux mini-jeux). Jamais d'obligation quotidienne.

Depuis l'étape 9 (D67, bouton **Weekly** en haut à droite) :
- **Défis de la semaine** : chaque lundi (UTC), 3 défis tirés au sort, les mêmes pour tous : un pour s'entraîner
  (Perfect, séries, notes S), un pour aider la ville (aides, aides sans faute, événements), un pour se mesurer aux
  autres (duels, victoires en duel, Mog-off, pareur). Chaque défi réussi se réclame (Cash) ; les 3 réclamés donnent un
  **trophée de la semaine** et un bonus. Les trophées débloquent des titres exclusifs (1, 4 et 10 trophées).
- **Coffre de la semaine** : chaque jour où l'on joue au moins 3 minutes coche une case (7 cases) ; le coffre s'ouvre
  le dimanche, et rapporte plus s'il y a plus de cases cochées.
- **Bras de fer** contre n'importe quel joueur, n'importe où (D68, voir `02_MECANIQUES/DUELS.md`).
- Aucune pénalité : sauter un jour ou une semaine ne fait rien perdre ; ce qui était gagné mais pas réclamé (défis,
  bonus, coffre) est versé automatiquement la semaine suivante. Montants : `Config/Weekly.luau` (hypothèses ❓).

## Les 5 premières minutes

| Temps cible | Ce qui se passe | Ce que le joueur comprend |
|---|---|---|
| 0–15 s | Garage de maman. Kevin, le boss Normie, traîne sur le canapé et se moque. Le coach tend un haltère fait de deux pastèques. | « Je dois m'entraîner. » |
| 15–60 s | Premier mini-jeu : le curl (glisser de haut en bas). Le Mog monte, le corps change déjà. | « Je progresse, et c'est un vrai petit jeu. » |
| 60–120 s | Maman demande d'ouvrir le bocal de cornichons (première aide). Les cornichons volent partout ; elle paie quelques pièces. | « Aider rapporte du Cash. » |
| 2–3 min | Premier achat au miroir du garage : une coupe ridicule. | « Le Cash sert à mon style. » |
| 3–5 min | 50 Mog atteints → Mog-off contre Kevin. Victoire, scène absurde, débloquage des pompes (nouveau mini-jeu). Au loin, Brayan le Bronzé attend. | « Il y a un boss à chaque stade, et je veux voir le suivant. » |

Le tutoriel est contextuel, rejouable et quittable. Aucun paiement nécessaire.
Implémenté (D46) : le mentor guide ces étapes ; à 2–3 min le joueur **essaie** un look chez le coiffeur (l'achat demanderait 25 Cash alors que le bocal en rapporte 5 : ❓ à trancher).

**Moment signature :** la victoire contre Kevin. Il est « moggé » si fort qu'il traverse le toit du garage, les serviettes volent, le coach annonce : « Le garage n'était pas prêt. » Scène de 2–3 s, quittable.
