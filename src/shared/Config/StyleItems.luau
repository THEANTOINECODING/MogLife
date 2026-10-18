-- Objets de style (purement esthétiques). Voir design/02_MECANIQUES/PERSONNAGE.md.
-- price = nil : objet exclusif, obtenu en battant un boss (bossId).
-- starter = true : coupe de départ gratuite, possédée par tous et proposée dans le menu de création (D55).
-- Visuels : sur les corps de stade, les VRAIS modèles (tools/blender/build_style.py, un par corps, pièces dans
-- ReplicatedStorage.Style et décalages dans StylePieces.luau). Les `pieces` ci-dessous sont les blocs de secours,
-- utilisés seulement sur un avatar Roblox sans corps de stade : attach (partie du corps), size et offset en
-- multiples de la taille de cette partie (devant = -Z), color, material, shape et transparency optionnelles.
-- ❓ Prix de départ, à calibrer après simulation de l'économie.

export type Piece = {
	attach: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	transparency: number?,
}

export type Item = {
	category: "Hair" | "Beard" | "Face" | "Top" | "Bottom" | "Accessory",
	price: number?,
	bossId: string?,
	starter: boolean?,
	order: number, -- ordre d'affichage dans la boutique
	pieces: { Piece },
	swatch: Color3?, -- couleur d'aperçu si l'objet n'a pas de blocs de secours
	setId: string?, -- ensemble auquel appartient la pièce
}

local StyleSets = require(script.Parent.StyleSets)
local V = Vector3.new
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function torsoShell(color: Color3, scale: number, material: Enum.Material?): Piece
	return {
		attach = "UpperTorso",
		size = V(1 + 0.04 * scale, 0.95, 1 + 0.08 * scale),
		offset = V(0, -0.02, 0),
		color = color,
		material = material or Enum.Material.Fabric,
	}
end

local StyleItems: { [string]: Item } = {
	-- Coupes
	Banana = {
		category = "Hair",
		price = 40,
		order = 1,
		pieces = {
			{ attach = "Head", size = V(0.7, 0.5, 1.6), offset = V(0, 0.6, -0.45), color = rgb(240, 200, 60) },
		},
	},
	Mullet = {
		category = "Hair",
		price = 60,
		order = 2,
		pieces = {
			{ attach = "Head", size = V(1.06, 0.25, 1.06), offset = V(0, 0.55, 0), color = rgb(120, 70, 30) },
			{ attach = "Head", size = V(0.95, 1.1, 0.25), offset = V(0, 0, 0.58), color = rgb(120, 70, 30) },
		},
	},
	Mohawk = {
		category = "Hair",
		price = 80,
		order = 3,
		pieces = {
			{ attach = "Head", size = V(0.18, 0.75, 1.1), offset = V(0, 0.8, 0), color = rgb(255, 60, 140) },
		},
	},
	ShinyBald = {
		category = "Hair",
		price = 100,
		order = 4,
		pieces = {
			{
				attach = "Head",
				size = V(1.08, 1.08, 1.08),
				offset = V(0, 0.12, 0),
				color = rgb(255, 245, 230),
				material = Enum.Material.Glass,
				shape = Enum.PartType.Ball,
				transparency = 0.5,
			},
		},
	},
	Pompadour = {
		category = "Hair",
		price = 150,
		order = 5,
		pieces = {
			{ attach = "Head", size = V(1, 0.8, 1.5), offset = V(0, 0.75, -0.55), color = rgb(25, 25, 30) },
		},
	},

	-- Coupes de départ (gratuites, menu de création et coiffeur)
	Curly = {
		category = "Hair",
		price = 0,
		starter = true,
		order = 6,
		pieces = { { attach = "Head", size = V(1.15, 0.5, 1.15), offset = V(0, 0.5, 0), color = rgb(110, 70, 40) } },
	},
	LongHair = {
		category = "Hair",
		price = 0,
		starter = true,
		order = 7,
		pieces = { { attach = "Head", size = V(1.1, 1.3, 0.4), offset = V(0, 0, 0.5), color = rgb(110, 70, 40) } },
	},
	Bun = {
		category = "Hair",
		price = 0,
		starter = true,
		order = 8,
		pieces = { { attach = "Head", size = V(0.5, 0.45, 0.5), offset = V(0, 0.8, 0.1), color = rgb(110, 70, 40) } },
	},
	Bob = {
		category = "Hair",
		price = 0,
		starter = true,
		order = 9,
		pieces = { { attach = "Head", size = V(1.12, 0.9, 1.12), offset = V(0, 0.25, 0.05), color = rgb(110, 70, 40) } },
	},

	-- Barbes (chez le coiffeur)
	LumberBeard = {
		category = "Beard",
		price = 45,
		order = 1,
		pieces = {
			{ attach = "Head", size = V(0.9, 0.45, 0.4), offset = V(0, -0.45, -0.35), color = rgb(80, 45, 20) },
		},
	},
	Goatee = {
		category = "Beard",
		price = 30,
		order = 2,
		pieces = {
			{ attach = "Head", size = V(0.25, 0.3, 0.2), offset = V(0, -0.5, -0.5), color = rgb(20, 18, 18) },
		},
	},
	Handlebar = {
		category = "Beard",
		price = 65,
		order = 3,
		pieces = {
			{ attach = "Head", size = V(0.8, 0.12, 0.12), offset = V(0, -0.2, -0.55), color = rgb(200, 95, 30) },
		},
	},
	ChinStrap = {
		category = "Beard",
		price = 55,
		order = 4,
		pieces = {
			{ attach = "Head", size = V(1.02, 0.15, 1.02), offset = V(0, -0.45, 0), color = rgb(20, 18, 18) },
		},
	},

	-- Visage (chez le coiffeur)
	FrownBrows = {
		category = "Face",
		price = 25,
		order = 1,
		pieces = {
			{ attach = "Head", size = V(0.8, 0.12, 0.1), offset = V(0, 0.2, -0.55), color = rgb(30, 20, 12) },
		},
	},
	SparkleSmile = {
		category = "Face",
		price = 60,
		order = 2,
		pieces = {
			{ attach = "Head", size = V(0.6, 0.15, 0.08), offset = V(0, -0.3, -0.55), color = rgb(255, 255, 250) },
		},
	},
	MegaJaw = {
		category = "Face",
		price = 120,
		order = 3,
		pieces = {
			{ attach = "Head", size = V(1.2, 0.45, 1.05), offset = V(0, -0.4, -0.05), color = rgb(238, 189, 153) },
		},
	},

	-- Hauts
	TightTank = { category = "Top", price = 30, order = 1, pieces = { torsoShell(rgb(245, 245, 245), 1) } },
	MogTank = { category = "Top", price = 70, order = 2, pieces = { torsoShell(rgb(35, 35, 40), 1) } },
	Hawaiian = { category = "Top", price = 90, order = 3, pieces = { torsoShell(rgb(255, 120, 60), 1.5) } },
	TrackJacket = { category = "Top", price = 120, order = 4, pieces = { torsoShell(rgb(40, 80, 200), 2) } },
	BoxerRobe = {
		category = "Top",
		price = 160,
		order = 5,
		pieces = {
			torsoShell(rgb(200, 20, 40), 3, Enum.Material.SmoothPlastic),
			{
				attach = "LowerTorso",
				size = V(1.15, 1.6, 1.2),
				offset = V(0, -0.3, 0),
				color = rgb(200, 20, 40),
				material = Enum.Material.SmoothPlastic,
			},
		},
	},
	PajamaTop = { category = "Top", bossId = "Kevin", order = 6, pieces = { torsoShell(rgb(110, 150, 230), 1.5) } },

	-- Bas
	FluoShorts = {
		category = "Bottom",
		price = 35,
		order = 1,
		pieces = {
			{ attach = "LowerTorso", size = V(1.1, 1.6, 1.15), offset = V(0, -0.2, 0), color = rgb(140, 255, 40) },
		},
	},
	VelvetJoggers = {
		category = "Bottom",
		price = 75,
		order = 2,
		pieces = {
			{ attach = "LeftUpperLeg", size = V(1.12, 1, 1.12), offset = V(0, 0, 0), color = rgb(110, 35, 140) },
			{ attach = "RightUpperLeg", size = V(1.12, 1, 1.12), offset = V(0, 0, 0), color = rgb(110, 35, 140) },
		},
	},
	LeatherPants = {
		category = "Bottom",
		price = 110,
		order = 3,
		pieces = {
			{ attach = "LeftUpperLeg", size = V(1.1, 1, 1.1), offset = V(0, 0, 0), color = rgb(25, 22, 20) },
			{ attach = "RightUpperLeg", size = V(1.1, 1, 1.1), offset = V(0, 0, 0), color = rgb(25, 22, 20) },
		},
	},

	-- Accessoires
	Headband = {
		category = "Accessory",
		price = 25,
		order = 1,
		pieces = {
			{ attach = "Head", size = V(1.05, 0.18, 1.05), offset = V(0, 0.25, 0), color = rgb(220, 40, 40) },
		},
	},
	Sweatbands = {
		category = "Accessory",
		price = 35,
		order = 2,
		pieces = {
			{ attach = "LeftLowerArm", size = V(1.2, 0.3, 1.2), offset = V(0, -0.3, 0), color = rgb(250, 250, 250) },
			{ attach = "RightLowerArm", size = V(1.2, 0.3, 1.2), offset = V(0, -0.3, 0), color = rgb(250, 250, 250) },
		},
	},
	DumbbellShades = {
		category = "Accessory",
		price = 50,
		order = 3,
		pieces = {
			{ attach = "Head", size = V(0.95, 0.2, 0.12), offset = V(0, 0.1, -0.55), color = rgb(15, 15, 15) },
		},
	},
	ShakerBackpack = {
		category = "Accessory",
		price = 80,
		order = 4,
		pieces = {
			{
				attach = "UpperTorso",
				size = V(0.45, 0.9, 0.45),
				offset = V(0, 0, 0.75),
				color = rgb(120, 200, 255),
				material = Enum.Material.Glass,
				transparency = 0.2,
			},
		},
	},
	GoldChain = {
		category = "Accessory",
		price = 200,
		order = 5,
		pieces = {
			{
				attach = "UpperTorso",
				size = V(0.7, 0.12, 1.12),
				offset = V(0, 0.42, -0.04),
				color = rgb(255, 200, 40),
				material = Enum.Material.Neon,
			},
		},
	},
	BronzeMedal = {
		category = "Accessory",
		bossId = "Brayan",
		order = 6,
		pieces = {
			{
				attach = "UpperTorso",
				size = V(0.3, 0.3, 0.08),
				offset = V(0, 0.1, -0.58),
				color = rgb(205, 127, 50),
				material = Enum.Material.Metal,
			},
		},
	},
	TinySocks = {
		category = "Accessory",
		bossId = "NoLegs",
		order = 8,
		pieces = {
			{ attach = "LeftFoot", size = V(1.6, 1.2, 1.6), offset = V(0, 0.4, 0), color = rgb(255, 255, 255) },
			{ attach = "RightFoot", size = V(1.6, 1.2, 1.6), offset = V(0, 0.4, 0), color = rgb(255, 255, 255) },
		},
	},
	RoyalFan = {
		category = "Accessory",
		bossId = "BlockKing",
		order = 9,
		pieces = {
			{
				attach = "UpperTorso",
				size = V(1.1, 1.1, 0.12),
				offset = V(0, 0.2, 0.75),
				color = rgb(150, 60, 220),
				material = Enum.Material.Neon,
				shape = Enum.PartType.Cylinder,
			},
		},
	},
	CoachWhistle = {
		category = "Accessory",
		bossId = "CoachTurbo",
		order = 7,
		pieces = {
			{
				attach = "UpperTorso",
				size = V(0.15, 0.15, 0.3),
				offset = V(0.2, 0.2, -0.6),
				color = rgb(200, 200, 210),
				material = Enum.Material.Metal,
			},
		},
	},
}

-- Les nouvelles pièces restent indisponibles jusqu'à l'import et l'activation des 20 ensembles.
-- Après achat d'un ensemble, les deux articles deviennent indépendants : on peut les mélanger.
for _, set in StyleSets.List do
	StyleItems[set.top] = {
		category = "Top",
		order = 100 + set.order,
		pieces = {},
		swatch = set.color,
		setId = set.id,
	}
	StyleItems[set.bottom] = {
		category = "Bottom",
		order = 100 + set.order,
		pieces = {},
		swatch = set.color,
		setId = set.id,
	}
end

return StyleItems
