-- Meubles : achat au comptoir du magasin de meubles (Cash + stade requis), pose sur les emplacements fixes
-- de sa propre maison, affichage pour tout le monde (les maisons se visitent librement).
-- Confort (D111) : les meubles posés rendent « bien reposé » quand on reste chez soi (bonus de Mog temporaire,
-- Balance.Rest). Visuel : le modèle 3D « Furniture_<id> » s'il est importé (PropService), sinon des blocs.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Furniture = require(ReplicatedStorage.Shared.Config.Furniture)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Format = require(ReplicatedStorage.Shared.Format)
local Throttle = require(script.Parent.Parent.Throttle)

local SHOP_TAG = "FurnitureShop"
local SLOT_TAG = "FurnitureSlot"
local VISUALS_NAME = "Furniture"

local DataService
local StatsService
local MinigameService
local PlotService
local ExerciseService
local PropService
local TutorialService

local REST = Balance.Rest

type Rest = {
	homeFor: number, -- secondes passées chez soi d'affilée (hors mini-jeu)
	bonus: number, -- bonus de Mog en cours (0,15 = +15 %)
	endsAt: number, -- heure serveur de fin du bonus (repoussée tant qu'on est chez soi)
	home: boolean, -- en train de se reposer chez soi
}

local rests: { [Player]: Rest } = {}
local plotBoxes: { [Model]: { cframe: CFrame, half: Vector3 } } = {}

local FurnitureService = {}

-- Confort de la maison : somme des prix des meubles posés
local function comfortOf(data): number
	local total = 0
	for slot, itemId in data.FurniturePlaced do
		local item = Furniture.Items[itemId]
		if item and item.slot == slot then
			total += item.price
		end
	end
	return total
end

local function restBonus(comfort: number): number
	return REST.MaxBonus * math.clamp(comfort / REST.FullComfort, 0, 1)
end

local function sendState(player: Player)
	local data = DataService.Get(player)
	if data then
		local comfort = comfortOf(data)
		Remotes.FurnitureState:FireClient(player, {
			owned = data.FurnitureOwned,
			placed = data.FurniturePlaced,
			comfort = comfort,
			restBonus = restBonus(comfort),
		})
	end
end

local function sendRest(player: Player, rest: Rest)
	Remotes.RestState:FireClient(player, { bonus = rest.bonus, endsAt = rest.endsAt, home = rest.home })
end

-- Le joueur est-il dans sa parcelle (maison et jardin, avec une petite marge) ?
local function isHome(player: Player): boolean
	local plot = PlotService.GetPlot(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not plot or not root then
		return false
	end
	local box = plotBoxes[plot]
	if not box then
		local cframe, size = plot:GetBoundingBox()
		box = { cframe = cframe, half = size / 2 + Vector3.one * REST.HomeMargin }
		plotBoxes[plot] = box
	end
	local offset = box.cframe:PointToObjectSpace(root.Position)
	return math.abs(offset.X) <= box.half.X and math.abs(offset.Y) <= box.half.Y and math.abs(offset.Z) <= box.half.Z
end

-- Une vérification par joueur : chez soi (hors mini-jeu) assez longtemps -> bien reposé ; le minuteur reste plein
-- tant qu'on y est, et file dès qu'on sort ou qu'on lance un mini-jeu
local function checkRest(player: Player, rest: Rest)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local now = workspace:GetServerTimeNow()
	if not isHome(player) or MinigameService.IsBusy(player) then
		rest.homeFor = 0
		if rest.home then
			rest.home = false
			sendRest(player, rest)
		end
		return
	end
	rest.homeFor += REST.CheckInterval
	local bonus = restBonus(comfortOf(data))
	if rest.homeFor < REST.HomeSeconds or bonus <= 0 then
		return
	end
	local fresh = rest.endsAt <= now
	local changed = not rest.home or rest.bonus ~= bonus
	rest.bonus = bonus
	rest.endsAt = now + REST.Duration
	rest.home = true
	if changed then
		sendRest(player, rest)
	end
	if fresh then
		Remotes.Notify:FireClient(player, {
			key = "Rest.Rested",
			args = { percent = Format.Gain(bonus * 100), minutes = Format.Gain(REST.Duration / 60) },
		})
	end
end

-- Multiplicateur de Mog « bien reposé » (1 sans bonus)
function FurnitureService.RestMultiplier(player: Player): number
	local rest = rests[player]
	if rest and rest.endsAt > workspace:GetServerTimeNow() then
		return 1 + rest.bonus
	end
	return 1
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
	prompt.Triggered:Connect(function(player)
		TutorialService.OnEvent(player, "ShopOpened", "Furniture")
	end)
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
	TutorialService = services.TutorialService
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

	-- Bien reposé (D111)
	local function track(player: Player)
		rests[player] = { homeFor = 0, bonus = 0, endsAt = 0, home = false }
	end
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player)
		rests[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(REST.CheckInterval)
			for player, rest in rests do
				local ok, err = pcall(checkRest, player, rest)
				if not ok then
					warn("[FurnitureService] repos :", err)
				end
			end
		end
	end)
	DataService.PlayerLoaded:Connect(sendState)
	Remotes.BuyFurniture.OnServerEvent:Connect(onBuy)
	Remotes.PlaceFurniture.OnServerEvent:Connect(onPlace)
	Remotes.RequestStats.OnServerEvent:Connect(Throttle.Wrap(Balance.RemoteThrottle.RequestStats, sendState))
end

return FurnitureService
