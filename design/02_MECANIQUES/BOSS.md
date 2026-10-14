# Boss de stade (Moggers)

À chaque stade de Mog correspond un **boss**, visible dans le monde. Le battre fait officiellement monter de stade et débloque la suite.

## Les boss

Tout le monde commence au stade **Normie**. « Mog requis » = le Mog nécessaire pour défier le boss ; le battre fait passer au stade suivant.

| Boss | Mog requis ❓ | Son mini-jeu | Niveau en direct ❓ | Victoire → stade | Victoire débloque |
|---|---:|---|---|---|---|
| **Kevin « demain je commence »** — en pyjama, excuses extravagantes | 50 | Reaction | ~50 / 100 | Gym Rat | Pompes, nouvelles aides |
| **Brayan le Bronzé** — bronzage orange fluo | 400 | Spotlight | ~59 | Bro | Développé couché |
| **Coach Turbo** — mégaphone plus gros que lui | 2 500 | Beats | ~65 | Alpha | Squat, transats |
| **Monsieur Pas-Les-Jambes** — torse énorme sur deux cure-dents, chaussettes géantes | 7 500 | Wobble | ~69 | Chad | Tractions, courses |
| **Le Roi du Quartier** — arrive avec son propre ventilateur | 20 000 | Combo | ~74 | Gigachad | Corde à sauter, touriste |
| **Le Dieu du Pump** — sur un nuage, foudre dans chaque biceps | 45 000 | ❓ | ~84 | **GOD MOGGER** | Le titre GOD MOGGER (mise à jour Olympe) |

Le MVP contient les **5 premiers boss** (Normie → Gigachad, décision D25). Le Dieu du Pump est annoncé « coming soon ». Les chiffres sont des hypothèses (voir `tools/simulate_economy.luau`).

## Affronter un boss

Le joueur s'approche du boss et appuie sur **Défier**.

### Avant le combat
Une fenêtre indique le Mog requis et celui du joueur :
- ✅ « Tu es prêt. Si tu perds le Mog-off, tu laisses **Y Cash**. »
- ⚠️ « Il a l'air BEAUCOUP trop fort pour toi. Si tu perds, tu laisses **X Cash**. » → bouton *Défier quand même* / *Plus tard*.

La perte est toujours **annoncée avant** : c'est un choix du joueur, jamais un piège.

### Si le joueur n'a pas le Mog requis
Défaite automatique et comique : le boss le mogge d'un seul regard, le joueur rétrécit et s'envole hors de l'estrade.
- Perte : **10 % du Cash**, plafonnée ❓ (ex. : 50 Cash max au début, plafond qui augmente avec les stades).
- Jamais de perte de Mog, d'objets ou de stade.
- Jamais en dessous de 0 Cash.

### Si le joueur a le Mog requis : le Mog-off (décision D24)
- **3 manches** de 6 répétitions sur le **mini-jeu propre au boss** (jamais utilisé ailleurs).
- **Le boss joue en direct** : son score monte en même temps que le tien (« You 72 vs 68 Brayan »). Il a un niveau propre et devient plus précis à chaque manche.
- **Chaque manche est plus dure** : rythme plus rapide (x1 → x0,92 → x0,85) et fenêtres de timing plus serrées (x0,9 → x0,78 → x0,66).
- Score de manche = moyenne des points (Parfait 100, Bien 70, Raté 20, répétition non jouée 0). Égalité = le boss gagne.
- 2 manches gagnées = victoire.
- **Défaite : perte de 5 % du Cash** (plafonnée par stade ❓), annoncée dans la fenêtre de défi. Aucune perte en revanche contre un boss déjà battu.
- Mode auto interdit en combat.
- Après 3 défaites d'affilée, le boss devient un peu moins exigeant ❓ (non implémenté).

### Victoire
- Montée officielle de stade ; le corps passe au modèle du nouveau stade.
- Scène absurde de 2–3 s, quittable (le boss traverse le toit, s'envole dans l'espace, se transforme en flaque…).
- Récompense de première victoire : Cash bonus + un objet de style exclusif au boss. Une seule fois, garanti même après reconnexion.
- Les victoires suivantes : possibles pour le plaisir, sans récompense.

## Règle de progression

Le Mog continue d'augmenter même si le boss n'est pas battu, mais **le stade, le corps et les déblocages** ne changent qu'après la victoire. La jauge affiche « Prêt à affronter Brayan ! » quand le seuil est atteint.
