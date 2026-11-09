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
	-- D125 (demande d'Antoine) : Démon des Enfers. Les huit tenues Robux sont refaites (tools/blender/premium_looks.py)
	{ "InfernalDemon", 200, 30, 25, 12_000, "Hellfire" },
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
	-- D125 : couleurs des pièces lumineuses (Néon) de chaque tenue Robux : { A (pièces _Glow), B (pièces _GlowB) }
	Glow = {
		CosmicEmperor = { Color3.fromRGB(205, 175, 255), Color3.fromRGB(255, 215, 120) },
		GoldenTitan = { Color3.fromRGB(255, 110, 20), Color3.fromRGB(255, 215, 110) },
		NeonPhantom = { Color3.fromRGB(30, 240, 255), Color3.fromRGB(255, 45, 200) },
		GymDragon = { Color3.fromRGB(255, 115, 20), Color3.fromRGB(255, 210, 80) },
		EternalSun = { Color3.fromRGB(255, 205, 80), Color3.fromRGB(255, 248, 220) },
		MechaMogger = { Color3.fromRGB(35, 225, 255), Color3.fromRGB(215, 255, 255) },
		MarbleStatue = { Color3.fromRGB(255, 200, 75), Color3.fromRGB(255, 245, 205) },
		InfernalDemon = { Color3.fromRGB(255, 55, 15), Color3.fromRGB(255, 150, 30) },
	},
	-- D125 : aura de chaque tenue Robux, vue par tous (OutfitFxController) : plusieurs couches de particules et une
	-- lumière. Le réglage « effets de tenue » la masque.
	-- anchor : partie du personnage ("UpperTorso", "LowerTorso", "Head") : les particules sortent de tout son volume ;
	--   "Feet" : un point au sol sous le personnage.
	-- texture : rbxasset://textures/particles/<nom> ; colors : début et fin ; alpha : opacité au début, au milieu et
	-- à la fin (0 = invisible) ; size : taille au début, au milieu et à la fin ; life, speed : min et max ;
	-- accel : accélération (studs/s²) ; spread : angle de dispersion ; flat : couché au sol (anneaux) ;
	-- spin : vitesse de rotation max (°/s) ; locked : suit le personnage ; emission : LightEmission (1 = lumineux)
	Auras = {
		CosmicEmperor = {
			light = { color = Color3.fromRGB(170, 130, 255), brightness = 1.3, range = 11 },
			layers = {
				{ -- étoiles qui scintillent autour du corps
					anchor = "UpperTorso",
					texture = "sparkles_main.dds",
					colors = { Color3.fromRGB(255, 250, 235), Color3.fromRGB(170, 130, 255) },
					alpha = { 0, 1, 0 },
					size = { 0.1, 0.35, 0 },
					rate = 10,
					life = { 1, 1.6 },
					speed = { 0.2, 0.6 },
					spread = 180,
					spin = 90,
					emission = 1,
				},
				{ -- nébuleuse violette et bleue qui tourne lentement
					anchor = "UpperTorso",
					texture = "smoke_main.dds",
					colors = { Color3.fromRGB(120, 60, 220), Color3.fromRGB(40, 70, 200) },
					alpha = { 0, 0.3, 0 },
					size = { 1.2, 2.4, 3.2 },
					rate = 3,
					life = { 2.2, 3 },
					speed = { 0.2, 0.5 },
					spread = 180,
					spin = 30,
					emission = 0.8,
				},
				{ -- galaxie au sol
					anchor = "Feet",
					texture = "explosion01_shockwave_main.dds",
					colors = { Color3.fromRGB(200, 160, 255), Color3.fromRGB(80, 60, 220) },
					alpha = { 0, 0.55, 0 },
					size = { 2, 5, 7 },
					rate = 0.7,
					life = { 2, 2.4 },
					speed = { 0.01, 0.01 },
					flat = true,
					spin = 40,
					emission = 1,
				},
			},
		},
		GoldenTitan = {
			light = { color = Color3.fromRGB(255, 140, 40), brightness = 1.5, range = 11 },
			layers = {
				{ -- braises de métal en fusion qui montent
					anchor = "UpperTorso",
					texture = "fire_sparks_main.dds",
					colors = { Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 70, 10) },
					alpha = { 1, 1, 0 },
					size = { 0.3, 0.2, 0 },
					rate = 14,
					life = { 1, 1.6 },
					speed = { 1, 2 },
					accel = Vector3.new(0, 3, 0),
					spread = 60,
					emission = 1,
				},
				{ -- chaleur autour du corps
					anchor = "UpperTorso",
					texture = "forcefield_glow_main.dds",
					colors = { Color3.fromRGB(255, 150, 40), Color3.fromRGB(255, 80, 10) },
					alpha = { 0, 0.18, 0 },
					size = { 4, 5, 5.5 },
					rate = 2,
					life = { 0.8, 1.1 },
					speed = { 0, 0 },
					spread = 0,
					locked = true,
					emission = 1,
				},
				{ -- flaque de métal en fusion au sol
					anchor = "Feet",
					texture = "explosion01_shockwave_main.dds",
					colors = { Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 70, 10) },
					alpha = { 0, 0.6, 0 },
					size = { 1.5, 4.5, 6 },
					rate = 0.8,
					life = { 1.6, 2 },
					speed = { 0.01, 0.01 },
					flat = true,
					emission = 1,
				},
			},
		},
		NeonPhantom = {
			light = { color = Color3.fromRGB(40, 230, 255), brightness = 1.2, range = 10 },
			layers = {
				{ -- pixels cyan qui grésillent
					anchor = "UpperTorso",
					texture = "SquareParticle.png",
					colors = { Color3.fromRGB(30, 240, 255), Color3.fromRGB(30, 240, 255) },
					alpha = { 1, 1, 0 },
					size = { 0.22, 0.16, 0 },
					rate = 7,
					life = { 0.3, 0.6 },
					speed = { 0.6, 1.6 },
					spread = 180,
					emission = 1,
				},
				{ -- pixels magenta
					anchor = "LowerTorso",
					texture = "SquareParticle.png",
					colors = { Color3.fromRGB(255, 45, 200), Color3.fromRGB(255, 45, 200) },
					alpha = { 1, 1, 0 },
					size = { 0.18, 0.12, 0 },
					rate = 6,
					life = { 0.3, 0.6 },
					speed = { 0.6, 1.6 },
					spread = 180,
					emission = 1,
				},
				{ -- anneau néon au sol
					anchor = "Feet",
					texture = "explosion01_shockwave_main.dds",
					colors = { Color3.fromRGB(30, 240, 255), Color3.fromRGB(255, 45, 200) },
					alpha = { 0, 0.7, 0 },
					size = { 1, 3.5, 5 },
					rate = 1,
					life = { 1, 1.2 },
					speed = { 0.01, 0.01 },
					flat = true,
					emission = 1,
				},
			},
		},
		GymDragon = {
			light = { color = Color3.fromRGB(255, 130, 40), brightness = 1.2, range = 10 },
			layers = {
				{ -- braises
					anchor = "UpperTorso",
					texture = "fire_sparks_main.dds",
					colors = { Color3.fromRGB(255, 220, 90), Color3.fromRGB(230, 50, 10) },
					alpha = { 1, 1, 0 },
					size = { 0.28, 0.2, 0 },
					rate = 10,
					life = { 1, 1.4 },
					speed = { 1, 2 },
					accel = Vector3.new(0, 2.5, 0),
					spread = 70,
					emission = 1,
				},
				{ -- fumée de naseaux, sombre
					anchor = "Head",
					texture = "smoke_main.dds",
					colors = { Color3.fromRGB(90, 80, 70), Color3.fromRGB(40, 35, 30) },
					alpha = { 0, 0.35, 0 },
					size = { 0.6, 1.4, 2.2 },
					rate = 1.5,
					life = { 1.6, 2.2 },
					speed = { 0.4, 0.8 },
					accel = Vector3.new(0, 1.2, 0),
					spread = 25,
					spin = 40,
					emission = 0,
				},
				{ -- petites flammes au sol
					anchor = "Feet",
					texture = "fire_main.dds",
					colors = { Color3.fromRGB(255, 200, 70), Color3.fromRGB(220, 40, 10) },
					alpha = { 0, 0.8, 0 },
					size = { 0.7, 0.9, 0 },
					rate = 8,
					life = { 0.5, 0.8 },
					speed = { 1.5, 3 },
					spread = 35,
					emission = 1,
				},
			},
		},
		EternalSun = {
			light = { color = Color3.fromRGB(255, 215, 120), brightness = 1.8, range = 13 },
			layers = {
				{ -- grains de lumière qui montent
					anchor = "UpperTorso",
					texture = "sparkles_main.dds",
					colors = { Color3.fromRGB(255, 252, 230), Color3.fromRGB(255, 180, 50) },
					alpha = { 0, 1, 0 },
					size = { 0.15, 0.3, 0 },
					rate = 12,
					life = { 1.2, 1.8 },
					speed = { 0.4, 1 },
					accel = Vector3.new(0, 1.5, 0),
					spread = 180,
					emission = 1,
				},
				{ -- rayonnement doré autour de la tête et de l'auréole
					anchor = "Head",
					texture = "forcefield_glow_main.dds",
					colors = { Color3.fromRGB(255, 225, 140), Color3.fromRGB(255, 170, 40) },
					alpha = { 0, 0.3, 0 },
					size = { 4, 5.5, 6 },
					rate = 2.5,
					life = { 0.9, 1.2 },
					speed = { 0, 0 },
					spread = 0,
					locked = true,
					emission = 1,
				},
				{ -- soleil au sol
					anchor = "Feet",
					texture = "explosion01_shockwave_main.dds",
					colors = { Color3.fromRGB(255, 240, 180), Color3.fromRGB(255, 160, 40) },
					alpha = { 0, 0.6, 0 },
					size = { 2, 5, 7 },
					rate = 0.8,
					life = { 1.6, 2 },
					speed = { 0.01, 0.01 },
					flat = true,
					spin = 30,
					emission = 1,
				},
			},
		},
		MechaMogger = {
			light = { color = Color3.fromRGB(60, 220, 255), brightness = 1.2, range = 10 },
			layers = {
				{ -- données qui s'élèvent
					anchor = "UpperTorso",
					texture = "SquareParticle.png",
					colors = { Color3.fromRGB(180, 250, 255), Color3.fromRGB(35, 200, 255) },
					alpha = { 1, 0.8, 0 },
					size = { 0.12, 0.1, 0 },
					rate = 7,
					life = { 0.6, 1 },
					speed = { 0.2, 0.5 },
					accel = Vector3.new(0, 2, 0),
					spread = 180,
					emission = 1,
				},
				{ -- étincelles d'énergie
					anchor = "UpperTorso",
					texture = "sparkles_main.dds",
					colors = { Color3.fromRGB(200, 255, 255), Color3.fromRGB(35, 160, 255) },
					alpha = { 0, 1, 0 },
					size = { 0.1, 0.25, 0 },
					rate = 5,
					life = { 0.4, 0.7 },
					speed = { 0.5, 1.2 },
					spread = 180,
					emission = 1,
				},
				{ -- anneau de scanner au sol
					anchor = "Feet",
					texture = "explosion01_shockwave_main.dds",
					colors = { Color3.fromRGB(120, 245, 255), Color3.fromRGB(35, 160, 255) },
					alpha = { 0, 0.7, 0 },
					size = { 1, 4, 5 },
					rate = 0.9,
					life = { 1, 1.2 },
					speed = { 0.01, 0.01 },
					flat = true,
					emission = 1,
				},
			},
		},
		MarbleStatue = {
			light = { color = Color3.fromRGB(255, 235, 190), brightness = 1.3, range = 11 },
			layers = {
				{ -- poussière d'or qui flotte
					anchor = "UpperTorso",
					texture = "sparkles_main.dds",
					colors = { Color3.fromRGB(255, 245, 210), Color3.fromRGB(255, 200, 80) },
					alpha = { 0, 0.9, 0 },
					size = { 0.1, 0.25, 0 },
					rate = 7,
					life = { 2, 2.8 },
					speed = { 0.1, 0.3 },
					spread = 180,
					emission = 1,
				},
				{ -- lueur divine
					anchor = "UpperTorso",
					texture = "forcefield_glow_main.dds",
					colors = { Color3.fromRGB(255, 240, 200), Color3.fromRGB(255, 210, 120) },
					alpha = { 0, 0.15, 0 },
					size = { 5, 6, 6.5 },
					rate = 1.5,
					life = { 1.2, 1.6 },
					speed = { 0, 0 },
					spread = 0,
					locked = true,
					emission = 1,
				},
				{ -- grains de marbre qui tombent
					anchor = "UpperTorso",
					texture = "smoke_main.dds",
					colors = { Color3.fromRGB(245, 242, 235), Color3.fromRGB(220, 218, 210) },
					alpha = { 0, 0.3, 0 },
					size = { 0.3, 0.6, 0.9 },
					rate = 1.5,
					life = { 1.5, 2 },
					speed = { 0.2, 0.4 },
					accel = Vector3.new(0, -2, 0),
					spread = 60,
					emission = 0,
				},
			},
		},
		InfernalDemon = {
			light = { color = Color3.fromRGB(255, 60, 20), brightness = 1.8, range = 13 },
			layers = {
				{ -- flammes de l'enfer qui lèchent les jambes
					anchor = "Feet",
					texture = "fire_main.dds",
					colors = { Color3.fromRGB(255, 170, 40), Color3.fromRGB(180, 10, 10) },
					alpha = { 0, 0.85, 0 },
					size = { 1.2, 1.4, 0.2 },
					rate = 16,
					life = { 0.6, 1 },
					speed = { 3, 5 },
					spread = 22,
					emission = 0.9,
				},
				{ -- braises rouges
					anchor = "UpperTorso",
					texture = "fire_sparks_main.dds",
					colors = { Color3.fromRGB(255, 150, 40), Color3.fromRGB(200, 20, 10) },
					alpha = { 1, 1, 0 },
					size = { 0.3, 0.2, 0 },
					rate = 12,
					life = { 1, 1.5 },
					speed = { 1, 2.5 },
					accel = Vector3.new(0, 3, 0),
					spread = 80,
					emission = 1,
				},
				{ -- fumée noire
					anchor = "UpperTorso",
					texture = "smoke_main.dds",
					colors = { Color3.fromRGB(35, 20, 20), Color3.fromRGB(10, 5, 5) },
					alpha = { 0, 0.45, 0 },
					size = { 1.2, 2.2, 3.2 },
					rate = 4,
					life = { 1.6, 2.2 },
					speed = { 0.5, 1 },
					accel = Vector3.new(0, 2, 0),
					spread = 60,
					spin = 40,
					emission = 0,
				},
				{ -- cercle de feu au sol
					anchor = "Feet",
					texture = "explosion01_shockwave_main.dds",
					colors = { Color3.fromRGB(255, 120, 30), Color3.fromRGB(200, 15, 10) },
					alpha = { 0, 0.75, 0 },
					size = { 2, 5, 7 },
					rate = 0.9,
					life = { 1.4, 1.8 },
					speed = { 0.01, 0.01 },
					flat = true,
					emission = 1,
				},
			},
		},
	},
	-- Mise en scène des tenues Robux (D122, étendue aux huit tenues en D125), vue par tous ; le réglage « effets de
	-- tenue » la masque aussi. style : famille d'effets (SignatureFxController) et d'attitude au repos (MotionController)
	-- trail : couleurs de la traînée en mouvement ; victoryPose : pose de célébration (MogOff, 1 à 5)
	-- idleEvery : secondes entre deux effets au repos ; entrance : durée de l'entrée en scène (s)
	-- pulse : respiration des pièces lumineuses (part de luminosité min et max, période en s)
	Signature = {
		CosmicEmperor = {
			style = "Cosmic",
			color = Color3.fromRGB(170, 120, 255),
			glow = Color3.fromRGB(230, 210, 255),
			trail = { Color3.fromRGB(230, 210, 255), Color3.fromRGB(60, 40, 200) },
			victoryPose = 5,
			idleEvery = 5,
			entrance = 1.8,
			pulse = { 0.7, 1, 3 },
		},
		GoldenTitan = {
			style = "Molten",
			color = Color3.fromRGB(255, 160, 40),
			glow = Color3.fromRGB(255, 110, 20),
			trail = { Color3.fromRGB(255, 220, 110), Color3.fromRGB(255, 60, 10) },
			victoryPose = 1,
			idleEvery = 4.5,
			entrance = 1.6,
			pulse = { 0.65, 1, 1.6 },
		},
		NeonPhantom = {
			style = "Neon",
			color = Color3.fromRGB(30, 240, 255),
			glow = Color3.fromRGB(255, 45, 200),
			trail = { Color3.fromRGB(30, 240, 255), Color3.fromRGB(255, 45, 200) },
			victoryPose = 3,
			idleEvery = 3.5,
			entrance = 1.4,
			pulse = { 0.55, 1, 0.9 },
		},
		GymDragon = {
			style = "Dragon",
			color = Color3.fromRGB(255, 120, 30),
			glow = Color3.fromRGB(255, 70, 20),
			trail = { Color3.fromRGB(255, 210, 70), Color3.fromRGB(200, 30, 10) },
			victoryPose = 2,
			idleEvery = 4.5,
			entrance = 1.6,
			pulse = { 0.6, 1, 2.2 },
		},
		EternalSun = {
			style = "Sun",
			color = Color3.fromRGB(255, 205, 70),
			glow = Color3.fromRGB(255, 240, 180),
			trail = { Color3.fromRGB(255, 250, 210), Color3.fromRGB(255, 150, 30) },
			victoryPose = 5,
			idleEvery = 5,
			entrance = 1.8,
			pulse = { 0.8, 1, 2.6 },
		},
		MechaMogger = {
			style = "Mecha",
			color = Color3.fromRGB(40, 220, 255),
			glow = Color3.fromRGB(150, 245, 255),
			trail = { Color3.fromRGB(160, 250, 255), Color3.fromRGB(30, 90, 255) },
			victoryPose = 3,
			idleEvery = 4,
			entrance = 1.5,
			pulse = { 0.6, 1, 1.2 },
		},
		MarbleStatue = {
			style = "Marble",
			color = Color3.fromRGB(245, 240, 228),
			glow = Color3.fromRGB(255, 215, 110),
			trail = { Color3.fromRGB(255, 255, 250), Color3.fromRGB(255, 205, 90) },
			victoryPose = 4,
			idleEvery = 5.5,
			entrance = 1.7,
			pulse = { 0.75, 1, 3.4 },
		},
		InfernalDemon = {
			style = "Demon",
			color = Color3.fromRGB(255, 50, 20),
			glow = Color3.fromRGB(255, 120, 30),
			trail = { Color3.fromRGB(255, 140, 30), Color3.fromRGB(120, 0, 0) },
			victoryPose = 1,
			idleEvery = 4,
			entrance = 1.8,
			pulse = { 0.5, 1, 1.4 },
		},
	},
	-- D126 : traces de pas de chaque tenue Robux (PremiumMotionController), vues par tous ; même réglage que l'aura.
	-- Une petite gerbe de particules sous le pied à chaque pas (StepDistance studs parcourus au sol).
	-- texture, colors, alpha, size, life, speed, emission : comme les couches d'aura ; count : particules par pas
	Footsteps = {
		CosmicEmperor = {
			texture = "sparkles_main.dds",
			colors = { Color3.fromRGB(255, 245, 220), Color3.fromRGB(160, 120, 255) },
			count = 4,
			size = { 0.35, 0.25, 0 },
			life = { 0.6, 1 },
			speed = { 0.5, 1.5 },
			emission = 1,
		},
		GoldenTitan = {
			texture = "sparkles_main.dds",
			colors = { Color3.fromRGB(255, 225, 120), Color3.fromRGB(255, 120, 30) },
			count = 4,
			size = { 0.3, 0.2, 0 },
			life = { 0.4, 0.7 },
			speed = { 1.5, 3 },
			emission = 1,
		},
		NeonPhantom = {
			texture = "sparkles_main.dds",
			colors = { Color3.fromRGB(40, 240, 255), Color3.fromRGB(255, 50, 200) },
			count = 3,
			size = { 0.3, 0.3, 0 },
			life = { 0.3, 0.5 },
			speed = { 0.2, 0.6 },
			emission = 1,
		},
		GymDragon = {
			texture = "fire_main.dds",
			colors = { Color3.fromRGB(255, 190, 60), Color3.fromRGB(230, 60, 10) },
			count = 3,
			size = { 0.45, 0.3, 0 },
			life = { 0.35, 0.6 },
			speed = { 1, 2.5 },
			emission = 1,
		},
		EternalSun = {
			texture = "sparkles_main.dds",
			colors = { Color3.fromRGB(255, 250, 220), Color3.fromRGB(255, 190, 60) },
			count = 4,
			size = { 0.4, 0.25, 0 },
			life = { 0.5, 0.9 },
			speed = { 0.8, 2 },
			emission = 1,
		},
		MechaMogger = {
			texture = "sparkles_main.dds",
			colors = { Color3.fromRGB(60, 230, 255), Color3.fromRGB(220, 255, 255) },
			count = 3,
			size = { 0.25, 0.2, 0 },
			life = { 0.25, 0.4 },
			speed = { 2, 4 },
			emission = 1,
		},
		MarbleStatue = {
			texture = "smoke_main.dds",
			colors = { Color3.fromRGB(245, 242, 235), Color3.fromRGB(220, 215, 205) },
			count = 2,
			size = { 0.5, 0.9, 1.2 },
			life = { 0.5, 0.8 },
			speed = { 0.5, 1.2 },
			emission = 0,
		},
		InfernalDemon = {
			texture = "fire_main.dds",
			colors = { Color3.fromRGB(255, 120, 30), Color3.fromRGB(150, 10, 10) },
			count = 4,
			size = { 0.55, 0.35, 0 },
			life = { 0.45, 0.8 },
			speed = { 1.5, 3.5 },
			emission = 1,
		},
	},
	-- Réglages communs de la mise en scène
	SignatureFx = {
		TrailMinSpeed = 6, -- studs/s : la traînée apparaît au-delà (marche rapide, course)
		TrailLifetime = 0.45,
		IdleAfter = 2.5, -- secondes immobile avant les effets au repos
		MaxDistance = 140, -- studs : au-delà, on ne joue rien (autres joueurs lointains)
		VictoryTime = 2.4, -- durée de l'effet de victoire
		GlowFlare = 1.6, -- D125 : éclat des pièces lumineuses pendant l'entrée en scène et la victoire
		AuraMaxDistance = 160, -- studs : au-delà, l'aura d'un autre joueur est coupée
	},
}
