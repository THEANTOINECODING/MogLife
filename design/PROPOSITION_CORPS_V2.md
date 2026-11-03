# Proposition : un nouveau corps du joueur (« Bro v2 ») — 3 novembre 2026

Demande d'Antoine : le corps de base n'est pas assez qualitatif ; c'est le cœur du jeu (prendre du muscle), il doit
être parfait, plaisant à jouer, donner envie de se muscler, du **spaghetti** au début à l'**overdose de muscle** à la
fin, au-delà de toute rationalité. Rien n'est remplacé dans le jeu tant qu'Antoine n'a pas choisi (❓ en bas).

## 1. Ce qui ne va pas aujourd'hui (constaté sur les rendus)

Image : `assets/concepts/body_v1_lineup.png` (les 7 corps actuels, sans habits, rendus depuis `build_bodies.py`).

| Problème | Pourquoi ça compte |
|---|---|
| **Facettes partout** (style PS1, D39) : muscles en blocs anguleux, mains et pieds en boîtes | Le muscle ne donne pas envie : il paraît cassé, pas gonflé. Le rendu fait « vieux » face aux jeux Roblox actuels. |
| **Raccords visibles** entre les pièces (épaules, coudes, taille) | Une pièce par partie R15 : on voit les coupures, surtout quand le corps bouge. |
| **Silhouettes trop proches** : Normie et Gym Rat se ressemblent, Bro → Gigachad = le même corps de plus en plus large | Le joueur ne sent pas de palier. La transformation, la récompense principale du jeu, est faible. |
| **Le GOD MOGGER n'est pas absurde** : un gros bloc à peine plus grand (hauteur ×1,3 au plus, `Bodies.luau`) | La promesse « overdose de muscle » n'est pas tenue ; rien à montrer en vidéo. |
| **Visage petit et figé** : yeux en haut du crâne, bouche en boîte, tête qui s'enfonce dans le torse | Le personnage n'a pas de personnalité ; on ne s'y attache pas. |
| **Le Normie n'est pas assez spaghetti** : torse en œuf rose, bras moyens | Le point de départ doit être drôle et attachant pour que le contraste final soit énorme. |

## 2. Le personnage proposé (prototype construit)

Images (dans `assets/concepts/`) :
- `body_v2_lineup.png` : les 7 stades, rendu doux ;
- `body_v2_trio.png` : Normie, Chad, GOD MOGGER de trois quarts, avec un ombrage « cuit » (creux assombris), ce que
  donnerait dans Roblox une texture d'ombres peinte sur le corps ;
- `body_v2_lineup_budget.png` : les 7 stades **allégés au budget du jeu** (environ 8 300 triangles par personnage) :
  la silhouette et les muscles tiennent.

Script : `tools/blender/proto_body_v2.py` (n'exporte rien vers le jeu). Un seul personnage réglé par une valeur de
muscle de 0 (spaghetti) à 1 (GOD MOGGER) ; chaque trait a sa courbe et certains n'apparaissent qu'à partir d'un stade.

### Règles de style
1. **Formes rondes qui se fondent** (sculpture en metaballs, comme les colosses du mur) : un muscle est un ballon
   gonflé, jamais un bloc. Lisse, puis ombres peintes dans la texture pour dessiner pectoraux, abdos, deltoïdes.
2. **La tête ne grandit jamais** : sur un corps qui triple, elle paraît minuscule. C'est le gag visuel du gym bro,
   lisible de loin et sur un petit écran.
3. **Un palier = un trait nouveau**, pour que chaque boss battu se voie au premier coup d'œil :

| Stade | Ce qui apparaît | Gag |
|---|---|---|
| Normie | Bras et jambes en spaghetti, coudes et genoux noueux, pomme d'Adam, petit ventre mou, dos voûté, short et baskets trop grands, dents du lapin, sourire nerveux | Le short tient à peine |
| Gym Rat | Premières bosses aux épaules et aux bras, il se redresse | Il fléchit un biceps qu'on ne voit pas |
| Bro | Pectoraux, premiers abdos, taille fine (le V commence) | Il est fier de rien |
| Alpha | Abdos nets, deltoïdes ronds, dorsaux | Sourire en coin |
| Chad | Trapèzes qui montent vers les oreilles, mâchoire carrée, veines | Les bras ne touchent plus le corps |
| Gigachad | Trapèzes qui avalent le cou, dorsaux en ailes, bras écartés de force | Marche en canard |
| GOD MOGGER | Corps 2 fois plus large que haut, le biceps a son propre biceps, tête minuscule posée sur une montagne, jambes restées fines | Il ne passe les portes que de profil |

4. **Le visage vit** : grands yeux ronds, sourcils qui passent d'inquiets à sûrs d'eux, bouche qui passe du sourire
   nerveux au grand sourire en coin. Les yeux, sourcils et bouche sont posés sur la vraie surface du visage.
5. **Couleurs unies teintées par le jeu** (peau, cheveux, yeux, haut, short), comme aujourd'hui : la création de
   personnage (D55) garde tous ses réglages.

## 3. Trois façons de le mettre dans le jeu

| | A. Nouvelles formes, même technique (recommandé) | B. Corps d'un seul tenant avec os (« skinned mesh ») | C. Modèles faits à la main par un artiste 3D |
|---|---|---|---|
| Principe | Le prototype est découpé en une pièce par partie R15 (comme aujourd'hui) ; `BodyService`, le pump, la croissance continue et les présentoirs restent | Un maillage par stade, déformé par les os du squelette R15 ; les habits deviennent des **vêtements superposés** Roblox (WrapLayer) qui s'adaptent seuls à chaque corps | Même technique que A ou B, formes sculptées à la main |
| Rendu | Lisse, sans facettes ; raccords cachés aux articulations (les pièces se chevauchent) | Le plus beau : aucune coupure, les coudes plient proprement | Le meilleur possible |
| Habits | À refaire pour les nouveaux corps (`build_style.py` mesure déjà la surface des corps : relance automatique, puis contrôle) | Un vêtement unique pour les 14 corps (fini les 43 × 14 modèles) | Selon A ou B |
| Risques | Modéré : on garde tout ce qui marche | ❓ À tester d'abord : la croissance continue dans un stade (taille des os), le coût des vêtements superposés sur iPhone | Coût, délai, dépendance à quelqu'un |
| Effort | Plusieurs sessions (corps, coupe en pièces, texture d'ombres, habits, contrôle en jeu) | Le plus long (rig, cages des vêtements, réécriture de `BodyService` et `Outfit`) | Externe |

Recommandation : **A d'abord** (un stade de bout en bout, par exemple le Normie, vu en jeu dans Studio), puis les
6 autres ; **B** à garder en tête pour plus tard si la garde-robe devient trop lourde à maintenir.

## 4. Ce qui rend la prise de muscle « addictive » (au-delà du modèle)

Déjà dans le jeu : pump à chaque répétition (D40), croissance continue pendant un stade (D60), transformation animée.
À ajouter avec le nouveau corps :
- **Le t-shirt qui craque** : quand le corps dépasse la taille de son haut, le haut se déchire (une fois par stade).
  Moment comique, et un clip parfait à partager.
- **Avant / après** à chaque nouveau stade : courte pose côte à côte (l'ancien corps en fantôme), puis une carte
  photo que le joueur peut garder (voir l'analyse virale).
- **Au-delà du GOD MOGGER** : le corps continue de grossir avec le Mog, par crans absurdes (muscles sur les muscles,
  veines dorées, aura, tête qui disparaît presque). Ça tient la promesse « au-delà de toute rationalité » et donne
  une fin de jeu sans fin (voir l'analyse virale).
- **La démarche suit la taille** (déjà amorcée en D84) : le spaghetti flotte, le GOD MOGGER fait trembler le sol.

## 5. Limites du prototype (honnêtement)

- Rendus Blender seulement : rien n'est encore vu dans Roblox. Le rendu « doux » utilise l'éclairage de Blender ;
  dans Roblox, la définition des muscles viendra de la texture d'ombres (image `body_v2_trio.png`).
- Le prototype est d'un seul tenant : la coupe en pièces R15 (option A) n'est pas faite.
- Version masculine seulement ; les corps féminins suivront les mêmes règles (brassière aux stades torse nu).
- Le short est encore trop bouffant aux derniers stades ; les mains sont simplifiées (poings).
- Le GOD MOGGER du prototype dépasse la hauteur actuelle (7,6 studs au lieu d'environ 6,8) : à vérifier avec les
  portes (le design exige que le plus gros corps passe les portes).

## ❓ À décider par Antoine

1. Le style « formes rondes, tête qui ne grandit pas, visage expressif » te plaît-il ? Qu'est-ce que tu changerais ?
2. Option A, B ou C ?
3. Jambes : restent fines jusqu'au bout (gag « jamais de jour des jambes ») ou grossissent avec le reste ?
4. Au-delà du GOD MOGGER : croissance sans fin, ou le GOD MOGGER reste la taille maximale ?
