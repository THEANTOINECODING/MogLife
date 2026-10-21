# 07 — Roadmap

> D76 implementation: see [strength playground](02_MECANIQUES/PLAYGROUND.md). Studio validation is recorded in `PLAYGROUND_DELIVERY_2026-10-21.md`; physical-device playtesting remains an alpha gate.

Principe : **un petit jeu complet d'abord, puis des mises à jour régulières** qui suivent toutes la même recette.

## Existant dans le dépôt (nuit du 13 au 14 octobre 2026)

Étapes **A, B, C et D codées et testées dans Studio via MCP** (logique serveur, gains, notation des mini-jeux, flux complets). Non testées : le ressenti réel en jouant à la main, le mobile sur un vrai téléphone, plusieurs joueurs en même temps.

- A : Mog, `schemaVersion`, `Texts.luau`, moteur de mini-jeux générique, curl, mode auto, HUD.
- B : pompes (Ring), développé couché (HoldRelease), squat (Tilt), stations provisoires.
- C : Kevin, Brayan, Coach Turbo (PNJ provisoires), Mog-off en 3 manches, défaite auto avec perte de Cash annoncée, montée de stade, récompenses idempotentes, revanche sans récompense.
- D : 5 aides avec délai et réplique unique, badges au-dessus des habitants, miroir et boutique (15 objets + 3 de boss), visuels provisoires sur l'avatar Roblox.
- Outil : `tools/simulate_economy.luau` (simulation de progression, à lancer dans Studio).
- 14 octobre (retour du créateur) : 19 mini-jeux, un par activité (6 exercices, 8 aides, 5 boss) ; boss en direct avec manches plus dures et perte de Cash ; MVP prolongé jusqu'à Gigachad (D23–D26).
- Choix provisoires faits pendant l'implémentation : voir `DECISIONS.md` (D17–D22).
- Reste avant l'alpha : étape E (personnage, carte garage + rue, boss modélisés, sons), tutoriel des 5 premières minutes, réglage des chiffres.

## Plan en 9 étapes (15 octobre 2026, décision D36)

Remplace la suite de l'étape E ci-dessous. Chaque étape prépare la suivante (le corps avant les habits, la ville et les PNJ avant le tutoriel).
**Règle transversale (D37) : chaque activité se joue vraiment dans le monde**, le personnage (et l'objet, le PNJ ou le boss) réalise le mouvement en suivant le résultat de chaque répétition du mini-jeu.

1. ✅ **La ville** (15/10) : maisons, garages, magasins et salle modélisés dans Blender, portes automatiques (entrée, garage ↔ salon, magasins), salle en plein air, collisions exactes.
2. ✅ **Le personnage du joueur** (16/10 ; 17/10 : création de personnage D55, Normie spaghetti D56, corps féminins D59, croissance continue D60) : un corps par stade (Normie → God Mogger), prise de muscle satisfaisante (transformation animée, effet à chaque stade, gonflement progressif) et **les 6 exercices animés pour de vrai** selon le jeu du joueur (D37).
3. ✅ **Le style** (16/10 ; 17/10 : objets pour les 14 corps, teintes de peau et de cheveux, importés et vérifiés en jeu ; reste du design : bronzage) : coiffures, barbes, tenues adaptées à tous les corps ; présentoirs dans les magasins.
4. ✅ **Les PNJ** (16/10 : 12 habitants/vendeurs/mentor modélisés et vérifiés à l'image, les 8 aides et le Mog-off animés) : habitants et boss refaits, mentor, **vendeurs dans chaque magasin** (D38) ; **aides et combats de boss animés pour de vrai** (D37).
5. ✅ **Le guide et le tutoriel** (16/10, D46 ; ❓ premier achat du tutoriel) : le mentor explique chaque nouveau stade et chaque magasin ; flèches pour les nouveaux joueurs.
6. ✅ **Le gameplay** (16-17/10 : combo, boosts, Mog-off mis en scène, notes et records, aides payées selon la réussite, coups spéciaux des boss, émotes, pareur, événements de ville, cinématiques ; D47–D58) : mini-jeux améliorés ; boissons et aliments comiques qui donnent un boost (❓ énergie, voir D36).
7. ✅ **Le son** (16-17/10 : musique par ambiance choisie par le créateur, volumes mesurés et équilibrés, D54) : musique par zone, effets pour chaque activité.
8. **Alpha** : testeurs, vrais téléphones, réglage de l'économie.
9. ✅ **Faire revenir les joueurs** (17/10, D67) : défis de la semaine et coffre de la semaine (bouton Weekly),
   duels entre joueurs à chances égales (18/10, D68 : bras de fer contre n'importe qui, n'importe où, table qui
   apparaît entre les deux joueurs, mêmes zones de force pour les deux),
   titres exclusifs et victoires affichées à côté du surnom. Testé dans Studio : bras de fer complet contre un mannequin (devant une maison et sur la place)
   (défaite, victoire, récompense, plafond, surnom), défis, bonus, trophée, titres, changement de semaine. Reste à
   tester : l'invitation entre deux vrais joueurs (mode « Serveur et 2 clients » de Studio), la liste des titres dans
   le menu du miroir, le jeu au doigt sur téléphone.

## MVP

### Étape A — Socle et premier mini-jeu
Mog comme stat principale, `schemaVersion`, fichier de textes en anglais (`Texts.luau`) utilisé par toute l'interface, **système de mini-jeux générique** (début de série, répétitions, notation, cadence serveur, mode auto) et le premier mini-jeu : **curl** (glisser haut/bas).
**Validation :** le curl est agréable 2 minutes d'affilée, sur mobile et sur PC ; aucun gain décidé par le client.

### Étape B — Les 4 mini-jeux
Pompes, développé couché, squat. Stations placeholder (blocs simples).
**Validation :** chaque mini-jeu se joue différemment et des testeurs ont un préféré.

### Étape C — Boss et stades
Kevin, Brayan, Coach Turbo ; Mog-off en 3 manches ; défaite comique et perte de Cash annoncée ; montée de stade et déblocages.
**Validation :** un joueur comprend seul qu'il doit atteindre le Mog requis, et la défaite volontaire fait rire plutôt qu'enrager.

### Étape D — Aides et boutique de style
5 aides, Cash, miroir et 15 objets de style (placeholders acceptés).
**Validation :** les joueurs alternent naturellement entraînement et aides ; ils veulent un objet précis.

### Étape E — Personnage et direction artistique (peut avancer en parallèle dès l'étape A)
Corps des 4 premiers stades, habits et coupes réels, garage et rue habillés, boss modélisés, animations, sons.
**Validation :** une capture d'écran du jeu est reconnaissable et fait sourire.

### Étape F — Alpha
Testeurs externes, vrais mobiles, analytics, corrections, simulation d'économie comparée aux tests.

### Étape G — Publication
Activation de la traduction automatique Roblox, relecture complète du français, page du jeu en anglais et en français, icône, miniatures honnêtes, cosmétiques payants éventuels (voir 06_MONETISATION.md), vérification des règles.

## Mises à jour (après publication)

Chaque mise à jour suit la même recette :
- 1 zone + 1 boss (avec son corps de stade) ;
- 1 ou 2 exercices (nouveau mini-jeu ou variation visible) ;
- 3 à 5 aides ;
- une série d'objets de style à thème.

| # | Zone | Boss | Exercices possibles |
|---|---|---|---|
| 1 | La plage | Monsieur Pas-Les-Jambes | Tractions, corde à sauter |
| 2 | La montagne | Le Roi du Quartier | Pneu géant, soulevé de terre |
| 3 | La Lune | ❓ | Haltère satellite (apesanteur) |
| 4 | L'Olympe | Le Dieu du Pump | ❓ (finale : GOD MOGGER) |

Entre deux mises à jour de zone : événements saisonniers (objets à thème, boss déguisé), puis fonctionnalités de `IDEES.md` si les joueurs les demandent.
