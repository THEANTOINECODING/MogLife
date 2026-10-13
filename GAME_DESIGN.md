# MOG LIFE : become a GOD MOGGER 💪🗿 — Document de conception V2
Version : 13 octobre 2026
Statut : proposition de conception à tester, pas constat d’implémentation.

> Source de vérité pour la direction du jeu. Claude Code et Codex implémentent une étape à la fois, selon les priorités de ce document.
> Les fonctionnalités signalées comme existantes viennent du document du créateur ; elles doivent être vérifiées dans le dépôt.
> Les nombres sont des paramètres initiaux. Les durées sont des objectifs de conception, pas des résultats mesurés.
> Aucun objectif de popularité, de rétention ou de revenu n’est garanti par ce document.

## 1. Vision et promesse

**En une phrase :** Pars d’un garage avec un haltère ridicule, transforme ton avatar en légende de la musculation et gagne des confrontations de poses spectaculaires dans une ville qui devient toujours plus absurde.

**Promesse au joueur :** « Je change vraiment d’apparence, je réussis des défis marrants et je peux montrer mon style aux autres. »

MOGLIFE est une comédie de progression sociale. La musculation alimente la transformation ; le Mog est la scène sur laquelle le joueur la montre.

Public visé : joueurs Roblox qui aiment la progression visible, les défis courts et jouer avec leurs amis. Conception mobile en priorité, avec commandes PC et manette équivalentes. La classification finale dépendra du contenu réellement produit et du questionnaire Roblox ; ne pas présumer une conformité « tous âges ».

Référence créative : reprendre de Douchebag Workout 2 la transformation, les activités et la parodie du gym bro. Créer nos propres personnages, décors, sons, animations, interfaces et textes. Ne pas reproduire ses assets ou sa présentation à l’identique.

### Trois piliers

1. **Transformation lisible :** en quelques minutes, le joueur voit une différence et débloque une animation ou un équipement.
2. **Spectacle comique :** haltères improvisés, coach théâtral, rivaux et cinématiques très courtes.
3. **Mog jouable :** des duels consentis de timing, avec chances égales, qui ne se résument pas à comparer deux compteurs.

### Ce que nous évitons

Cliquer pendant dix minutes sans décision ; ajouter cinq monnaies ; bloquer le jeu derrière une énergie ; copier les pet simulators ; multiplier les achats dès l’arrivée ; perdre sa progression parce qu’on perd un duel.

La rejouabilité recherchée vient de la maîtrise, des transformations, des objectifs et des amis. Pas de pénalité d’absence, de fausse urgence ou d’achats aléatoires payants.

## 2. Les boucles de jeu

### Boucle de 30 à 90 secondes

Choisir un exercice → effectuer une série avec un peu de timing → gagner Force et Cash → constater sa transformation → voir le prochain objectif.

### Boucle de 3 à 8 minutes

S’entraîner → acheter une amélioration → défier un rival PNJ ou participer à un Mog → obtenir une récompense visible → débloquer la suite.

### Boucle de session, environ 15 à 25 minutes

Atteindre un palier personnel, battre un rival, faire quelques duels puis repartir avec un prochain objectif explicite. Le joueur peut aussi s’arrêter après un seul défi sans perdre ses gains.

### Boucle de retour

Continuer un chapitre de rivaux, maîtriser un exercice, compléter une collection de poses, retrouver ses amis. Plus tard : défis hebdomadaires accessibles sur plusieurs sessions, sans obligation quotidienne.

La progression doit proposer deux choses : quelque chose à obtenir rapidement et quelque chose de spectaculaire à entrevoir.

## 3. Première expérience : les cinq premières minutes

| Temps cible | Expérience | Résultat attendu |
|---|---|---|
| 0–15 s | Arrivée devant le coach et un haltère bricolé ; une seule instruction | Le joueur comprend quoi faire |
| 15–45 s | Première série ; feedback visuel immédiat | Il voit qu’il progresse |
| 45–90 s | Petite transformation et première amélioration accessible | Première décision d’achat |
| 1–3 min | Duel tutoriel contre un PNJ indulgent | Il comprend le Mog |
| 3–5 min | Nouveau rang, exercice ou pose | Il veut essayer la nouveauté |

Le tutoriel est contextuel, rejouable et quittable. Le PNJ adapte sa difficulté après plusieurs échecs, sans vendre de solution. Aucun paiement nécessaire pour le terminer.

Dès l’arrivée : montrer un aperçu du quartier suivant et un avatar PNJ avancé. Ne pas remplir l’écran de boutiques.

**Moment signature :** le premier duel se termine avec une pose exagérée, un souffle qui fait voler les serviettes et le coach qui annonce : « Le garage n’était pas prêt. » Scène de 2–3 secondes, quittable, sans bloquer les autres.

## 4. Statistiques et progression corporelle

| Donnée | Fonction | Règle |
|---|---|---|
| Force | Progression PvE, exercices, rangs et zones | Augmente ; jamais retirée par un duel |
| Cash | Améliorations et accessoires gratuits | Gagné en jouant ; dépensé explicitement |
| Mog | Réputation gagnée en défis et duels | Débloque poses, titres et effets ; aucune puissance |
| Rang | Palier dérivé de la Force | Pas une monnaie |
| Maîtrise d’exercice | Extension ultérieure | Pas dans le MVP |

**Énergie : supprimée du MVP.** Elle risquerait de couper la boucle avant qu’elle soit plaisante. Les pauses sont des choix d’activité, pas des attentes imposées.

La Force est une progression fictive, pas une évaluation de l’apparence réelle des joueurs. L’humour vise les personnages et les situations ; pas le genre, les origines, le handicap ou le corps réel des personnes.

### Corps et lisibilité

- Progression visuelle continue à l’intérieur de chaque rang.
- Changements marquants au passage de rang : posture, épaules, silhouette, animation.
- Échelle plafonnée : aucun avatar ne masque le jeu ou ne bloque une porte.
- Collider et déplacements compatibles avec tous les paliers ; la taille ne donne aucun avantage en duel.
- Conserver les choix d’apparence du joueur lorsque le rig le permet.
- Toute transformation doit être réversible visuellement et testée sur les rigs effectivement pris en charge.
- Ne pas refaire immédiatement le système existant si une adaptation suffit.

Le Gigachad est un personnage de comédie et un accomplissement du jeu, pas une norme physique à atteindre dans la vie réelle.

## 5. Entraînement : simple, mais réellement interactif

### Contrôles

Le joueur sélectionne une station et s’entraîne. Le spam ne donne pas davantage de répétitions : le serveur valide au maximum une répétition par seconde dans le prototype.

Deux façons gratuites de jouer :
- **Maintenir :** rythme automatique à l’entraînement, sans bonus de précision.
- **Timing actif :** une pression par répétition ; le placement sur une jauge apporte un petit bonus.

Coefficients initiaux :
- Normal ou maintien : x1.
- Good : x1,2.
- Perfect : x1,5.
- Une tentative ratée donne le gain normal, mais pas le bonus.

Sur mobile, maintenir et jouer le timing doivent être des actions clairement distinctes. Aucun clic plus rapide ne peut accélérer la cadence. Le timing utilise une entrée simple, jamais des gestes rapides ou du multitouch obligatoire.

Une série dure 20 répétitions. À sa fin, proposer continuer, changer d’exercice ou aller au défi. Aucune pénalité de sortie anticipée ; les répétitions validées restent acquises. Les bonus de combo et QTE supplémentaires sont reportés.

### Exercices initiaux

| Exercice | Force/rép normale | Cash/rép | Force requise | Zone | Interaction visuelle |
|---|---:|---:|---:|---|---|
| Curl improvisé | 1 | 1 | 0 | Garage | Haltère dépareillé |
| Pompes | 2 | 1 | 120 | Garage | Tapis rafistolé |
| Développé couché | 4 | 2 | 600 | Quartier | Banc grinçant |
| Squat | 8 | 3 | 2 000 | Quartier | Barre avec pneus |

Ces valeurs remplacent les hypothèses du premier document après validation. Les animations et stations doivent être suffisamment différentes pour que le nouvel exercice soit une découverte.

À ajouter seulement après validation de la boucle : tractions, soulevé de terre, retournement de pneu, portage de voiture, haltère satellite. Une nouvelle activité doit changer une animation, un défi ou une interaction ; pas seulement un multiplicateur.

### Calcul initial

Force gagnée = BaseForce × EquipmentMultiplier × TimingMultiplier.
Cash gagné = BaseCash.

Équipement : un seul multiplicateur actif, jamais un produit cumulatif de toutes les améliorations. Aucun bonus premium ni boost temporaire dans le MVP. Le serveur garde les fractions ; l’interface peut arrondir l’affichage.

Le maintien rapporte le même gain normal que le timing raté. Jouer activement peut aller jusqu’à 50 % plus vite, mais l’accès au contenu ne nécessite pas des Perfect.

## 6. Cash, équipements et choix

### Améliorations initiales

| Amélioration | Coût Cash | Multiplicateur actif | Condition |
|---|---:|---:|---|
| Kit bricolé | Gratuit | x1 | Départ |
| Kit correct | 60 | x1,15 | 30 Force |
| Kit solide | 180 | x1,35 | 120 Force + kit précédent |
| Kit de quartier | 450 | x1,60 | 600 Force + kit précédent |

Chaque coût est le prix du passage, sans remboursement automatique des achats précédents. Les upgrades sont compatibles avec tous les exercices : elles améliorent le matériel utilisé à chaque station.

Afficher prix, multiplicateur avant/après et aperçu. Ne pas inventer un « retour sur investissement » en Cash : ces équipements accélèrent la Force, pas les revenus Cash par répétition.

Des accessoires gratuits utilisent aussi le Cash : bandeau, débardeur, lunettes cartoon. Leur prix se calibre après les upgrades pour éviter qu’un achat esthétique précoce bloque la progression. La confirmation rappelle lorsqu’un objet est purement cosmétique.

Pas de vente obligatoire de Force, pas de capacité de sac, pas de déplacement jusqu’à un vendeur toutes les trente secondes.

**Boosts reportés :** si ajoutés, privilégier un smoothie fictif, une récompense d’activité et une durée d’usage actif. Pas de représentation de dopage ou de promesse sanitaire. Pas de cumul incontrôlé des multiplicateurs.

## 7. Rangs, zones et chapitres

### Rangs : hypothèses initiales

| Rang | Force | Récompense de passage |
|---|---:|---|
| Rookie / Normie | 0 | Pose de départ |
| Gym Rat | 120 | Nouvelle posture |
| Bro | 600 | Accès quartier |
| Alpha | 2 000 | Squat et pose |
| Chad | 6 000 | Accessoire et rival de chapitre |
| Gigachad | 12 000 | Introduction du prochain chapitre |

« Rookie » peut remplacer « Normie » si les tests montrent que le second crée un ton désagréable. Le rang ne peut pas être choisi arbitrairement par le client.

Les seuils du premier document sont trop espacés pour être retenus sans simulation. Par exemple, passer de 100 à 1 000 Force à 3 Force/rép exige 300 répétitions : cinq minutes à une répétition/seconde, avant les déplacements et autres activités. D’autres paliers y seraient beaucoup plus longs.

### Zones

| Zone | Accès | Contenu distinct | Version |
|---|---|---|---|
| Garage de maman | Immédiat | Curl, pompes, coach, rival introductif | MVP |
| Salle de quartier | 600 Force | Banc, squat, estrade de Mog, rival | MVP |
| Muscle Beach | Hypothèse : 12 000 Force | Défis de portage et coopération | Extension |
| Temple du Pump | À équilibrer | Défis avancés et spectacle final | Extension |

Dans le MVP, le prochain chapitre est annoncé honnêtement comme à venir ; ne pas montrer un portail utilisable vers une zone inexistante. Gigachad donne une récompense réelle même si Muscle Beach n’est pas encore publiée.

La carte initiale est compacte, avec vue sur les stations et l’estrade. Aucun long trajet entre deux étapes du tutoriel. Ne pas créer quatre grandes cartes avant d’avoir une première zone plaisante.

## 8. Le Mog : mécanique signature

**Définition :** une confrontation courte de poses et de timing. Le personnage paraît puissant ; le joueur doit quand même bien jouer.

### Mode PvP du MVP

- Invitation explicite et acceptation des deux joueurs.
- Invitations désactivables ; mode spectateur possible.
- Aucune invitation pendant le tutoriel, un entraînement actif ou un duel.
- Délai global d’invitation : 30 secondes.
- Après refus : aucune nouvelle invitation du même joueur pendant 5 minutes.
- Refus automatique après 10 secondes, sans pénalité.
- Positionnement sur une estrade dédiée ; aucune collision exploitable pendant le duel.
- Un duel dure environ 15–20 secondes, puis une scène très courte.

### Déroulement précis

Trois manches. À chaque manche, trois signaux de timing espacés et prévisibles. Neuf entrées au total.

Pour chaque signal : score de 0 à 100 calculé selon l’écart au centre de la fenêtre, avec tolérance réseau bornée et vérifiée côté serveur. Une entrée manquante vaut 0. Fenêtre initiale : ±350 ms ; centre Perfect : ±70 ms. Ce sont des paramètres à ajuster par appareil et avec mesures de latence.

Score final = moyenne des neuf scores.
Différence de moins de 2 points : égalité.
Sinon, meilleur score : victoire.

Les deux participants jouent le même motif et ont les mêmes fenêtres. Pas de hasard décisif, de bonus de Force, de tenue, de Mog, de paiement ou d’ami dans ce calcul.

**Pourquoi la Force compte quand même :** elle ouvre les défis PNJ, les exercices, les zones et les transformations. Elle rend le joueur spectaculaire ; le PvP mesure sa maîtrise. Ne pas promettre des chances égales tout en cachant un bonus de statistiques.

### Résultat et récompenses

- Victoire : +10 Mog.
- Égalité : +6 Mog chacun.
- Défaite terminée avec participation : +3 Mog.
- Aucune perte de Force, Cash, taille permanente ou objets.
- Abandon volontaire : aucune récompense ; l’autre reçoit sa récompense seulement si le duel avait commencé et si sa participation est valide.
- Participation valide : au moins six entrées acceptées ; pas de récompense sur simple présence.

Récompenses limitées aux trois premiers duels terminés d’une même paire de comptes par jour UTC ; suivants disponibles en entraînement sans Mog. Le compteur de paire doit être persistant et partagé entre serveurs, pas seulement conservé en mémoire du serveur courant. Si cette protection est indisponible, désactiver les récompenses PvP en alpha, conserver les duels et les récompenses PNJ.

Cette limite réduit les abus entre amis mais ne résout pas à elle seule le multi-compte. Ne pas ouvrir une économie échangeable ou un classement récompensé avant d’avoir observé les abus.

Le Mog est une réputation cumulée, pas un classement de compétence. Ne pas appeler le joueur au plus haut Mog « meilleur duelliste ». Les classements compétitifs sont reportés.

### Mise en scène

Le gagnant pose ; les serviettes s’envolent ; le perdant fait un geste comique bref. Si un effet de rétrécissement est testé, le proposer comme effet visuel réversible et désactivable, sans modifier les vraies statistiques.

Pas d’annonce humiliante dans tout le serveur, de surnom imposé au perdant ou de messages de provocation ciblés. Le spectacle suffit.

Réduction des secousses, effets lumineux modérés, volume des cris indépendant et cinématiques quittables.

## 9. Rivaux PNJ et humour

Les PNJ assurent que le jeu fonctionne seul ou dans un serveur presque vide.

| Rival | Personnalité | Défi | Condition initiale |
|---|---|---|---|
| Kevin « demain je commence » | Se donne des excuses extravagantes | Tutoriel de poses | Premières séries |
| Coach Turbo | S’encourage lui-même au mégaphone | Timing régulier | 120 Force |
| Monsieur Pas-Les-Jambes | Porte des chaussettes énormes | Défi de squat et pose | 2 000 Force |
| Le Roi du Quartier | Entre avec son propre ventilateur | Final de chapitre | 6 000 Force |

Chaque rival possède un objectif de score explicite et une animation originale. Force requise = accès ; score de timing = réussite. La victoire ne doit pas être automatiquement accordée par une grande Force.

Récompenses de première victoire : respectivement 10, 20, 30, 40 Mog et une pose ou un élément de collection selon le rival. Victoires répétées : entraînement gratuit sans monnaie supplémentaire dans le MVP. Ne jamais farmer le tutoriel.

Exemples de répliques :
- « Cette barre a peur de toi. Enfin… elle grince surtout. »
- « Ce n’est pas un garage. C’est un centre de recherche sur les biceps. »
- « Le jour des jambes est enfin arrivé. Il avait raté le bus. »

Le texte doit rester court, localisable et ne pas interrompre chaque série. Les rivaux peuvent se moquer d’eux-mêmes.

## 10. Mog, collection et identité

Premiers paliers de réputation :

| Mog cumulé | Déblocage |
|---:|---|
| 10 | Pose « miroir du garage » |
| 30 | Titre « Habitué du pump » |
| 60 | Pose « ventilation maximale » |
| 100 | Aura cartoon discrète |
| 180 | Pose « entrée de légende » |

Une pose débloquée se sélectionne depuis un menu simple. Toutes les poses ont exactement la même valeur compétitive. Prévoir un accès direct à l’aperçu, sans achat.

La collection et les succès sont sauvegardés définitivement. Les joueurs montrent leur identité sans devoir acheter de puissance.

Extensions possibles : badges de maîtrise, défi coopératif de portage, décoration d’un casier, album de transformations. Choisir la prochaine extension après observation des joueurs ; ne pas tout implémenter.

## 11. Progression et équilibre

### Objectifs de rythme

- Feedback perceptible dès la première répétition.
- Premier achat en environ une minute de jeu actif.
- Première confrontation dans les trois premières minutes.
- Première nouvelle activité en 2–5 minutes.
- Quartier en environ 5–10 minutes, selon les activités choisies.
- Au moins trois découvertes substantielles dans les vingt premières minutes.
- Chad / Gigachad : tester une cible de 20–45 minutes selon le mode de jeu ; ne pas l’imposer si les chiffres et les déplacements ne la permettent pas.

Les récompenses ne doivent pas toutes être un nombre supplémentaire : nouvel exercice, rival, zone, pose, effet ou changement de silhouette.

### Simulation demandée avant retouche globale

Simuler au minimum :
1. Maintien gratuit, achats optimaux, sans duel.
2. Timing moyen, avec achats et temps de trajet.
3. Joueur orienté duels, qui s’entraîne moins.
4. Joueur qui achète tôt un accessoire.
5. Joueur qui ne connaît pas encore le meilleur chemin.

Rapporter temps jusqu’aux exercices, rangs et achats, temps sans nouveauté, revenus et dépenses. Déclarer chaque hypothèse : cadence, précision moyenne, pauses, trajets et décisions d’achat.

Un calcul théorique d’entraînement continu est une borne, pas une session humaine. Comparer ensuite à des tests réels. Ajuster un groupe de paramètres à la fois et conserver l’ancienne configuration.

Pas de rebirth dans le MVP. Ultérieurement, un nouveau chapitre peut proposer une progression nouvelle sans retirer les zones, achats et collections déjà gagnés.

## 12. Monétisation

**Décision initiale : aucune boutique payante dans le prototype de boucle.**

Pour la première version publique, privilégier :
- Packs cosmétiques à contenu explicite.
- Animations d’entrée et poses sans avantage.
- Effets visuels, avec réglage de discrétion pour les autres.
- Personnalisation du casier si cette fonction existe réellement.

Ne pas vendre x2 Force, auto-entraînement, Cash ou victoire au lancement. Le maintien d’entraînement est gratuit. Vendre l’auto-entraînement supprimerait une commodité utile et risquerait de rendre la boucle passive centrale.

Si des accélérateurs sont envisagés plus tard : décision séparée, tests du parcours gratuit, plafonnement et exclusion absolue du score PvP. Aucun prix Robux définitif avant validation de l’offre et des intégrations.

Règles d’interface :
- Aucun achat proposé pendant les premières minutes ou après une défaite.
- Prix et contenu exacts visibles ; aucune économie fictive.
- Pas de faux compte à rebours, de pénalité d’absence ou de popups répétés.
- Pas de coffres aléatoires payants.
- Objet payé permanent correctement restauré après reconnexion.
- La confirmation officielle Roblox termine l’achat ; un événement client ne suffit pas à accorder un produit.

La monétisation doit s’ajouter à un jeu déjà plaisant. Les règles de plateforme devront être recontrôlées au moment de publier.

## 13. Présentation, son et interface

Direction : comédie cartoon lisible, gym de quartier chaleureuse, matériaux volontairement bricolés, contrastes forts. Éviter le réalisme anatomique et les menus surchargés.

HUD principal : Force, Cash, prochain objectif et bouton Mog/collection. Mog détaillé dans son panneau ; ne pas multiplier les jauges à l’écran.

Feedback de répétition : animation fluide, son bref, gain discret. Pas de pluie permanente de nombres. Passage de rang : effet plus fort mais court.

Sur mobile :
- Contrôles adaptés aux zones de pouce et tailles d’écran.
- Interface sans chevauchement avec les boutons Roblox.
- Prévoir maintien gratuit et options de réduction des effets.
- Tester sur de vrais appareils modestes, pas seulement en émulation Studio.

Objectif de performance : au moins 30 FPS sur l’appareil mobile de référence choisi pour les tests, avec joueurs et effets. Mesurer l’appareil et les conditions ; ne pas annoncer une garantie universelle.

## 14. MVP et ordre de construction

### État signalé par le créateur, à vérifier

Clic de répétition, Force, Cash, élargissement du corps et rangs.
Fichiers connus : src/shared/Config/Exercises.luau et src/shared/Config/Ranks.luau.
Aucun autre chemin ou service n’est présumé existant.

### Étape A — Auditer et rendre l’entraînement plaisant

Inventaire réel du dépôt ; sauvegarde de référence ; répétitions serveur ; maintien gratuit ; timing ; caméra et feedback ; un exercice.
Validation : cinq minutes jouables sans spam nécessaire, entrée mobile fonctionnelle, aucune récompense client arbitraire.

### Étape B — Première boucle complète

Garage et quartier compacts ; quatre exercices ; quatre kits ; rangs recalibrés ; premiers PNJ et poses ; sauvegarde fiable.
Validation : un nouveau joueur comprend seul, obtient son premier achat et participe à un défi ; simulation disponible.

### Étape C — Mog PvP

Invitations, estrade, timing égalisé, résultats, protection des refus, récompenses protégées, déconnexions.
Validation : deux clients réels ; un nouveau joueur peut gagner contre un ancien à meilleure précision ; un refus bloque les relances prévues.

### Étape D — Alpha et corrections

Petits groupes externes, tests mobile, observation des abandons, correctifs, instrumentation et contenu manquant.
Validation : joueurs capables de reformuler le but et de citer ce qu’ils veulent débloquer ensuite.

### Étape E — Publication et cosmétiques

Seulement après la stabilité et la validation de la boucle : produits explicites, localisation minimale, icône et miniatures honnêtes, description et règles de publication contrôlées.

**Hors MVP :** pets, trading, clans, maisons, saisons payantes, tournois mondiaux, rebirth, simulation alimentaire, quatre mondes complets, multiples stats anatomiques et gains hors ligne. Toute extension exige une raison observée et un coût estimé.

## 15. Mesures et tests joueurs

Événements proposés :
- first_rep, first_upgrade, first_rank, first_npc_duel, first_pvp_duel.
- exercise_unlocked, zone_unlocked, tutorial_completed.
- duel_invited, duel_accepted, duel_declined, duel_completed.
- session_started et progression snapshots espacés ; éviter un événement par clic.

Suivre :
- Temps médian et distribution jusqu’au premier achat et premier duel.
- Abandon à chaque étape du tutoriel.
- Exercices et activités réellement choisis.
- Duels acceptés, terminés, rejoués et différences selon appareil.
- Retours D1 et D7 par cohorte dans les analytics Roblox lorsqu’ils sont disponibles.
- Erreurs de sauvegarde, latence, FPS et achats non livrés après activation de la boutique.

Pas de pourcentage de rétention universel annoncé comme preuve de succès. Comparer les versions sur des cohortes comparables et noter les effectifs. Dix testeurs peuvent révéler des problèmes ; ils ne prouvent pas une rétention future.

Questions de fin de test :
« Quel était ton prochain objectif ? »
« À quel moment t’es-tu ennuyé ? »
« Quelle activité voulais-tu refaire ? »
« Pourquoi voudrais-tu inviter un ami ? »

Si les joueurs apprécient l’idée mais abandonnent avant le Mog, raccourcir l’accès au Mog avant d’ajouter des mondes. S’ils veulent répéter les duels mais évitent l’entraînement, repenser son rôle et son rythme.

## 16. Instructions pour Claude Code et Codex

### Contrat de travail

1. Lire ce document, les instructions du dépôt et le code réel avant d’éditer.
2. Distinguer : existant vérifié, existant déclaré, spécification nouvelle, extension.
3. Ne pas réécrire tout le projet. Livrer une tranche jouable à la fois.
4. Ne pas inventer des dépendances, assets, résultats de tests ou états de Studio.
5. Garder les valeurs d’équilibre dans des configurations centralisées.
6. Respecter l’architecture et les conventions du dépôt ; les chemins supplémentaires ci-dessous sont des suggestions.
7. Expliquer toute divergence de conception avant de l’implémenter si elle change le jeu.
8. Ne jamais marquer « testé dans Roblox Studio » sans test réellement effectué.
9. À chaque livraison : fichiers modifiés, résultat jouable, tests faits, limites, prochaine étape.
10. Éviter que Claude et Codex modifient les mêmes fichiers en simultané. Utiliser un responsable par lot, des commits courts et une passation explicite.

### Configurations suggérées

Conserver Exercises.luau et Ranks.luau si leur structure convient.
Envisager Economy, Mog, Zones et Cosmetics dans le même dossier de configuration, seulement si nécessaire.

État sauvegardé minimal : schemaVersion, Force, Cash, équipements achetés, rival victories, Mog, poses/objets débloqués, objet équipé et tutoriel. Rangs et zones peuvent être dérivés de la Force. Sauvegarder les compteurs anti-farm dans le système adapté à leur portée interserveurs.

### Autorité serveur

Le client envoie une intention, jamais un montant de récompense fiable.
Le serveur valide cadence, station, déblocages, distance, possession, coût, duel, invitations et participation. La précision du timing est soumise à des contrôles plausibles ; la rendre serveur-autoritaire ne suffit pas à supprimer l’automatisation.

Économie et sauvegarde : transactions cohérentes, gestion de reconnexion, migrations et protection contre écrasements concurrents. Échec de chargement ≠ profil vide à sauvegarder sur l’ancien. Les récompenses de première victoire et achats sont idempotents.

Monétisation future : vérification des droits côté serveur et attribution idempotente des achats via le mécanisme officiel approprié. Ne pas accorder de produit sur un simple signal client.

### Vérifications importantes

- Spam réseau et clic rapide : pas de gain au-delà de la cadence.
- Upgrade : pas de Cash négatif ni double dépense.
- Première victoire : pas de double récompense après reconnexion.
- Duel : pas de modification du résultat en envoyant un score arbitraire.
- Refus, sortie, égalité, latence élevée et serveur sans adversaire.
- Sauvegarde : pas de perte de progression ni écrasement d’un profil non chargé.
- Taille maximale : portes, caméra et collisions fonctionnent.
- Maintien gratuit : parcours de progression terminé sans achat.
- Récompenses PvP interserveurs : pas de remise à zéro au changement de serveur.

Privilégier tests de logique pour l’économie et scénarios Studio pour les interactions. Si Studio n’est pas accessible, fournir les étapes manuelles à faire et signaler ce qui reste non vérifié.

## 17. Définition de réussite de cette V2

Le prototype tient sa promesse si un nouveau joueur :
- comprend l’action immédiatement ;
- voit une transformation dans les premières minutes ;
- découvre une vraie nouvelle activité ;
- comprend que le Mog se joue, pas qu’il s’achète ;
- peut participer seul avec les PNJ ;
- repart avec un objectif choisi et mémorable.

Ce document organise une hypothèse de jeu. Les tests joueurs décident quelles parties méritent d’être approfondies.

## 18. Références de plateforme

Consultées le 13 octobre 2026. Les choix de conception et valeurs de ce document sont nos propositions ; ils ne sont pas des prescriptions Roblox.

- Boucles de jeu : https://create.roblox.com/docs/production/game-design/core-loops
- Rétention, tutoriel et performance : https://create.roblox.com/docs/production/analytics/retention
- Monétisation et présentation des offres : https://create.roblox.com/docs/production/monetization
- Standards de la communauté : https://about.roblox.com/community-standards

