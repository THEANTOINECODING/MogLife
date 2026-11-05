-- Articles de luxe à effets (D112), vendus chez Swole Threads, 2 000 à 10 000 Cash. Trois emplacements :
-- - Trail : traînée derrière le joueur quand il bouge ;
-- - Aura : particules autour du corps, en permanence ;
-- - Entrance : explosion d'effets quand un duel ou un combat de boss commence.
-- Vus par tous les joueurs (c'est du prestige) ; le réglage « Outfit effects » les coupe chez soi. Leur prix compte
-- dans le Drip (Drip.ItemValue) comme tout article. Aucun texte ni image importée : textures de particules de Roblox.
-- ❓ Prix de départ, à calibrer pendant l'alpha.

export type Fx = {
	texture: string,
	colors: { Color3 },
	size: number, -- studs
	rate: number, -- particules par seconde (aura) ou nombre de particules (entrée)
	lifetime: number,
	speed: number,
	spread: number?, -- degrés
	light: number?, -- LightEmission
	rotSpeed: number?,
	width: number?, -- traînée : largeur en studs
}

export type Entry = {
	id: string,
	category: "Trail" | "Aura" | "Entrance",
	price: number,
	fx: Fx,
}

local TEX = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Spark = "rbxasset://textures/particles/fire_sparks_main.dds",
	Shock = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	Core = "rbxasset://textures/particles/explosion01_core_main.dds",
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local List: { Entry } = {
	-- Traînées
	{
		id = "SweatStreak",
		category = "Trail",
		price = 2_000,
		fx = {
			texture = "",
			colors = { rgb(120, 200, 255), rgb(255, 255, 255) },
			size = 0,
			rate = 0,
			lifetime = 0.5,
			speed = 0,
			width = 1.2,
		},
	},
	{
		id = "ProteinRibbon",
		category = "Trail",
		price = 3_500,
		fx = {
			texture = "",
			colors = { rgb(255, 130, 190), rgb(255, 240, 250) },
			size = 0,
			rate = 0,
			lifetime = 0.7,
			speed = 0,
			width = 1.6,
			light = 0.3,
		},
	},
	{
		id = "GoldenGains",
		category = "Trail",
		price = 6_000,
		fx = {
			texture = "",
			colors = { rgb(255, 215, 80), rgb(255, 150, 30) },
			size = 0,
			rate = 0,
			lifetime = 0.9,
			speed = 0,
			width = 2,
			light = 0.6,
		},
	},
	{
		id = "RainbowFlex",
		category = "Trail",
		price = 9_000,
		fx = {
			texture = "",
			colors = { rgb(255, 70, 70), rgb(255, 200, 60), rgb(80, 220, 110), rgb(80, 160, 255), rgb(200, 100, 255) },
			size = 0,
			rate = 0,
			lifetime = 1.1,
			speed = 0,
			width = 2.4,
			light = 0.5,
		},
	},
	-- Auras
	{
		id = "SteamyPump",
		category = "Aura",
		price = 2_500,
		fx = {
			texture = TEX.Smoke,
			colors = { rgb(255, 255, 255) },
			size = 1.6,
			rate = 5,
			lifetime = 1.4,
			speed = 2,
			spread = 30,
		},
	},
	{
		id = "MuscleSparks",
		category = "Aura",
		price = 4_500,
		fx = {
			texture = TEX.Spark,
			colors = { rgb(255, 230, 90) },
			size = 0.6,
			rate = 10,
			lifetime = 0.6,
			speed = 6,
			spread = 180,
			light = 1,
		},
	},
	{
		id = "FlexFlames",
		category = "Aura",
		price = 7_000,
		fx = {
			texture = TEX.Fire,
			colors = { rgb(255, 150, 40), rgb(255, 60, 20) },
			size = 1.4,
			rate = 8,
			lifetime = 0.8,
			speed = 3,
			spread = 15,
			light = 0.8,
		},
	},
	{
		id = "CosmicMog",
		category = "Aura",
		price = 10_000,
		fx = {
			texture = TEX.Sparkle,
			colors = { rgb(190, 120, 255), rgb(120, 200, 255) },
			size = 1,
			rate = 9,
			lifetime = 1.6,
			speed = 1.5,
			spread = 180,
			light = 1,
			rotSpeed = 90,
		},
	},
	-- Entrées
	{
		id = "ConfettiCannon",
		category = "Entrance",
		price = 2_000,
		fx = {
			texture = TEX.Sparkle,
			colors = { rgb(255, 80, 80), rgb(255, 220, 60), rgb(80, 220, 120), rgb(90, 170, 255) },
			size = 0.8,
			rate = 60,
			lifetime = 1.6,
			speed = 28,
			spread = 50,
			rotSpeed = 200,
		},
	},
	{
		id = "SmokeBomb",
		category = "Entrance",
		price = 3_500,
		fx = {
			texture = TEX.Smoke,
			colors = { rgb(140, 90, 200), rgb(60, 40, 90) },
			size = 5,
			rate = 30,
			lifetime = 2,
			speed = 12,
			spread = 180,
		},
	},
	{
		id = "ThunderStomp",
		category = "Entrance",
		price = 6_000,
		fx = {
			texture = TEX.Shock,
			colors = { rgb(140, 210, 255) },
			size = 10,
			rate = 4,
			lifetime = 0.6,
			speed = 0,
			spread = 0,
			light = 1,
		},
	},
	{
		id = "GodRays",
		category = "Entrance",
		price = 9_500,
		fx = {
			texture = TEX.Core,
			colors = { rgb(255, 230, 140), rgb(255, 180, 60) },
			size = 7,
			rate = 12,
			lifetime = 1.2,
			speed = 6,
			spread = 180,
			light = 1,
			rotSpeed = 60,
		},
	},
}

local ById: { [string]: Entry } = {}
for _, entry in List do
	ById[entry.id] = entry
end

return {
	List = List,
	ById = ById,
	Categories = { "Trail", "Aura", "Entrance" },
	EntranceDuration = 1.6, -- secondes d'émission d'une entrée
}
