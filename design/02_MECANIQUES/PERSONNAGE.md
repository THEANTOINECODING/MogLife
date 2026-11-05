# Personnage et boutique de style

## Le personnage du jeu

Chaque joueur incarne **un bro cartoon propre au jeu**, pas son avatar Roblox. Raison : l'avatar Roblox ne peut qu'être agrandi globalement, alors que la direction artistique exige des traits exagérés (torse en V géant, jambes en allumettes, mâchoire carrée).

- **Un corps par stade** (7 modèles : Normie, Gym Rat, Bro, Alpha, Chad, Gigachad, GOD MOGGER), du maigrichon au démesuré. Le MVP en contient 4 (Normie → Alpha).
- Le corps prend du muscle à chaque séance (D40, D60) : **pump** à chaque répétition (redescend en ~20 s) et **croissance continue** : pendant un stade, le corps (pièces et squelette) se rapproche du corps du stade suivant au rythme du Mog vers le boss ; battre le boss ne change plus la taille, seulement les détails (éclat doré).
- Tous les corps partagent le **même squelette** (rig compatible R15) : les animations, habits et coupes fonctionnent sur tous les stades.
- Taille plafonnée : le plus gros corps ne cache pas l'écran des autres et passe les portes.
- La taille ne donne aucun avantage en Mog-off.
- Le Normie est un « spaghetti » (D56) : torse, bras et jambes très fins, coudes et genoux noueux, short trop large.

## Création de personnage (D55)

Au premier lancement (avant l'intro de Muscle City), puis gratuitement au miroir de sa maison :

| Réglage | Choix |
|---|---|
| Corps | Masculin ou féminin : 14 corps (7 stades × 2), même squelette, même progression absurde. Le corps féminin porte toujours un haut (brassière de sport aux stades torse nu), une seule poitrine, rien de suggestif. |
| Peau | 10 teintes naturelles + 3 fantaisie (vert, bleu, lavande) |
| Cheveux | Coupe classique + 4 coupes gratuites (boucles, longs, chignon, carré) + celles achetées chez le coiffeur ; 10 couleurs + 6 fantaisie (barbes et sourcils suivent) |
| Yeux | 6 couleurs |
| Visage | Expression : sûr de lui, nerveux, déterminé (bouche et sourcils) |
| Tenue de départ | Couleur du haut et du short (12 couleurs) ; les habits de la boutique gardent les leurs |
| Surnom | Prénom + titre choisis dans une liste (« Brad "Spaghetti" »), affiché au-dessus de la tête ; pas de texte libre |

Boutons « Aléatoire » et « Voir mon futur moi » (aperçu en GOD MOGGER). **Pas de choix de taille** : elle vient du stade.
Listes et couleurs : `src/shared/Config/Look.luau`.

## La boutique de style

Le Cash sert **uniquement à l'apparence**. Aucun objet ne donne d'avantage.

| Catégorie | Exemples absurdes |
|---|---|
| **Coupes** | Banane géante, mulet, crête iroquoise, pompadour d'un mètre, chauve brillant (reflet animé) |
| **Barbes** (coiffeur) | Barbe de bûcheron, bouc diabolique, moustache en guidon, collier « du destin » |
| **Hauts** | Débardeur trop petit, débardeur « MOG », chemise hawaïenne, peignoir de boxeur |
| **Bas** (vêtements) | Short de sport fluo, jogging en velours, pantalon de cuir (ajoutés le 16/10) |
| **Accessoires** | Lunettes de soleil haltères, chaîne en or géante, bandeau, sifflet de coach |
| **Bronzage** | Naturel, doré, orange fluo (comme Brayan), « coup de soleil » |
| **Visage** (coiffeur) | Sourcils froncés, sourire éclatant, mâchoire encore plus carrée (ajoutés le 16/10) |

- Le **miroir** du magasin ouvre la boutique et l'essayage gratuit : un aperçu 3D (son propre corps de stade + sa tenue) montre l'article touché avant de l'acheter.
- Chaque objet est modélisé pour les 7 corps (il épouse un Normie comme un GOD MOGGER) et suit le pump et la croissance (D41).
- Présentoirs : le magasin de vêtements expose des mannequins habillés (4 gabarits), le coiffeur des têtes coiffées et barbues.
- Chaque boss vaincu donne un objet exclusif.
- Prix affichés clairement, achat confirmé, objets conservés pour toujours.
- MVP : environ 15 objets (5 coupes, 5 hauts, 5 accessoires). Chaque mise à jour en ajoute une série à thème (plage, Lune, Olympe…).

### Refonte de la garde-robe (D70, préparation du 18/10/2026)

Les 34 articles déjà possédables sont reconstruits dans Blender avec des détails de silhouette et des finitions plus visibles. Leurs identifiants restent identiques : les achats déjà sauvegardés ne sont pas perdus. Trois ensembles originaux sont préparés, chacun avec un haut, un bas et une pièce de tête. Les thèmes provisoires sont sport rétro fluorescent, vedette de rue et champion doré. Ils ne seront ajoutés à la boutique qu'après la décision du créateur sur les thèmes, la vente et les prix.

Ce premier lot comptait 43 articles, chacun décliné pour les corps masculins et féminins des sept stades. Chaque pièce garde la même partie du squelette d'un stade à l'autre. L'import des FBX dans Studio reste manuel ; les nouveaux décalages de pièces sont préparés à part pour être activés au même moment que les modèles.

### Ensembles de vêtements (D71, préparation du 18/10/2026)

Le premier lot D70 a été jugé trop simple. La nouvelle sélection visée contient 20 ensembles originaux, chacun avec haut et bas. L'achat et l'équipement se font en un clic ; une fois achetées, les deux pièces sont aussi disponibles séparément dans la garde-robe. Les vêtements anciens déjà possédés restent accessibles au joueur. Les coiffures, barbes, visages et accessoires gardent leurs catégories.

Les 20 ensembles sont construits dans Blender pour les 14 corps. La refonte D73 mesure les coques du torse, des manches et des jambes sur la surface réelle des corps ; elle varie les coupes, longueurs, cols et panneaux tout en conservant les noms, couleurs et identifiants. Au cours d'un stade, le corps et les habits soudés à une même partie R15 suivent un facteur de taille commun, puis le pump, afin de conserver leur ajustement. Une vérification géométrique couvre les corps au repos, au pump maximal et à plusieurs degrés de croissance ; l'essai des nouvelles formes en mouvement dans Studio attend l'import manuel des FBX. Antoine a activé la vente de 45 à 1 250 Cash (D72). Les pièces déjà possédées restent disponibles séparément. Certains ensembles ont des particules discrètes, visibles uniquement par le porteur et désactivables dans Settings.

**Pourquoi un joueur pourrait choisir une tenue :** une étude expérimentale sur les cosmétiques a trouvé que choisir son apparence renforçait l'identification à son avatar ; elle n'a pas montré d'effet significatif sur le plaisir ou la performance, et ne prouve pas une hausse des achats. On privilégie donc les silhouettes reconnaissables, la liberté de mélanger les pièces et l'essayage sur son propre corps. La documentation Roblox recommande une présentation claire des produits et déconseille les fausses urgences ou promotions trompeuses, particulièrement dans un jeu tous publics. Les prix et l'attrait réel des looks seront évalués auprès de testeurs, pas déduits de ces sources.

Sources : [étude expérimentale sur la personnalisation](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2021.770139/full) ; [Roblox Creator Hub, monétisation](https://create.roblox.com/docs/production/monetization).

## Articles de luxe à effets (D112)

Chez Swole Threads, onglets Traînées, Auras, Entrées (`Config/Luxury.luau`) : 2 000 à 10 000 Cash, vus par tous les joueurs, coupés chez soi par le réglage « Outfit effects ». L'entrée se joue au début d'un duel, d'un Mog-off ou du combat du Colisée. Leur prix compte dans le Drip (D111). ❓ Prix à calibrer pendant l'alpha.
