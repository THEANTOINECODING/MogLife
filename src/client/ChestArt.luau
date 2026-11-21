-- Coffres au trésor en 3D (D137) : vignettes des packs de Cash de la boutique Robux (StoreController) et scène de
-- célébration d'un achat (ShopArt.Celebrate). Bois en planches, coins et bandes de métal, serrure, couvercle ouvert sur
-- un tas d'or qui déborde (pièces, lingots, pierres précieuses pour les plus gros). Réglages : Config/Store.luau Chests.
--   local chest = ChestArt.Build(tier, openDegrees?) -- Model ; chest.lid(angleDegrees) rouvre le couvercle
-- Purement visuel : rien n'est envoyé au serveur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StoreConfig = require(ReplicatedStorage.Shared.Config.Store)

local GOLD = Color3.fromRGB(255, 200, 45)
local GOLD_LIGHT = Color3.fromRGB(255, 232, 120)
local BILL = Color3.fromRGB(70, 185, 95)

local ChestArt = {}

export type Chest = { model: Model, lid: (degrees: number) -> () }

function ChestArt.Build(tier: number, openDegrees: number?): Chest
	local spec = StoreConfig.Chests[math.clamp(tier, 1, #StoreConfig.Chests)]
	local s = spec.scale
	local model = Instance.new("Model")
	model.Name = "Chest"
	local function part(
		size: Vector3,
		cframe: CFrame,
		color: Color3,
		material: Enum.Material?,
		shape: Enum.PartType?,
		parent: Instance?
	): Part
		local piece = Instance.new("Part")
		piece.Size = size
		piece.CFrame = cframe
		piece.Color = color
		piece.Material = material or Enum.Material.SmoothPlastic
		piece.Shape = shape or Enum.PartType.Block
		piece.Anchored = true
		piece.CanCollide = false
		piece.CastShadow = false
		piece.TopSurface = Enum.SurfaceType.Smooth
		piece.BottomSurface = Enum.SurfaceType.Smooth
		piece.Parent = parent or model
		return piece
	end
	local w, h, d = 2.6 * s, 1.25 * s, 1.7 * s
	local wood = spec.body
	local dark = Color3.new(wood.R * 0.62, wood.G * 0.62, wood.B * 0.62)
	local metal = spec.band
	local metalMaterial = if spec.shiny then Enum.Material.Foil else Enum.Material.Metal

	-- Caisse : quatre parois (l'intérieur reste creux pour le trésor), planches marquées, fond
	local wall = 0.14 * s
	part(Vector3.new(w, wall, d), CFrame.new(0, wall / 2, 0), dark, Enum.Material.Wood)
	part(Vector3.new(w, h, wall), CFrame.new(0, h / 2, -d / 2 + wall / 2), wood, Enum.Material.Wood)
	part(Vector3.new(w, h, wall), CFrame.new(0, h / 2, d / 2 - wall / 2), wood, Enum.Material.Wood)
	for _, x in { -1, 1 } do
		part(Vector3.new(wall, h, d), CFrame.new(x * (w / 2 - wall / 2), h / 2, 0), wood, Enum.Material.Wood)
	end
	for row = 1, 2 do
		local y = h * row / 3
		part(Vector3.new(w + 0.02, 0.05 * s, 0.03), CFrame.new(0, y, -d / 2 - 0.005), dark, Enum.Material.Wood)
	end
	-- Bandes de métal verticales, cornières, liseré du haut, serrure avec trou
	for _, x in { -w * 0.3, w * 0.3 } do
		part(Vector3.new(0.24 * s, h + 0.04, d + 0.06), CFrame.new(x, h / 2, 0), metal, metalMaterial)
	end
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part(
				Vector3.new(0.18 * s, h + 0.06, 0.18 * s),
				CFrame.new(x * (w / 2 - 0.06 * s), h / 2, z * (d / 2 - 0.06 * s)),
				metal,
				metalMaterial
			)
		end
	end
	part(Vector3.new(w + 0.06, 0.12 * s, d + 0.06), CFrame.new(0, h - 0.06 * s, 0), metal, metalMaterial)
	local lock =
		part(Vector3.new(0.46, 0.56, 0.16) * s, CFrame.new(0, h * 0.72, -d / 2 - 0.08 * s), metal, metalMaterial)
	part(
		Vector3.new(0.08, 0.2, 0.04) * s,
		lock.CFrame * CFrame.new(0, -0.04 * s, -0.08 * s),
		Color3.fromRGB(30, 22, 18)
	)

	-- Trésor : un dôme de pièces au ras du bord, qui déborde d'autant plus que le coffre est gros (dans son propre
	-- modèle « Treasure » : la scène d'ouverture le cache tant que le couvercle est fermé)
	local treasure = Instance.new("Model")
	treasure.Name = "Treasure"
	treasure.Parent = model
	local rng = Random.new(tier * 97)
	local heap = h - 0.05 * s
	for _ = 1, spec.heap do
		local radius = rng:NextNumber(0.28, 0.46) * s
		local x = rng:NextNumber(-w * 0.4, w * 0.4)
		local z = rng:NextNumber(-d * 0.32, d * 0.32)
		local rise = (1 - math.abs(x) / (w * 0.5)) * (1 - math.abs(z) / (d * 0.5)) * spec.overflow * s
		part(
			Vector3.new(radius, radius, radius) * 1.5,
			CFrame.new(x, heap + rise * 0.6, z),
			if rng:NextNumber() < 0.5 then GOLD else GOLD_LIGHT,
			Enum.Material.Neon,
			Enum.PartType.Ball,
			treasure
		)
	end
	-- Pièces dressées dans le tas, qui accrochent la lumière
	for _ = 1, spec.coins do
		local x = rng:NextNumber(-w * 0.38, w * 0.38)
		local z = rng:NextNumber(-d * 0.28, d * 0.28)
		local rise = (1 - math.abs(x) / (w * 0.5)) * spec.overflow * s
		local coin = part(
			Vector3.new(0.08, 0.42, 0.42) * s,
			CFrame.new(x, heap + rise * 0.7 + 0.12 * s, z)
				* CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, math.pi), rng:NextNumber(-0.5, 0.5)),
			GOLD,
			Enum.Material.Foil,
			Enum.PartType.Cylinder,
			treasure
		)
		coin.Reflectance = 0.25
	end
	-- Lingots (moyen et gros coffres) et pierres précieuses (gros coffre)
	for index = 1, spec.bars do
		part(
			Vector3.new(0.7, 0.22, 0.32) * s,
			CFrame.new((index - (spec.bars + 1) / 2) * 0.6 * s, heap + spec.overflow * s * 0.55, -d * 0.12)
				* CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.25, 0.25)),
			GOLD,
			Enum.Material.Foil,
			nil,
			treasure
		)
	end
	for index = 1, #spec.gems do
		local gem = part(
			Vector3.new(0.34, 0.34, 0.34) * s,
			CFrame.new((index - (#spec.gems + 1) / 2) * 0.55 * s, heap + spec.overflow * s * 0.8, d * 0.05)
				* CFrame.Angles(math.rad(45), math.rad(45), 0),
			spec.gems[index],
			Enum.Material.Glass,
			nil,
			treasure
		)
		gem.Transparency = 0.15
		gem.Reflectance = 0.3
	end
	-- Liasses et pièces tombées devant le coffre
	for index = 1, spec.bills do
		local x = (index - (spec.bills + 1) / 2) * 0.62 * s
		part(
			Vector3.new(0.5, 0.14, 0.86) * s,
			CFrame.new(x, 0.07 * s + (index % 2) * 0.14 * s, -d / 2 - 0.7 * s)
				* CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0),
			BILL
		)
		part(
			Vector3.new(0.52, 0.15, 0.12) * s,
			CFrame.new(x, 0.07 * s + (index % 2) * 0.14 * s, -d / 2 - 0.7 * s)
				* CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0),
			Color3.fromRGB(240, 235, 210)
		)
	end
	for _ = 1, spec.spill do
		local coin = part(
			Vector3.new(0.08, 0.4, 0.4) * s,
			CFrame.new(rng:NextNumber(-w * 0.6, w * 0.6), 0.04 * s, -d / 2 - rng:NextNumber(0.25, 1.3) * s)
				* CFrame.Angles(0, rng:NextNumber(0, math.pi), math.pi / 2),
			GOLD,
			Enum.Material.Foil,
			Enum.PartType.Cylinder
		)
		coin.Reflectance = 0.25
	end

	-- Couvercle : planche bombée (trois lattes en escalier) cerclée de métal, articulée sur l'arête arrière du haut
	local lidModel = Instance.new("Model")
	lidModel.Name = "Lid"
	lidModel.Parent = model
	local hinge = CFrame.new(0, h, d / 2)
	local rest: { [BasePart]: CFrame } = {}
	local function lidPart(size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?)
		local piece = part(size, hinge * offset, color, material, nil, lidModel)
		rest[piece] = offset
	end
	local lidH = 0.3 * s
	lidPart(Vector3.new(w + 0.04, lidH, d + 0.04), CFrame.new(0, lidH / 2, -d / 2), wood, Enum.Material.Wood)
	lidPart(Vector3.new(w + 0.02, lidH * 0.7, d * 0.62), CFrame.new(0, lidH * 1.3, -d / 2), wood, Enum.Material.Wood)
	lidPart(Vector3.new(w, lidH * 0.5, d * 0.26), CFrame.new(0, lidH * 1.85, -d / 2), wood, Enum.Material.Wood)
	for _, x in { -w * 0.3, w * 0.3 } do
		lidPart(Vector3.new(0.24 * s, lidH * 2.1, d + 0.08), CFrame.new(x, lidH * 1.05, -d / 2), metal, metalMaterial)
	end
	lidPart(Vector3.new(w + 0.08, 0.1 * s, d + 0.08), CFrame.new(0, 0.05 * s, -d / 2), metal, metalMaterial)
	model.PrimaryPart = lock
	local origin = lock.CFrame
	-- Le couvercle suit le coffre où qu'il soit (le modèle peut avoir été déplacé avec PivotTo)
	local function lid(degrees: number)
		local moved = lock.CFrame * origin:Inverse()
		local turn = moved * hinge * CFrame.Angles(math.rad(degrees), 0, 0)
		for piece, offset in rest do
			piece.CFrame = turn * offset
		end
	end
	lid(openDegrees or spec.open)
	return { model = model, lid = lid }
end

-- Scène de célébration d'un coffre (achat de Cash, coffre de la semaine) : le coffre fermé tombe, tremble, puis le
-- couvercle saute et reste ouvert sur le trésor ; renvoie l'animation à donner à ShopArt.Celebrate
function ChestArt.Scene(tier: number): (viewport: ViewportFrame) -> (t: number) -> ()
	return function(viewport: ViewportFrame)
		local chest = ChestArt.Build(tier, 0)
		local model = chest.model
		model.Parent = viewport
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		local box, size = model:GetBoundingBox()
		local center = box.Position + Vector3.new(0, size.Y * 0.15, 0)
		local distance = size.Magnitude / 2 / math.tan(math.rad(15)) * 1.15
		local pivot = model:GetPivot()
		local mid = CFrame.new(box.Position) -- il tourne autour de son centre, pas de sa serrure
		local open = StoreConfig.Chests[math.clamp(tier, 1, #StoreConfig.Chests)].open
		-- Le trésor reste invisible tant que le couvercle est fermé (le tas dépasse du bord)
		local hidden: { [BasePart]: number } = {}
		local treasure = model:FindFirstChild("Treasure")
		if treasure then
			for _, piece in treasure:GetChildren() do
				if piece:IsA("BasePart") then
					hidden[piece] = piece.Transparency
					piece.Transparency = 1
				end
			end
		end
		return function(t: number)
			local drop = math.clamp(t / 0.35, 0, 1)
			local fall = (1 - drop) ^ 2 * size.Y * 1.5
			local rattle = if t > 0.35 and t < 0.6 then math.sin(t * 70) * 0.06 else 0
			local spin = math.rad(-25) + math.sin(t * 1.4) * math.rad(18)
			model:PivotTo(mid * CFrame.new(0, fall, 0) * CFrame.Angles(0, spin, rattle) * mid:Inverse() * pivot)
			local u = math.clamp((t - 0.55) / 0.35, 0, 1)
			local over = 1 + 2.70158 * (u - 1) ^ 3 + 1.70158 * (u - 1) ^ 2
			chest.lid(open * if u > 0 then over else 0)
			if u > 0 and next(hidden) then
				for piece, transparency in hidden do
					piece.Transparency = transparency
				end
				table.clear(hidden)
			end
			camera.CFrame = CFrame.lookAt(center + Vector3.new(0, size.Y * 0.55, -distance), center)
		end
	end
end

return ChestArt
