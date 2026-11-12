-- Boosts temporaires (D47) : achetés en Cash au camion à shakes, au distributeur et au caissier de l'épicerie (D98)
-- (tag "BoostShop"), ils
-- multiplient le Mog des exercices pendant quelques minutes.
-- Garde-manger (D114) : un achat va dans la réserve du joueur (Balance.BoostShop.MaxStock par aliment) ; il le mange
-- quand il veut, n'importe où, mais un seul boost à la fois (refusé tant qu'un boost est actif). Tout le monde voit
-- le repas (Remotes.BoostEaten, animation dans SnackController).
-- L'heure de fin est enregistrée (os.time) : le boost continue de s'écouler si le joueur se déconnecte.
-- Boost Robux (D128, Products.Boost, accordé par PurchaseService) : un second multiplicateur, à part, dont le temps
-- restant est compté en secondes de jeu (il ne s'écoule que connecté : ce qui est payé n'est jamais perdu).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Throttle = require(script.Parent.Parent.Throttle)

local SHOP_TAG = "BoostShop"

local DataService
local StatsService
local TutorialService
local MinigameService
local BossService

local lastEat: { [Player]: number } = {}
local PAID_TICK = 1 -- secondes entre deux décomptes du boost Robux

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

-- Boost Robux du joueur (champ PaidBoost, réparé s'il manque ou s'il est abîmé)
local function paidOf(data): { Multiplier: number, Remaining: number }
	local paid = data.PaidBoost
	if typeof(paid) ~= "table" or typeof(paid.Multiplier) ~= "number" or typeof(paid.Remaining) ~= "number" then
		paid = { Multiplier = 1, Remaining = 0 }
		data.PaidBoost = paid
	end
	return paid
end

-- Multiplicateur du boost Robux en cours (1 sans boost)
function BoostService.PaidMultiplier(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 1
	end
	local paid = paidOf(data)
	return if paid.Remaining > 0 then math.max(paid.Multiplier, 1) else 1
end

-- Multiplicateur de Mog des boosts en cours : en-cas (Cash) × boost Robux (1 sans boost)
function BoostService.Multiplier(player: Player): number
	local id = BoostService.Active(player)
	return (if id then Boosts[id].mogMultiplier else 1) * BoostService.PaidMultiplier(player)
end

-- Réserve du joueur (aliment -> nombre), nettoyée des aliments inconnus ou à zéro
local function stockOf(data): { [string]: number }
	if typeof(data.BoostStock) ~= "table" then
		data.BoostStock = {}
	end
	for id, count in data.BoostStock do
		if not Boosts[id] or typeof(count) ~= "number" or count < 1 then
			data.BoostStock[id] = nil
		end
	end
	return data.BoostStock
end

local function sendState(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local id, endsAt = BoostService.Active(player)
	-- Aura du boost (D121), vue par tous : attributs répliqués du joueur, dessinés par AuraController
	player:SetAttribute("BoostAura", id or "")
	player:SetAttribute("BoostAuraEnds", endsAt)
	local paid = paidOf(data)
	Remotes.BoostState:FireClient(player, {
		id = id,
		endsAt = endsAt,
		stock = table.clone(stockOf(data)),
		paid = { multiplier = paid.Multiplier, remaining = math.max(paid.Remaining, 0) },
	})
end

-- Boost Robux accordé par un reçu (PurchaseService) : le temps s'ajoute à ce qui reste. Renvoie true si accordé.
function BoostService.GrantPaid(player: Player, multiplier: number, duration: number): boolean
	local data = DataService.Get(player)
	if not data or multiplier <= 1 or duration <= 0 then
		return false
	end
	local paid = paidOf(data)
	local running = paid.Remaining > 0
	paid.Multiplier = if running then math.max(paid.Multiplier, multiplier) else multiplier
	paid.Remaining = math.max(paid.Remaining, 0) + duration
	sendState(player)
	return true
end

-- Décompte du boost Robux : seulement pendant que le joueur est là
local function tickPaid(elapsed: number)
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		local paid = data and data.PaidBoost
		if typeof(paid) == "table" and typeof(paid.Remaining) == "number" and paid.Remaining > 0 then
			paid.Remaining = math.max(paid.Remaining - elapsed, 0)
			if paid.Remaining == 0 then
				sendState(player)
			end
		end
	end
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

	local stock = stockOf(data)
	local count = stock[boostId] or 0
	if count >= Balance.BoostShop.MaxStock then
		Remotes.Notify:FireClient(player, { key = "Boost.StockFull", args = { boost = { key = `Boost.{boostId}` } } })
		return
	end
	StatsService.Add(player, "Cash", -boost.price)
	stock[boostId] = count + 1
	sendState(player)
	Remotes.Notify:FireClient(player, {
		key = "Boost.Stored",
		args = { boost = { key = `Boost.{boostId}` }, count = count + 1 },
	})
end

-- Manger un aliment de sa réserve : un seul boost à la fois, jamais pendant une série ou un combat
local function onEat(player: Player, boostId: unknown)
	if typeof(boostId) ~= "string" then
		return
	end
	local boost = Boosts[boostId]
	local data = DataService.Get(player)
	if not boost or not data then
		return
	end
	local now = os.clock()
	if now - (lastEat[player] or -math.huge) < Balance.BoostShop.EatCooldown then
		return
	end
	local stock = stockOf(data)
	if (stock[boostId] or 0) < 1 then
		return
	end
	if MinigameService.IsBusy(player) or BossService.IsFighting(player) then
		Remotes.Notify:FireClient(player, { key = "Boost.EatBusy" })
		return
	end
	local currentId = BoostService.Active(player)
	if currentId then
		Remotes.Notify:FireClient(
			player,
			{ key = "Boost.OneAtATime", args = { boost = { key = `Boost.{currentId}` } } }
		)
		return
	end
	lastEat[player] = now
	stock[boostId] -= 1
	if stock[boostId] < 1 then
		stock[boostId] = nil
	end
	data.Boost = { Id = boostId, EndsAt = os.time() + boost.duration }
	sendState(player)
	Remotes.BoostEaten:FireAllClients(player, boostId)
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
	-- Le caissier de l'épicerie a son propre titre (attribut TitleKey, D98) ; le camion et le distributeur, celui par défaut
	local titleKey = shop:GetAttribute("TitleKey")
	prompt.ObjectText = Texts.Get(if typeof(titleKey) == "string" then titleKey else "Boost.Shop")
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
	MinigameService = services.MinigameService
	BossService = services.BossService
end

function BoostService.Start()
	for _, shop in CollectionService:GetTagged(SHOP_TAG) do
		setupShop(shop)
	end
	CollectionService:GetInstanceAddedSignal(SHOP_TAG):Connect(setupShop)
	Remotes.BuyBoost.OnServerEvent:Connect(onBuy)
	Remotes.EatBoost.OnServerEvent:Connect(onEat)
	Players.PlayerRemoving:Connect(function(player)
		lastEat[player] = nil
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(PAID_TICK)
			local now = os.clock()
			tickPaid(now - last)
			last = now
		end
	end)
	Remotes.RequestStats.OnServerEvent:Connect(Throttle.Wrap(Balance.RemoteThrottle.RequestStats, sendState))
	DataService.PlayerLoaded:Connect(sendState)
end

return BoostService
