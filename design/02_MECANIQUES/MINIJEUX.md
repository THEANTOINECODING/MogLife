# Mini-jeux (mécanique principale)

> **D81 : cette fiche fait foi** pour les 20 mini-jeux (entraînements, aides, boss, duel). Retour aux jeux faits
> ensemble avant Codex (D80), puis amélioration de chacun (D81) : simples à comprendre, satisfaisants, avec du
> challenge, pensés d'abord pour le téléphone (environ 80 % des joueurs Roblox sont sur iPhone, d'après Antoine).
> La refonte de Codex (D76 à D79) est archivée dans `design/archive/PLAYGROUND_codex_abandonne.md`.

**Chaque activité a son propre mini-jeu** (D23) : aucun mini-jeu n'est réutilisé ailleurs, sauf `Combo`, prêté au
Dieu du Pump en attendant son vrai combat (voir `IDEES.md`). Tous sont construits sur `src/client/MinigameKit.luau`.

## Règles communes (D81)

**Simple à comprendre**
- **Un seul geste par jeu** : toucher, maintenir/relâcher, glisser dans une direction, glisser-déplacer, ou toucher
  à gauche/à droite. Une seule chose à regarder.
- **Consigne d'une phrase** affichée en grand au départ, puis gardée dans la colonne (`Minigame.Hint.<Jeu>`).
- **Main fantôme** : les deux premières parties de chaque mini-jeu (par session), une main montre le geste et
  appuie au bon moment ; elle disparaît à la première réussite (au plus tard après 3 répétitions).
- **Nouveauté annoncée** : la première fois qu'une surprise arrive dans une partie, un bandeau l'explique
  (« Red ring: don't tap! »).

**Pensé pour le téléphone**
- On joue **n'importe où sur l'écran**, d'un pouce, sans petit bouton à viser (sauf Stop). Le pouce ne cache jamais
  l'action : les objets déplacés suivent le **déplacement** du doigt (comme un pavé tactile), pas sa position.
- Gauche/droite = **à gauche ou à droite du milieu du panneau de jeu** (un pouce de chaque côté ; D82 : avant, c'était
  le milieu de l'écran, et la piste de gauche du Coach, à droite de l'écran, comptait pour « droite »).
- **Le personnage bouge au moment du geste** (D82) : son propre personnage fait la répétition dès le geste, sans
  attendre le serveur (le saut à la corde part à l'appui). Aux transats, seule une répétition réussie pose un transat
  sur la pile ; un raté glisse et tombe à côté.
- Clavier, souris et manette donnent exactement les mêmes gestes (Espace / bouton A, flèches, ZQSD/WASD, stick,
  gâchettes).
- **Vibration** à chaque répétition sur téléphone (`HapticEffect`) et manette ; coupable dans les réglages
  (« Vibration »).

**Satisfaisant**
- Chaque geste a un retour immédiat : éclat à l'endroit du geste (étincelles dorées sur un Perfect), vibration,
  petit tremblement sur un raté, son qui monte avec le combo, gain qui s'envole.
- Combo visible (x1,2, x1,5, x2) ; au maximum, « ON FIRE » et les bords de l'écran rougeoient.
- Fin de série : note S/A/B/C qui tombe avec un rebond, étoiles, record personnel.

**Challenge**
- Les fenêtres de notation se resserrent de 30 % au fil de la série (`Balance.Minigames.SeriesTightening`, D80).
- **Niveau** envoyé par le serveur : entraînements et aides = stades du joueur au-dessus du stade de déblocage ;
  boss et duel = manche − 1. Chaque niveau débloque des **surprises** propres au jeu (tableau ci-dessous).
- Une répétition ratée ne rapporte que 25 % du Mog (`Balance.Quality.Miss`), casse le combo et, dans les jeux de
  rythme, **ne rien faire est un raté** dès que la partie a commencé (et toujours en combat de boss).
- **Ne rien faire ne rapporte jamais** : les zones « à ne pas toucher » ne paient que si l'on joue.

## Exercices (6)

| Exercice | Module | Geste | Surprises (niveau) | Mog/rép ❓ |
|---|---|---|---|---:|
| Curl de pastèque | `Swipe` | La pastèque retombe vers les mains dorées : glisser vers le haut quand elle arrive dans les mains pour la relancer (comme jongler ; D87, l'ancien anneau était difficile à comprendre). Ratée : elle s'écrase et ne fait qu'un petit rebond | Lancers lents « tortue », plus hauts (1) | 1 |
| Pompes | `Ring` | Toucher quand l'anneau touche le cercle | Anneau double : deux appuis (1) ; anneau rouge : ne pas toucher (2) | 2 |
| Développé couché | `HoldRelease` | Maintenir pour pousser, relâcher dans la zone verte (qui change de place) | La zone bouge pendant qu'on pousse (2) | 4 |
| Squat | `Tilt` | Glisser vers le bas jusqu'à la ligne, lever le doigt pour remonter | Squat avec pause en bas (1) | 8 |
| Tractions | `Alternate` | Toucher le côté de la main allumée, sur le temps | Les deux mains ensemble (1) ; rythme irrégulier (2) | 14 |
| Corde à sauter | `Rope` | Toucher pour sauter quand la corde passe sous les pieds | Tours rapides (1) ; fausses accélérations (2) | 24 |

Au développé couché, la barre tremble au-dessus de la zone et retombe tout en haut (raté). La zone dessinée est
exactement la zone notée.

## Aides (8)

| Aide | Module | Geste | Surprises (niveau) |
|---|---|---|---|
| Bocal de maman | `Twist` | Refait en D87 (l'ancien était long et peu intuitif) : le couvercle vu de dessus ; tourner le doigt autour de lui dans le sens des flèches pour le dévisser, il tourne sous le doigt avec des clics. Un quart de tour = une répétition (vite = Perfect). 4 quarts par bocal, puis POP : le couvercle s'envole, les cornichons jaillissent, maman fait la fête. Une main fantôme montre le geste. 8 répétitions (au lieu de 12) | Couvercle dur : il faut tourner plus loin (2) |
| Pneu du coursier | `Pressure` | **Pompe à vélo** (D82) : glisser vers le bas pour pomper (grand coup = beaucoup d'air), s'arrêter dans la zone verte (tirée au sort à chaque pneu) ; trop d'air, il éclate. Dans le vert sans pomper un instant : le coursier repart | Chaque pneu prend l'air différemment (1) ; fuite plus forte et zone plus étroite (2) |
| Clous du petit voisin | `Hammer` | Toucher quand le marteau est au-dessus du clou | Clou tordu : deux coups (1) ; pouce du petit voisin à ne pas taper (2) |
| Voiture du voisin | `Steer` | Glisser pour rester sur la route et éviter poubelle, chat, flaque. D82 : route plus large, virages plus doux, bordures, décor, fumée, mains qui poussent ; esquiver n'est pas une faute | Virages plus serrés et obstacles plus fréquents à chaque niveau |
| Piano de Mme Do-Ré | `Lanes` | Glisser à gauche/à droite vers la voie libre | Vagues plus rapides à chaque niveau ; vagues doubles (1) |
| Transats du maître-nageur | `Stack` | Toucher pour lâcher le transat : ce qui dépasse tombe, le suivant est plus étroit | Transat plus rapide à chaque niveau |
| Courses de l'épicier | `Catch` | Glisser le panier pour attraper les courses | Objets à ne pas attraper (1) ; fruits qui rebondissent (2) |
| Chemin du touriste | `Sequence` | Retenir le chemin tracé sur le plan (6 × 6), le refaire en glissant | Chemin de 5 pas dès le départ (D82), puis 6, puis 7 |

## Boss (5 dans le MVP)

| Boss | Module | Geste | Surprises (manche) |
|---|---|---|---|
| Kevin | `Reaction` | Glisser dans le sens de son bras, le plus vite possible (trop tôt = raté) ; un cercle montre le temps qui reste, Kevin encaisse quand on réussit (D82) | Manche 1 : gauche/droite ; manche 2 : 4 directions ; manche 3 : feintes |
| Brayan le Bronzé | `Spotlight` | Garder sa crème dans le soleil, qui saute (sa prochaine place est annoncée) | Nuages qui cachent le soleil (2) |
| Coach Turbo | `Beats` | Toucher le côté de la note quand elle touche la ligne ; panneau large en bas de l'écran, un pouce par piste, le joueur et le coach visibles au-dessus (D82) | Notes longues à maintenir (2) ; notes plus rapides à chaque manche |
| Monsieur Pas-Les-Jambes | `Wobble` | Glisser vers son poing au moment du choc pour le bloquer (D82 : poing plus lent, fenêtre plus large, boss un peu moins fort) | Coups d'en haut (2) ; deux poings à la suite (3) |
| Le Roi du Quartier | `Combo` | Glisser la combinaison de flèches avant que le ventilateur l'efface (D82 : plus de temps, boss un peu moins fort) | 5 flèches (3) |
| Le Dieu du Pump | `Combo` (provisoire) | — | ❓ vrai combat à concevoir plus tard (`IDEES.md`) |

Chaque manche est aussi plus rapide et plus serrée (`Balance.Boss.SpeedByRound`, `TimingScaleByRound`).

## Duel entre joueurs (D68)

| Activité | Module | Geste |
|---|---|---|
| Bras de fer | `Gauge` | Toucher quand l'aiguille est dans la zone verte (doré = pleine puissance). **Dernier effort** (D81) : le dernier balayage de chaque manche a 3 petites zones à toucher à la suite (3 = Perfect, 2 = Good). Même motif pour les deux joueurs. |

## Réglages

Tous les chiffres sont dans `Config/Balance.luau` (`Minigames.<Module>`) et `Config/Duels.luau` (`LastEffort`) :
vitesses, tailles de zones, chances et niveaux d'apparition des surprises. Ce sont des valeurs de départ ❓ à
régler en jouant, surtout sur téléphone.

## Ajouter un mini-jeu

1. Un module dans `src/client/Minigames/` basé sur `MinigameKit` (`new(parent, interval, onRep, options)`,
   `Destroy`). Utiliser les gestes du kit (`OnPress`, `OnRelease`, `OnSwipe`, `OnSide`, `TrackDrag`, `OnAction`),
   `Rep(quality, endroit)` pour noter (il respecte la cadence du serveur), `RepReady()` pour les jeux au rythme du
   joueur, `Guide` / `GuideCue` pour la main fantôme, `Announce` pour une surprise.
2. Une clé `Minigame.Hint.<Nom>` (et `Minigame.Twist.<Nom>.<Surprise>`) dans `Texts.luau`.
3. Ses réglages dans `Balance.Minigames.<Nom>`.
4. Le référencer dans `Exercises.luau`, `Helps.luau` ou `Stages.luau`.

## Sécurité

Le client envoie la qualité de chaque répétition ; le serveur vérifie le quota de rythme, la distance, le
déblocage, et calcule lui-même les gains. Limite connue : un tricheur peut s'attribuer des Perfect (x1,6 au maximum,
et en combat il reste borné par le rythme).

## Tests

Tous faits dans Studio réduit (affichage en pause), sans toucher aux données (`Kit.StepSignal` remplace l'affichage,
`Kit.Input` remplace l'écran par de faux gestes) :
- **Sans rien faire** (niveaux 0, 1 et 2, 12 s) : aucun des 20 jeux ne donne de Good ni de Perfect, aucune erreur.
- **Robot qui joue bien** (`tests/minigames_bot.luau`, niveau 2, toutes les surprises, 22 s, en passant par les vrais
  gestes : appuis, glissés, glisser-déplacer, touches) : 19 jeux sans aucun raté ou presque ; Brayan 1 raté sur 14 (le
  soleil saute) ; voiture 0 à 1 raté sur 14 après correction.
- **Robot qui tape au hasard** : il rate la grande majorité des répétitions. Les plus « généreux » restent le piano
  (environ 40 % de réussites : 3 voies, on finit parfois dans la bonne) et les transats (environ 30 %).
- **Parcours complet par le serveur** : série de squats (niveau reçu, consigne, cadre ON FIRE), aide des transats,
  duel contre le mannequin (2 manches) et combat contre Kevin jusqu'au résultat, sans erreur.
- **Pas encore fait** : jouer au doigt dans Studio au premier plan, puis sur un vrai iPhone (lisibilité, confort du
  pouce, vibration, difficulté ressentie, réglage des valeurs ❓).
