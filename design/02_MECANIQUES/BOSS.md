# Boss de stade (Moggers)

> **D80, D81 : cette fiche fait foi.** La refonte de Codex (D76 à D79) est abandonnée (archive : `design/archive/PLAYGROUND_codex_abandonne.md`). Le geste exact de chaque mini-jeu, ses surprises et les règles communes (téléphone d'abord, main fantôme, plus de mode Auto) sont décrits dans [MINIJEUX.md](MINIJEUX.md).

À chaque stade de Mog correspond un **boss**, visible dans le monde. Le battre fait officiellement monter de stade et débloque la suite.

## Les boss

Tout le monde commence au stade **Normie**. « Mog requis » = le Mog nécessaire pour défier le boss ; le battre fait passer au stade suivant.

| Boss | Mog requis ❓ | Son mini-jeu | Niveau en direct ❓ | Victoire → stade | Victoire débloque |
|---|---:|---|---|---|---|
| **Kevin « demain je commence »** — en pyjama, excuses extravagantes | 50 | Reaction (glisser dans le sens de son bras) | ~50 / 100 | Gym Rat | Pompes, nouvelles aides |
| **Brayan le Bronzé** — bronzage orange fluo | 400 | Spotlight (crème dans le soleil) | ~59 | Bro | Développé couché |
| **Coach Turbo** — mégaphone plus gros que lui | 2 500 | Beats (deux pistes, notes longues) | ~65 | Alpha | Squat, transats |
| **Monsieur Pas-Les-Jambes** — torse énorme sur deux cure-dents, chaussettes géantes | 7 500 | Trace (tracer sa pose avant la fin du temps, D110) | ~69 | Chad | Tractions, courses |
| **Le Roi du Quartier** — arrive avec son propre ventilateur | 20 000 | Combo (combinaison de glissés) | ~74 | Gigachad | Corde à sauter, touriste |
| **Le Dieu du Pump** — sur un nuage, foudre dans chaque biceps | 45 000 | Combat au Colisée (D89 à D104), finale « Suplex olympien » (D110) | ~84 | **GOD MOGGER** | Le titre GOD MOGGER (mise à jour Olympe) |

Le MVP contient les **5 premiers boss** (Normie → Gigachad, décision D25). Le Dieu du Pump est annoncé « coming soon ». Les chiffres sont des hypothèses (voir `tools/simulate_economy.luau`).

Depuis D75, la difficulté monte d'un boss à l'autre : anticipation d'un trajet, visée mobile, maintien au signal, lecture
puis action, enfin équilibre contre une force variable. Leur précision simulée et leur cadence progressent aussi dans
`Stages.luau` ; les manches d'un même boss se resserrent via `Balance.Boss`. Cette progression est une intention
d'équilibrage à vérifier sur appareils réels, car les mécaniques ne se comparent pas par un seul chiffre.

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
- **Le Mog-off se voit** (D37) : à chaque répétition, le joueur prend une vraie pose de culturisme (double biceps, most muscular, lat spread, pectoraux de profil, bras en V), plus ou moins réussie ; le boss se gonfle à chacune de ses répétitions.
- **Le boss joue en direct** : son score monte en même temps que le tien (« You 72 vs 68 Brayan »). Il a un niveau propre et devient plus précis à chaque manche.
- **Chaque manche est plus dure** : rythme plus rapide (x1 → x0,92 → x0,85) et fenêtres de timing plus serrées (x0,9 → x0,78 → x0,66).
- Score de manche = moyenne des points (Parfait 100, Bien 70, Raté 20, répétition non jouée 0). Égalité = le boss gagne.
- 2 manches gagnées = victoire.
- **Défaite : perte de 5 % du Cash** (plafonnée par stade ❓), annoncée dans la fenêtre de défi. Aucune perte en revanche contre un boss déjà battu.
- Pas de mode Auto (D79). En combat, ne rien faire est un raté : la manche finit toujours.
- Chaque manche débloque les surprises du mini-jeu du boss (feintes de Kevin, nuages de Brayan, notes longues du Coach, poses dures puis en miroir de Monsieur Pas-Les-Jambes, 5 flèches du Roi), en plus d'être plus rapide et plus serrée (D81).
- Sur téléphone et tablette, les commandes de déplacement disparaissent pendant le mini-jeu ; on joue n'importe où sur l'écran (D81).
- Après 3 défaites d'affilée, le boss devient un peu moins exigeant ❓ (non implémenté).

### Duels physiques (D85)

Chaque combat est mis en scène dans le monde par un duel propre au boss, vu par tous les joueurs proches
(`src/client/BossFights/`, réglages `Config/BossFights.luau`). Le mini-jeu et ses règles ne changent pas : chaque coup
du joueur et du boss devient une action, et une position visible montre qui mène.

| Boss | Duel | Qui mène | Coup spécial (dernière manche) | Fin |
|---|---|---|---|---|
| Kevin | Bataille de polochons (plumes) | Étoiles au-dessus de celui qui est en retard | Il bâille et pique du nez (💤) | Le perdant s'effondre dans les plumes |
| Brayan | Choc de rayons solaires avec deux miroirs | Le point de choc avance vers celui qui perd | Éclairs de bronzage, le joueur se protège les yeux | Le perdant est soufflé par le rayon |
| Coach Turbo | Tir à la corde (foulard, ligne au sol) | Le foulard glisse vers celui qui gagne | Il hurle de plus en plus vite dans son mégaphone | Le perdant passe la ligne et tombe |
| Monsieur Pas-Les-Jambes | Choc de pectoraux sur un ring | Le perdant est repoussé vers le bord | Le ring tremble | Le perdant bascule hors du ring |
| Le Roi du Quartier | Battle de poses sur un tapis rouge, ventilateur royal | La couronne flotte au-dessus de celui qui mène | Le vent souffle fort | Le perdant met un genou à terre |

Les boss ont un squelette (os aux noms des pièces R15, `tools/blender/rig_bosses.py`) : leurs bras et leurs jambes
bougent. Sans squelette (ancien modèle), le duel anime leur corps entier.

Placement : les deux combattants restent sur l'estrade du boss (8 × 8 ; au-delà, on tombe en contrebas). Le boss recule
de `BossShift` vers le fond pendant le duel et reprend sa place à la fin. Le ring de Monsieur Pas-Les-Jambes est celui
de la carte (rien n'est ajouté). Pendant les manches, la barre « toi contre le boss » est fine (manches dedans) et placée en haut de la
partie de l'écran que le mini-jeu laisse libre ; la caméra cadre les combattants en dessous (D87). Chaque coup du
boss a un élan, les coups encaissés font vaciller, les combattants rebondissent sur leurs appuis entre les coups.

Modèles : les boss à squelette (`assets/export/Boss_<Id>_Rig.fbx`) remplacent les anciens dans
`ServerStorage.NpcModels` (place Studio, pas Rojo) ; les anciens sont gardés dans `ServerStorage.NpcModelsBackup`.

### Victoire
- Montée officielle de stade ; le corps passe au modèle du nouveau stade.
- Scène absurde de 2–3 s, quittable (le boss traverse le toit, s'envole dans l'espace, se transforme en flaque…).
- Récompense de première victoire : Cash bonus + un objet de style exclusif au boss. Une seule fois, garanti même après reconnexion.
- Les victoires suivantes : possibles pour le plaisir, sans récompense.

## Règle de progression

Le Mog continue d'augmenter même si le boss n'est pas battu, mais **le stade, le corps et les déblocages** ne changent qu'après la victoire. La jauge affiche « Prêt à affronter Brayan ! » quand le seuil est atteint.
