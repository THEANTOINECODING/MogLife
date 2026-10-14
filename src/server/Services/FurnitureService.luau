-- Meubles : achat au comptoir du magasin de meubles (Cash + stade requis), pose sur les emplacements fixes
-- de sa propre maison, affichage pour tout le monde (les maisons se visitent librement).
-- Purement décoratif. Visuel : le modèle 3D « Furniture_<id> » s'il est importé (PropService), sinon des blocs.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Furniture = require(ReplicatedStorage.Shared.Config.Furniture)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local SHOP_TAG = "FurnitureShop"
local SLOT_TAG = "FurnitureSlot"
local VISUALS_NAME = "Furniture"

local DataService
local StatsService
local MinigameService
local PlotService
local ExerciseService
local PropService

local FurnitureService = {}

local function sendState(player: Player)
	local data = DataService.Get(player)
	if data then
		Remotes.FurnitureState:FireClient(player, { owned = data.FurnitureOwned, placed = data.FurniturePlaced })
	end
end

local function clear(plot: Model)
	local old = plot:FindFirstChild(VISUALS_NAME)
	if old then
		old:Destroy()
	end
end

-- Reconstruit tous les meubles posés dans la maison du joueur
local function render(player: Player)
	local plot = PlotService.GetPlot(player)
	local data = DataService.Get(player)
	if not plot or not data then
		return
	end
	clear(plot)
	local visuals = Instance.new("Model")
	visuals.Name = VISUALS_NAME
	for slot, slotPart in PlotService.GetSlots(plot) do
		local itemId = data.FurniturePlaced[slot]
		local item = if itemId then Furniture.Items[itemId] else nil
		if not item or item.slot ~= slot then
			continue
		end
		-- Modèle 3D importé : posé au sol (ou au centre du mur pour les posters), dos contre le mur
		local onWall = slot == "Poster"
		local model =
			PropService.Place(`Furniture_{itemId}`, slotPart.CFrame * CFrame.new(0, 0, if onWall then 0.1 else 0), {
				collide = slot ~= "Rug" and slot ~= "Poster",
				align = if onWall then "Back" else nil,
				centered = onWall,
			})
		if model then
			model.Name = itemId
			model.Parent = visuals
			continue
		end
		for index, piece in item.pieces do
			local rotation = piece.rotation or Vector3.zero
			local part = Instance.new("Part")
			part.Name = `{itemId}_{index}`
			part.Anchored = true
			part.Size = piece.size
			part.CFrame = slotPart.CFrame
				* CFrame.new(piece.offset)
				* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
			part.Color = piece.color
			part.Material = piece.material or Enum.Material.SmoothPlastic
			part.Shape = piece.shape or Enum.PartType.Block
			part.CanCollide = slot ~= "Rug" and slot ~= "Poster"
			part.CastShadow = slot ~= "Rug"
			part.Parent = visuals
		end
	end
	visuals.Parent = plot
end

local function nearShop(player: Player): boolean
	for _, counter in CollectionService:GetTagged(SHOP_TAG) do
		if counter:IsA("BasePart") and MinigameService.IsNear(player, counter, Balance.Furniture.ShopDistance) then
			return true
		end
	end
	return false
end

local function onBuy(player: Player, itemId: unknown)
	if typeof(itemId) ~= "string" then
		return
	end
	local item = Furniture.Items[itemId]
	local data = DataService.Get(player)
	if not item or not data or data.FurnitureOwned[itemId] or not nearShop(player) then
		return
	end
	local requiredStage = item.requiredStage or 1
	if data.Stage < requiredStage then
		Remotes.Notify:FireClient(player, {
			key = "Series.Locked",
			args = { boss = { key = `Boss.{ExerciseService.UnlockingBossId(requiredStage)}` } },
		})
		return
	end
	if data.Cash < item.price then
		Remotes.Notify:FireClient(player, { key = "Shop.NotEnough" })
		return
	end

	StatsService.Add(player, "Cash", -item.price)
	data.FurnitureOwned[itemId] = true
	-- Premier meuble de ce type : il est posé directement à la maison
	if data.FurniturePlaced[item.slot] == nil then
		data.FurniturePlaced[item.slot] = itemId
		render(player)
	end
	sendState(player)
	Remotes.Notify:FireClient(player, { key = "Furniture.Bought", args = { item = { key = `Furniture.{itemId}` } } })
end

local function onPlace(player: Player, slot: unknown, itemId: unknown)
	if typeof(slot) ~= "string" then
		return
	end
	local plot = PlotService.GetPlot(player)
	local data = DataService.Get(player)
	local slotPart = plot and PlotService.GetSlots(plot)[slot]
	if not data or not slotPart or not MinigameService.IsNear(player, slotPart, Balance.Furniture.PlaceDistance) then
		return
	end
	if itemId == nil then
		data.FurniturePlaced[slot] = nil
	elseif typeof(itemId) == "string" then
		local item = Furniture.Items[itemId]
		if not item or item.slot ~= slot or not data.FurnitureOwned[itemId] then
			return
		end
		data.FurniturePlaced[slot] = itemId
	else
		return
	end
	render(player)
	sendState(player)
end

local function setupCounter(counter: Instance)
	if not counter:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Texts.Get("Furniture.Prompt")
	prompt.ObjectText = Texts.Get("Furniture.Store")
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
end

-- Chaque emplacement a un prompt « Décorer » ; le client le cache dans les maisons des autres
local function setupSlot(slotPart: Instance)
	if not slotPart:IsA("BasePart") then
		return
	end
	local slot = slotPart:GetAttribute("Slot")
	if typeof(slot) ~= "string" then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Texts.Get("Furniture.Decorate")
	prompt.ObjectText = Texts.Get(`Slot.{slot}`)
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = slotPart
end

-- Rafraîchit meubles et état (après une modification directe des données, ex. commandes de test)
function FurnitureService.Refresh(player: Player)
	render(player)
	sendState(player)
end

function FurnitureService.Init(services)
	DataService = services.DataService
	StatsService = services.StatsService
	MinigameService = services.MinigameService
	PlotService = services.PlotService
	ExerciseService = services.ExerciseService
	PropService = services.PropService
end

function FurnitureService.Start()
	for _, counter in CollectionService:GetTagged(SHOP_TAG) do
		setupCounter(counter)
	end
	CollectionService:GetInstanceAddedSignal(SHOP_TAG):Connect(setupCounter)
	for _, slotPart in CollectionService:GetTagged(SLOT_TAG) do
		setupSlot(slotPart)
	end
	CollectionService:GetInstanceAddedSignal(SLOT_TAG):Connect(setupSlot)

	PlotService.OnAssigned(function(player)
		render(player)
		sendState(player)
	end)
	PlotService.OnReleased(function(_, plot)
		clear(plot)
	end)
	DataService.PlayerLoaded:Connect(sendState)
	Remotes.BuyFurniture.OnServerEvent:Connect(onBuy)
	Remotes.PlaceFurniture.OnServerEvent:Connect(onPlace)
	Remotes.RequestStats.OnServerEvent:Connect(sendState)
end

return FurnitureService
