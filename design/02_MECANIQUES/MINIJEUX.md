# Mini-jeux (mécanique principale)

> **D76: active mechanics are documented in [PLAYGROUND.md](PLAYGROUND.md).** The historical sections below describe the previous version. Progression IDs, unlocks and reward services remain compatible.

**Chaque activité a son PROPRE mini-jeu** : chaque exercice, chaque aide et chaque boss se joue différemment, et aucun mini-jeu n'est réutilisé ailleurs (décision D23).
Pour rester simple à produire, tous les mini-jeux partagent une boîte à outils commune (`src/client/MinigameKit.luau` : entrées, notation, mode auto, nettoyage).
Depuis D75, les 19 activités du monde ont chacune un module nommé et une règle dans `Config/SceneGames.luau`.
`SceneChallenge.luau` partage les gestes et les scènes ; `GripCounter.luau` gère le duel. Les résultats et les récompenses
restent décidés par le serveur.

## Règles communes

- **Une seule entrée simple** à la fois : un doigt sur mobile, souris ou clavier sur PC, équivalent manette. Jamais de multitouch obligatoire ni de clics frénétiques.
- Les gestes de précision utilisent des positions relatives au panneau et les fenêtres de temps sont les mêmes sur
  chaque plateforme. La vitesse du curseur au clavier et celle du geste tactile sont plafonnées par le même paramètre.
  Le ressenti équivalent reste à vérifier sur iPhone, iPad, ordinateur et manette avec des joueurs.
- Chaque répétition est notée **Raté / Bien / Parfait**.
- Le serveur applique un **quota de rythme** : jamais plus de répétitions que le temps écoulé ne le permet (+1 d'avance). Jouer plus vite ne rapporte rien de plus.
- **Mode auto** gratuit (maintenir un bouton) pour les exercices et les aides : gain de base, sans bonus. Interdit en combat de boss.
- Option d'accessibilité : fenêtres de timing plus larges (à faire).

## Gain de Mog (exercices)

Mog gagné = Mog de base de l'exercice × multiplicateur de qualité (Raté x1, Bien x1,25, Parfait x1,6).

## Exercices (6)

| Exercice | Mini-jeu | Mécanique | Mog/rép ❓ | Débloqué par |
|---|---|---|---:|---|
| Curl haltère | WatermelonCurl | Suivre la pastèque contre une résistance qui oscille | 1 | Départ |
| Pompes | ChestCatapult | Comprimer puis relâcher pour bondir | 2 | Kevin |
| Développé couché | BarRescue | Rattraper la barre puis la soulever | 4 | Brayan |
| Squat | CrackedFloor | Choisir la dalle intacte | 8 | Coach Turbo |
| Tractions | TravelingBar | Suivre la prise mobile pendant la montée | 14 | Monsieur Pas-Les-Jambes |
| Corde à sauter | ShowRope | Choisir un saut court ou double au passage de la corde : deux grandes zones tactiles, gauche/droite au clavier et à la manette | 24 | Le Roi du Quartier |

## Aides (8)

| Aide | Mini-jeu | Mécanique |
|---|---|---|
| Bocal de maman | SecretSeal | Trouver la bulle d'air puis maintenir pour ouvrir le couvercle |
| Pneu du livreur | LeakHunt | Trouver la fuite puis maintenir pour pomper |
| Clous du petit voisin | NailAngle | Orienter le marteau vers le clou |
| Voiture du voisin | CarSlingshot | Tirer la sangle à l'opposé de la place visée |
| Piano de Mme Do-Ré | PianoPivot | Choisir un pivot devant chaque obstacle |
| Transats du maître-nageur | PerfectSpot | Amener le transat au bon coin de la plage |
| Courses de l'épicier | ImpossibleBag | Trouver l'objet lourd et le placer au fond |
| Chemin du touriste | LivingPostcard | Tourner le panorama vers le repère de la carte |

## Boss (5 dans le MVP)

| Boss | Mini-jeu | Mécanique |
|---|---|---|
| Kevin | SofaEscape | Prévoir sa fuite vers le frigo, la télé ou le canapé |
| Brayan le Bronzé | TanMirror | Viser son reflet avec le miroir pendant que le soleil bouge |
| Coach Turbo | MegaphoneRebel | Tenir pendant l'onde, relâcher dans l'accalmie |
| Monsieur Pas-Les-Jambes | ToothpickSweep | Trouver la jambe tremblante puis maintenir pour glisser le tapis |
| Le Roi du Quartier | Headwind | Corriger son appui contre les rafales du ventilateur |
| Le Dieu du Pump | ❓ à créer | (mise à jour Olympe) |

## Duel entre joueurs (D68)

| Activité | Mini-jeu | Mécanique |
|---|---|---|
| Bras de fer | GripCounter | Choisir la prise annoncée, tenir, puis relâcher sur le moment doré ; même motif pour les deux joueurs |

## Ajouter un mini-jeu

Sur les écrans tactiles en paysage, les commandes et les retours restent à gauche du panneau de jeu. Un panneau
plus haut que l'espace disponible est réduit avec ses commandes pour rester entièrement visible.
En portrait, le panneau occupe la place entre les boutons Stop/Auto et la consigne du bas ; sa hauteur diminue sur
les petits téléphones sans réduire la largeur des zones tactiles.

1. Un module dans `src/client/Minigames/` basé sur `MinigameKit` ou `SceneChallenge` (`new`, `SetAuto`, `Destroy`).
2. Une clé `Minigame.Hint.<Nom>` dans `Texts.luau`.
3. Le référencer dans `Exercises.luau`, `Helps.luau` ou `Stages.luau`.

## Sécurité

Le client envoie la qualité de chaque répétition ; le serveur vérifie le quota de rythme, la distance, le déblocage, et calcule lui-même les gains. Limite connue : un tricheur peut s'attribuer des Parfait (x1,6 au maximum, et en combat il reste borné par le rythme).

## Validation de l'équité des commandes (alpha D75)

Faire jouer les mêmes séries, sans mode auto, à des débutants sur iPhone portrait, iPad paysage, ordinateur souris,
ordinateur clavier et manette. Pour chaque activité, comparer les taux de Good/Perfect, les ratés, le temps de
compréhension et la vue du personnage. Retoucher `Config/SceneGames.luau`, `Config/Duels.luau` et les tailles de panneau
si un appareil crée un avantage mesurable. Pour les boss, vérifier que le taux de victoire descend de Kevin au Roi du
Quartier à progression comparable, sans boss infranchissable au doigt. Vérifier aussi l'audibilité et le confort des
sons avec musique et effets activés ou coupés. Aucun résultat de ces essais n'est encore établi.

## Refonte de jouabilité du 20 octobre 2026

Les 19 activités définies dans `SceneGames.luau` ont une scène révisée : silhouette dessinée pour chaque activité,
objet animé, objectif visible, piste de temps, zone de réussite et rappel de commande adapté à la dernière entrée
utilisée. `Combo`, déjà relié au boss PumpGod dans le code, et le duel `GripCounter` ont également été repris. Le
choix de design ❓ du mini-jeu final du Dieu du Pump reste ouvert.

- Une seule action à la fois. Les choix à trois cases, l'équilibre, le suivi, la visée et les maintiens n'affichent
  que les repères utiles à leur geste. Trouver une case et agir dessus se fait en un seul maintien.
- La corde utilise deux larges zones (court / double), avec la même fenêtre temporelle pour les touches et la
  manette. Les autres visées et suivis emploient des coordonnées relatives, un déplacement plafonné et une
  diagonale normalisée ; le doigt ne peut pas téléporter le curseur.
- La finale `Combo` ne soumet qu'une séquence par intervalle du serveur. Les zones visibles du duel suivent le
  rétrécissement réel de sa fenêtre selon la manche.
- Les seuils communs restent dans `SceneGames.luau` et ceux du duel dans `Duels.luau`. Le client calcule la note
  locale ; le serveur conserve la cadence, les gains et les autres validations existantes.

La création de chaque panneau et son fonctionnement initial ont été vérifiés en Studio. La difficulté **ressentie**
sur iPhone, iPad et PlayStation n'est pas validée par ce test : elle exige les essais sur appareils prévus ci-dessus
et un réglage des seuils à partir des résultats.
