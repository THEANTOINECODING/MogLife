# Reprise de la refonte des mini-jeux — 21 octobre 2026

## Point de reprise vérifié

L'audit est `MINIGAME_REVIEW_2026-10-21.md`. À la reprise, le dépôt contenait déjà une implémentation version 4 non livrée : règles et variantes, Auto, précision/combo, récompenses, contrôles par grille, interface mobile, budgets, messages explicatifs et annulation des puzzles. Ces changements ont été retrouvés dans les fichiers, pas reconstitués depuis une mémoire de conversation.

## Travail de cette reprise

- Relu les règles, le design D76/D77 et le code réel ; conservé les autres modifications présentes (assets, personnage, ville et autres systèmes).
- Formaté `src/` avec StyLua et validé le lot existant.
- Reproduit dans Studio un glissement de la première à la troisième case de Produce Parade, relâché sans événement move : zéro point et un échec malgré trois fruits valides.
- Corrigé `src/shared/Playground/init.luau` : le relâchement trace aussi la dernière portion du geste ; l'interpolation s'arrête dès une victoire ou une défaite.
- Ajouté dans `tests/playground_review.luau` une régression pour la chaîne de fruits et l'arrivée du trajet Shortcut Chalk.
- Actualisé `design/02_MECANIQUES/PLAYGROUND.md` avec le comportement version 4 déjà présent.

## Vérifications effectuées

Studio ciblé : MogLife, place 103855142580510. Les derniers tests de règles ont été exécutés côté serveur après redémarrage du mode Play pour utiliser les modules actualisés.

- `tests/playground.luau` : les 20 jeux solo passent, chacun sur trois graines, avec solution, échec inactif, géométrie de dessin valide et score immuable après la fin. Auto indisponible pour les boss.
- `tests/playground_review.luau` : 11 groupes passent. Inclut 12 graines pour chaque jeu assisté, 606 positions/graines stationnaires contre Brayan, Atlas sans visée, Rope Rave tout Good, reset Coach côté droit, attente sans bonus de paiement, pénalité des erreurs, combo accessible, undo, tolérance rythmique bornée, variantes et relâchement rapide.
- En mode Play côté client : création/destruction des 21 interfaces dans des conteneurs 390×844, 844×390 et 1366×768, soit 63 montages réussis. Taille non nulle et limites verticales du panneau vérifiées. Ce sont des tests de disposition, pas des sessions sur téléphone physique.
- StyLua exécuté ; Selene : zéro erreur, avertissement ou erreur de parsing. Construction Rojo réussie dans le dossier temporaire Windows.
- Console : avertissements Roblox FoundationProvider et asset 203785492 de type incompatible, déjà relevés dans l'audit initial. Aucune exception des mini-jeux relevée pendant les montages.

Les tests utilisent des états isolés sans appels de récompense, modification de profil ou déblocage. Le démarrage normal charge le profil existant. Interfaces temporaires détruites et Play arrêté en fin de vérification. Aucun commit ni publication.

## Limites et prochaine tranche

Le lot est validé automatiquement, pas déclaré terminé artistiquement ni validé par des joueurs. Restent le ressenti au doigt et à la manette, les mesures réseau avec latence/jitter, l'économie réelle, les duels à deux joueurs et la performance sur téléphone. Le test de délai rythme est une simulation d'état, pas une mesure réseau. Le reset gauche de Coach est couvert par le parcours de solution, pas encore par une régression dédiée de son échec gauche.

La prochaine tranche est un parcours manuel entraînement → aide → Kevin, avec vérification des résultats et du retour aux déplacements, puis les appareils physiques. La progression visuelle de Swing King, la profondeur de certains puzzles et la mise en scène restent des pistes de l'audit ; elles ne sont pas toutes achevées par les variantes actuelles. Le choix d'un nouveau principe pour Crown Sneak et le boss final restent séparés de cette correction.
