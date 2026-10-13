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

### Palette ❓

| Usage | Couleur |
|---|---|
| Principale | ❓ |
| Secondaire | ❓ |
| Accent (boutons, récompenses) | ❓ |

## Interface

- HUD : Mog (avec jauge vers le prochain boss), Cash, prochain objectif, bouton Style. Rien de plus.
- Mini-jeux : une zone d'interaction claire, en bas de l'écran sur mobile, avec le résultat (Raté / Bien / Parfait) en gros et en couleur.
- Typographie grasse et exagérée, boutons arrondis et épais.
- Mobile d'abord : zones de pouce, pas de chevauchement avec les boutons Roblox.

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
