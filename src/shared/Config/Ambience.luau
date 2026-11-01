-- Ambiance du décor (D97) : eau Terrain (fontaine de la place), nuages, jets d'eau de la fontaine.
-- Les volumes d'eau sont des pièces invisibles de la carte (tag WaterVolume, remplies par SceneryService) ;
-- les jets sont des points de la carte (tag FountainJet, attribut Jet = clé de Jets ci-dessous, JetDir = direction)
-- où AmbienceController accroche les particules.

export type Jet = {
	rate: number, -- particules par seconde
	speed: NumberRange,
	lifetime: NumberRange,
	spread: number, -- angle d'ouverture (degrés)
	gravity: number, -- chute (studs/s²)
	size: { number }, -- taille au début et à la fin
	transparency: { number },
	color: Color3,
	drag: number?,
	texture: string, -- "Smoke" ou "Sparkle"
	glow: number?, -- LightEmission
}

local WATER = Color3.fromRGB(205, 238, 255)
local FOAM = Color3.fromRGB(240, 250, 255)

return {
	-- Rendu de l'eau Terrain (commun à toute la carte)
	Water = {
		Color = Color3.fromRGB(40, 150, 175),
		Transparency = 0.55,
		WaveSize = 0.08,
		WaveSpeed = 8,
		Reflectance = 0.6,
	},

	-- Nuages dynamiques (Terrain.Clouds)
	Clouds = {
		Cover = 0.5,
		Density = 0.55,
		Color = Color3.fromRGB(255, 255, 255),
	},

	Jets = {
		-- Becs de la margelle : arc vers le pied de la fontaine
		Arc = {
			rate = 70,
			speed = NumberRange.new(12.5, 13.5),
			lifetime = NumberRange.new(0.78, 0.82),
			spread = 1.5,
			gravity = 30,
			size = { 0.45, 0.3 },
			transparency = { 0.15, 0.35 },
			color = WATER,
			texture = "Smoke",
		},
		-- Gerbe au-dessus de l'haltère, qui retombe dans la vasque
		Geyser = {
			rate = 90,
			speed = NumberRange.new(16, 19),
			lifetime = NumberRange.new(1.1, 1.3),
			spread = 5,
			gravity = 30,
			size = { 0.6, 0.35 },
			transparency = { 0.1, 0.45 },
			color = WATER,
			texture = "Smoke",
		},
		-- Petits jets au sommet des disques de l'haltère
		PlateJet = {
			rate = 45,
			speed = NumberRange.new(11, 12.5),
			lifetime = NumberRange.new(1.15, 1.25),
			spread = 3,
			gravity = 30,
			size = { 0.4, 0.3 },
			transparency = { 0.15, 0.4 },
			color = WATER,
			texture = "Smoke",
		},
		-- Rideau d'eau qui déborde de la vasque
		Curtain = {
			rate = 40,
			speed = NumberRange.new(1.5, 2.5),
			lifetime = NumberRange.new(0.65, 0.7),
			spread = 18,
			gravity = 30,
			size = { 0.55, 0.4 },
			transparency = { 0.25, 0.5 },
			color = WATER,
			texture = "Smoke",
		},
		-- Éclaboussures et écume à la surface du bassin
		Splash = {
			rate = 14,
			speed = NumberRange.new(2, 4),
			lifetime = NumberRange.new(0.35, 0.55),
			spread = 55,
			gravity = 12,
			size = { 0.5, 1.3 },
			transparency = { 0.35, 1 },
			color = FOAM,
			drag = 2,
			texture = "Smoke",
		},
		-- Quelques reflets qui scintillent dans la gerbe
		Sparkle = {
			rate = 4,
			speed = NumberRange.new(3, 6),
			lifetime = NumberRange.new(0.6, 1),
			spread = 70,
			gravity = 4,
			size = { 0.5, 0 },
			transparency = { 0, 1 },
			color = Color3.fromRGB(255, 255, 255),
			texture = "Sparkle",
			glow = 1,
		},
	} :: { [string]: Jet },
}
