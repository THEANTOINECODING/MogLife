# Mini-jeux (mécanique principale)

**Chaque activité a son PROPRE mini-jeu** : chaque exercice, chaque aide et chaque boss se joue différemment, et aucun mini-jeu n'est réutilisé ailleurs (décision D23).
Pour rester simple à produire, tous les mini-jeux partagent une boîte à outils commune (`src/client/MinigameKit.luau` : entrées, notation, mode auto, nettoyage).

## Règles communes

- **Une seule entrée simple** à la fois : un doigt sur mobile, souris ou clavier sur PC, équivalent manette. Jamais de multitouch obligatoire ni de clics frénétiques.
- Chaque répétition est notée **Raté / Bien / Parfait**.
- Le serveur applique un **quota de rythme** : jamais plus de répétitions que le temps écoulé ne le permet (+1 d'avance). Jouer plus vite ne rapporte rien de plus.
- **Mode auto** gratuit (maintenir un bouton) pour les exercices et les aides : gain de base, sans bonus. Interdit en combat de boss.
- Option d'accessibilité : fenêtres de timing plus larges (à faire).

## Gain de Mog (exercices)

Mog gagné = Mog de base de l'exercice × multiplicateur de qualité (Raté x1, Bien x1,25, Parfait x1,6).

## Exercices (6)

| Exercice | Mini-jeu | Mécanique | Mog/rép ❓ | Débloqué par |
|---|---|---|---:|---|
| Curl haltère | Swipe | Suivre la pastèque fantôme de haut en bas | 1 | Départ |
| Pompes | Ring | Taper quand l'anneau touche le cercle | 2 | Kevin |
| Développé couché | HoldRelease | Maintenir, relâcher dans la zone verte | 4 | Brayan |
| Squat | Tilt | Garder la barre droite (gauche / droite) | 8 | Coach Turbo |
| Tractions | Alternate | Une main puis l'autre, sur la pulsation | 14 | Monsieur Pas-Les-Jambes |
| Corde à sauter | Rope | Sauter quand la corde passe, vitesse variable | 24 | Le Roi du Quartier |

## Aides (8)

| Aide | Mini-jeu | Mécanique |
|---|---|---|
| Bocal de maman | Twist | Dévisser en tournant, un tour par pulsation |
| Pneu du livreur | Pressure | Pomper pour garder l'aiguille dans le vert (le pneu fuit) |
| Clous du petit voisin | Hammer | Taper quand le marteau est au-dessus du clou |
| Voiture du voisin | Steer | Garder la voiture sur une route qui serpente |
| Piano de Mme Do-Ré | Lanes | Chaque vague bloque 2 voies sur 3 : rejoindre la voie libre |
| Transats du maître-nageur | Stack | Lâcher chaque transat pile sur la pile |
| Courses de l'épicier | Catch | Rattraper les courses avec le panier |
| Chemin du touriste | Sequence | Mémoriser 3 flèches puis les refaire |

## Boss (5 dans le MVP)

| Boss | Mini-jeu | Mécanique |
|---|---|---|
| Kevin | Reaction | Copier sa pose (flèche) le plus vite possible |
| Brayan le Bronzé | Spotlight | Rester dans le soleil qui se déplace |
| Coach Turbo | Beats | Notes sur 2 pistes, au rythme du mégaphone |
| Monsieur Pas-Les-Jambes | Wobble | Équilibre en 2D : ramener la bille au centre |
| Le Roi du Quartier | Combo | Taper un combo de 4 flèches avant que son ventilateur l'efface |
| Le Dieu du Pump | ❓ à créer | (mise à jour Olympe) |

## Duel entre joueurs (D68)

| Activité | Mini-jeu | Mécanique |
|---|---|---|
| Bras de fer | Gauge | L'aiguille balaie la jauge de force : appuyer quand elle est dans la zone verte, qui change de place à chaque balayage ; mêmes zones pour les deux joueurs |

## Ajouter un mini-jeu

1. Un module dans `src/client/Minigames/` basé sur `MinigameKit` (`new`, `SetAuto`, `Destroy`).
2. Une clé `Minigame.Hint.<Nom>` dans `Texts.luau`.
3. Le référencer dans `Exercises.luau`, `Helps.luau` ou `Stages.luau`.

## Sécurité

Le client envoie la qualité de chaque répétition ; le serveur vérifie le quota de rythme, la distance, le déblocage, et calcule lui-même les gains. Limite connue : un tricheur peut s'attribuer des Parfait (x1,6 au maximum, et en combat il reste borné par le rythme).
