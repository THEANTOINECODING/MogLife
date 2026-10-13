# 07 — Roadmap

Principe : **un petit jeu complet d'abord, puis des mises à jour régulières** qui suivent toutes la même recette.

## Existant dans le dépôt (13 octobre 2026, non testé dans Studio)

- Répétition au clic validée par le serveur, stats Force / Cash / Mog sauvegardées (ProfileStore).
- Élargissement de l'avatar Roblox selon la Force, rangs, leaderstats, HUD provisoire.
- **À adapter** : la Force disparaît au profit du Mog ; le clic simple devient un système de mini-jeux ; l'avatar Roblox sera remplacé par le personnage du jeu ; pas de `schemaVersion`.

## MVP

### Étape A — Socle et premier mini-jeu
Mog comme stat principale, `schemaVersion`, **système de mini-jeux générique** (début de série, répétitions, notation, cadence serveur, mode auto) et le premier mini-jeu : **curl** (glisser haut/bas).
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
Icône, miniatures honnêtes, description, cosmétiques payants éventuels (voir 06_MONETISATION.md), vérification des règles.

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
