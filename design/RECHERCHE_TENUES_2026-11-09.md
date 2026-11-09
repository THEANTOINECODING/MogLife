# Recherche : ce qui fait vendre une tenue payante (09/11/2026)

Demande d'Antoine : « prend le temps de te renseigner sur les skin qui fonctionne et sont acheter par les joueurs,
analyse les vfx la lumière les effets ». Résultat appliqué dans **D125** (`DECISIONS.md`).

## Sources consultées

- Riot Games, *The craft and fantasy of VALORANT weapon skins* :
  https://playvalorant.com/en-us/news/dev/the-craft-and-fantasy-of-valorant-weapon-skins
- DevForum Roblox, *How do I make good particle effects?* :
  https://devforum.roblox.com/t/how-do-i-make-good-particle-effects/1035137
- Recherches web (résultats de moteur, pas de page de référence unique) :
  - skins Fortnite les plus vendus et les plus aimés (skins réactifs, émotes intégrées) ;
  - tutoriels d'aura Roblox (ParticleEmitter, Beam, Trail, Néon) ;
  - auras vendues dans Gym League (Void, Galaxy).

## Ce qui fait acheter

1. **Un fantasme lisible en une seconde, par la silhouette.** On reconnaît la tenue de loin, sans voir les détails :
   - couvre-chef (couronne, cornes, auréole, capuche) ;
   - ailes, cape, queue ;
   - épaulières énormes.
2. **Un moment « oh ».** La tenue fait quelque chose que les autres ne font pas :
   - une entrée en scène ;
   - une victoire mise en scène ;
   - un effet au repos.
3. **Des effets réactifs.** Les skins réactifs de Fortnite (dont Shadow Midas) s'illuminent davantage selon ce qui se passe. Chez nous : les pièces lumineuses respirent, puis s'embrasent à l'entrée et à la victoire.
4. **De la lumière.** Les tenues les plus chères brillent : lignes néon, cœur lumineux, aura, lumière portée sur le sol.
5. **Une sensation très différente, sans avantage de jeu** (Valorant : « fantasy » d'abord ; les niveaux de prix se lisent à la quantité d'effets).
6. **L'aura, un produit en soi** (Gym League vend des auras). Chez nous, l'aura fait partie de la tenue, vue par tous les joueurs.

## Règles techniques retenues (effets Roblox)

- **Couches de particules**, pas un seul émetteur :
  - braises ou étoiles ;
  - fumée ou nébuleuse ;
  - anneau au sol couché (orientation `VelocityPerpendicular`).
- **LightEmission 1 pour ce qui brille, 0 pour la fumée.**
- **Particules courtes et lentes** autour du corps, émises depuis le volume de la partie du corps, pas d'un point.
- **Néon + Bloom** pour les liserés ; une **PointLight** colorée par tenue.
- Textures intégrées à Roblox seulement (aucun asset à téléverser) :
  - `sparkles_main`, `fire_main`, `fire_sparks_main`, `smoke_main` ;
  - `forcefield_glow_main`, `explosion01_shockwave_main`, `SquareParticle`.
- **Téléphones** (~80 % des joueurs) :
  - l'aura d'un joueur à plus de 160 studs est coupée ;
  - le réglage « effets de tenue » masque tout.
