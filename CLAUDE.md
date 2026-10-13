# MOG LIFE : become a GOD MOGGER 💪🗿 — règles du projet

Jeu Roblox de musculation humoristique (« gym bro »), inspiré des mécaniques de Douchebag Workout 2.
Titre officiel sur Roblox : **MOG LIFE : become a GOD MOGGER 💪🗿** (à utiliser tel quel dans l'interface et la page du jeu).
La conception du jeu est dans `GAME_DESIGN.md`, la direction artistique dans `STYLE_GUIDE.md`.
Toujours lire la section concernée de `GAME_DESIGN.md` avant d'implémenter une fonctionnalité.

## Stack

- Langage : **Luau**, fichiers `.luau`
- Synchronisation avec Studio : **Rojo** (`default.project.json`)
- Outils gérés par **Rokit** (`rokit.toml`) : rojo, wally, stylua, selene, luau-lsp
- Paquets : **Wally** (`wally.toml`). Paquets serveur dans `ServerPackages/` (non versionné, `wally install` pour le recréer)
- Sauvegarde : **ProfileStore** (via `DataService`)

## Structure

| Dossier | Dans Studio | Contenu |
|---|---|---|
| `src/server/` | ServerScriptService.Server | `init.server.luau` + `Services/` |
| `src/client/` | StarterPlayerScripts.Client | `init.client.luau` + `Controllers/` |
| `src/shared/` | ReplicatedStorage.Shared | `Config/`, `Remotes.luau` |
| `assets/` | — | Sources Blender et exports FBX/OBJ |
| `tools/` | — | Scripts d'automatisation (export, upload) |

- Un **service** serveur = un module dans `src/server/Services/` avec `Init(services)` (optionnel) et `Start()` (optionnel). L'ajouter dans `ORDER` de `init.server.luau`.
- Un **contrôleur** client = pareil dans `src/client/Controllers/` et `init.client.luau`.
- Nouveau remote : l'ajouter dans `NAMES` **et** dans le type en bas de `src/shared/Remotes.luau`.

## Règles impératives

1. **Le serveur décide de tout.** Le client envoie des demandes, jamais des résultats (pas de « ajoute-moi 50 de force »). Le serveur valide : type des arguments, délai, distance, prérequis, argent.
2. **Aucun chiffre d'équilibrage en dur dans le code.** Tout va dans `src/shared/Config/` (`Balance.luau`, `Exercises.luau`, `Ranks.luau`…).
3. Les données joueur passent uniquement par `DataService` et sont modifiées via `StatsService.Add` (ou un service dédié). Ajouter tout nouveau champ dans `Balance.StartingData` (ProfileStore le complète automatiquement chez les anciens joueurs grâce à `Reconcile`).
4. Ne jamais renommer `STORE_NAME` dans `DataService` sans plan de migration : ça efface la progression des joueurs.
5. Contenu adapté à tous les âges (règles Roblox) : humour gym bro absurde, pas de contenu suggestif, pas d'insultes.
6. Pas de copie du jeu original : ni nom, ni personnages, ni textes, ni graphismes.

## Après chaque modification

```bash
stylua src
selene src
```
Corriger toutes les erreurs de Selene avant de considérer la tâche terminée.
Si Studio est connecté (MCP `Roblox_Studio`, intégré à Studio), lancer un test de jeu (`start_stop_play`) et vérifier la sortie (`get_console_output`).
**Le code se modifie toujours dans `src/`** (Rojo synchronise vers Studio), jamais directement dans Studio via `multi_edit`, sinon les changements sont perdus.

## Assets 3D

- Style low-poly, couleurs unies (voir `STYLE_GUIDE.md`)
- Maximum ~10 000 triangles par objet (limite Roblox ~20 000 par MeshPart, viser bien moins pour le mobile)
- Textures 1024×1024 maximum
- Export **FBX** dans `assets/export/`, échelle : 1 stud ≈ 0,28 m
- Appareils de musculation : Part/MeshPart avec le tag CollectionService `Equipment` et l'attribut `ExerciseId` (= clé dans `Exercises.luau`)
