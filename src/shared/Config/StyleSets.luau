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
	-- D122 (choix d'Antoine) : tenues haut de gamme, avec en plus traînée, entrée en scène, pose de victoire et
	-- animation au repos (Signature, plus bas ; SignatureFxController et MotionController)
	{ "GymDragon", 40, 200, 90, 12_000, "Dragonfire" },
	{ "EternalSun", 255, 190, 50, 12_000, "Solar" },
	{ "MechaMogger", 30, 220, 255, 12_000, "Reactor" },
	{ "MarbleStatue", 240, 236, 225, 12_000, "Marble" },
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
		-- D122
		Dragonfire = {
			rate = 12,
			lifetime = 1.1,
			size = 0.3,
			speed = 1.4,
			colors = { Color3.fromRGB(255, 200, 60), Color3.fromRGB(230, 50, 20) },
			light = Color3.fromRGB(255, 120, 40),
			texture = "rbxasset://textures/particles/fire_sparks_main.dds",
		},
		Solar = {
			rate = 12,
			lifetime = 1.4,
			size = 0.34,
			speed = 0.8,
			colors = { Color3.fromRGB(255, 245, 190), Color3.fromRGB(255, 170, 40) },
			light = Color3.fromRGB(255, 210, 110),
			texture = "rbxasset://textures/particles/sparkles_main.dds",
		},
		Reactor = {
			rate = 11,
			lifetime = 0.8,
			size = 0.24,
			speed = 1.6,
			colors = { Color3.fromRGB(140, 250, 255), Color3.fromRGB(40, 140, 255) },
			light = Color3.fromRGB(60, 220, 255),
			texture = "rbxasset://textures/particles/sparkles_main.dds",
		},
		Marble = {
			rate = 7,
			lifetime = 1.8,
			size = 0.3,
			speed = 0.4,
			colors = { Color3.fromRGB(255, 255, 250), Color3.fromRGB(255, 215, 110) },
			light = Color3.fromRGB(255, 240, 210),
			texture = "rbxasset://textures/particles/sparkles_main.dds",
		},
	},
	-- Mise en scène des tenues haut de gamme (D122), vue par tous ; le réglage « effets de tenue » la masque aussi.
	-- style : famille d'effets (SignatureFxController) et d'attitude au repos (MotionController)
	-- trail : couleurs de la traînée en mouvement ; victoryPose : pose de célébration (MogOff, 1 à 5)
	-- idleEvery : secondes entre deux effets au repos ; entrance : durée de l'entrée en scène (s)
	Signature = {
		GymDragon = {
			style = "Dragon",
			color = Color3.fromRGB(255, 120, 30),
			glow = Color3.fromRGB(255, 70, 20),
			trail = { Color3.fromRGB(255, 210, 70), Color3.fromRGB(200, 30, 10) },
			victoryPose = 2,
			idleEvery = 4.5,
			entrance = 1.6,
		},
		EternalSun = {
			style = "Sun",
			color = Color3.fromRGB(255, 205, 70),
			glow = Color3.fromRGB(255, 240, 180),
			trail = { Color3.fromRGB(255, 250, 210), Color3.fromRGB(255, 150, 30) },
			victoryPose = 5,
			idleEvery = 5,
			entrance = 1.8,
		},
		MechaMogger = {
			style = "Mecha",
			color = Color3.fromRGB(40, 220, 255),
			glow = Color3.fromRGB(150, 245, 255),
			trail = { Color3.fromRGB(160, 250, 255), Color3.fromRGB(30, 90, 255) },
			victoryPose = 3,
			idleEvery = 4,
			entrance = 1.5,
		},
		MarbleStatue = {
			style = "Marble",
			color = Color3.fromRGB(245, 240, 228),
			glow = Color3.fromRGB(255, 215, 110),
			trail = { Color3.fromRGB(255, 255, 250), Color3.fromRGB(255, 205, 90) },
			victoryPose = 4,
			idleEvery = 5.5,
			entrance = 1.7,
		},
	},
	-- Réglages communs de la mise en scène
	SignatureFx = {
		TrailMinSpeed = 6, -- studs/s : la traînée apparaît au-delà (marche rapide, course)
		TrailLifetime = 0.45,
		IdleAfter = 2.5, -- secondes immobile avant les effets au repos
		MaxDistance = 140, -- studs : au-delà, on ne joue rien (autres joueurs lointains)
		VictoryTime = 2.4, -- durée de l'effet de victoire
	},
}
