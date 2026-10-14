-- Meubles de la maison (purement décoratifs). Voir design/04_MONDE_PNJ.md (« Maison de maman »).
-- Chaque meuble va sur un type d'emplacement (slot) de la maison : Sofa, Tv, Bed, Rug, Poster, Plant, Lamp, Trophy.
-- price : en Cash. requiredStage : stade minimum pour l'acheter (2 = après Kevin, 3 = après Brayan…).
-- Visuels PROVISOIRES en blocs (en attendant les modèles Blender). Chaque pièce est placée par rapport à
-- l'emplacement : x à droite, y vers le haut (0 = sol, ou centre du mur pour Poster), le devant du meuble vers -Z.
-- ❓ Prix de départ, à calibrer avec la simulation de l'économie.

export type Piece = {
	size: Vector3,
	offset: Vector3,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	rotation: Vector3?, -- degrés
}

export type Item = {
	slot: string,
	price: number,
	requiredStage: number?,
	order: number,
	pieces: { Piece },
}

local V = Vector3.new
local M = Enum.Material
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
local function piece(size: Vector3, offset: Vector3, color: Color3, material: Enum.Material?, extra: { [string]: any }?)
	local p = { size = size, offset = offset, color = color, material = material }
	if extra then
		for key, value in extra do
			(p :: any)[key] = value
		end
	end
	return p :: Piece
end
local BALL = { shape = Enum.PartType.Ball }
local CYLINDER_UP = { shape = Enum.PartType.Cylinder, rotation = V(0, 0, 90) }

-- Canapé générique : assise, dossier contre le mur (+Z), accoudoirs
local function sofa(color: Color3, trim: Color3, material: Enum.Material?): { Piece }
	return {
		piece(V(7, 1.6, 3), V(0, 1, 0), color, material or M.Fabric),
		piece(V(7, 2.4, 0.8), V(0, 2.4, 1.1), color, material or M.Fabric),
		piece(V(0.8, 2.2, 3), V(-3.5, 1.4, 0), trim, material or M.Fabric),
		piece(V(0.8, 2.2, 3), V(3.5, 1.4, 0), trim, material or M.Fabric),
	}
end

local Items: { [string]: Item } = {
	-- Canapés
	SaggyCouch = { slot = "Sofa", price = 40, order = 1, pieces = sofa(rgb(130, 90, 60), rgb(110, 74, 50)) },
	BenchSofa = {
		slot = "Sofa",
		price = 140,
		requiredStage = 2,
		order = 2,
		pieces = {
			piece(V(7, 1, 2.6), V(0, 1.6, 0), rgb(30, 30, 34), M.Leather),
			piece(V(0.6, 1, 0.6), V(-3, 0.5, 0), rgb(170, 170, 176), M.Metal),
			piece(V(0.6, 1, 0.6), V(3, 0.5, 0), rgb(170, 170, 176), M.Metal),
			piece(V(9, 0.5, 0.5), V(0, 4.2, 1.2), rgb(190, 190, 196), M.Metal),
			piece(V(0.6, 3, 3), V(-4.4, 4.2, 1.2), rgb(40, 40, 44), M.Metal, { shape = Enum.PartType.Cylinder }),
			piece(V(0.6, 3, 3), V(4.4, 4.2, 1.2), rgb(40, 40, 44), M.Metal, { shape = Enum.PartType.Cylinder }),
		},
	},
	LeopardSofa = {
		slot = "Sofa",
		price = 300,
		requiredStage = 3,
		order = 3,
		pieces = sofa(rgb(225, 170, 70), rgb(80, 50, 30)),
	},
	ThroneSofa = {
		slot = "Sofa",
		price = 700,
		requiredStage = 5,
		order = 4,
		pieces = {
			piece(V(5, 1.8, 3), V(0, 1.1, 0), rgb(150, 30, 40), M.Fabric),
			piece(V(5, 6, 0.8), V(0, 4, 1.1), rgb(230, 190, 60), M.Metal),
			piece(V(0.8, 3, 3), V(-2.9, 1.6, 0), rgb(230, 190, 60), M.Metal),
			piece(V(0.8, 3, 3), V(2.9, 1.6, 0), rgb(230, 190, 60), M.Metal),
			piece(V(1.2, 1.2, 1.2), V(0, 7.4, 1.1), rgb(240, 60, 60), M.Neon, BALL),
		},
	},

	-- Télés
	TubeTv = {
		slot = "Tv",
		price = 50,
		order = 1,
		pieces = {
			piece(V(4, 2, 1.6), V(0, 1, 0.2), rgb(120, 84, 56), M.WoodPlanks),
			piece(V(3, 2.6, 2.2), V(0, 3.3, 0.3), rgb(60, 60, 64)),
			piece(V(2.4, 2, 0.1), V(0, 3.3, -0.85), rgb(110, 160, 210), M.Neon),
		},
	},
	GiantScreen = {
		slot = "Tv",
		price = 260,
		requiredStage = 3,
		order = 2,
		pieces = {
			piece(V(6, 1.4, 1.6), V(0, 0.7, 0.2), rgb(40, 40, 44)),
			piece(V(8, 4.6, 0.4), V(0, 4, 0.5), rgb(20, 20, 24)),
			piece(V(7.4, 4, 0.1), V(0, 4, 0.25), rgb(80, 200, 255), M.Neon),
		},
	},

	-- Lits
	Mattress = {
		slot = "Bed",
		price = 30,
		order = 1,
		pieces = {
			piece(V(5, 0.8, 7), V(0, 0.4, 0.5), rgb(230, 225, 210), M.Fabric),
			piece(V(3, 0.5, 1.2), V(0, 1, 3.2), rgb(240, 240, 245), M.Fabric),
		},
	},
	RaceCarBed = {
		slot = "Bed",
		price = 220,
		requiredStage = 2,
		order = 2,
		pieces = {
			piece(V(5.4, 1.6, 7.6), V(0, 0.8, 0.5), rgb(210, 40, 40)),
			piece(V(4.6, 0.5, 6), V(0, 1.85, 0.6), rgb(240, 240, 245), M.Fabric),
			piece(V(5.4, 1.4, 1), V(0, 2.3, 4), rgb(210, 40, 40)),
			piece(V(0.6, 1.8, 1.8), V(-2.8, 0.9, -1.8), rgb(25, 25, 28), nil, { shape = Enum.PartType.Cylinder }),
			piece(V(0.6, 1.8, 1.8), V(2.8, 0.9, -1.8), rgb(25, 25, 28), nil, { shape = Enum.PartType.Cylinder }),
			piece(V(0.6, 1.8, 1.8), V(-2.8, 0.9, 2.8), rgb(25, 25, 28), nil, { shape = Enum.PartType.Cylinder }),
			piece(V(0.6, 1.8, 1.8), V(2.8, 0.9, 2.8), rgb(25, 25, 28), nil, { shape = Enum.PartType.Cylinder }),
		},
	},

	-- Tapis
	PizzaRug = {
		slot = "Rug",
		price = 35,
		order = 1,
		pieces = {
			piece(V(0.1, 7, 7), V(0, 0.05, 0), rgb(240, 180, 70), M.Fabric, CYLINDER_UP),
			piece(V(0.12, 1.4, 1.4), V(-1.5, 0.06, 1), rgb(200, 50, 40), M.Fabric, CYLINDER_UP),
			piece(V(0.12, 1.4, 1.4), V(1.6, 0.06, -0.6), rgb(200, 50, 40), M.Fabric, CYLINDER_UP),
			piece(V(0.12, 1.4, 1.4), V(0, 0.06, -2), rgb(200, 50, 40), M.Fabric, CYLINDER_UP),
		},
	},
	ZebraRug = {
		slot = "Rug",
		price = 110,
		requiredStage = 2,
		order = 2,
		pieces = {
			piece(V(10, 0.1, 7), V(0, 0.05, 0), rgb(240, 240, 235), M.Fabric),
			piece(V(0.8, 0.12, 7), V(-3, 0.06, 0), rgb(30, 30, 32), M.Fabric),
			piece(V(0.8, 0.12, 7), V(-0.6, 0.06, 0), rgb(30, 30, 32), M.Fabric),
			piece(V(0.8, 0.12, 7), V(1.8, 0.06, 0), rgb(30, 30, 32), M.Fabric),
			piece(V(0.8, 0.12, 7), V(4.2, 0.06, 0), rgb(30, 30, 32), M.Fabric),
		},
	},
	GoldRug = {
		slot = "Rug",
		price = 400,
		requiredStage = 4,
		order = 3,
		pieces = {
			piece(V(11, 0.1, 8), V(0, 0.05, 0), rgb(170, 30, 40), M.Fabric),
			piece(V(9.6, 0.12, 6.6), V(0, 0.06, 0), rgb(230, 190, 60), M.Fabric),
			piece(V(8.4, 0.14, 5.4), V(0, 0.07, 0), rgb(170, 30, 40), M.Fabric),
		},
	},

	-- Décoration murale (emplacement au centre du mur, le mur est juste derrière)
	FlexPoster = {
		slot = "Poster",
		price = 25,
		order = 1,
		pieces = {
			piece(V(4, 5, 0.1), V(0, 0, 0), rgb(250, 230, 120), M.SmoothPlastic),
			piece(V(1.2, 2.4, 0.12), V(-0.6, -0.6, -0.02), rgb(220, 120, 60)),
			piece(V(2.2, 1, 0.12), V(0.5, 0.4, -0.02), rgb(220, 120, 60)),
			piece(V(1.4, 1.4, 0.12), V(1.2, 1, -0.03), rgb(220, 120, 60), nil, BALL),
		},
	},
	SunsetPoster = {
		slot = "Poster",
		price = 60,
		order = 2,
		pieces = {
			piece(V(6, 4, 0.1), V(0, 0, 0), rgb(250, 140, 80)),
			piece(V(6, 1.4, 0.12), V(0, -1.3, -0.02), rgb(120, 60, 140)),
			piece(V(2, 2, 0.12), V(0, 0.2, -0.03), rgb(255, 220, 90), M.Neon, BALL),
		},
	},
	NeonDumbbell = {
		slot = "Poster",
		price = 180,
		requiredStage = 3,
		order = 3,
		pieces = {
			piece(V(5, 0.4, 0.2), V(0, 0, -0.1), rgb(255, 60, 200), M.Neon),
			piece(V(0.6, 2.4, 0.2), V(-2.6, 0, -0.1), rgb(60, 220, 255), M.Neon),
			piece(V(0.6, 2.4, 0.2), V(2.6, 0, -0.1), rgb(60, 220, 255), M.Neon),
		},
	},

	-- Plantes
	Cactus = {
		slot = "Plant",
		price = 20,
		order = 1,
		pieces = {
			piece(V(1.8, 1.6, 1.8), V(0, 0.8, 0), rgb(190, 100, 60), M.Concrete),
			piece(V(1, 3.4, 1), V(0, 3.2, 0), rgb(70, 150, 70), M.Grass),
			piece(V(1.4, 0.6, 0.6), V(0.9, 3.4, 0), rgb(70, 150, 70), M.Grass),
			piece(V(0.6, 1.2, 0.6), V(1.4, 4, 0), rgb(70, 150, 70), M.Grass),
		},
	},
	ShakerPlant = {
		slot = "Plant",
		price = 80,
		requiredStage = 2,
		order = 2,
		pieces = {
			piece(V(2, 3, 2), V(0, 1.5, 0), rgb(40, 40, 46)),
			piece(V(2.2, 0.6, 2.2), V(0, 3.3, 0), rgb(250, 120, 40)),
			piece(V(3.4, 3.4, 3.4), V(0, 5.2, 0), rgb(90, 170, 70), M.Grass, BALL),
		},
	},

	-- Lampes
	LavaLamp = {
		slot = "Lamp",
		price = 45,
		order = 1,
		pieces = {
			piece(V(1.4, 1, 1.4), V(0, 0.5, 0), rgb(180, 180, 186), M.Metal),
			piece(V(1, 2.6, 1), V(0, 2.3, 0), rgb(255, 80, 160), M.Neon),
			piece(V(1.2, 0.6, 1.2), V(0, 3.9, 0), rgb(180, 180, 186), M.Metal),
		},
	},
	DumbbellLamp = {
		slot = "Lamp",
		price = 150,
		requiredStage = 3,
		order = 2,
		pieces = {
			piece(V(0.5, 5, 0.5), V(0, 2.5, 0), rgb(60, 60, 66), M.Metal),
			piece(V(0.6, 2.6, 2.6), V(0, 0.3, 0), rgb(40, 40, 44), M.Metal, CYLINDER_UP),
			piece(V(3, 1.6, 3), V(0, 5.6, 0), rgb(255, 230, 150), M.Neon),
		},
	},

	-- Trophées
	BronzeCup = {
		slot = "Trophy",
		price = 60,
		order = 1,
		pieces = {
			piece(V(4, 2.6, 1.6), V(0, 1.3, 0.5), rgb(120, 84, 56), M.WoodPlanks),
			piece(V(1.4, 0.4, 1.4), V(0, 2.8, 0.5), rgb(170, 110, 60), M.Metal),
			piece(V(0.4, 1, 0.4), V(0, 3.4, 0.5), rgb(190, 120, 60), M.Metal),
			piece(V(1.6, 1.4, 1.6), V(0, 4.4, 0.5), rgb(200, 130, 70), M.Metal),
		},
	},
	GoldenDumbbell = {
		slot = "Trophy",
		price = 350,
		requiredStage = 4,
		order = 2,
		pieces = {
			piece(V(4, 2.6, 1.6), V(0, 1.3, 0.5), rgb(40, 40, 44), M.Marble),
			piece(V(3, 0.5, 0.5), V(0, 3.4, 0.5), rgb(240, 200, 70), M.Metal, { shape = Enum.PartType.Cylinder }),
			piece(V(0.6, 1.8, 1.8), V(-1.5, 3.4, 0.5), rgb(240, 200, 70), M.Metal, { shape = Enum.PartType.Cylinder }),
			piece(V(0.6, 1.8, 1.8), V(1.5, 3.4, 0.5), rgb(240, 200, 70), M.Metal, { shape = Enum.PartType.Cylinder }),
		},
	},
	BicepStatue = {
		slot = "Trophy",
		price = 800,
		requiredStage = 5,
		order = 3,
		pieces = {
			piece(V(3, 1.4, 2), V(0, 0.7, 0.5), rgb(235, 232, 222), M.Marble),
			piece(V(1.4, 3, 1.4), V(-0.6, 2.9, 0.5), rgb(240, 238, 230), M.Marble),
			piece(V(2.6, 1.2, 1.2), V(0.4, 4.6, 0.5), rgb(240, 238, 230), M.Marble),
			piece(V(2, 2, 2), V(0.1, 5.6, 0.4), rgb(240, 238, 230), M.Marble, BALL),
			piece(V(1.2, 1.4, 1.2), V(1.4, 5.6, 0.5), rgb(240, 238, 230), M.Marble, BALL),
		},
	},
}

-- Ordre d'affichage des emplacements dans le magasin
local Slots = { "Sofa", "Tv", "Bed", "Rug", "Poster", "Plant", "Lamp", "Trophy" }

return {
	Items = Items,
	Slots = Slots,
}
