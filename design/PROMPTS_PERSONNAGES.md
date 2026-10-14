# Prompts de dessin des personnages

À coller dans le générateur d'images de ChatGPT. Les prompts sont en anglais : les générateurs d'images les suivent mieux.
Ranger les images obtenues dans `assets/concepts/` (ex. `assets/concepts/kevin_front.png`).

## Méthode

1. **Image de face** avec le prompt principal du personnage. Régénérer jusqu'à obtenir le bon style.
2. **Planche de vues** (face, profil, dos) avec le prompt « turnaround » : elle aide Meshy / Tripo à reconstruire le dos et les côtés.
3. Vérifier avant la 3D : corps entier visible (pieds compris), fond uni, un seul personnage, pas de texte, pas d'ombre au sol.

## Bloc de style commun (déjà inclus dans chaque prompt)

Ce paragraphe est identique dans tous les prompts, pour que tous les personnages du jeu aient le même style :

> Art style: grotesque satirical 3D caricature, like a hand-sculpted latex puppet or a clay caricature figurine from a satirical comedy show. Hyper-exaggerated proportions pushed to the extreme. Detailed, slightly realistic skin with pores, blemishes, oily shine and subsurface scattering. Ugly, burlesque and unlikable, but funny. NOT cute, NOT chibi, NOT Pixar, NOT anime, NOT a children's cartoon, NOT a toy. Soft neutral studio lighting, high detail.

## Kevin « I'll Start Tomorrow » — premier boss

```text
Full-body character design of "Kevin", a lazy, smug teenage couch potato who is the first boss of a comedy gym game.

Body: extremely tall and skeletally thin, like a human noodle. Long scrawny neck with a huge pointy Adam's apple. Narrow sunken chest, rounded shoulders, hunched slouching posture with his head pushed forward like a vulture. Arms like thin sticks with knobbly elbows and long bony fingers. Legs like two drinking straws with bony knees. Small soft pot belly sticking out from the bony frame.

Head and face: big bulbous head on the thin neck. Huge red bulbous nose. Greasy, stringy, unwashed black hair plastered on his forehead with a few strands sticking up. Face covered in many large angry red pimples and whiteheads, especially on the forehead, nose and chin, plus a few on the neck. Pale, oily, greenish-white skin that has not seen the sun. Heavy dark bags under half-closed, bored, smug eyes. Big buck teeth with a gap, mouth hanging slightly open as if breathing through the mouth. Patchy, wispy teenage mustache. Smug, condescending, lazy expression.

Clothes: wrinkled, oversized, faded blue striped pajamas covered with crumbs, a ketchup stain and a coffee stain, pajama top half-buttoned and misaligned, one pajama leg rolled up. Worn-out fuzzy slippers shaped like sad bunnies. He holds a video game controller in one hand and a half-eaten slice of pizza in the other.

Pose: standing straight on both feet, facing the camera, arms held slightly away from the body (relaxed A-pose) so the whole silhouette is clearly readable, feet slightly apart.

Art style: grotesque satirical 3D caricature, like a hand-sculpted latex puppet or a clay caricature figurine from a satirical comedy show. Hyper-exaggerated proportions pushed to the extreme. Detailed, slightly realistic skin with pores, blemishes, oily shine and subsurface scattering. Ugly, burlesque and unlikable, but funny. NOT cute, NOT chibi, NOT Pixar, NOT anime, NOT a children's cartoon, NOT a toy. Soft neutral studio lighting, high detail.

Composition: one single character, full body from head to feet, centered, front view, plain pure white background, no floor shadow, no text, no logo, no frame.
```

## Le GOD MOGGER (Le Dieu du Pump) — boss final

```text
Full-body character design of "The God Mogger", the final boss of a comedy gym game: the most absurdly overmuscled, arrogant man in the universe.

Body: colossal and ridiculously wide, a literal mountain of muscle. His torso is about three times wider than his hips. Gigantic swollen shoulders and trapezius muscles that rise up to the top of his ears, so his tiny head seems to sink between them. Huge inflated chest like two boulders. Enormous arms, each one thicker than his whole torso should be, with bulging biceps the size of watermelons and thick visible veins. Exaggerated eight-pack abs. In total contrast, two comically tiny, skinny short legs that look like they could snap under the weight, and small feet.

Head and face: a tiny head on top of the muscle mountain, completely dominated by a GIGANTIC square jaw, like an anvil or a brick, at least twice as wide as the rest of his head and jutting far forward, with a deep cleft chin. Tiny, beady, arrogant eyes set very close together, thin smug eyebrows raised. Sleek slicked-back hair with one perfect curl. A smug, self-satisfied smirk showing perfectly white teeth that shine. Skin: absurd deep bronze spray tan, very oily and glossy as if covered in baby oil, with a few drops of sweat.

Clothes and accessories: a golden laurel wreath on his head, a huge shiny golden championship belt around the waist, and tight white wrestling shorts. Golden wrist bands. Nothing else.

Pose: standing on both tiny feet, facing the camera, chest pushed out, arms held away from the body in a slightly raised position showing off his enormous arms (wide A-pose), so the whole silhouette is clearly readable.

Art style: grotesque satirical 3D caricature, like a hand-sculpted latex puppet or a clay caricature figurine from a satirical comedy show. Hyper-exaggerated proportions pushed to the extreme. Detailed, slightly realistic skin with pores, blemishes, oily shine and subsurface scattering. Ugly, burlesque and unlikable, but funny. NOT cute, NOT chibi, NOT Pixar, NOT anime, NOT a children's cartoon, NOT a toy. Soft neutral studio lighting, high detail.

Composition: one single character, full body from head to feet, centered, front view, plain pure white background, no floor shadow, no text, no logo, no frame.
```

## Planche de vues (à envoyer juste après une image validée)

```text
Using exactly the same character as in the previous image (same face, same body proportions, same clothes, same colors, same art style), create a character turnaround sheet for 3D modeling: three full-body views side by side, aligned at the same height and the same scale: front view, side view (left profile) and back view. Same neutral pose in all three views. Plain pure white background, no shadows, no text, no labels.
```

## Si le résultat ne convient pas

- **Trop mignon / trop cartoon** : répondre « Make him uglier and more grotesque, more like a satirical latex puppet, more realistic skin, less cartoon ».
- **Pas assez exagéré** : « Push the proportions much further: [la partie à exagérer] twice as big ».
- **Pieds coupés ou personnage décentré** : « Show the full body including the feet, centered, with white space around ».
- **Refus de ChatGPT** : retirer le mot qui pose problème (souvent ce qui concerne le corps ou la peau) et garder le reste.
