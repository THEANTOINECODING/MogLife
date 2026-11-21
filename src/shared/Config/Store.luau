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

	-- Coffres des packs de Cash (D137, ChestArt), du plus petit au plus gros. open : degrés d'ouverture du couvercle ;
	-- heap : boules d'or du tas ; overflow : hauteur du tas au-dessus du bord (studs) ; coins : pièces dressées ;
	-- bars : lingots ; gems : couleurs des pierres précieuses ; bills / spill : liasses et pièces tombées devant
	Chests = {
		{
			scale = 0.8,
			body = Color3.fromRGB(140, 88, 48),
			band = Color3.fromRGB(150, 155, 168),
			shiny = false,
			open = 38,
			heap = 7,
			overflow = 0.15,
			coins = 3,
			bars = 0,
			gems = {},
			bills = 1,
			spill = 3,
		},
		{
			scale = 1,
			body = Color3.fromRGB(150, 70, 45),
			band = Color3.fromRGB(255, 200, 60),
			shiny = true,
			open = 72,
			heap = 14,
			overflow = 0.4,
			coins = 7,
			bars = 2,
			gems = { Color3.fromRGB(70, 200, 255) },
			bills = 3,
			spill = 7,
		},
		{
			scale = 1.2,
			body = Color3.fromRGB(95, 45, 150),
			band = Color3.fromRGB(255, 215, 70),
			shiny = true,
			open = 100,
			heap = 24,
			overflow = 0.75,
			coins = 12,
			bars = 3,
			gems = { Color3.fromRGB(255, 70, 110), Color3.fromRGB(70, 200, 255), Color3.fromRGB(90, 255, 140) },
			bills = 5,
			spill = 12,
		},
	},
	-- Cartes des packs (D137) : couleurs par rang (du plus petit au plus gros), écart minimal pour afficher « +X% »
	CardTiers = {
		{ top = Color3.fromRGB(62, 50, 92), bottom = Color3.fromRGB(32, 26, 52), glow = Color3.fromRGB(180, 160, 255) },
		{
			top = Color3.fromRGB(80, 48, 140),
			bottom = Color3.fromRGB(36, 22, 70),
			glow = Color3.fromRGB(120, 200, 255),
		},
		{ top = Color3.fromRGB(150, 80, 30), bottom = Color3.fromRGB(70, 28, 40), glow = Color3.fromRGB(255, 210, 70) },
	},
	BonusMin = 0.05,

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
