# 03 — Progression et économie

## Deux ressources seulement

| Ressource | Gagnée par | Sert à | Règles |
|---|---|---|---|
| **Mog** 🗿 | Les exercices (mini-jeux) | Défier les boss, débloquer les aides (seuils) | Ne fait qu'augmenter. N'est jamais dépensé ni perdu. |
| **Cash** 💵 | Les aides en ville, les premières victoires de boss | Coupes, habits, accessoires (purement esthétiques) | Peut baisser : achats, défaite contre un boss trop fort. Jamais négatif. |
| Stade | Dérivé des boss battus | Corps, déblocages | Jamais choisi par le client |

Pas d'énergie, pas de kits d'équipement, pas de rebirth dans le MVP.

## Stades

Normie → Gym Rat → Bro → Alpha → Chad → Gigachad → **GOD MOGGER**
On passe au stade suivant en battant le boss correspondant (voir BOSS.md).

## Décision du joueur

À chaque instant, le joueur choisit entre :
- **s'entraîner** → Mog → prochain boss et nouveaux exercices ;
- **aider** → Cash → style ;
- **défier un boss** → risqué s'il n'a pas le Mog requis.

## Défaite contre un boss trop fort

Perte de 10 % du Cash, plafonnée ❓ (plafond qui augmente avec les stades). Toujours annoncée avant le combat. Jamais de perte de Mog, d'objets ou de stade.

## Objectifs de rythme

- Premier Mog dès la première répétition.
- Première aide et premier Cash en moins de 2 minutes.
- Premier achat de style vers 2–3 minutes.
- Premier boss (Kevin) vers 3–5 minutes.
- Un nouveau mini-jeu toutes les 5 à 10 minutes pendant le MVP.
- Coach Turbo battu (fin du MVP) : cible 25–40 minutes à tester.

Les récompenses ne sont pas toutes des nombres : nouveau mini-jeu, nouveau boss, nouvelle zone, nouveau corps, nouvel objet de style.

## Dernière simulation (14 octobre 2026, `tools/simulate_economy.luau`)

| Profil | Kevin | Brayan | Coach Turbo | Pas-Les-Jambes | Roi du Quartier | Défaites |
|---|---|---|---|---|---|---:|
| Joueur précis | 2:04 | 6:32 | 20:48 | 38:25 | 59:54 | 0 |
| Joueur moyen qui progresse | 2:04 | 7:20 | 22:40 | 42:30 | 67:26 | 4 |
| Joueur moyen qui ne progresse pas | 2:04 | 7:20 | bloqué | — | — | — |

Coach Turbo est le premier vrai mur : il faut devenir plus précis. Le Cash s'accumule en fin de MVP (≈ 3 500 gagnés pour 1 290 d'objets) : prévoir des objets plus chers ou plus nombreux.

## Simulation à faire avant d'ajuster les chiffres

Profils :
1. Joueur faible (beaucoup de ratés), aucune aide (le mode auto a été retiré, D79).
2. Joueur moyen (mélange Bien/Raté), alterne exercices et aides.
3. Joueur très précis (beaucoup de Parfait).
4. Joueur qui dépense tout en style dès que possible.
5. Joueur qui défie les boss trop tôt.

Rapporter : temps jusqu'à chaque boss et chaque mini-jeu, plus longue période sans nouveauté, Cash gagné et dépensé, nombre d'objets achetables à la fin du MVP. Déclarer les hypothèses (cadence, précision, temps de trajet, délais des aides).
