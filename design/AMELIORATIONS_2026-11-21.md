# Les meilleures améliorations pour MOG LIFE — 21 novembre 2026

Écrit pendant la nuit du 21 au 22 novembre, après la refonte de la boutique (D137).
Cette liste tient compte de tout ce qui existe déjà :
- pack de départ, groupe, codes, bonus entre amis, Golden Pump Hour et gain d'absence (D131) ;
- Mog Rush (D132) ;
- classement mondial et rang du joueur (D136) ;
- secrets (D121, D135).

Elle ne répète pas les analyses du 19 et du 20 novembre ; elle les met à jour.

Chaque piste respecte `00_VISION.md` :
- pas de puissance vendue ;
- pas de hasard payant ;
- pas de pénalité d'absence ;
- chaque activité a son propre mini-jeu.

Effet : ★ à ★★★. Effort : S (moins d'une journée), M (quelques jours), L (une mise à jour entière).

## 🔴 Avant tout : voir le jeu

**1. Une vraie séance de test à l'écran.** Effet ★★★, effort S.

Depuis plusieurs jours, beaucoup de choses n'ont jamais été vues à l'image, car la capture de Studio était en panne ou le rendu en pause :
- animations du personnage (D134) ;
- meubles v3 ;
- tableau à 4 faces ;
- menu repliable ;
- 4 secrets refaits ;
- toute la nouvelle boutique (coffres 3D, rayons, célébration d'achat).

Il faut les regarder sur iPhone et sur PC, de préférence à deux clients. Tout le reste a moins de valeur qu'un bug visuel trouvé avant les joueurs.

Antoine doit d'abord reconnecter Rojo : il s'était déconnecté cette nuit. J'ai copié à la main dans Studio le code de la boutique pour le tester, et Rojo remettra la version de `src/` à la reconnexion.

**2. Accès des moins de 16 ans (Kids / Select).** Effet ★★★, effort S, travail d'Antoine.

C'est toujours la condition pour que le public visé voie le jeu (leçon 1 du 20/11).

## 🟠 Faire revenir et faire parler du jeu

**3. Événement de Noël (décembre 2026).** Effet ★★★, effort M.

La date s'y prête : c'est le moment de l'année où Roblox met le plus en avant les jeux mis à jour. Le contenu, en recette courte :
- la place enneigée ;
- un exercice d'hiver avec son propre mini-jeu (exemple : soulever un sapin géant) ;
- une aide de saison (déneiger, porter les cadeaux du voisin) ;
- 2 à 3 objets de style gagnables, et une tenue de Noël en Robux ;
- un calendrier de l'Avent de 24 cases, une par jour joué. Une case ratée reste récupérable, donc sans pénalité d'absence.

Sur la page du jeu, une icône et un titre de saison.

**4. Moments à partager.** Effet ★★★, effort M. Déjà proposé, toujours pas fait.
- **Carte avant / après** à chaque nouveau stade : le Normie à gauche et le nouveau corps à droite, le nom du joueur et le stade.
- **Mode photo** : caméra libre, interface cachée, poses du menu Flex.
- **Bouton de partage Roblox.**

C'est ce qui fait circuler un jeu sur TikTok.

**5. Ascension après le GOD MOGGER.** Effet ★★★, effort L.

Des crans absurdes, chacun avec un titre, une aura et un badge, et un classement mondial du cran. Le tableau World (D136) peut en devenir l'écran. Les questions de design sont toujours ouvertes (❓ du 20/11).

**6. La force dans le monde.** Effet ★★, effort M.

3 à 5 objets de la ville qu'on ne soulève qu'à partir d'un stade (voiture, rocher, enclume…). Chacun a son mini-jeu et une récompense : Cash, raccourci, secret. Ça donne un sens au fait de grossir.

**7. Notifications d'expérience.** Effet ★★, effort S.

Golden Pump Hour, fin de manche du Mog Rush, coffre du dimanche prêt. Toujours avec l'accord du joueur.

## 🟢 Boutique : vendre plus, honnêtement

**8. Tenue vedette de la semaine.** Effet ★★, effort S.

Une tenue Robux mise en avant en haut de la boutique, avec un compte à rebours jusqu'au lundi, et une tenue différente chaque semaine. Toutes restent achetables tout le temps : on ne crée pas de fausse rareté, seulement un rendez-vous.

**9. Bonus du premier achat.** Effet ★★, effort S.

« ×2 sur ton premier pack de Cash » : une pastille dorée sur l'onglet Cash tant que le joueur n'a rien acheté. C'est très courant, simple et clair. Le serveur vérifie avec un champ `FirstCashBonus` dans la sauvegarde.

**10. Offrir à un ami.** Effet ★★, effort M.

On achète un pack de Cash ou une tenue pour un joueur du serveur, et le cadeau arrive avec une célébration et le nom de celui qui offre. Le serveur garde le destinataire au moment de l'achat et l'accorde au reçu. C'est l'un des gros moteurs de revenus des jeux sociaux, et ça renforce le jeu à plusieurs.

**11. Vitrine de la boutique dans le monde.** Effet ★, effort S.

Un kiosque doré sur la place, avec un coffre 3D qui s'ouvre en boucle (le même `ChestArt`). Il ouvre la boutique. Beaucoup de joueurs n'ouvrent jamais le menu.

**12. Serveurs privés.** Effet ★, effort S, réglage d'Antoine dans le Creator Hub.

## 🟡 Qualité

**13. Performance sur iPhone.** Effet ★★, effort M.

Plusieurs éléments comptent beaucoup de pièces :
- les mannequins de tenues (242 pièces chacun) ;
- le tableau à 4 faces ;
- les meubles v3.

Mesurer avec le MicroProfiler sur un vrai iPhone, puis fusionner ou alléger ce qui coûte.

**14. Petits défauts relevés par l'analyse de types.** Effet ★, effort S.

La vérification de types de luau-lsp sur tout le projet ne trouve aucune vraie erreur. On relève seulement des avertissements dus à l'ancienne façon de parcourir les tables, et des valeurs « peut-être nil » déjà protégées. Rien d'urgent ; à nettoyer si on passe le projet en `--!strict`.

**15. Une seule fenêtre au lancement.** Effet ★★, effort S.

En ouvrant le jeu cette nuit, deux fenêtres se suivaient : « THIS WEEK », puis le gain d'absence (« Your protein shaker worked… »). Elles bloquent le joueur avant qu'il ait fait quoi que ce soit. Il vaudrait mieux une seule carte de bienvenue qui regroupe tout : le gain d'absence, ce qui est à réclamer et le défi du jour. Elle se ferme d'un toucher.

## Ordre conseillé

1. Séance de test à l'écran (1), Kids / Select (2), une seule fenêtre au lancement (15).
2. Noël (3), à commencer tout de suite pour sortir début décembre.
3. Moments à partager (4) et notifications (7).
4. Boutique : tenue vedette (8), premier achat (9), kiosque (11), puis offrir à un ami (10).
5. Ascension (5) et force dans le monde (6) pour la fin de jeu.

## ❓ À décider par Antoine

- Faire un événement de Noël ? Quel exercice et quelle aide de saison ?
- Bonus du premier achat (×2 Cash) : d'accord ?
- Offrir à un ami : d'accord ? Seulement les packs, ou aussi les tenues ?
- Une seule carte de bienvenue au lancement à la place de la fenêtre hebdomadaire et du gain d'absence ?
- Le classement World doit-il compter le Mog acheté en Robux ? Question déjà posée en D136.
