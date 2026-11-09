# Importer la nouvelle garde-robe dans Roblox Studio

## Mise à jour D126 : tenues Robux + coupes + barbes (un seul fichier)

1. En mode **Edit**, importer **`MogLife_Update.fbx`** (3 864 pièces), avec `MogLife_Style.png` dans le même dossier.
2. Activer `StylePieces.pending.luau` dans `src/shared/Config/StylePieces.luau` (Rojo connecté). Le script en a besoin
   pour réparer les noms coupés.
3. Coller `tools/install_characters.luau` dans la barre de commande. Le script :
   - retire les anciennes pièces des tenues Robux, des coupes et des barbes ;
   - range les nouvelles ;
   - affiche le total (attendu : 6 958).
4. Enregistrer la place (Ctrl+S).

## Tenues Robux seulement (D125, le plus rapide)

Quand seules les tenues Robux ont changé, importer **`MogLife_Premium.fbx`** (3 388 pièces) au lieu de
`MogLife_Wardrobe.fbx` (6 706 pièces) :

1. Activer d'abord `StylePieces.pending.luau` dans `src/shared/Config/StylePieces.luau` (Rojo connecté) : le script
   s'en sert pour réparer les noms de plus de 50 caractères que l'importeur coupe (« GodMogger__InfernalDemo...tom__… »).
2. En mode **Edit**, importer `MogLife_Premium.fbx` (Accueil > Importer 3D), avec `MogLife_Style.png` dans le même dossier.
3. Coller le contenu de `tools/install_characters.luau` dans la barre de commande. Le script :
   - vérifie les 3 388 pièces et la texture ;
   - retire les anciennes pièces des 8 tenues Robux de `ReplicatedStorage.Style` ;
   - range les nouvelles ;
   - affiche le total (attendu : 6 706).
4. Enregistrer la place.

## État après l'import du 18/10/2026

Les 3 318 MeshParts et leur texture ont été installés dans `ReplicatedStorage.Style` depuis `MogLife_Wardrobe`. Les décalages de `StylePieces.pending.luau` ont été activés dans `src/shared/Config/StylePieces.luau` via Rojo. En Play, 42 combinaisons représentatives ont été chargées sur les 14 corps ; l'achat d'un ensemble, la croissance et le pump ont été vérifiés. La validation Blender couvre les 20 ensembles sur les 14 corps, avec zéro défaut de couverture dans ses échantillons. L'inspection visuelle en mouvement et la mesure de 30 FPS sur téléphone restent à faire.

Les étapes ci-dessous servent si la garde-robe doit être réimportée.

1. En mode **Edit**, importer `MogLife_Wardrobe.fbx` avec l'importeur 3D de Studio. Garder `MogLife_Style.png` dans le même dossier afin que Studio retrouve la texture. Ne pas modifier l'échelle à la main.
2. Vérifier que le modèle `MogLife_Wardrobe` apparaît dans `Workspace`, puis exécuter le contenu de `tools/install_characters.luau` dans la barre de commande. Le script vérifie les **3 318 pièces** et la texture avant de remplacer les anciens MeshParts dans `ReplicatedStorage.Style`.
3. Enregistrer la place. Les nouveaux décalages sont dans `StylePieces.pending.luau` ; les activer dans `src/shared/Config/StylePieces.luau` au même moment que les modèles importés, via Rojo.
4. Tester les tenues sur les corps féminins et masculins, pendant les animations, la croissance et le pump. Mesurer la fluidité sur un appareil mobile représentatif ; l'objectif de 30 FPS n'a pas encore été mesuré.

`MogLife_Characters.fbx` contient aussi les corps et sert uniquement si la bibliothèque complète doit être réimportée.
