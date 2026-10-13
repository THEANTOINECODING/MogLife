# 07 — Roadmap

Principe : **un petit jeu complet d'abord, puis des mises à jour régulières** qui suivent toutes la même recette.

## Existant dans le dépôt (nuit du 13 au 14 octobre 2026)

Étapes **A, B, C et D codées et testées dans Studio via MCP** (logique serveur, gains, notation des mini-jeux, flux complets). Non testées : le ressenti réel en jouant à la main, le mobile sur un vrai téléphone, plusieurs joueurs en même temps.

- A : Mog, `schemaVersion`, `Texts.luau`, moteur de mini-jeux générique, curl, mode auto, HUD.
- B : pompes (Ring), développé couché (HoldRelease), squat (Tilt), stations provisoires.
- C : Kevin, Brayan, Coach Turbo (PNJ provisoires), Mog-off en 3 manches, défaite auto avec perte de Cash annoncée, montée de stade, récompenses idempotentes, revanche sans récompense.
- D : 5 aides avec délai et réplique unique, badges au-dessus des habitants, miroir et boutique (15 objets + 3 de boss), visuels provisoires sur l'avatar Roblox.
- Outil : `tools/simulate_economy.luau` (simulation de progression, à lancer dans Studio).
- Choix provisoires faits pendant l'implémentation : voir `DECISIONS.md` (D17–D22).
- Reste avant l'alpha : étape E (personnage, carte garage + rue, boss modélisés, sons), tutoriel des 5 premières minutes, réglage des chiffres.

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
