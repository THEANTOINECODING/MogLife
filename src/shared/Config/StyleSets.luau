-- Ensembles MOG LIFE. Classés par prix croissant selon détails, silhouette et effets.
-- Prix relevés en D99 (demande d'Antoine : le style doit se mériter) : ×2 pour les petits prix, jusqu'à ×5 pour les
-- objets de luxe. Le premier ensemble coûte environ deux tours des premières aides et la victoire sur Kevin ; les
-- derniers sont des objectifs de plusieurs heures aux stades avancés. À confronter aux parcours de l'alpha.
-- Les articles anciens restent dans les données des joueurs et dans leur garde-robe.

export type Set = {
	id: string,
	top: string,
	bottom: string,
	order: number,
	price: number?, -- prix en Cash ; nil pour une tenue Robux
	color: Color3,
	effect: string?,
	robux: boolean?, -- tenue Robux (D121) : Game Pass (Config/GamePasses.luau), jamais vendue en Cash
	dripValue: number?, -- valeur de Drip de l'ensemble (sinon son prix)
}

local definitions = {
	-- id, couleur RGB, prix en Cash, effet facultatif
	{ "BoardwalkBolt", 250, 120, 38, 90 },
	{ "JungleJolt", 21, 107, 53, 130 },
	{ "TurboTaxi", 245, 192, 23, 200 },
	{ "SunsetStunt", 211, 68, 46, 290 },
	{ "CometCoach", 31, 58, 107, 380 },
	{ "BubblegumBlitz", 239, 41, 120, 510 },
	{ "CloudCruiser", 204, 197, 245, 660, "Snow" },
	{ "FrostFlex", 141, 198, 238, 830, "Snow" },
	{ "GarageGremlin", 56, 89, 94, 1050 },
	{ "ThunderArcade", 43, 40, 111, 1300, "Pulse" },
	{ "BrickhouseBrawler", 194, 17, 22, 1550 },
	{ "MidnightExpress", 15, 19, 31, 1850 },
	{ "PaperCrown", 244, 231, 186, 2200, "Glint" },
	{ "MoonMechanic", 203, 221, 230, 2600, "Stardust" },
	{ "CircuitAce", 12, 25, 70, 3100, "Pulse" },
	{ "RoyalRumble", 84, 18, 61, 3600 },
	{ "VelvetVillain", 90, 23, 123, 4250 },
	{ "IronMeteor", 52, 59, 74, 4900 },
	{ "DiscoDynamo", 94, 30, 145, 5550, "Glint" },
	{ "GoldenHour", 239, 194, 79, 6250, "Glint" },
}

-- Tenues Robux (D121, demande d'Antoine : « Drip au maximum ») : chacune vaut une tenue à 12 000 Cash pour le Drip
-- (le bonus maximal de Balance.Drip), avec un effet spectaculaire vu par tous. Achat par Game Pass uniquement.
-- id, couleur RGB, valeur de Drip, effet
local premium = {
	{ "CosmicEmperor", 120, 60, 230, 12_000, "Galaxy" },
	{ "GoldenTitan", 245, 190, 50, 12_000, "Molten" },
	{ "NeonPhantom", 20, 240, 255, 12_000, "Neon" },
}

local list: { Set } = {}
local byId: { [string]: Set } = {}
for _, entry in premium do
	local id = entry[1] :: string
	local set: Set = {
		id = id,
		top = id .. "Top",
		bottom = id .. "Bottom",
		order = #definitions + #list + 1,
		price = nil,
		color = Color3.fromRGB(entry[2] :: number, entry[3] :: number, entry[4] :: number),
		effect = entry[6] :: string?,
		robux = true,
		dripValue = entry[5] :: number,
	}
	byId[id] = set
end
for order, entry in definitions do
	local id = entry[1] :: string
	local set: Set = {
		id = id,
		top = id .. "Top",
		bottom = id .. "Bottom",
		order = order,
		price = entry[5] :: number,
		color = Color3.fromRGB(entry[2] :: number, entry[3] :: number, entry[4] :: number),
		effect = entry[6] :: string?,
	}
	table.insert(list, set)
	byId[id] = set
end
-- Les tenues Robux après les 20 ensembles (même ordre que tools/blender/outfit_looks.py LOOKS)
for _, entry in premium do
	table.insert(list, byId[entry[1] :: string])
end

return {
	Active = true,
	List = list,
	ById = byId,
	Effects = {
		Pulse = { rate = 1.4, lifetime = 0.35, size = 0.10, speed = 0.08 },
		Stardust = { rate = 1.8, lifetime = 0.75, size = 0.07, speed = 0.18 },
		Glint = { rate = 1.2, lifetime = 0.30, size = 0.11, speed = 0.09 },
		Snow = { rate = 1.8, lifetime = 0.90, size = 0.07, speed = 0.16 },
	},
	-- Effets des tenues Robux (D121), vus par tous : particules plus nombreuses, deux couleurs et une lueur.
	-- colors : début et fin des particules ; light : couleur de la lumière autour du torse
	PremiumEffects = {
		Galaxy = {
			rate = 9,
			lifetime = 1.6,
			size = 0.32,
			speed = 0.7,
			colors = { Color3.fromRGB(150, 110, 255), Color3.fromRGB(255, 220, 120) },
			light = Color3.fromRGB(150, 110, 255),
			texture = "rbxasset://textures/particles/sparkles_main.dds",
		},
		Molten = {
			rate = 8,
			lifetime = 1.2,
			size = 0.28,
			speed = 1.1,
			colors = { Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 110, 30) },
			light = Color3.fromRGB(255, 180, 60),
			texture = "rbxasset://textures/particles/fire_sparks_main.dds",
		},
		Neon = {
			rate = 10,
			lifetime = 1.0,
			size = 0.26,
			speed = 0.9,
			colors = { Color3.fromRGB(30, 245, 255), Color3.fromRGB(255, 40, 200) },
			light = Color3.fromRGB(30, 245, 255),
			texture = "rbxasset://textures/particles/sparkles_main.dds",
		},
	},
}
