# Audit mobile et iPad — 19 octobre 2026

## Les dix problèmes signalés

| N° | Problème | État et constat |
|---:|---|---|
| 1 | Interface téléphone encombrée | HUD réduit à une ligne Mog/Cash sur écran tactile. Objectif, Weekly et boutons secondaires rangés dans Menu sur iPhone et iPad. Capture vérifiée sur iPhone 17 Pro en portrait. |
| 2 | Bouton courir | Ajouté et rendu plus visible en orange : maintien sur écran tactile, Shift au clavier ; vitesse décidée par le serveur. La course est bloquée pendant les activités et les fenêtres modales. |
| 3 | Trait jaune avant le boss | Faisceau retiré ; un petit repère reste près du boss. |
| 4 | Duels difficiles sur iPad | Jauge entièrement touchable ; titre, compteur, aide et Stop disposés à gauche. Capture de duel sur iPad Pro : la jauge reste dégagée et le joystick disparaît pendant la manche. |
| 5 | Boss impraticables sur téléphone et iPad | Le doigt de déplacement ne commande plus Spotlight/Wobble, les touches du mini-jeu restent dans son panneau et les commandes Roblox disparaissent pendant le combat. Panneau Wobble vérifié sur iPad. L'ajustement chiffré de difficulté attend le choix du créateur. |
| 6 | Statues dans le ciel | Le modèle est assemblé avant la mesure, puis posé sur le socle. Mesure Studio : bas du modèle et haut du socle coïncident à moins d'un millionième de stud. |
| 7 | Cheveux de couleur étrange | L'atlas importé affichait un damier noir et blanc malgré la bonne couleur. La texture des cheveux teints est désactivée à l'affichage ; la couleur choisie s'affiche uniformément. |
| 8 | Bras de fer peu épique | Coup final animé ajouté à chaque manche, avec une courte tenue de pose. Valeur d'inclinaison finale vérifiée en duel contre mannequin ; rendu final à apprécier en jeu. |
| 9 | Interface étrange sur iPad | Le HUD et les boutons restent masqués jusqu'à la fermeture des résultats de duel et de boss. La fenêtre Réglages défile si l'écran est bas. Captures de duel et de résultat de boss vérifiées sur iPad Pro. |
| 10 | Tête qui entre dans le torse | Non reproduit sur l'avatar Alpha féminin prêt à défier Mr. No-Legs, au repos et pendant les poses vues en duel et en combat. Le moment exact est demandé par QCM avant de modifier le squelette. |

## Problèmes supplémentaires trouvés pendant l'audit

- Les panneaux de mini-jeu hauts dépassaient certains écrans tactiles en paysage. Ils se réduisent avec leur contenu. Un panneau de 430 px mesure 307 px dans une surface simulée de 331 px de haut.
- Les textes et le bouton Stop recouvraient la jauge tactile en paysage. Une colonne de commandes les sépare désormais du panneau de jeu. Le HUD se masque pendant les séries.
- Le résultat de duel pouvait arriver après la fin de l'activité et laisser réapparaître le HUD derrière lui. La transition attend maintenant la fermeture de la fenêtre.
- La boutique, le créateur, la liste des meubles et certains messages avaient des tailles fixes gênantes en portrait. Leurs panneaux et listes ont été réorganisés pour les petits écrans.
- RUN recouvrait le saut sur un grand iPad ; il est placé au-dessus.
- La caméra apparaissait derrière le mur d'une maison et le panneau de propriété masquait le personnage. L'apparition a été reculée vers le trottoir, point vérifié sur les 20 parcelles ; le panneau s'efface localement quand la caméra est proche et le zoom tactile maximal est limité. La capture iPhone montre désormais le personnage et la rue.
- La qualité d'une répétition reste déclarée par le client. Le serveur contrôle le rythme, la distance et les gains, mais ne peut pas prouver un « Perfect ». Cette limite existante est également notée dans `design/02_MECANIQUES/MINIJEUX.md` ; une validation complète demanderait de revoir les protocoles des mini-jeux.

## Vérifications et limites

- `stylua src`, `selene src` : aucune erreur ni avertissement. `git diff --check` : propre.
- Tests Play via Rojo : iPhone 17 Pro en portrait, iPad Pro M5 et iPad 10e génération en paysage, duel contre mannequin, combat Mr. No-Legs, positions de statue et couleur des cheveux. La dernière correction de la caméra et du HUD est vérifiée visuellement sur iPhone et iPad 10e génération ; sur ce dernier, Menu s'ouvre et affiche Home, Flex, Style, Settings, Weekly et Next goal sans chevauchement. Un premier changement de profil iPad avait bloqué la caméra simulée à 1×1 pixel ; un nouveau lancement de Studio a permis de refaire le test. Aucune erreur de script du jeu dans la console ; avertissements Roblox CorePackages et erreur d'asset `203785492` sans instance du jeu identifiée.
- Les données du joueur test ont été remises à leurs valeurs initiales après chaque session. Studio est revenu en mode édition et le simulateur d'appareil a été arrêté.
- Les outils Studio ont permis de vérifier les zones et captures, mais pas la sensation d'un vrai doigt sur un appareil physique. Le réglage de difficulté des boss et le défaut de tête attendent les réponses au QCM.
