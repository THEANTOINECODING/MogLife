# Prompts de dessin des personnages

À coller dans le générateur d'images de ChatGPT. Les prompts sont en anglais : les générateurs d'images les suivent mieux.
Ranger les images obtenues dans `assets/concepts/` (ex. `assets/concepts/kevin_2d.png`, `kevin_3d.png`).

## Le style visé (décision du créateur, 14/10/2026)

Burlesque et ridicule, **simple** : dessin vectoriel plat, contours épais, aplats de couleur avec une seule ombre, formes simples, peu de détails.
L'humour vient des **proportions** et des **expressions**, pas des détails (pas de peau réaliste, pas de textures chargées).
Esprit des jeux comiques Flash des années 2010 — sans copier aucun jeu existant (règle 6 du projet).

## Méthode : deux images par personnage

1. **Dessin 2D** (prompt « 2D ») : c'est la référence de style, à valider.
2. **Version 3D simple** (prompt « 3D », envoyé dans la même conversation juste après) : le même personnage en modèle 3D lisse aux couleurs plates. C'est cette image que l'on convertit en 3D avec Meshy / Tripo.
3. Si besoin, **planche de vues** (face, profil, dos) de la version 3D.

## Bloc de style 2D (identique dans tous les prompts 2D)

> Art style: flat 2D vector cartoon, like a 2010s Flash comedy game. Clean thick dark outlines, flat colors with only one simple darker shade for shadows, no gradients, no textures, no realistic skin, simple geometric shapes, minimal details. Slightly muted, desaturated colors. Caricatural, burlesque and ridiculous: the humor comes from the exaggerated proportions and the facial expression, not from details. Ugly and pathetic but funny, not cute, not childish, not chibi, not anime, not realistic.

## Bloc de style 3D (identique dans tous les prompts 3D)

> Turn exactly this character into a simple stylized 3D game character model, faithful to the 2D design: same proportions, same face, same expression, same clothes, same colors. Smooth simple 3D shapes, flat matte colors, very little texture detail, no realistic skin, no fine wrinkles, no hair strands (hair as simple solid chunks), soft even lighting. Looks like a toy-like 3D figure of the flat cartoon, not a realistic sculpture.

---

## Kevin « I'll Start Tomorrow » — premier boss

### 2D

```text
Full-body character design of Kevin, the first boss of a comedy gym game: a lazy, pathetic teenage couch potato.

Body: very tall and ridiculously skinny, like a stick figure with skin. Long thin neck, narrow chest where you can see a few ribs drawn as simple lines, slouching shoulders, small soft round belly. Arms and legs as thin as broomsticks, with knobbly knees and elbows.

Face: long droopy face with a big potato-shaped nose. Half-closed, bored, droopy eyes with tired bags drawn as simple lines. Mouth slightly open with two big buck teeth. A few red dots on the forehead, nose and chin for pimples, and a few stubble dots on the chin. Messy, greasy dark hair drawn as a few simple spiky chunks. Smug, lazy, pathetic expression.

Clothes: oversized, wrinkled light blue pajamas with simple vertical stripes, a big ketchup stain on the shirt, one button missing. Fuzzy bunny slippers. He holds a game controller in one hand.

Pose: standing, facing the camera, arms slightly away from the body, full body visible including the feet.

Art style: flat 2D vector cartoon, like a 2010s Flash comedy game. Clean thick dark outlines, flat colors with only one simple darker shade for shadows, no gradients, no textures, no realistic skin, simple geometric shapes, minimal details. Slightly muted, desaturated colors. Caricatural, burlesque and ridiculous: the humor comes from the exaggerated proportions and the facial expression, not from details. Ugly and pathetic but funny, not cute, not childish, not chibi, not anime, not realistic.

Composition: one single character, full body, centered, plain white background, no text, no logo, no frame.
```

### 3D (à envoyer juste après, dans la même conversation)

```text
Turn exactly this character into a simple stylized 3D game character model, faithful to the 2D design: same proportions, same face, same expression, same clothes, same colors. Smooth simple 3D shapes, flat matte colors, very little texture detail, no realistic skin, no fine wrinkles, no hair strands (hair as simple solid chunks), soft even lighting. Looks like a toy-like 3D figure of the flat cartoon, not a realistic sculpture.

Pose: standing, facing the camera, arms held slightly away from the body (A-pose), feet slightly apart, full body visible including the feet.

Composition: one single character, centered, front view, plain white background, no shadow on the ground, no text.
```

---

## Le GOD MOGGER — boss final

### 2D

```text
Full-body character design of the God Mogger, the final boss of a comedy gym game: a man with SO much muscle that he is not even humanly possible anymore. Pure absurd overkill.

Body: an impossible, ridiculous mountain of muscles, muscles stacked on top of muscles. His upper body is a gigantic round blob of muscle, about four times wider than a normal man. Huge boulder-shaped chest. Biceps much bigger than his own head, each arm as big as a whole person, so heavy that his arms cannot even touch his sides. Neck and shoulder muscles (traps) so enormous that they swallow his head: only his face pokes out from the top of the muscle mountain. Thick veins drawn as simple lines. Ridiculously tiny, thin, short legs under this colossal mass, like two small sticks that look about to break.

Face: a tiny face completely dominated by a GIGANTIC square jaw, as big as a brick wall, jutting far forward, with a deep cleft chin. Tiny dot eyes very close together, smug raised eyebrows, arrogant self-satisfied smirk with shiny white teeth. Slicked-back hair drawn as one simple shape with a perfect curl. Absurd orange-bronze tan.

Clothes: tiny white wrestling shorts, a golden laurel crown, a big golden champion belt.

Pose: standing, facing the camera, arms held away from the body because his muscles are too big, chest pushed out, full body visible including the tiny feet.

Art style: flat 2D vector cartoon, like a 2010s Flash comedy game. Clean thick dark outlines, flat colors with only one simple darker shade for shadows, no gradients, no textures, no realistic skin, simple geometric shapes, minimal details. Slightly muted, desaturated colors. Caricatural, burlesque and ridiculous: the humor comes from the exaggerated proportions and the facial expression, not from details. Ugly and pathetic but funny, not cute, not childish, not chibi, not anime, not realistic.

Composition: one single character, full body, centered, plain white background, no text, no logo, no frame.
```

### 3D (à envoyer juste après, dans la même conversation)

```text
Turn exactly this character into a simple stylized 3D game character model, faithful to the 2D design: same impossible muscle proportions, same gigantic jaw, same tiny legs, same face, same clothes, same colors. Smooth simple 3D shapes, flat matte colors, very little texture detail, no realistic skin, no fine wrinkles, no hair strands (hair as simple solid chunks), soft even lighting. Looks like a toy-like 3D figure of the flat cartoon, not a realistic sculpture.

Pose: standing, facing the camera, arms held away from the body (wide A-pose), full body visible including the tiny feet.

Composition: one single character, centered, front view, plain white background, no shadow on the ground, no text.
```

---

## Planche de vues (optionnel, après une version 3D validée)

```text
Using exactly the same 3D character as in the previous image (same proportions, face, clothes, colors and style), create a turnaround sheet: three full-body views side by side at the same height and scale: front view, side view (left profile) and back view. Same neutral pose in all three views. Plain white background, no shadows, no text, no labels.
```

## Si le résultat ne convient pas

- **Trop réaliste / trop détaillé** : « Simpler: flat colors, thick outlines, fewer details, no realistic skin, like a simple Flash cartoon ».
- **Trop mignon** : « Uglier and more pathetic, more caricatural, less cute ».
- **Pas assez exagéré** : « Push the proportions much further: [la partie] twice as big ».
- **Pieds coupés ou décentré** : « Full body including the feet, centered, with white space around ».
- **Refus de ChatGPT** : retirer le mot qui pose problème et garder le reste.
