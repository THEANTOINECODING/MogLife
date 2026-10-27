# 05 — Art, interface et son

## Direction : l'absurde exagéré

Dans l'esprit de Douchebag Workout : **tout est exagéré, tout le temps.** Nos propres designs, rien de copié.

### Les personnages
- Proportions extrêmes : torse en V gigantesque, bras énormes, **jambes en allumettes**, petite tête sur un cou de taureau, **mâchoire carrée** démesurée.
- Expressions caricaturales : sourcils froncés, sourire éclatant qui brille, veines cartoon, gouttes de sueur énormes.
- Chaque stade change radicalement la silhouette : le joueur doit voir la différence de loin.
- Chaque boss a **un trait poussé à l'extrême** (le bronzage de Brayan, le mégaphone de Coach Turbo, les jambes de Pas-Les-Jambes).

### Les objets et décors
- Matériel absurde et bricolé : haltères faits de pastèques, banc de musculation dans un caddie, barre de squat avec des pneus de tracteur.
- Objets surdimensionnés et lisibles de loin.
- Low-poly, couleurs saturées, contrastes forts, formes simples.

### Les effets
- Moments de victoire et de passage de stade : ralentis, serviettes qui volent, éclairs, paillettes de sueur.
- Défaites comiques : rétrécissement, envol, rebonds cartoon.
- Courts (2–3 s) et quittables. Option de réduction des effets et des secousses.

### Ambiance : elle évolue de zone en zone (décision D27)

Chaque zone a sa propre ambiance, de plus en plus absurde. Palettes **proposées** (à valider) :

| Zone | Ambiance | Palette proposée |
|---|---|---|
| Garage de maman | Bric-à-brac, bricolé, poussiéreux | Brun, orange rouille, bleu délavé |
| La rue | Banlieue cartoon pastel | Rose, menthe, jaune pâle |
| La plage | Ville balnéaire ensoleillée | Turquoise, orange chaud, sable |
| La montagne | Années 80 rétro | Violet, rose néon, bleu électrique |
| La Lune | Science-fiction kitsch | Gris lunaire, bleu nuit, vert fluo |
| L'Olympe | Temple doré | Blanc marbre, or, bleu ciel |

**Constantes sur tout le jeu** : interface violet foncé + doré (déjà en place), personnages aux couleurs saturées pour se détacher de chaque décor.

### Technique des personnages (décision D28)

- Chaque personnage garde le **squelette R15 standard** de Roblox : toutes les animations Roblox fonctionnent sans travail en plus.
- Par-dessus, une **« coque » visuelle** modélisée dans Blender : une pièce 3D exagérée par partie du corps (torse énorme, jambes en allumettes, mâchoire carrée…), collée sur le squelette, comme les habits actuels.
- **Une coque par stade** (7 pour le joueur) et une par PNJ. Les habits et coupes se posent par-dessus.
- Pipeline : Blender → export FBX (`assets/export/`) → import dans Studio (un import par lot) → la coque est assemblée par le code.

### Animations (classement validé par Antoine le 26/10/2026, D83)

Les habitants, vendeurs et boss sont une seule pièce 3D, sans squelette : ils sont animés **en entier, par le code**
(`NpcController`, réglages dans `Config/NpcAnims.luau`), chez chaque joueur.

**Essentiel (fait, D83)**
1. Habitants et boss respirent, se balancent, se tournent vers le joueur proche ; un habitant dont l'aide est
   disponible sautille.
2. Attitude propre à chaque boss : Kevin s'affaisse dans son canapé puis se redresse, Brayan se tourne en prenant la
   pose avec des reflets, Coach Turbo sautille, Monsieur Pas-Les-Jambes vacille, le ventilateur du Roi souffle, le Dieu
   du Pump flotte avec un halo.
3. Réactions pendant une aide : inquiet au début, petit saut sur une réussite, tête basse sur un raté, grande fête
   (saut, tour sur lui-même, confettis) quand l'aide est réussie ; les autres joueurs le voient remercier.
4. Combat : le boss encaisse les Perfect et les Good (il s'incline en arrière), se moque des ratés et de la défaite du
   joueur ; vaincu, il s'envole (serveur).
5. Célébration du joueur : pose de victoire vue par tous après un boss battu ou une série notée S, caméra qui se
   rapproche.

**Important (fait, D84)** — `MotionController`, réglages dans `Config/Motion.luau` et `Balance.HudFx` :
6. Démarche selon le gabarit (stade) : torse bombé, épaules qui roulent, bras écartés, bassin qui se dandine, menton
   relevé ; elle s'ajoute à la marche de Roblox, de plus en plus marquée de Normie à Gigachad.
7. Attente : respiration lente et profonde (plus forte chez les gros gabarits) ; son personnage immobile depuis 12 s
   prend une pose de culturisme (vue par tous), puis toutes les 18 s.
8. Interface vivante : compteurs de Mog et de Cash qui défilent et rebondissent ; billets (aide) et muscles (série)
   qui s'envolent vers le compteur ; ouverture du coffre de la semaine (il tombe, tremble, éclate) ; « ! » des
   habitants qui flottent et s'agitent.
9. Pareur : il applaudit en rythme devant lui pendant toute la série.
Ajouts (D84) : poussière à chaque pas, à la couleur du sol, plus abondante avec le gabarit et en courant ; anneau de
poussière à l'atterrissage et petite secousse de sa caméra à partir d'Alpha ; traînée de vitesse en courant.

**Bonus (plus tard)** : vrais squelettes dans Blender (boss d'abord), ville animée (passants, voitures, oiseaux,
vent), nouvelles cinématiques, tenues animées et danses.

## Interface

- HUD : Mog et Cash sur une ligne en tactile ; le prochain objectif et Style restent accessibles dans Menu. Sur PC, la jauge vers le boss et l'objectif restent visibles. Rien de plus pendant l'exploration.
- Mini-jeux : une zone d'interaction claire, en bas de l'écran sur mobile, avec le résultat (Raté / Bien / Parfait) en gros et en couleur.
- Typographie grasse et exagérée, boutons arrondis et épais.
- Mobile d'abord : zones de pouce, pas de chevauchement avec les boutons Roblox.
- **Traduction** (voir 04_MONDE_PNJ.md) : aucun texte dans les images ou textures (il ne serait pas traduit) ; zones de texte prévues 30 % plus larges que l'anglais ; préférer des icônes aux mots quand c'est possible.

## Son

- D75 : chaque nouveau mini-jeu ajoute un son discret au contact, un impact bref à la réussite et le son de note
  confirmé par le serveur. Les sons existants de `Config/Sounds.luau` sont réutilisés avec des volumes réduits et une
  hauteur différente selon Good/Perfect ; ils restent réglables dans Settings. Les scènes montrent aussi le geste,
  un objet ou un indice propre à l'activité, puis un résultat cartoon immédiat.

- Bruitages cartoon exagérés : grognements d'effort, grincements, « BOING » de défaite.
- Le coach et les boss ont des cris signatures (volume réglable).
- ❓ Musique : thème « montage d'entraînement » parodique, variante par zone.

## Production des assets (Blender / IA)

- **Corps du personnage** : 7 modèles (un par stade) sur le même squelette compatible R15. Priorité absolue : ils font l'identité du jeu.
- Habits et coupes : modèles qui s'adaptent à tous les corps (accessoires ou vêtements en couches ❓ à valider techniquement).
- ~10 000 triangles max par objet, textures 1024×1024 max, export FBX dans `assets/export/`, 1 stud ≈ 0,28 m.
- **Décors (D35)** : 198 décors low poly PS1 générés par script (`tools/blender/props_*.py`, bibliothèque `props_lib.py`),
  une seule texture palette 512×512 partagée (`MogProps_Palette.png`). Export : `tools/blender/export_props.py` →
  `assets/export/props/Props_<Catégorie>.fbx` + planches `catalogue_*.png`. Catégories : rue, nature, salle,
  maison (dont les 21 meubles du magasin, `Furniture_<id>`), ville et arène, futures zones (plage, montagne, Lune,
  Olympe), kit de façade, événements et objets des boss.
- Intégration : les modèles importés vont dans `ServerStorage.Props` ; `PropService` les pose sur les emplacements
  de la carte (tag `PropSlot`, générés par `tools/build_map.py`) et retire les blocs provisoires ; les meubles
  achetés utilisent `Furniture_<id>`. Sans modèle importé, les blocs restent.

## Performance

Au moins 30 FPS sur l'appareil mobile de référence choisi pour les tests. Mesurer, ne pas promettre.
