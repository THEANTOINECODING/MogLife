-- Réglages du joueur (bouton « Settings » du HUD), sauvegardés (data.Settings) : on les retrouve à chaque session.
-- Tous des interrupteurs, activés par défaut. Ordre d'affichage = ordre de la liste.
-- Textes : Settings.<Id> (nom) et Settings.<Id>.Hint (explication).

return {
	List = {
		"Music", -- musique de fond
		"Sounds", -- effets sonores
		"ScreenFx", -- secousses, éclairs et coups spéciaux des boss, « punch » de caméra sur les Perfect
		"Vibration", -- petites vibrations du téléphone et de la manette pendant les mini-jeux (D81)
		"OutfitFx", -- petites particules de sa propre tenue, visibles uniquement par soi
		"CloseUp", -- gros plan de la caméra sur son personnage pendant les activités
		"Names", -- noms au-dessus des autres joueurs
		"Players", -- afficher les autres joueurs (les masquer allège l'écran et le téléphone)
		"Duels", -- recevoir des invitations de duel (bras de fer)
	},
}
