# Passation Codex — import installé et route rétablie, 18 octobre 2026

- **Studio, mode Édition :** Antoine a importé `MogLife_Wardrobe.fbx`. Codex a lancé `tools/install_characters.luau` : les 3 318 MeshParts de style sont rangés dans `ReplicatedStorage.Style`, tous ont une texture. Les 3 318 décalages correspondants sont maintenant dans `src/shared/Config/StylePieces.luau` et synchronisés par Rojo. L'import brut n'est plus dans Workspace.
- **Route :** les quatre parties de route existaient, mais `Workspace.Map.Town.Ring.Ground` avait été déplacé de `(0, -0.4, 0)` à `(21, 0.5, 18)` et recouvrait l'asphalte. Codex l'a remis à la position prévue par `world/Map/Town/Ring.model.json`. La route complète et ses marquages ont été revus à l'image avant et après ; la bonne position était encore présente après l'arrêt du Play. **Antoine doit faire Ctrl+S dans Studio pour conserver les modifications de la place.**
- **Essais Play :** deux ensembles (`GoldenHour` et `CircuitAce`) ont été vus sur le personnage en jeu, sur Normie féminin, Alpha féminin, GodMogger féminin et Alpha masculin à la limite de croissance. Le haut et le bas étaient visibles et suivaient le corps ; les 20 tenues n'ont pas toutes été passées en revue en mouvement. Le serveur a démarré sans erreur du jeu ; seuls des avertissements CorePackages Roblox sont apparus. Les données de test du joueur (Look, Stage, Mog, StyleEquipped, Weekly) ont été remises à leur état initial et vérifiées avec `Get` avant l'arrêt.
- **Vente :** `StyleSets.Active` reste `false` et les ensembles n'ont pas de prix. Le QCM sur les prix attend la réponse d'Antoine ; l'achat en un clic et les effets restent à essayer après activation. Les silhouettes montrent encore des ressemblances : ne pas présenter la garde-robe comme visuellement validée pour la vente.

---

# Passation précédente — 20 ensembles, 18 octobre 2026

Antoine a rejeté le rendu de la première garde-robe D70 : volumes flottants et manque de variété. Ses choix suivants sont consignés en D71 : 20 ensembles originaux haut + bas, équipement en un clic, pièces mélangeables ensuite, effets discrets et réglables. Le prix des ensembles a été demandé en QCM et attend toujours sa réponse ; **aucun prix ni achat n'est activé**.

- **Blender :** `tools/blender/outfit_looks.py` construit 20 nouveaux ensembles sur chacun des 14 corps, à partir des surfaces réelles du torse et du bassin. L'export compte désormais 74 articles (34 anciens possédables, 40 nouvelles pièces) et 3 318 MeshParts de style. Les 9 articles D70 rejetés ont été retirés de l'export. Sources et exports : `assets/blender/wardrobe.blend`, `assets/export/characters/MogLife_Wardrobe.fbx`, `MogLife_Style.png`, `StylePieces.pending.luau`. La palette passe à 512×512. `tools/install_characters.luau` attend ce nouveau compte avant toute installation. **La garde-robe n'a pas été importée dans Studio.**
- **Code :** `Config/StyleSets.luau` contient les 20 ensembles avec `Active = false` et aucun prix. La boutique a l'essayage et l'équipement en un clic ; le serveur valide les achats, les deux pièces possédées et la présence de tous les modèles avant d'agir. Les vêtements déjà achetés sont conservés. `OutfitFxController` prépare quelques particules très faibles, locales au porteur, avec interrupteur `OutfitFx` dans Settings. Tout ceci reste inactif tant que `Active = false`.
- **Vérifié :** Blender a validé les 14 corps, 74 articles par corps, les mêmes parties de squelette, les maillages fermés et 1 216 triangles maximum par article. Les motifs ont été repositionnés sur la surface visible des vêtements ; planches rendues de face (`outfits_all.png`, `wardrobe_extremes.png`) et de dos (`outfits_extremes_back.png`). StyLua et Selene : 0 erreur, 0 avertissement. Studio MCP a été ouvert en Play pour vérifier le démarrage du code avec la vente désactivée : les 20 définitions et les deux nouveaux remotes existent, les interfaces se chargent ; pas d'erreur du jeu dans la sortie. Le temps `Weekly.Seconds` ajouté par ce Play a été restauré et vérifié avant l'arrêt.
- **Limites :** le rendu Blender reste une première version et le jugement d'Antoine sur l'envie d'achat est indispensable. Les effets, le paiement, l'essayage des 20 ensembles et leur adaptation pendant les animations ou la prise de masse n'ont pas été vus en Play : les modèles ne sont pas encore dans Studio. Le FBX de 3 318 pièces peut être lourd à importer et à répliquer sur mobile ; la performance doit être mesurée. La pièce `StylePieces.pending.luau` ne doit pas remplacer la configuration active avant l'import. La vente ne doit être activée qu'après vérification visuelle et prix approuvés.
- **Suite :** Antoine importe manuellement `MogLife_Wardrobe.fbx` dans Studio ; Codex lance ensuite `tools/install_characters.luau` en mode Édition via MCP, copie `StylePieces.pending.luau` vers `src/shared/Config/StylePieces.luau`, teste en Play sur Normie, Bro et GOD MOGGER, à plusieurs tailles et en mouvement ; Antoine fait Ctrl+S. Corriger les défauts relevés, valider prix en QCM, puis activer la sélection D71. Ne pas committer `assets/blender/bosses.blend` ni `assets/export/props.fbx`.

---

# Passation Codex — garde-robe, 18 octobre 2026

Antoine a demandé une refonte complète dans Blender : humour gym bro spectaculaire, identité originale MOG LIFE, 34 articles existants repris, vêtements adaptables aux 14 corps et à leur croissance, plusieurs ensembles coordonnés. La décision est D70. Les trois ensembles préparés sont Circuit (sport rétro fluorescent), Street (rue) et Victory (champion doré), chacun avec haut, bas et pièce de tête. **Les thèmes définitifs, le mode de vente et les prix ont été demandés à Antoine en QCM ; pas encore de réponse au moment de cette passation.** Aucun chiffre de boutique n'a été modifié.

- Les modèles sont reconstruits dans `tools/blender/build_style.py`, sauvegardés dans `assets/blender/wardrobe.blend` et exportés vers `assets/export/characters/MogLife_Wardrobe.fbx` avec `MogLife_Style.png`. Il y a 43 articles × 14 corps, soit 1 316 pièces de style. L'export complet `MogLife_Characters.fbx` a aussi été régénéré, mais l'import à faire est celui de la garde-robe seule.
- Les nouveaux décalages sont dans `assets/export/characters/StylePieces.pending.luau`. **Ne pas les copier dans src avant l'import manuel dans Studio**, car l'ancienne garde-robe est encore dans la place et serait décalée. Le fichier actif `src/shared/Config/StylePieces.luau` est resté inchangé. Les 9 nouveaux articles ne sont pas encore vendus dans `StyleItems.luau` : prix en attente.
- `tools/install_characters.luau` vérifie que les 1 316 pièces et la texture sont présentes avant de remplacer l'ancienne garde-robe. Après l'import manuel d'Antoine, copier les décalages dans src, lancer StyLua/Selene, puis exécuter le script d'installation en mode Édition par MCP et demander Ctrl+S à Antoine.
- Vérifié **dans Blender et à l'image Blender**, pas dans Roblox Studio : 43 articles pour chacun des 14 corps, mêmes parties du squelette entre les stades, maillages fermés, 1 040 triangles maximum par article, atlas 256×256. Deux planches visuelles : `wardrobe_preview.png` et `wardrobe_extremes.png`. La croissance réelle en Play et l'achat des nouveaux ensembles restent à tester après import.
- Ne pas committer `assets/blender/bosses.blend` ni `assets/export/props.fbx` : modifications indépendantes d'Antoine.

---

# Passation Codex — 18 octobre 2026

Antoine a autorisé la poursuite des tâches pendant la nuit. J'ai lu les règles, la vision, la roadmap, les décisions D66–D69, les fichiers de design concernés et le code avant modification. Studio est accessible par MCP ; Rojo tourne déjà sur le port 34872. Les changements ont été enregistrés en commits locaux ; rien n'a été publié ni envoyé en ligne.

- **Deux vrais clients : encore non testé.** Le MCP ne lance qu'un client ; Studio était en mode édition, sans « Serveur et 2 clients » ouvert. Il faut faire ce test dans l'onglet Test (invitation, refus, table, animations, résultat, plafond de 3 duels par paire, réglage « Duel invites »). Ne pas le présenter comme validé.
- **Table près d'un mur : corrigée et vérifiée à l'image avec le mannequin.** `src/shared/Config/Duels.luau` demande plus de place derrière les joueurs. Avant : mannequin contre la façade, mur sur une grande partie de l'écran. Après : table tournée de 90°, deux adversaires visibles de profil. Un duel démarre encore en espace ouvert. Le duel à deux vrais joueurs près d'un mur reste à tester.
- **Titres du miroir : vérifiés à l'image.** `src/client/Controllers/CreatorController.luau` affiche les six titres sur une colonne, lisibles. Au miroir de la maison, les titres verrouillés montrent leurs conditions. Avec 1 trophée et 5 victoires de test, « Weekly Warrior » et « Wrist Wrecker » se débloquent ; sélectionner ce dernier change l'aperçu. L'édition a été annulée.
- **Économie : simulation sans sauvegarde joueur.** `tools/simulate_economy.luau` ajoute des profils comparables : boosts seuls, pareur seul, les deux. Résultats et questions ouvertes dans `design/ALPHA_PREPARATION.md`. Aucun chiffre d'équilibrage changé.
- **Alpha :** `design/ALPHA_PREPARATION.md` contient les essais à faire, une fiche testeur et les limites. Aucun événement d'analytics demandé par `08_TESTS_ET_MESURES.md` n'est encore branché dans `src/` ; les mesures réelles demandent soit cette instrumentation, soit une fiche manuelle.

StyLua et Selene ont été exécutés : 0 erreur, 0 avertissement. La sortie Studio n'a montré aucune erreur du jeu pendant ces vérifications ; elle contient des avertissements Roblox/CorePackages et un asset `rbxassetid://203785492` de mauvais type, non traité dans cette session. Avant chaque test Play, j'ai conservé les données du joueur ; après chaque test, j'ai restauré `Duels` et `Weekly` et vérifié que `Cash`, le surnom et les compteurs avaient leurs valeurs initiales (530 Cash, 0 victoire, 0 trophée, titre `ThePump`). Ne pas toucher à `assets/blender/bosses.blend` ni `assets/export/props.fbx` : modifications antérieures d'Antoine.

---

# Rapport de la nuit — MOG LIFE 💪🗿

Nuit du 13 au 14 octobre 2026. Travail autonome : **étapes B, C et D de la roadmap**, plus une simulation de l'économie.

## En bref

Le cœur du MVP est en place et testé dans Studio via le MCP :

| Étape | Contenu | Testé |
|---|---|---|
| B | Pompes, développé couché, squat : 3 nouveaux mini-jeux, tous différents | ✅ gains serveur et notation Perfect/Good/Miss |
| C | Kevin, Brayan, Coach Turbo : défi, Mog-off en 3 manches, défaite comique, montée de stade | ✅ défaite auto, victoire, revanche, défaite sans jouer |
| D | 5 habitants à aider (Cash), miroir et boutique de 15 objets + 3 de boss | ✅ aide complète, délai, verrou, achats, refus, porter/retirer |

La barre du curl a aussi été améliorée : panneau dégradé, zones fléchées ▲ ▼, contour vert quand la répétition est prête.

**Tes données sont restaurées** : 51,2 Mog, stade 1, 0 Cash, rien d'acheté. Les tests ont modifié ton compte temporairement, puis j'ai tout remis comme avant.

## Comment essayer

1. Studio ouvert, Rojo connecté (onglet *Plugins* → *Rojo* → *Connect* ; la synchro tourne dans le terminal de l'app).
2. **Jouer**. Le terrain est provisoire (tout est posé sur la Baseplate) :

| Où | Quoi |
|---|---|
| Devant toi (z −16) | 4 stations : curl (pastèques), pompes (tapis rose), développé couché (caddie rouge), squat (pneus de tracteur) |
| Plus loin (z −34) | Les 3 boss sur des dalles rouges : Kevin (pyjama), Brayan (orange fluo), Coach Turbo (rouge) |
| Derrière toi (z +18) | 5 habitants sur des dalles vertes, avec « ! » ou 🔒 au-dessus de la tête |
| À gauche | Le miroir doré : la boutique de style |

3. Tu as 51 Mog : **va défier Kevin** (50 Mog requis). Gagne 2 manches de curl et tu passes Gym Rat, avec +20 Cash et le pyjama de Kevin.
4. Aide la maman (bocal = mini-jeu des pompes) et le livreur (pneu = mini-jeu du curl), puis va au miroir.
5. Essaie aussi de défier **Brayan trop tôt** pour voir l'envol comique (la perte de Cash est annoncée avant).

Contrôles des nouveaux mini-jeux :
- **Pompes** : clique, tape ou appuie sur Espace quand l'anneau bleu touche le cercle jaune.
- **Développé couché** : maintiens (clic ou Espace), relâche quand la jauge est dans le vert, au centre jaune pour un Perfect.
- **Squat** : garde le curseur au centre avec A / D, ou en bougeant la souris à gauche ou à droite.

## Ce que dit la simulation (`tools/simulate_economy.luau`)

Temps théoriques pour finir le MVP (battre Coach Turbo), avec les chiffres actuels :

| Profil | Kevin | Brayan | Coach Turbo | Cash restant |
|---|---|---|---|---|
| Mode auto seulement, sans aides | 2:00 | 4:30 | **8:50** | 145 |
| Joueur moyen, avec aides | 2:15 | 6:40 | **22:20** | 862 |
| Joueur précis, avec aides | 2:15 | 6:40 | 19:45 | 754 |
| Dépense tout en style | 2:15 | 6:45 | 23:25 | 107 (12 objets) |
| Défie les boss trop tôt | 2:45 | 7:40 | 23:45 | 826 (36 perdus) |

**Ce que j'en retiens, sans avoir rien changé (c'est à toi de décider) :**
1. **Le MVP se termine trop vite** : le design vise 25–40 min pour Coach Turbo, la simulation donne 9 à 23 min. Piste : monter le Mog requis de Coach Turbo (800 → ~1 500) ou baisser le Mog du développé couché.
2. **Le mode auto sans aides est le chemin le plus rapide.** Ce n'est pas grave en soi, mais les aides « coûtent » du temps d'entraînement. Piste : un petit bonus de Mog en jeu actif, ou des aides plus rentables.
3. **Coach Turbo est juste à la limite** pour un joueur moyen (score 69 contre une cible de 68). C'est peut-être voulu (« le boss de fin du chapitre »), mais un joueur un peu moins bon sera bloqué.
4. **Le Cash s'accumule** (plus de 800 à la fin pour un joueur qui n'achète pas tout) : il y a de la place pour plus d'objets ou des objets plus chers.
5. **Kevin arrive vers 2 min** : parfait par rapport à l'objectif du design (3–5 min, un peu en avance).

Ces chiffres sont des **hypothèses**, à comparer avec de vrais tests.

## Choix provisoires que j'ai dû faire (détails dans `design/DECISIONS.md`)

- **D17** : une manche de boss non jouée se termine d'elle-même (0 point).
- **D18** : défier un boss d'un stade supérieur = défaite automatique, avec perte annoncée (« Bats d'abord Kevin ! »). Un boss déjà battu peut être revu pour le plaisir, sans récompense ni perte.
- **D19** : « le boss devient moins exigeant après 3 défaites » n'est **pas** fait (c'était marqué ❓).
- **D20** : le mode auto est **autorisé** pendant les aides, **interdit** en combat. ❓
- **D21** : une aide ne peut pas « rater » : finir suffit pour être payé. ❓
- **D22** : pas encore d'essayage gratuit au miroir (à faire avec le vrai personnage).

## Questions pour toi

1. Les choix D20 et D21 te conviennent-ils ?
2. Veux-tu que j'ajuste les chiffres d'après la simulation (point 1 surtout) ?
3. Pour les visuels (étape E) : quelle **ambiance** (années 80, plage, néons…) et quelle **palette** ? Comment imagines-tu le **coach** ?
4. **Nom de la ville** ?

## Limites connues

- **Tout le visuel est provisoire** : PNJ = avatars Roblox recolorés aux proportions exagérées, habits = blocs collés sur l'avatar, carte = Baseplate. C'est l'étape E.
- **La notation est calculée par le client.** Le serveur limite la cadence, la distance et les valeurs, mais un tricheur pourrait s'attribuer des Perfect (au maximum x1,6 sur ses gains).
- **Pas de tutoriel** des 5 premières minutes (Kevin sur le canapé, le bocal…) : il dépend de la vraie carte.
- **Pas testé** : à la main (ressenti), sur un vrai téléphone, avec plusieurs joueurs.
- Studio était réduit pendant mes tests : les mini-jeux ont été vérifiés en pilotant leur logique directement, pas en les regardant tourner. **Ton test à la main est donc important.**

## Ce que j'ai ajouté pour les tests

`DevService` (actif **uniquement dans Studio**, jamais dans le jeu publié) crée `ServerStorage.DevCommands`, qui permet de lire et modifier les données d'un joueur pendant un test. C'est ce qui m'a permis de tester les boss et les exercices des stades suivants.

## Prochaines étapes possibles

- **Étape E** (visuels) : c'est la plus visible, mais elle a besoin de tes choix artistiques (questions 3 et 4).
- **Réglage des chiffres** après ton test à la main et la simulation.
- **Tutoriel** des 5 premières minutes.
