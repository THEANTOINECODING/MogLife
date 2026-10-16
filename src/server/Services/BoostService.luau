-- Boosts temporaires (D47) : achetés en Cash au camion à shakes et au distributeur (tag "BoostShop"), ils
-- multiplient le Mog des exercices pendant quelques minutes. Un seul actif à la fois : racheter le même prolonge
-- (plafonné à Balance.BoostShop.MaxDuration), en acheter un autre le remplace.
-- L'heure de fin est enregistrée (os.time) : le boost continue de s'écouler si le joueur se déconnecte.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local SHOP_TAG = "BoostShop"

local DataService
local StatsService
local TutorialService

local BoostService = {}

-- Boost en cours du joueur (nil s'il n'y en a pas ou s'il est fini)
function BoostService.Active(player: Player): (string?, number)
	local data = DataService.Get(player)
	local boost = data and data.Boost
	if not boost or boost.Id == "" or not Boosts[boost.Id] or boost.EndsAt <= os.time() then
		return nil, 0
	end
	return boost.Id, boost.EndsAt
end

-- Multiplicateur de Mog du boost en cours (1 sans boost)
function BoostService.Multiplier(player: Player): number
	local id = BoostService.Active(player)
	return if id then Boosts[id].mogMultiplier else 1
end

local function sendState(player: Player)
	local id, endsAt = BoostService.Active(player)
	Remotes.BoostState:FireClient(player, { id = id, endsAt = endsAt })
end

local function isNearShop(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	for _, shop in CollectionService:GetTagged(SHOP_TAG) do
		if shop:IsA("BasePart") and (shop.Position - root.Position).Magnitude <= Balance.BoostShop.Distance then
			return true
		end
	end
	return false
end

local function onBuy(player: Player, boostId: unknown)
	if typeof(boostId) ~= "string" then
		return
	end
	local boost = Boosts[boostId]
	local data = DataService.Get(player)
	if not boost or not data or not isNearShop(player) then
		return
	end
	if data.Stage < boost.requiredStage then
		local stage = Stages.List[boost.requiredStage]
		Remotes.Notify:FireClient(player, { key = "Boost.Locked", args = { stage = { key = `Stage.{stage.id}` } } })
		return
	end
	if data.Cash < boost.price then
		Remotes.Notify:FireClient(player, { key = "Shop.NotEnough" })
		return
	end

	StatsService.Add(player, "Cash", -boost.price)
	local now = os.time()
	local currentId, endsAt = BoostService.Active(player)
	-- Même boost : on prolonge ; autre boost : il remplace l'ancien
	local start = if currentId == boostId then endsAt else now
	data.Boost = { Id = boostId, EndsAt = math.min(start + boost.duration, now + Balance.BoostShop.MaxDuration) }
	sendState(player)
	Remotes.Notify:FireClient(player, {
		key = "Boost.Bought",
		args = { boost = { key = `Boost.{boostId}` }, minutes = math.ceil(boost.duration / 60) },
	})
end

-- Boost offert (événement de ville) : jamais à la place d'un boost plus fort déjà actif. Renvoie true si donné.
function BoostService.Grant(player: Player, boostId: string): boolean
	local boost = Boosts[boostId]
	local data = DataService.Get(player)
	if not boost or not data then
		return false
	end
	local now = os.time()
	local currentId, endsAt = BoostService.Active(player)
	if currentId and currentId ~= boostId and Boosts[currentId].mogMultiplier >= boost.mogMultiplier then
		return false
	end
	local start = if currentId == boostId then endsAt else now
	data.Boost = { Id = boostId, EndsAt = math.min(start + boost.duration, now + Balance.BoostShop.MaxDuration) }
	sendState(player)
	return true
end

local function setupShop(shop: Instance)
	if not shop:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Texts.Get("Boost.Prompt")
	prompt.ObjectText = Texts.Get("Boost.Shop")
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = shop
	prompt.Triggered:Connect(function(player)
		TutorialService.OnEvent(player, "ShopOpened", "Boosts")
	end)
end

function BoostService.Init(services)
	DataService = services.DataService
	StatsService = services.StatsService
	TutorialService = services.TutorialService
end

function BoostService.Start()
	for _, shop in CollectionService:GetTagged(SHOP_TAG) do
		setupShop(shop)
	end
	CollectionService:GetInstanceAddedSignal(SHOP_TAG):Connect(setupShop)
	Remotes.BuyBoost.OnServerEvent:Connect(onBuy)
	Remotes.RequestStats.OnServerEvent:Connect(sendState)
	DataService.PlayerLoaded:Connect(sendState)
end

return BoostService
