# Duels entre joueurs : Tug of Mog

Décision D67 (17/10/2026, choix du créateur). Un tir à la corde en rythme entre deux joueurs, sur une estrade de la
salle. C'est le seul mode où l'on affronte un autre joueur ; il complète le Mog-off contre les boss sans le remplacer.

## Lancer un duel

- On s'approche d'un autre joueur : un bouton **Tug of Mog** apparaît sur lui (touche F, Y à la manette).
- L'invité voit une fenêtre en haut de l'écran (« X challenges you to a Tug of Mog! ») avec **Accepter / Refuser**.
  Sans réponse au bout de 12 s, c'est un refus, sans pénalité.
- Garde-fous : pas d'invitation pendant le tutoriel, une série, une aide, un combat ou un autre duel ; 20 s entre deux
  invitations ; après un refus, le même joueur ne peut plus inviter celui-ci pendant 5 min ; le réglage
  **Duel invites** (Settings) coupe les invitations reçues.
- S'il accepte, les deux joueurs sont placés face à face sur l'une des **deux estrades** de la salle (de chaque côté
  du ring du Coach), puis ramenés à leur place à la fin. Les autres joueurs voient le duel : la corde et son drapeau
  sont visibles de tous.

## Le mini-jeu « Tug » (propre au duel, jamais utilisé ailleurs)

- La corde défile vers les mains du joueur. **Nœud rouge** : appuyer quand il est dans les mains.
  **Nœud doré** (long) : appuyer quand il arrive, maintenir, relâcher quand sa fin arrive.
- Chaque répétition tire la corde : Perfect 3 crans, Good 2, raté 0. La corde va de -12 à +12 : l'atteindre, c'est le
  K.-O. et la manche est gagnée tout de suite. Sinon, après 8 nœuds, la manche va au côté vers lequel penche la corde
  (0 = manche nulle).
- 3 manches, 2 gagnées = victoire. Chaque manche est plus rapide, avec des fenêtres plus serrées et plus de nœuds
  dorés.
- **Chances égales** : les deux joueurs reçoivent exactement la même suite de nœuds (même graine), les mêmes fenêtres
  et la même vitesse. Ni le Mog, ni le stade, ni la tenue n'entrent dans le calcul.

## Récompenses

- Cash selon le stade de chaque joueur : victoire > égalité > défaite (Config/Duels.luau). **Rien n'est jamais
  perdu.**
- Participation valide : au moins 4 tractions réussies (Good ou Perfect) pendant le duel. Un joueur inactif ne gagne
  rien.
- Plafond : les 3 premiers duels de la journée (UTC) avec le même joueur sont récompensés ; ensuite, duel « pour la
  gloire » (sans Cash ni victoire comptée). Le compteur est sauvegardé chez chacun des deux joueurs.
- Abandon (quitter, s'éloigner) : rien pour celui qui part. Si au moins une manche a été jouée, l'autre gagne ; sinon
  le duel est annulé.
- Les victoires comptées s'affichent à côté du surnom (« 🏆12 ») et débloquent des titres exclusifs (5, 25 et 100
  victoires), à choisir au miroir de la maison.

## Mise en scène

Bandeau VS, 3-2-1-PULL!, caméra de profil sur les deux joueurs, jauge de la corde (toi à gauche, en or ; l'adversaire à
droite, en rouge ; le drapeau glisse vers celui qui gagne), pastilles des manches, « ROUND WON / LOST », petit coup de
corde qui tire le perdant de la manche, pose de victoire du gagnant vue par tous, puis la fenêtre du résultat. Musique et
jingles du combat de boss.

## Tests

En Studio, `ServerStorage.DevCommands:Invoke("DuelBot", userId)` lance un duel contre un mannequin d'entraînement (pas
de vrai deuxième joueur nécessaire). Le vrai duel entre deux joueurs se teste avec le mode « Serveur et 2 clients » de
Studio.

## ❓ À régler pendant l'alpha

Montants de Cash, nombre de nœuds, vitesse, crans de traction et taille de la corde ; nombre d'estrades si elles sont
souvent occupées.
