# Entraînement

**Rôle :** la source principale de Force. On s'entraîne *pour* pouvoir faire les exploits ; l'entraînement n'est pas le but du jeu.

## Contrôles

Le joueur choisit une station et s'entraîne. Le serveur valide **au maximum une répétition par seconde** : cliquer plus vite ne sert à rien.

Deux façons de jouer, toutes les deux gratuites :
- **Maintenir** : rythme automatique, sans bonus.
- **Timing actif** : une pression par répétition au bon moment sur une jauge, pour un petit bonus.

| Résultat | Multiplicateur |
|---|---|
| Maintien ou timing raté | x1 |
| Good | x1,2 |
| Perfect | x1,5 |

Sur mobile, maintenir et jouer en timing sont deux actions clairement distinctes, sans geste rapide ni multitouch.

Une **série** dure 20 répétitions. À la fin, on propose : continuer, changer d'exercice, ou aller voir le prochain exploit. Pas de pénalité si on arrête en cours ; les répétitions validées restent acquises.

## Exercices du MVP

| Exercice | Force/rép | Cash/rép | Force requise | Lieu | Visuel |
|---|---:|---:|---:|---|---|
| Curl improvisé | 1 | 1 | 0 | Garage | Haltère dépareillé |
| Pompes | 2 | 1 | 120 | Garage | Tapis rafistolé |
| Développé couché | 4 | 2 | 600 | Salle de quartier | Banc grinçant |
| Squat | 8 | 3 | 2 000 | Salle de quartier | Barre avec des pneus |

Chaque nouvel exercice doit avoir une animation et une station vraiment différentes : c'est une découverte, pas juste un meilleur multiplicateur.

❓ Le Cash par répétition est-il encore nécessaire maintenant que les petits boulots existent ? À trancher après simulation (voir 03_PROGRESSION.md).

## Calcul

Force gagnée = ForceDeBase × MultiplicateurKit × MultiplicateurTiming

- Un seul kit actif (le meilleur possédé), jamais un empilement de multiplicateurs.
- Le serveur garde les décimales ; l'interface arrondit l'affichage.
- Pas de boost premium ni temporaire dans le MVP.
