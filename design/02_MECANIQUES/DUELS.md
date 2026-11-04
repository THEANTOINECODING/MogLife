# Duels entre joueurs : bras de fer

> **D80, D81 : cette fiche fait foi.** La refonte de Codex (D76 à D79) est abandonnée (archive : `design/archive/PLAYGROUND_codex_abandonne.md`). Le geste exact de chaque mini-jeu, ses surprises et les règles communes (téléphone d'abord, main fantôme, plus de mode Auto) sont décrits dans [MINIJEUX.md](MINIJEUX.md).

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

## Le mini-jeu « Gauge » (D68, D81, propre au duel)

- Une aiguille balaie la jauge de force ; à chaque balayage, une zone verte (au cœur doré) apparaît à un autre endroit.
  Toucher l'écran (n'importe où), Espace ou A quand l'aiguille est dedans. Un appui par balayage ; un balayage sans
  appui est raté. Le bras se crispe et tremble quand l'aiguille entre dans la zone ; vibration à chaque poussée.
- ~~Dernier effort~~ (D81, retiré en D88 : Antoine ne l'aimait pas) : le dernier balayage de chaque manche avait 3 petites zones orange à toucher à la suite
  (3 = Perfect, 2 = Good, sinon raté).
- Chaque répétition pousse le bras : Perfect 3 crans, Good 2, raté 0. Les bras vont de -12 à +12 : l'atteindre, c'est
  **plaquer le bras de l'adversaire** et gagner la manche tout de suite. Sinon, après 8 balayages, la manche va au côté
  vers lequel penchent les bras (0 = manche nulle).
- 3 manches, 2 gagnées = victoire. Chaque manche est plus rapide et la zone plus étroite.
- **Chances égales** : les deux joueurs reçoivent exactement les mêmes zones au même moment (même graine), les mêmes
  fenêtres et la même vitesse ; ni le Mog, ni le stade, ni la tenue n'entrent dans le calcul. L'équivalence ressentie
  entre appareils attend des tests réels.

## Récompenses

- Le vainqueur gagne aussi du Mog (D88) : 0,6 % de son propre Mog, entre 5 et 1 500, mêmes conditions que le Cash
  (participation valide, limite par paire et par jour) ; rien pour une victoire par abandon.
- Cash selon le stade de chaque joueur : victoire > égalité > défaite (Config/Duels.luau).
- **Le perdant perd 15 % de son Mog** (D110, choix d'Antoine : « il faut perdre beaucoup »), jamais sous le Mog qu'il
  fallait pour atteindre son stade ; aussi en cas d'abandon en cours de duel. Annoncé dans l'invitation.
- Équité (D110) : la n-ième poussée d'un joueur ne compte qu'avec la n-ième de l'autre (chacun juge sur sa propre
  horloge) : le joueur au meilleur réseau ne peut plus plaquer le bras avant que les poussées de l'autre arrivent ;
  deux poussées collées par le réseau comptent toutes les deux. La jauge occupe la même part de l'écran sur tous les
  appareils (elle était minuscule sur tablette).
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
