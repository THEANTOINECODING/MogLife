-- Boosts temporaires (décision D47, à la place d'un système d'énergie refusé par D2) : des boissons et en-cas
-- comiques, achetés en Cash au camion à shakes et au distributeur, qui multiplient le Mog gagné à l'entraînement
-- pendant quelques minutes. Ils ne bloquent jamais rien : sans boost, on joue normalement.
-- Un seul boost actif à la fois ; racheter le même prolonge sa durée (plafonnée), un autre le remplace.
-- Rien de suggestif ni de « drogue » (règles Roblox, tous publics) : uniquement des aliments absurdes.
-- ❓ Prix, effets et durées : hypothèses de départ, à régler pendant l'alpha. Prix relevés en D99 (×2 à ×2,25).

export type Boost = {
	price: number,
	requiredStage: number, -- index dans Stages.List
	mogMultiplier: number, -- multiplie le Mog des exercices
	duration: number, -- secondes
	color: Color3, -- couleur de l'icône et de la jauge
	order: number,
}

local Boosts: { [string]: Boost } = {
	ProteinShake = {
		price = 40,
		requiredStage = 1,
		mogMultiplier = 1.25,
		duration = 180,
		color = Color3.fromRGB(240, 200, 230),
		order = 1,
	},
	TurboJuice = {
		price = 120,
		requiredStage = 2,
		mogMultiplier = 1.5,
		duration = 240,
		color = Color3.fromRGB(120, 230, 90),
		order = 2,
	},
	GiantSteak = {
		price = 350,
		requiredStage = 3,
		mogMultiplier = 1.75,
		duration = 300,
		color = Color3.fromRGB(200, 90, 70),
		order = 3,
	},
	GoldenEggs = {
		price = 900,
		requiredStage = 4,
		mogMultiplier = 2,
		duration = 300,
		color = Color3.fromRGB(255, 210, 60),
		order = 4,
	},
}

return Boosts
