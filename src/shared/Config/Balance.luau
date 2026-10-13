-- Toutes les valeurs d'équilibrage du jeu. Ne jamais mettre ces chiffres en dur ailleurs.

return {
	-- Données d'un nouveau joueur (aussi utilisé comme template ProfileStore)
	StartingData = {
		Strength = 0,
		Cash = 0,
		Mog = 0,
	},

	-- Anti-spam : délai minimum entre deux répétitions (secondes)
	TrainCooldown = 0.35,

	-- Distance max (studs) entre le joueur et l'appareil pour s'entraîner
	MaxEquipmentDistance = 12,

	-- Apparence : le corps s'élargit avec la force (échelle logarithmique)
	BodyScale = {
		MinWidth = 1,
		MaxWidth = 2.2,
		MinDepth = 1,
		MaxDepth = 1.8,
		StrengthForMax = 1_000_000,
	},
}
