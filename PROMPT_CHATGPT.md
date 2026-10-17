# Prompt pour continuer MOG LIFE avec ChatGPT (Codex)

Copier tout ce qui est sous la ligne dans Codex (application ou `codex` dans un terminal ouvert sur
`C:\Users\antoi\Documents\MogLife`). Codex lit aussi `AGENTS.md`, qui renvoie à `CLAUDE.md`.

---

Tu reprends le développement du jeu Roblox **MOG LIFE : become a GOD MOGGER 💪🗿**. Le dossier du projet est
`C:\Users\antoi\Documents\MogLife`. Je suis le créateur (Antoine). **Réponds-moi toujours en français**, simplement :
je ne suis pas développeur.

## 1. À lire avant de toucher quoi que ce soit

1. `CLAUDE.md` : les règles du projet. Elles s'appliquent à toi exactement comme à Claude (même si le nom dit
   « Claude »).
2. `design/README.md`, puis `design/00_VISION.md` et `design/07_ROADMAP.md`.
3. Les dernières décisions en haut de `design/DECISIONS.md` (D66 à D69).
4. Le fichier de design du sujet sur lequel tu travailles (ex. `design/02_MECANIQUES/DUELS.md`).
5. Le code réel avant de le modifier (`src/`), et `git log --oneline -15` pour voir l'historique récent.

## 2. Où en est le jeu (18/10/2026)

- Étapes 1 à 7 et 9 de la feuille de route faites ; l'étape 8 (alpha avec de vrais testeurs) n'a pas commencé.
- Derniers ajouts :
  - **D66** : caméra stable pendant les mini-jeux et les combats.
  - **D67** : défis et coffre de la semaine (bouton Weekly), trophées, titres exclusifs.
  - **D68** : bras de fer contre n'importe quel joueur, n'importe où. Une table apparaît entre les deux joueurs,
    avec le mini-jeu « Gauge » (jauge de force).
  - **D69** : porte arrière de la salle de sport, à terminer (voir la tâche 1).
- Fichiers à ne pas committer sans me demander : `assets/blender/bosses.blend` et `assets/export/props.fbx`. Ils sont
  modifiés en dehors de nos sessions.

## 3. Comment te connecter à tout

### a) Outils du projet (terminal)
- Les outils sont gérés par Rokit (`rokit.toml`) : rojo, wally, stylua, selene, luau-lsp. S'ils manquent : `rokit install`.
- Après chaque modification du code : `stylua src` puis `selene src`. Il faut 0 erreur et 0 avertissement.
- Scripts Python sans Blender (lancer avec `py -3`) :
  - `tools/build_map.py` régénère la carte dans `world/` ;
  - `tools/gen_colliders.py` régénère les murs de collision dans `src/server/PropColliders.luau`.

### b) Rojo (synchronisation fichiers → Studio)
- Lancer `rojo serve default.project.json` dans un terminal, en arrière-plan. Le serveur écoute sur le port 34872.
- Dans Roblox Studio : ouvrir le plugin Rojo et cliquer sur **Connect**.
- Le code se modifie **uniquement dans `src/`** (et la carte dans `tools/build_map.py` → `world/`). Ne jamais modifier
  un script directement dans Studio : Rojo l'écraserait.

### c) Roblox Studio (MCP « Roblox_Studio »)
- Il est déjà déclaré dans `C:\Users\antoi\.codex\config.toml` (`[mcp_servers.Roblox_Studio]`, il lance
  `%LOCALAPPDATA%\Roblox\mcp.bat`).
- Studio doit être ouvert sur la place du jeu, avec le serveur MCP activé dans Studio (réglages de l'Assistant /
  MCP). Si les outils n'apparaissent pas, demande-moi de vérifier que Studio est ouvert et le MCP activé, puis de
  redémarrer Codex.
- Commence toujours par `list_roblox_studios` : l'identifiant `studio_id` change à chaque redémarrage de Studio.
- Outils utiles :
  - `execute_luau` (sur le serveur, le client ou en mode édition) ;
  - `start_stop_play` (lancer ou arrêter un test de jeu) ;
  - `screen_capture`, `get_console_output`, `user_mouse_input`.
- Pièges connus :
  - les clics de souris sont en pixels de la fenêtre de jeu (`workspace.CurrentCamera.ViewportSize`), pas de la
    capture, qui peut être 1,25 fois plus grande ;
  - si Studio est en arrière-plan, l'image est figée et les clics ne passent pas. Vérifie l'état par script plutôt
    qu'en te fiant à une capture.

### d) Commandes de test dans Studio
- Uniquement en mode Play, dans Studio : `ServerStorage.DevCommands:Invoke(commande, userId, ...)`.
- Commandes disponibles :
  - `Get` : copie des données du joueur ;
  - `Set` : modifie un champ des données ;
  - `StartHelp`, `StartEvent`, `ShowChallenge` ;
  - `DuelBot` : bras de fer contre un mannequin. Arguments : `perfect`, `good`, sa précision de 0 à 1 ;
  - `WeeklyTrack` : avance un compteur des défis de la semaine.
- **La sauvegarde du joueur est réelle** :
  - au début de chaque session de test, lis ses données avec `Get` et garde-les ;
  - à la fin, remets uniquement ce que ton test a changé (Cash, Mog, Duels, Weekly, Tips…), puis vérifie avec `Get`.

### e) Blender (MCP « blender »)
- Il est déjà déclaré dans `config.toml` (`uvx mcp-for-blender`).
- Il faut que j'ouvre Blender et que je démarre le module complémentaire MCP (barre latérale N → onglet MCP).
- Si l'outil `get_addon_status` dit qu'il n'est pas connecté, demande-le-moi. Si le module est trop ancien :
  `uvx mcp-for-blender install-addon`.
- Les modèles se construisent par des scripts dans `tools/blender/`. On exécute dans Blender
  `exec(open(r"C:\Users\antoi\Documents\MogLife\tools\blender\<script>.py", encoding="utf-8").read())`.
- Les modèles produits vont dans `assets/export/`, en FBX.
- **L'import dans Studio est manuel** : c'est moi qui le fais (Accueil → Importer 3D), puis je colle le script indiqué
  dans la barre de commande de Studio. Dis-moi exactement quoi faire et attends ma confirmation.

## 4. La porte arrière de la salle (D69) est terminée

Elle a été exportée, importée et vérifiée le 18/10. Attention pour tout futur import de modèles : l'importateur de
Studio peut perdre la texture de palette. `tools/install_props.luau` la remet automatiquement, et le script peut être
lancé par toi avec `execute_luau` en mode édition (je n'ai plus qu'à faire l'import et Ctrl+S).

## 5. Ensuite, dans cet ordre (une tâche à la fois, en me demandant avant de passer à la suivante)

1. **Tester le bras de fer à deux vrais joueurs** : Studio → onglet Test → « Serveur et 2 clients ».
   - Bouton « Arm Wrestle » sur l'autre joueur, invitation, accepter / refuser, table posée entre les deux.
   - Les deux bras animés, le résultat, le plafond de 3 duels par jour avec le même joueur.
   - Le réglage « Duel invites » coupé.
2. **Bras de fer contre un mur** : quand la table est posée près d'un mur de maison, la caméra filme de derrière le
   joueur et on voit mal l'adversaire. Améliorer la caméra (`DuelController`) ou le choix du sens de la table
   (`DuelService.findPlacement`).
3. **Liste des titres exclusifs** au miroir de la maison (`CreatorController`, onglet Name) : la vérifier à l'image.
4. **Préparer l'étape 8 (alpha)** : lire `design/08_TESTS_ET_MESURES.md` et les questions sur l'économie dans
   `design/IDEES.md`. Ne change aucun chiffre sans ma réponse.

## 6. Règles de travail (résumé de `CLAUDE.md`, à respecter strictement)

- **Le serveur décide de tout.** Le client envoie des demandes, jamais des résultats.
- **Aucun chiffre d'équilibrage dans le code** : tout va dans `src/shared/Config/`.
- **Les textes affichés** sont en anglais, dans `src/shared/Config/Texts.luau`. Phrases complètes avec `{noms}`, jamais
  de morceaux collés.
- **Les données du joueur** passent par `DataService` et `StatsService.Add`. Un nouveau champ va dans
  `Balance.StartingData`. Ne jamais renommer `STORE_NAME`.
- **Organisation du code** :
  - nouveau service serveur : l'ajouter dans `ORDER` de `src/server/init.server.luau` ;
  - nouveau contrôleur client : l'ajouter dans `src/client/init.client.luau` ;
  - nouveau remote : l'ajouter dans `NAMES` **et** dans le type, dans `src/shared/Remotes.luau`.
- **Mini-jeux** : chaque activité a son propre mini-jeu, jamais réutilisé ailleurs. Ils sont construits sur
  `src/client/MinigameKit.luau`.
- **Contenu et monétisation** :
  - jeu pour tous les âges ;
  - aucune copie de Douchebag Workout ;
  - pas de vente de puissance (`design/06_MONETISATION.md`).
- **Décisions** :
  - les `❓` du design sont des décisions pour moi : pose-moi la question ;
  - une idée nouvelle va dans `design/IDEES.md`, une décision dans `design/DECISIONS.md` (prochain numéro : D70).
- **Honnêteté sur les tests** : n'écris jamais « testé dans Studio » si tu ne l'as pas fait. Dis ce qui a été vérifié
  à l'image, ce qui l'a été seulement par script, et ce qui ne l'a pas été.
- **Commits** courts et clairs, en français. Ne pousse rien en ligne sans me le demander.
- **À la fin de chaque tâche**, donne-moi :
  - les fichiers modifiés ;
  - ce qui marche en jeu ;
  - les tests faits ;
  - les limites ;
  - la prochaine étape.
- **Un seul assistant à la fois** : Claude et toi ne modifiez jamais les mêmes fichiers en même temps. Quand je
  reviendrai à Claude, laisse un résumé de ce que tu as fait en haut de `RAPPORT_NUIT.md`, avec la date.
