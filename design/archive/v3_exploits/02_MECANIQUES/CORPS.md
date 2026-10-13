# Corps et transformation

La transformation est la récompense la plus visible du jeu : elle doit se voir **dès les premières minutes**.

## Règles

- Progression continue à l'intérieur de chaque rang ; changements marquants à chaque passage de rang (posture, épaules, silhouette, animation de marche).
- Taille plafonnée : aucun avatar ne cache l'écran des autres ou ne bloque une porte.
- La taille ne donne **aucun avantage** en duel de Mog.
- Collisions et déplacements fonctionnent à toutes les tailles (portes, caméra, véhicules).
- On garde les choix d'apparence du joueur quand le rig le permet.
- Toute transformation est réversible visuellement et testée sur les rigs pris en charge (R15 d'abord).

## Lien avec les exploits

- Les animations d'exploit changent avec le rang : un Normie lutte, un Chad soulève avec désinvolture (voir la surpuissance dans EXPLOITS.md).
- ❓ Effets de corps réservés aux rangs hauts : ombre plus large, sol qui tremble légèrement à chaque pas (désactivable).

## Point technique connu

Dans le code actuel, le corps atteint sa taille maximale à 1 000 000 de Force, alors que Gigachad est à 12 000 dans ce design. Il faudra caler l'échelle sur les rangs (étape A de la roadmap).
