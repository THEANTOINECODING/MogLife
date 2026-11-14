-- Boutique Robux (D128, StoreController) et mannequins des tenues Robux du magasin de vêtements
-- (PremiumDisplayController). Les produits et leurs prix sont dans Products.luau et GamePasses.luau.

return {
	-- Onglets, dans l'ordre ; un onglet sans rien à vendre est caché
	Tabs = {
		{ id = "Outfits", color = Color3.fromRGB(150, 90, 240) },
		{ id = "Boosts", color = Color3.fromRGB(245, 150, 35) },
		{ id = "Cash", color = Color3.fromRGB(60, 190, 90) },
		{ id = "Mog", color = Color3.fromRGB(235, 70, 80) },
	},
	PreviewSpin = 0.7, -- radians par seconde : la tenue tourne dans l'aperçu

	-- Coffres des packs de Cash (vignette 3D), du plus petit au plus gros
	Chests = {
		{
			scale = 0.8,
			body = Color3.fromRGB(140, 88, 48),
			band = Color3.fromRGB(120, 124, 135),
			bills = 2,
			coins = 3,
		},
		{
			scale = 1,
			body = Color3.fromRGB(150, 90, 45),
			band = Color3.fromRGB(255, 200, 60),
			bills = 4,
			coins = 7,
		},
		{
			scale = 1.2,
			body = Color3.fromRGB(255, 196, 50),
			band = Color3.fromRGB(255, 240, 170),
			bills = 6,
			coins = 12,
		},
	},

	-- Mannequins des tenues Robux (pièces invisibles taguées « PremiumDisplay », attributs SetId et Stage, posées par
	-- tools/build_map.py). Montés chez chaque joueur seulement quand il s'approche (242 pièces par tenue).
	Display = {
		BuildDistance = 90, -- studs : on monte le mannequin en dessous
		DropDistance = 120, -- studs : on le retire au-delà
		CheckEvery = 1, -- secondes entre deux mesures de distance
		PromptDistance = 9,
		LabelHeight = 1.5, -- studs au-dessus de la tête
		LabelSize = Vector2.new(4.6, 1.4), -- studs : assez étroite pour que deux étiquettes voisines ne se touchent pas
		LabelDistance = 32, -- studs : l'étiquette disparaît au-delà
		AuraRateScale = 0.6, -- débit de l'aura d'un mannequin par rapport à celle d'un joueur
		LightRange = 9,
	},
}
