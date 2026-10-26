# MOG LIFE : become a GOD MOGGER 💪🗿 — règles du projet

Jeu Roblox de musculation humoristique (« gym bro »), inspiré des mécaniques de Douchebag Workout 2.
Titre officiel sur Roblox : **MOG LIFE : become a GOD MOGGER 💪🗿** (à utiliser tel quel dans l'interface et la page du jeu).
Idée centrale : **chaque activité (exercice, aide, boss) a son propre mini-jeu**, jamais réutilisé ailleurs ; les exercices rapportent du Mog ; un boss par stade qui joue en direct contre le joueur ; aider la ville rapporte du Cash pour le style ; direction artistique absurde aux traits exagérés. Tous les mini-jeux sont construits sur `src/client/MinigameKit.luau`.

La conception du jeu est dans le dossier `design/` (index : `design/README.md`).
Toujours lire `design/00_VISION.md` puis le fichier concerné avant d'implémenter une fonctionnalité.

## Contrat de travail

1. Lire le design, ces règles et le code réel avant d'éditer.
2. Distinguer : existant vérifié, existant déclaré, spécification nouvelle, extension.
3. Une étape de `design/07_ROADMAP.md` à la fois. Ne pas réécrire tout le projet ; livrer une tranche jouable.
4. Ne pas inventer de dépendances, d'assets, de résultats de tests ou d'états de Studio. Ne jamais écrire « testé dans Studio » sans l'avoir fait.
5. Ne pas trancher les `❓` du design à la place du créateur : poser la question. Une idée nouvelle va dans `design/IDEES.md`, pas dans le code.
6. Expliquer toute divergence avec le design avant de l'implémenter.
7. À chaque livraison : fichiers modifiés, résultat jouable, tests faits, limites, prochaine étape.
8. Claude et Codex ne modifient jamais les mêmes fichiers en même temps : un responsable par lot, commits courts, passation explicite.

## Stack

- Langage : **Luau**, fichiers `.luau`
- Synchronisation avec Studio : **Rojo** (`default.project.json`)
- Outils gérés par **Rokit** (`rokit.toml`) : rojo, wally, stylua, selene, luau-lsp
- Paquets : **Wally** (`wally.toml`). Paquets serveur dans `ServerPackages/` (non versionné, `wally install` pour le recréer)
- Sauvegarde : **ProfileStore** (via `DataService`)

## Structure

| Dossier | Dans Studio | Contenu |
|---|---|---|
| `src/server/` | ServerScriptService.Server | `init.server.luau` + `Services/` + `Npc.luau` (PNJ provisoires) |
| `src/client/` | StarterPlayerScripts.Client | `init.client.luau` + `Controllers/` + `Minigames/` (un module par mini-jeu, interface `new / Destroy`, gestes et notation dans `MinigameKit.luau`) + `Ui.luau` |
| `world/` | Workspace (Rojo ignore le reste de la carte) | Objets de jeu versionnés : `Stations/` (tag `Station`), `Bosses/` (tag `BossSpot`), `Helpers/` (tag `HelperSpot`), `Shop/` (tag `Mirror`) |
| `src/shared/` | ReplicatedStorage.Shared | `Config/`, `Remotes.luau` |
| `assets/` | — | Sources Blender et exports FBX/OBJ |
| `tools/` | — | Scripts d'automatisation (ex. `simulate_economy.luau`, à coller dans la barre de commande de Studio) |

- **Architecture des activités** : `MinigameService` est le moteur générique des « runs » (cadence, distance, mode auto). `ExerciseService` (séries → Mog), `HelpService` (aides → Cash) et `BossService` (manches de Mog-off) lancent des runs avec `StartRun(player, spec)` et reçoivent `onRep` / `onEnd`. Ne pas dupliquer cette logique.
- **Tests dans Studio** : `DevService` (Studio uniquement) expose `ServerStorage.DevCommands` (`Get`, `Set`, `StartHelp`). Toujours **restaurer les données du joueur** après un test, elles sont réellement sauvegardées.
- Si Studio est réduit, le rendu est en pause (pas de `RenderStepped`, prompts inutilisables) : tester la logique via les remotes et en pilotant les modules de mini-jeu directement.
- Un **service** serveur = un module dans `src/server/Services/` avec `Init(services)` (optionnel) et `Start()` (optionnel). L'ajouter dans `ORDER` de `init.server.luau`.
- Un **contrôleur** client = pareil dans `src/client/Controllers/` et `init.client.luau`.
- Nouveau remote : l'ajouter dans `NAMES` **et** dans le type en bas de `src/shared/Remotes.luau`.

## Règles impératives

1. **Le serveur décide de tout.** Le client envoie des demandes, jamais des résultats (pas de « ajoute-moi 50 de force »). Le serveur valide : type des arguments, délai, distance, prérequis, argent.
2. **Aucun chiffre d'équilibrage en dur dans le code.** Tout va dans `src/shared/Config/` (`Balance.luau`, `Exercises.luau`, `Stages.luau`, `Helps.luau`, `StyleItems.luau`, `Npcs.luau`…).
3. Les données joueur passent uniquement par `DataService` et sont modifiées via `StatsService.Add` (ou un service dédié). Ajouter tout nouveau champ dans `Balance.StartingData` (ProfileStore le complète automatiquement chez les anciens joueurs grâce à `Reconcile`).
4. Ne jamais renommer `STORE_NAME` dans `DataService` sans plan de migration : ça efface la progression des joueurs.
5. Contenu adapté à tous les âges (règles Roblox) : humour gym bro absurde, pas de contenu suggestif, pas d'insultes.
6. Pas de copie du jeu original : ni nom, ni personnages, ni textes, ni graphismes.
7. **Textes et traduction** (le jeu est traduit par la localisation Roblox) :
   - Tous les textes affichés sont écrits **en anglais** et regroupés dans `src/shared/Config/Texts.luau` (clé → texte). Jamais de texte en dur dans un script d'interface.
   - Phrases complètes avec emplacements nommés (`"You lose {amount} Cash!"`), jamais de morceaux concaténés.
   - Aucun texte dans les images, textures ou modèles 3D.
   - Zones de texte avec 30 % de marge (le français et l'allemand sont plus longs) ; `TextScaled` ou taille automatique.
   - Les nombres s'affichent via une fonction de formatage commune.

## Après chaque modification

```bash
stylua src
selene src
```
Corriger toutes les erreurs de Selene avant de considérer la tâche terminée.
Si Studio est connecté (MCP `Roblox_Studio`, intégré à Studio), lancer un test de jeu (`start_stop_play`) et vérifier la sortie (`get_console_output`).
**Le code se modifie toujours dans `src/`** (Rojo synchronise vers Studio), jamais directement dans Studio via `multi_edit`, sinon les changements sont perdus.

## Assets 3D

- Style low-poly, couleurs unies (voir `design/05_ART_SON.md`)
- Maximum ~10 000 triangles par objet (limite Roblox ~20 000 par MeshPart, viser bien moins pour le mobile)
- Textures 1024×1024 maximum
- Export **FBX** dans `assets/export/`, échelle : 1 stud ≈ 0,28 m
- Stations d'exercice : Part/MeshPart avec le tag CollectionService `Station` et l'attribut `ExerciseId` (= clé dans `Exercises.luau`). Le serveur y ajoute le ProximityPrompt.
