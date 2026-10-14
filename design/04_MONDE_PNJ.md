# 04 — Monde et personnages

## L'escalade absurde

Chaque zone est plus absurde que la précédente, jusqu'à l'Olympe où l'on devient GOD MOGGER.

| Zone | Accès | Boss | Ambiance | Version |
|---|---|---|---|---|
| **Garage de maman** | Départ | Kevin, Brayan | Bric-à-brac, haltères en pastèques, canapé défoncé | MVP |
| **La rue** | Brayan battu | Coach Turbo | Salle de quartier miteuse, voisins excentriques | MVP |
| La plage | Coach Turbo battu | Monsieur Pas-Les-Jambes | Muscle Beach parodique, mouettes musclées | Mise à jour |
| La montagne | Pas-Les-Jambes battu | Le Roi du Quartier | Entraînement façon film des années 80, yacks | Mise à jour |
| La Lune | ❓ | ❓ (boss bonus) | Haltères en apesanteur, astronautes bodybuilders | Mise à jour |
| L'Olympe | Roi du Quartier battu | Le Dieu du Pump | Temple en marbre, nuages, statues qui posent | Mise à jour |

Dans le MVP, la sortie de la rue montre la plage au loin avec un panneau honnête « Bientôt ».
**La ville s'appelle Muscle City** (D30).

**Carte du MVP (D31)** : générée par `tools/build_map.py` dans `world/Map/`. Garage de maman (départ : curl, pompes, Kevin, Brayan devant, maman, livreur) → la rue (maisons pastel, habitants sur le trottoir d'en face) → la salle de quartier (4 autres stations, Coach Turbo) → la place des boss (Pas-Les-Jambes, Roi du Quartier, statue du Dieu du Pump dans son temple). La place des boss est provisoire : ces boss déménageront à la plage et à la montagne quand ces zones existeront. Pas encore de zones verrouillées par les boss.

## Langues

- **Langue source des textes du jeu : l'anglais.** Le design reste rédigé en français.
- **Français :** traduction relue et corrigée à la main, en priorité les répliques drôles.
- **Autres langues :** traduction automatique de Roblox (localisation activée dans le Creator Hub), corrigée plus tard pour les langues où le jeu a beaucoup de joueurs.
- Le joueur voit la langue de son compte Roblox. ❓ Ajouter un sélecteur de langue dans les paramètres du jeu (simple à faire si le menu de Roblox ne suffit pas).
- Les noms propres (boss, PNJ, zones) peuvent avoir une version par langue quand le jeu de mots ne passe pas (ex. : *Mr. No-Legs* / *Monsieur Pas-Les-Jambes*).
- Les répliques d'exemple de ce document sont en français ; leur version anglaise sera écrite à l'implémentation.

## Personnages

### Le coach
Il accompagne le joueur partout, commente ses séries, présente chaque boss avec une emphase ridicule.
**Look (décision D29) : le mentor mystérieux.** Lunettes de soleil même la nuit, apparaît de nulle part (derrière une poubelle, dans un frigo…), parle en proverbes absurdes sur les biceps (« Le biceps qui doute est déjà un triceps. »). Silhouette massive mais toujours à moitié dans l'ombre ou de dos. ❓ Son nom.

### Boss
Voir `02_MECANIQUES/BOSS.md`. Chaque boss a : un look ultra-exagéré, une entrée en scène, 3 répliques avant le combat, une scène de défaite absurde, un objet de style exclusif.

### Habitants (aides)
Voir `02_MECANIQUES/AIDES.md`. Maman, le livreur dépassé, le petit voisin, le voisin à la voiture, Mme Do-Ré. Chaque zone en ajoute 3 à 5.

## Humour

- Toujours exagéré, toujours absurde, jamais méchant envers les vrais gens.
- Répliques courtes, traduisibles, qui n'interrompent pas chaque série.
- Les personnages peuvent se moquer d'eux-mêmes.

Exemples :
- Kevin : « Je commence lundi. Quel lundi ? Un lundi. »
- Brayan : « Je ne bronze pas. Je brille. »
- Le coach : « Ce n'est pas un garage. C'est un centre de recherche sur les biceps. »
- Coach Turbo, à lui-même : « TU ES INCROYABLE, TURBO ! »
