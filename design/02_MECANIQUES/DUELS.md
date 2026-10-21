# Duels entre joueurs : bras de fer

> **D76 : les mini-jeux actuels sont décrits dans [PLAYGROUND.md](PLAYGROUND.md).** Les sections ci-dessous décrivent l'ancienne version, gardée pour l'historique. Identifiants de progression, déblocages et récompenses restent compatibles.

Décision D68 (18/10/2026, demande du créateur ; remplace le Tug of Mog de D67). Un bras de fer contre **n'importe quel
joueur, n'importe où** dans la ville. C'est le seul mode où l'on affronte un autre joueur ; il complète le Mog-off
contre les boss sans le remplacer.

## Lancer un duel

- On s'approche d'un autre joueur : un bouton **Arm Wrestle** apparaît sur lui (touche F, Y à la manette).
- L'invité voit une fenêtre en haut de l'écran (« X challenges you to an arm wrestle! ») avec **Accepter / Refuser**.
  Sans réponse au bout de 12 s, c'est un refus, sans pénalité. Personne n'est jamais forcé à jouer.
- Garde-fous : pas d'invitation pendant le tutoriel, une série, une aide, un combat ou un autre duel ; 20 s entre deux
  invitations ; après un refus, le même joueur ne peut plus inviter celui-ci pendant 5 min ; le réglage
  **Duel invites** (Settings) coupe les invitations reçues.
- S'il accepte, une **table de bras de fer apparaît entre les deux joueurs**, là où ils sont : sur un sol plat, avec
  assez de place (sinon le serveur essaie d'autres sens autour d'eux ; s'il n'y a vraiment pas la place, il le dit).
  Les deux joueurs se placent de chaque côté ; la table disparaît à la fin. Tout le monde voit le duel.

## Le mini-jeu « GripCounter » (D75, propre au duel)

- Chaque échange montre la prise que prépare l'adversaire parmi trois positions. Le joueur pose le doigt, clique ou
  maintient la direction correspondante, résiste, puis relâche lorsque la barre atteint la marque dorée. Le bon grip
  et le bon moment donnent Perfect ou Good ; une prise erronée, un contre trop tôt/tard ou l'inaction donnent Miss.
  Un seul geste maintenu par échange, sans multitouch et sans spam.
- Chaque répétition pousse le bras : Perfect 3 crans, Good 2, raté 0. Les bras vont de -12 à +12 : l'atteindre, c'est
  **plaquer le bras de l'adversaire** et gagner la manche tout de suite. Sinon, après 8 balayages, la manche va au côté
  vers lequel penchent les bras (0 = manche nulle).
- 3 manches, 2 gagnées = victoire. Chaque manche est plus rapide et la fenêtre du contre se réduit.
- **Chances égales** : les deux joueurs reçoivent exactement les mêmes prises et moments de contre (même graine),
  les mêmes fenêtres et la même vitesse. Les positions et le temps sont normalisés sur le panneau ; ni le Mog, ni le
  stade, ni la tenue n'entrent dans le calcul. L'équivalence ressentie entre appareils attend des tests réels.

## Récompenses

- Cash selon le stade de chaque joueur : victoire > égalité > défaite (Config/Duels.luau). **Rien n'est jamais
  perdu.**
- Participation valide : au moins 4 poussées réussies (Good ou Perfect) pendant le duel. Un joueur inactif ne gagne
  rien.
- Plafond : les 3 premiers duels de la journée (UTC) avec le même joueur sont récompensés ; ensuite, duel « pour la
  gloire » (sans Cash ni victoire comptée). Le compteur est sauvegardé chez chacun des deux joueurs.
- Abandon (quitter, s'éloigner) : rien pour celui qui part. Si au moins une manche a été jouée, l'autre gagne ; sinon
  le duel est annulé.
- Les victoires comptées s'affichent à côté du surnom (« 🏆12 ») et débloquent des titres exclusifs (5, 25 et 100
  victoires : Wrist Wrecker, Iron Grip, Unmoggable), à choisir au miroir de la maison.

## Mise en scène

Bandeau VS, 3-2-1-PUSH!, caméra de profil sur les deux joueurs autour de la table, jauge du bras de fer (toi à gauche,
en or ; l'adversaire à droite, en rouge ; le poing glisse vers celui qui gagne), pastilles des manches, « ROUND WON /
LOST », petit recul du perdant de la manche, pose de victoire du gagnant vue par tous, puis la fenêtre du résultat.
Coude sur la table, mains jointes au centre : elles basculent vers le coussin de plaquage selon le score en direct.
Musique et jingles du combat de boss.
Sur tablette, le panneau de prise a une grande surface tactile et le bouton d'arrêt reste hors du joystick. La fin
de chaque manche gagnée plaque le bras sur son coussin, même lorsque la limite de K.-O. n'a pas été atteinte.
En paysage tactile, le titre, le compteur, les retours et les commandes occupent une colonne à gauche de la prise.
La fenêtre du résultat garde cette disposition jusqu'à sa fermeture.

## Tests

En Studio, `ServerStorage.DevCommands:Invoke("DuelBot", userId, perfect?, good?)` lance un duel contre un mannequin
d'entraînement posé devant le joueur (pas de vrai deuxième joueur nécessaire). Le vrai duel entre deux joueurs se
teste avec le mode « Serveur et 2 clients » de Studio.

## ❓ À régler pendant l'alpha

Montants de Cash, nombre de balayages, vitesse, largeur des zones, crans de poussée ; taille de la table selon les
corps les plus grands.
