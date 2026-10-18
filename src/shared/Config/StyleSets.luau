-- Ensembles MOG LIFE. Les prix seront saisis après validation d'Antoine et des essais joueurs.
-- Active reste false tant que les FBX et StylePieces ne sont pas importés et vérifiés dans Studio.
-- Les articles anciens restent dans les données des joueurs et dans leur garde-robe.

export type Set = {
	id: string,
	top: string,
	bottom: string,
	order: number,
	price: number?,
	color: Color3,
	effect: string?,
}

local definitions = {
	{ "CircuitAce", 12, 25, 70, "Pulse" },
	{ "BoardwalkBolt", 250, 120, 38 },
	{ "VelvetVillain", 90, 23, 123 },
	{ "MoonMechanic", 203, 221, 230, "Stardust" },
	{ "GoldenHour", 239, 194, 79, "Glint" },
	{ "BubblegumBlitz", 239, 41, 120 },
	{ "BrickhouseBrawler", 194, 17, 22 },
	{ "ThunderArcade", 43, 40, 111, "Pulse" },
	{ "RoyalRumble", 84, 18, 61 },
	{ "MidnightExpress", 15, 19, 31 },
	{ "JungleJolt", 21, 107, 53 },
	{ "FrostFlex", 141, 198, 238, "Snow" },
	{ "TurboTaxi", 245, 192, 23 },
	{ "DiscoDynamo", 94, 30, 145, "Glint" },
	{ "CometCoach", 31, 58, 107 },
	{ "SunsetStunt", 211, 68, 46 },
	{ "GarageGremlin", 56, 89, 94 },
	{ "CloudCruiser", 204, 197, 245, "Snow" },
	{ "IronMeteor", 52, 59, 74 },
	{ "PaperCrown", 244, 231, 186, "Glint" },
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
		color = Color3.fromRGB(entry[2] :: number, entry[3] :: number, entry[4] :: number),
		effect = entry[5] :: string?,
	}
	table.insert(list, set)
	byId[id] = set
end

return {
	Active = false,
	List = list,
	ById = byId,
	Effects = {
		Pulse = { rate = 1.4, lifetime = 0.35, size = 0.10, speed = 0.08 },
		Stardust = { rate = 1.8, lifetime = 0.75, size = 0.07, speed = 0.18 },
		Glint = { rate = 1.2, lifetime = 0.30, size = 0.11, speed = 0.09 },
		Snow = { rate = 1.8, lifetime = 0.90, size = 0.07, speed = 0.16 },
	},
}
