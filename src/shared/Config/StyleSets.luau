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
	price: number,
	color: Color3,
	effect: string?,
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

local list: { Set } = {}
local byId: { [string]: Set } = {}
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
}
