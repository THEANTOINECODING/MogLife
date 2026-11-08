# Recherche : les menus et le HUD qui marchent sur Roblox — 9 novembre 2026

Demande d'Antoine : le menu du jeu ne lui plaît pas. Il faut se renseigner à fond sur les menus qui marchent, analyser
ceux des jeux les plus joués et refaire le nôtre dans le même style.

Méthode :
- captures d'écran réelles de l'interface en jeu, examinées une par une, morceau par morceau ;
- guides officiels de Roblox ;
- analyses de jeux mobiles (Clash Royale) ;
- conseils de designers d'interface sur le DevForum.

Ce qui est observé sur une capture est marqué 👁 ; ce qui vient d'un texte est marqué 📄.

## Jeux observés

| Jeu | Rang (8/11/2026) | Ce qu'on voit à l'écran |
|---|---|---|
| **Steal an Egg** | 1er (≈ 1 M de joueurs) | 👁 Au milieu du bord gauche, 2 gros boutons rectangulaires (vert « Shop », bleu « Index »), chacun avec une icône blanche et un mot. L'argent est en bas à gauche, en très gros chiffres verts cernés de noir, sans cadre, avec une petite icône « + ». À droite, de petits boutons carrés pour le secondaire. Très simple, très lisible. |
| **Steal a Brainrot** | record de 25 M | 👁 Une colonne de cases carrées au milieu du bord gauche (Shop, Rebirth, Index) : fond ardoise, icône colorée, nom en blanc gras sous l'icône. 📄 Les guides confirment : Shop, Rebirth, Index, Codes, de haut en bas. |
| **Gym League** (concurrent direct) | — | 👁 Une colonne de grandes cases au bord gauche : SHOP (vert), AURA (bleu), STAT (orange), CUSTOM (violet), GYM (gris), puis un petit bouton « Codes ». Chaque case a sa couleur, une **illustration du personnage** et un nom en MAJUSCULES blanches cerné de noir, à cheval sur le bas de la case. En haut, des pilules sombres dans le style de la barre de Roblox ($, Aura, Daily Reward, Quests). |
| **Pet Simulator 99** | — | 👁 Une grille de 2×3 grosses icônes 3D brillantes **sans cadre** en haut à gauche (cadeau avec minuteur, maison, pansement). Les emplacements pas encore débloqués sont des silhouettes noires avec un cadenas. L'argent est dessous, en grosses icônes et chiffres blancs cernés, sans fond. Le bouton « Rewards » vert est en bas à droite. |
| **Grow a Garden** | — | 👁 Trois gros boutons de texte en haut au centre (SEEDS / GARDEN / SELL) : des téléportations. Les fenêtres sont décorées comme le jeu : bois, terre, bandeau d'herbe verte, croix rouge carrée. |
| **Adopt Me!** | — | 👁 Le sac à dos est un panneau clair et rose. Les onglets à gauche sont des pilules vertes **en relief** (une bande plus foncée dessous). La grille d'objets a des cartes en dégradé chaud, avec une lettre de rareté. La croix est ronde et rouge. Polices très rondes et grasses. |
| **Blox Fruits** | 4e | 👁 Une colonne de cases à icône et nom au bord gauche (Backpack, Wardrobe, Stats). Fenêtre d'inventaire : bandeau de titre centré, croix rouge, cartes colorées selon la rareté. |
| **99 Nights in the Forest** | 3e | 👁 Une fenêtre de fabrication en grand voile sombre : cases à icône et prix, titres de section en jaune majuscule. |

## Ce que tous ces jeux font (les règles)

1. **La navigation est toujours visible, en une seule touche.** 👁 Aucun des jeux observés ne range ses boutons
   principaux derrière un bouton ☰. Roblox le recommande : 📄 « afficher seulement ce qui est utile dans le contexte »,
   mais les actions fréquentes doivent rester à portée. Chaque étape en plus est une friction (📄 docs Roblox, « Flows
   and friction »).
2. **Une colonne au milieu du bord gauche**, ou une grille de 2 à 3 colonnes. 👁 C'est la convention du genre
   simulateur : les joueurs savent où chercher (📄 docs Roblox, « Conventions »). Sur téléphone, le joystick occupe le
   bas à gauche et le saut le bas à droite : 📄 il ne faut jamais mettre de bouton dans la zone du joystick.
3. **Une couleur par bouton, une grosse icône, un mot court.** 👁 Les icônes dominent, le texte confirme. 📄 Les plus
   jeunes jouent surtout sur téléphone ; les icônes colorées se lisent sans lire.
4. **Le relief « bonbon ».** 👁 Les formes sont rondes, avec un contour sombre épais, un dégradé vertical, un reflet en
   haut et une bande plus foncée dessous (Adopt Me, Gym League). 📄 Il n'y a presque jamais d'angle droit dans les
   meilleurs simulateurs.
5. **L'argent est gros, lisible et achetable.** 👁 Ce sont de grosses icônes et de gros chiffres cernés, souvent sans
   cadre. Un « + » à côté ouvre la boutique (Steal an Egg, Pet Simulator 99).
6. **Les fenêtres reprennent le thème du jeu**, avec un titre et une croix rouge, toujours au même endroit
   (👁 Grow a Garden, Adopt Me ; 📄 docs Roblox : « croix rouge carrée en haut à droite, partout »).
7. **Tout réagit au doigt.** 📄 Le bouton s'enfonce dès que le doigt touche (pas au relâcher), à 88 à 97 % de sa
   taille. Au relâcher, il dépasse un peu sa taille puis revient. Même effet partout, sans exagérer.
8. **Une pastille rouge attire l'œil sur ce qui attend** (récompense à prendre). 📄 Clash Royale réserve le rouge aux
   notifications et limite à une fenêtre au démarrage.
9. **Couleurs avec un sens** (📄 Clash Royale) : jaune = action principale, vert = acheter ou valider, rouge = fermer
   ou notification. Ce code ne change jamais : Clash Royale a dû annuler une mise à jour qui le cassait.
10. **Taille au toucher** : 📄 44 px au minimum (la barre de Roblox suit cette règle). Sur petit écran (plus petit côté
    ≤ 500 px), le bouton de saut de Roblox fait 70 px.

## Ce qui n'allait pas dans notre menu (D96)

- Le rond ☰ cachait tout derrière une étape : il fallait l'ouvrir, puis choisir. C'est l'inverse des jeux observés.
- Les cases du tiroir étaient plates, sombres et petites (68 × 54) : peu engageantes, et on ne voyait rien avant
  d'ouvrir.
- Les compteurs étaient dans un rectangle sombre au centre, avec un texte « 🗿 48.2K » : rien à toucher pour acheter,
  sauf un « + » carré ajouté ensuite.
- La fenêtre de la semaine n'avait plus de bouton : passé l'arrivée, impossible de la rouvrir.

## Ce qui est mis en place (D124)

Le détail est dans `DECISIONS.md` (D124). En résumé :
- une colonne de cases en relief au bord gauche ;
- des pastilles Mog et Cash à pièce ronde et bouton « + » ;
- une barre du boss dorée ;
- une pastille d'objectif assortie ;
- des boutons qui s'enfoncent et rebondissent ;
- une pastille rouge sur « Rewards » ;
- une croix rouge assortie sur toutes les fenêtres.

## Sources

- Roblox Creator Docs : [UI and UX design](https://create.roblox.com/docs/production/game-design/ui-ux-design), [Adaptive design](https://create.roblox.com/docs/production/publishing/adaptive-design), [Position and size UI objects](https://create.roblox.com/docs/ui/cross-platform-design)
- DevForum : [The correct way to design mobile buttons](https://devforum.roblox.com/t/the-correct-way-to-design-mobile-buttons/2494558), [The Ultimate UI Design Guide](https://devforum.roblox.com/t/the-ultimate-ui-design-guide/1236916), [What makes a UI polished and crisp](https://devforum.roblox.com/t/what-makes-a-ui-have-that-polished-and-crisp-look-and-how-do-i-get-that/703624), [Updated Experience Controls](https://devforum.roblox.com/t/updated-experience-controls-now-live)
- [Clash Royale : UX best practices](https://www.therookies.co/blog/game-design-ux-best-practices-detailed-breakdown-of-clash-royale/) (The Rookies)
- Classement des jeux : [Rowatcher](https://rowatcher.com/roblox-player-count), [Statroblox](https://statroblox.com/leaderboards/playing)
- Guides avec captures en jeu : [allthings.how (Steal a Brainrot)](https://allthings.how/?p=329201), Beebom, Pro Game Guides, Deltia's Gaming
