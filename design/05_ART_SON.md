# 05 — Art, interface et son

## Direction

- Comédie cartoon lisible, **low-poly**, couleurs saturées, contrastes forts.
- Ville de quartier chaleureuse, matériel volontairement bricolé (haltères dépareillés, barre avec des pneus).
- Objets d'exploit **surdimensionnés et reconnaissables de loin** : on doit comprendre ce qu'on peut soulever d'un coup d'œil.
- Pas de réalisme anatomique.
- ❓ Ambiance générale : années 80 ? ville balnéaire ensoleillée ? néons ?

## Palette ❓

| Usage | Couleur |
|---|---|
| Principale | ❓ |
| Secondaire | ❓ |
| Accent (boutons, récompenses) | ❓ |
| Objets d'exploit possibles | ❓ (couleur de surbrillance) |
| Objets d'exploit impossibles | ❓ |

## Interface

- HUD principal : Force, Cash, **prochain exploit**, bouton Mog/collection. Rien de plus à l'écran.
- Sur un objet d'exploit : Poids et Force requise, indication possible / impossible.
- Feedback de répétition : animation fluide, son bref, gain discret. Pas de pluie permanente de chiffres.
- Passage de rang et exploit d'histoire : effet plus fort mais court.
- Police grasse et lisible ; gros boutons arrondis ; **mobile d'abord** (zones de pouce, pas de chevauchement avec les boutons Roblox).
- Options : réduction des effets et des secousses.

## Son

- Sons d'effort comiques, grincements de matériel, cris d'encouragement du coach (volume indépendant).
- ❓ Musique : thème « montage d'entraînement » parodique ?

## Règles techniques pour les assets (Blender / IA)

- Low-poly, surfaces planes, couleurs unies plutôt que textures détaillées.
- ~10 000 triangles max par objet ; textures 1024×1024 max.
- Export FBX dans `assets/export/`, 1 stud ≈ 0,28 m, pivot à la base.

## Performance

Au moins 30 FPS sur l'appareil mobile de référence choisi pour les tests, avec joueurs et effets. Mesurer, ne pas promettre.
