-- Visite guidée d'un magasin à la première entrée (D121), demandée par le serveur (ShopTourService) :
-- 1. vue d'ensemble depuis l'entrée ;
-- 2. le vendeur fait un geste et une bulle dit une réplique drôle ;
-- 3. les comptoirs importants (miroirs, comptoir des meubles, caisse) s'allument un par un, avec une légende ;
-- 4. la caméra revient au joueur, qui reprend la main.
-- 5 à 8 s au total (Balance.ShopTour), avec le bouton « Passer » des cinématiques (CutsceneController).
-- Vue ou passée, la visite est confirmée au serveur, qui ne la reproposera plus.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local ZONE_TAG = "ShopZone"
-- Points de vente qu'on montre (tags des comptoirs et miroirs) et leur légende
local COUNTER_TAGS = { "Mirror", "FurnitureShop", "BoostShop" }
local GOLD = Color3.fromRGB(255, 210, 60)

local MinigameController
local CutsceneController
local NpcController

local ShopTourController = {}
ShopTourController.Played = 0 -- visites jouées (tests dans Studio)

local function zoneOf(store: string): BasePart?
	for _, zone in CollectionService:GetTagged(ZONE_TAG) do
		if zone:IsA("BasePart") and zone:GetAttribute("Store") == store then
			return zone
		end
	end
	return nil
end

local function inZone(zone: BasePart, position: Vector3): boolean
	local p = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y + 2 and math.abs(p.Z) <= half.Z
end

-- Le vendeur du magasin : le PNJ (dossier Npcs) dont une pièce porte l'attribut Store
local function vendorOf(store: string): Model?
	local folder = workspace:FindFirstChild("Npcs")
	if not folder then
		return nil
	end
	for _, model in folder:GetChildren() do
		if not model:IsA("Model") then
			continue
		end
		if model:GetAttribute("Store") == store then
			return model
		end
		for _, item in model:GetDescendants() do
			if item:GetAttribute("Store") == store then
				return model
			end
		end
	end
	return nil
end

-- Comptoirs et miroirs du magasin, du plus proche de l'entrée au plus loin (au plus Balance.ShopTour.MaxCounters)
local function countersOf(zone: BasePart): { BasePart }
	local npcs = workspace:FindFirstChild("Npcs")
	local found: { BasePart } = {}
	-- D'abord les comptoirs du décor ; sans comptoir (l'épicerie : on achète au vendeur), le vendeur tagué lui-même
	for _, allowNpcs in { false, true } do
		for _, tag in COUNTER_TAGS do
			for _, item in CollectionService:GetTagged(tag) do
				local isNpc = npcs ~= nil and item:IsDescendantOf(npcs)
				if item:IsA("BasePart") and isNpc == allowNpcs and inZone(zone, item.Position) then
					table.insert(found, item)
				end
			end
		end
		if #found > 0 then
			break
		end
	end
	local entrance = (zone.CFrame * CFrame.new(0, 0, -zone.Size.Z / 2)).Position
	table.sort(found, function(a, b)
		return (a.Position - entrance).Magnitude < (b.Position - entrance).Magnitude
	end)
	-- Un seul arrêt pour des miroirs voisins (les trois du coiffeur, alignés)
	local kept: { BasePart } = {}
	for _, part in found do
		local near = false
		for _, other in kept do
			if (other.Position - part.Position).Magnitude < Balance.ShopTour.MergeDistance then
				near = true
				break
			end
		end
		if not near then
			table.insert(kept, part)
		end
		if #kept >= Balance.ShopTour.MaxCounters then
			break
		end
	end
	return kept
end

local function counterCaption(part: BasePart, store: string): string
	for _, tag in COUNTER_TAGS do
		if CollectionService:HasTag(part, tag) then
			return Texts.Get(`Tour.{store}.{tag}`)
		end
	end
	return ""
end

-- Bulle au-dessus du vendeur, qui disparaît d'elle-même
local function bubble(model: Model, text: string, duration: number)
	local body = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not body then
		return
	end
	local _, size = model:GetBoundingBox()
	local billboard = Ui.create("BillboardGui", {
		Name = "TourBubble",
		Size = UDim2.fromOffset(260, 74),
		StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 1.4, 0),
		AlwaysOnTop = true,
		Adornee = body,
		Parent = model,
	})
	local frame = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = billboard,
	}, { Ui.corner(UDim.new(0, 16)), Ui.stroke(Color3.fromRGB(40, 35, 55), 3, 0) })
	Ui.label({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 1, -16),
		TextColor3 = Color3.fromRGB(30, 28, 40),
		TextStrokeTransparency = 1,
		Text = text,
		Parent = frame,
	})
	billboard.Size = UDim2.fromOffset(0, 0)
	TweenService:Create(billboard, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(260, 74) })
		:Play()
	task.delay(duration, function()
		billboard:Destroy()
	end)
end

local function highlight(part: BasePart): Highlight
	local light = Instance.new("Highlight")
	light.Name = "TourHighlight"
	light.FillColor = GOLD
	light.OutlineColor = GOLD
	light.FillTransparency = 1
	light.OutlineTransparency = 1
	light.DepthMode = Enum.HighlightDepthMode.Occluded
	light.Adornee = part
	light.Parent = part
	TweenService:Create(light, TweenInfo.new(0.35), { FillTransparency = 0.65, OutlineTransparency = 0 }):Play()
	return light
end

-- Plan de caméra qui regarde `target` depuis l'intérieur du magasin (entre la cible et le centre de la salle)
local function shotOn(zone: BasePart, target: Vector3, distance: number, height: number): CFrame
	local center = zone.Position
	local flat = Vector3.new(center.X - target.X, 0, center.Z - target.Z)
	local dir = if flat.Magnitude > 0.1 then flat.Unit else -zone.CFrame.LookVector
	return CFrame.lookAt(target + dir * distance + Vector3.new(0, height, 0), target)
end

local function play(store: string)
	local zone = zoneOf(store)
	local camera = workspace.CurrentCamera
	if not zone or not camera then
		Remotes.ShopTourDone:FireServer(store, false)
		return
	end
	local cfg = Balance.ShopTour
	local home = camera.CFrame
	local floorY = zone.Position.Y - zone.Size.Y / 2
	local entrance = zone.CFrame * CFrame.new(0, 0, -zone.Size.Z / 2 + 2)
	local eye = Vector3.new(entrance.X, floorY + cfg.OverviewHeight, entrance.Z)
	local back = (zone.CFrame * CFrame.new(0, 0, zone.Size.Z * 0.25)).Position
	local look = Vector3.new(back.X, floorY + 3, back.Z)
	local lights: { Highlight } = {}

	local shots = {
		{
			from = CFrame.lookAt(eye + zone.CFrame.LookVector * 2 + Vector3.new(0, 1.5, 0), look),
			to = CFrame.lookAt(eye + (look - eye).Unit * 4, look),
			duration = cfg.Overview,
			caption = Texts.Get(`Tour.{store}.Title`),
		},
	}
	local last = shots[1].to
	local vendor = vendorOf(store)
	if vendor then
		local feet, height = CutsceneController.Measure(vendor)
		local face = feet + Vector3.new(0, height * 0.8, 0)
		local to = shotOn(zone, face, cfg.VendorDistance, 1.2)
		table.insert(shots, {
			from = last,
			to = to,
			duration = cfg.Vendor,
			caption = Texts.Get(`Npc.{"Vendor" .. store}`),
			onStart = function()
				task.wait(cfg.Vendor * 0.35)
				if vendor.Parent then
					NpcController.React(vendor, "Happy")
					bubble(vendor, Texts.Get(`Tour.{store}.Line`), cfg.Vendor * 0.75 + cfg.Counter)
				end
			end,
		})
		last = to
	end
	for _, part in countersOf(zone) do
		local to = shotOn(zone, part.Position, cfg.CounterDistance, 3)
		table.insert(shots, {
			from = last,
			to = to,
			duration = cfg.Counter,
			caption = counterCaption(part, store),
			onStart = function()
				table.insert(lights, highlight(part))
			end,
		})
		last = to
	end
	-- Retour au joueur, là où était sa caméra
	table.insert(shots, { from = last, to = home, duration = cfg.Return })

	MinigameController.SetGameplayLocked(true, "ShopTour")
	ShopTourController.Played += 1
	CutsceneController.Play(shots, function()
		for _, light in lights do
			light:Destroy()
		end
		MinigameController.SetGameplayLocked(false, "ShopTour")
		Remotes.ShopTourDone:FireServer(store, true)
	end)
end

function ShopTourController.Init(controllers)
	MinigameController = controllers.MinigameController
	CutsceneController = controllers.CutsceneController
	NpcController = controllers.NpcController
end

function ShopTourController.Start()
	Remotes.ShopTour.OnClientEvent:Connect(function(store)
		if typeof(store) ~= "string" then
			return
		end
		-- Déjà occupé (série, boutique ouverte, autre cinématique) : on refuse, le serveur reproposera plus tard
		if MinigameController.IsGameplayLocked() or CutsceneController.IsPlaying() then
			Remotes.ShopTourDone:FireServer(store, false)
			return
		end
		play(store)
	end)
end

return ShopTourController
