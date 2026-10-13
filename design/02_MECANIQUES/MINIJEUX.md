# Mini-jeux et exercices (mécanique principale)

**Chaque exercice a sa propre mécanique.** Les aides en ville et les combats de boss réutilisent ces mêmes mini-jeux : c'est ce qui garde le jeu simple à produire et varié à jouer.

## Règles communes à tous les mini-jeux

- **Une seule entrée simple** à la fois : un doigt sur mobile, souris ou clavier sur PC, équivalent manette. Jamais de multitouch obligatoire ni de clics frénétiques.
- Chaque répétition est notée : **Raté / Bien / Parfait**.
- Une **série** = 20 répétitions. À la fin : continuer, changer d'exercice ou aller voir le boss. Arrêter en cours ne fait rien perdre.
- Le serveur limite la cadence (environ **1 répétition par seconde**, ❓ à ajuster par mini-jeu) : jouer plus vite que l'animation ne rapporte rien de plus.
- Chaque mini-jeu a un **mode auto** gratuit (maintenir le bouton) qui donne le gain de base sans bonus, pour jouer détendu ou se reposer les doigts.
- Option d'accessibilité : fenêtres de timing plus larges.

## Gain de Mog

Mog gagné = Mog de base de l'exercice × multiplicateur de qualité

| Qualité | Multiplicateur ❓ |
|---|---|
| Raté ou mode auto | x1 |
| Bien | x1,25 |
| Parfait | x1,6 |

Le serveur garde les décimales ; l'interface arrondit.

## Les mini-jeux

### MVP

| Exercice | Mécanique | Mobile | PC | Mog/rép ❓ | Stade requis |
|---|---|---|---|---:|---|
| **Curl haltère** | Glisser de haut en bas en suivant le rythme de l'haltère | Glisser le doigt verticalement | Mouvement de souris | 1 | Normie |
| **Pompes** | Taper quand le cercle qui rétrécit touche la cible | Tap | Clic / Espace | 2 | Kevin battu |
| **Développé couché** | Maintenir pour pousser la barre, relâcher dans la zone verte | Maintenir puis relâcher | Maintenir le clic | 4 | Brayan battu |
| **Squat** | Garder la barre en équilibre alors qu'elle penche aléatoirement | Glisser à gauche / droite | A / D (ou souris) | 8 | Coach Turbo battu |

### Mises à jour suivantes

| Exercice | Mécanique |
|---|---|
| Tractions | Taper alternativement côté gauche / côté droit |
| Abdos | Tracer des cercles avec le doigt |
| Corde à sauter | Taper quand la corde passe, de plus en plus vite |
| Pneu géant | Remplir une jauge en maintenant, puis glisser vers le haut d'un coup |
| Soulevé de terre | Maintenir une aiguille qui tremble dans une zone étroite |
| Haltère satellite (Lune) | Même chose que le curl… en apesanteur, l'haltère flotte |

Un nouvel exercice doit avoir une **mécanique nouvelle** ou une **variation visible** d'une mécanique existante, et une station au visuel absurde différent.

## Réutilisation

| Mini-jeu | Réutilisé par |
|---|---|
| Glisser haut/bas (curl) | Aide : pomper le pneu du vélo du livreur |
| Cercle qui rétrécit (pompes) | Aide : planter les clous de la cabane |
| Maintenir/relâcher (développé couché) | Aide : pousser la voiture du voisin |
| Équilibre (squat) | Aide : porter le piano de Mme Do-Ré |
| Tous | Manches de Mog-off contre les boss |

## Sécurité

Le client envoie « je commence la série » puis, pour chaque répétition, son moment d'entrée. Le serveur vérifie la cadence, l'exercice débloqué, la station et la plausibilité du timing, puis calcule lui-même le Mog. Le client ne transmet jamais un montant.
