-- Ensembles MOG LIFE. Classés par prix croissant selon détails, silhouette et effets.
-- Le premier ensemble suit les premiers gains (25 Cash du bocal + 20 de Kevin) ; les derniers sont des objectifs
-- de style pour les stades avancés. Les prix restent à confronter aux parcours de l'alpha.
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
	{ "BoardwalkBolt", 250, 120, 38, 45 },
	{ "JungleJolt", 21, 107, 53, 60 },
	{ "TurboTaxi", 245, 192, 23, 80 },
	{ "SunsetStunt", 211, 68, 46, 105 },
	{ "CometCoach", 31, 58, 107, 130 },
	{ "BubblegumBlitz", 239, 41, 120, 160 },
	{ "CloudCruiser", 204, 197, 245, 195, "Snow" },
	{ "FrostFlex", 141, 198, 238, 235, "Snow" },
	{ "GarageGremlin", 56, 89, 94, 280 },
	{ "ThunderArcade", 43, 40, 111, 330, "Pulse" },
	{ "BrickhouseBrawler", 194, 17, 22, 385 },
	{ "MidnightExpress", 15, 19, 31, 445 },
	{ "PaperCrown", 244, 231, 186, 510, "Glint" },
	{ "MoonMechanic", 203, 221, 230, 585, "Stardust" },
	{ "CircuitAce", 12, 25, 70, 670, "Pulse" },
	{ "RoyalRumble", 84, 18, 61, 765 },
	{ "VelvetVillain", 90, 23, 123, 870 },
	{ "IronMeteor", 52, 59, 74, 985 },
	{ "DiscoDynamo", 94, 30, 145, 1110, "Glint" },
	{ "GoldenHour", 239, 194, 79, 1250, "Glint" },
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
