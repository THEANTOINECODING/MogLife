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
