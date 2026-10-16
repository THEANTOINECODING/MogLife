# Personnage et boutique de style

## Le personnage du jeu

Chaque joueur incarne **un bro cartoon propre au jeu**, pas son avatar Roblox. Raison : l'avatar Roblox ne peut qu'être agrandi globalement, alors que la direction artistique exige des traits exagérés (torse en V géant, jambes en allumettes, mâchoire carrée).

- **Un corps par stade** (7 modèles : Normie, Gym Rat, Bro, Alpha, Chad, Gigachad, GOD MOGGER), du maigrichon au démesuré. Le MVP en contient 4 (Normie → Alpha).
- Le corps prend du muscle à chaque séance (décision D40) : **pump** à chaque répétition (redescend en ~20 s), **croissance permanente** dans le stade selon la progression du Mog vers le boss suivant, **transformation** en battant le boss. Technique : mise à l'échelle des pièces de la coque (une par partie du squelette).
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
