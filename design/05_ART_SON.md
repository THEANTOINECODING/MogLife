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

## Interface

- HUD : Mog (avec jauge vers le prochain boss), Cash, prochain objectif, bouton Style. Rien de plus.
- Mini-jeux : une zone d'interaction claire, en bas de l'écran sur mobile, avec le résultat (Raté / Bien / Parfait) en gros et en couleur.
- Typographie grasse et exagérée, boutons arrondis et épais.
- Mobile d'abord : zones de pouce, pas de chevauchement avec les boutons Roblox.
- **Traduction** (voir 04_MONDE_PNJ.md) : aucun texte dans les images ou textures (il ne serait pas traduit) ; zones de texte prévues 30 % plus larges que l'anglais ; préférer des icônes aux mots quand c'est possible.

## Son

- Bruitages cartoon exagérés : grognements d'effort, grincements, « BOING » de défaite.
- Le coach et les boss ont des cris signatures (volume réglable).
- ❓ Musique : thème « montage d'entraînement » parodique, variante par zone.

## Production des assets (Blender / IA)

- **Corps du personnage** : 7 modèles (un par stade) sur le même squelette compatible R15. Priorité absolue : ils font l'identité du jeu.
- Habits et coupes : modèles qui s'adaptent à tous les corps (accessoires ou vêtements en couches ❓ à valider techniquement).
- ~10 000 triangles max par objet, textures 1024×1024 max, export FBX dans `assets/export/`, 1 stud ≈ 0,28 m.

## Performance

Au moins 30 FPS sur l'appareil mobile de référence choisi pour les tests. Mesurer, ne pas promettre.
