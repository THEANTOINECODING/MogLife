-- Apparence provisoire des PNJ (boss et habitants), en attendant les vrais modèles (étape E).
-- Couleurs et proportions exagérées appliquées à un rig R15 généré.

export type Look = {
	skin: Color3,
	torso: Color3,
	legs: Color3,
	width: number,
	height: number,
	depth: number,
	head: number,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Npcs: { [string]: Look } = {
	-- Boss
	Kevin = {
		skin = rgb(255, 220, 190),
		torso = rgb(110, 150, 230), -- pyjama
		legs = rgb(110, 150, 230),
		width = 0.7,
		height = 1,
		depth = 0.7,
		head = 1.3,
	},
	Brayan = {
		skin = rgb(255, 140, 20), -- bronzage orange fluo
		torso = rgb(255, 140, 20),
		legs = rgb(250, 240, 90),
		width = 1.6,
		height = 1.05,
		depth = 1.3,
		head = 0.9,
	},
	CoachTurbo = {
		skin = rgb(240, 200, 170),
		torso = rgb(220, 40, 40), -- survêtement
		legs = rgb(220, 40, 40),
		width = 1.4,
		height = 1.1,
		depth = 1.2,
		head = 1.1,
	},

	-- Habitants
	Mom = {
		skin = rgb(240, 205, 180),
		torso = rgb(160, 90, 200),
		legs = rgb(60, 60, 80),
		width = 1,
		height = 0.95,
		depth = 1,
		head = 1.1,
	},
	Courier = {
		skin = rgb(200, 150, 110),
		torso = rgb(140, 90, 40),
		legs = rgb(90, 70, 50),
		width = 0.9,
		height = 1,
		depth = 0.9,
		head = 1,
	},
	Kid = {
		skin = rgb(250, 215, 185),
		torso = rgb(80, 200, 120),
		legs = rgb(60, 90, 160),
		width = 0.8,
		height = 0.7,
		depth = 0.8,
		head = 1.3,
	},
	Neighbor = {
		skin = rgb(230, 190, 160),
		torso = rgb(60, 140, 70),
		legs = rgb(100, 100, 100),
		width = 1.1,
		height = 1,
		depth = 1.2,
		head = 1,
	},
	MrsDoRe = {
		skin = rgb(245, 210, 195),
		torso = rgb(240, 120, 170),
		legs = rgb(240, 120, 170),
		width = 1,
		height = 0.9,
		depth = 1,
		head = 1.2,
	},
}

return Npcs
