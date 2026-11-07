-- Achats Robux à usage unique (Developer Products, D122, Config/Products.luau) : seul ce service reçoit les reçus
-- de Roblox (MarketplaceService.ProcessReceipt) et les distribue :
-- - packs de Cash (montant fixe) et de Mog (part du Mog demandé par le boss du stade, calculée au moment du reçu) ;
-- - victoire contre un boss, proposée sur l'écran de défaite (choix d'Antoine), première victoire seulement ;
-- - autres produits enregistrés par d'autres services (PurchaseService.Register : « prendre la place » d'une machine).
-- Seule la confirmation officielle de Roblox accorde un produit. Chaque reçu est noté dans la sauvegarde (Receipts) :
-- un même achat n'est jamais accordé deux fois, même après une reconnexion ou un redémarrage du serveur.
-- Rien de ce qui s'achète ici ne compte au bras de fer entre joueurs (D122).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Products = require(ReplicatedStorage.Shared.Config.Products)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Parent.Analytics)

local BOSS_WIN = Products.BossWin

local DataService
local StatsService
local BossService
local PumpGodService
local MinigameService

-- Produit -> fonction qui l'accorde ; renvoie true si c'est accordé, false pour que Roblox réessaie plus tard
type Handler = (player: Player, receipt: { [string]: any }) -> boolean
local handlers: { [number]: Handler } = {}
local offers: { [Player]: { bossId: string, at: number } } = {} -- victoire de boss proposée après une défaite
local pendingBoss: { [Player]: string } = {} -- boss dont la victoire est en cours d'achat

local PurchaseService = {}

-- Un autre service accorde lui-même son produit (sans sauvegarde de reçu à faire : PurchaseService s'en charge)
function PurchaseService.Register(productId: number, handler: Handler)
	if productId ~= 0 then
		handlers[productId] = handler
	end
end

local function remember(data, purchaseId: string)
	data.Receipts[purchaseId] = os.time()
	-- Les plus anciens sont oubliés au-delà de Products.MaxReceipts (Roblox ne renvoie plus un reçu accordé)
	local count = 0
	local oldestId, oldestAt = nil, math.huge
	for id, at in data.Receipts do
		count += 1
		if at < oldestAt then
			oldestId, oldestAt = id, at
		end
	end
	if count > Products.MaxReceipts and oldestId then
		data.Receipts[oldestId] = nil
	end
end

local function processReceipt(receipt): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and DataService.Get(player)
	if not player or not data then
		-- Roblox réessaiera à sa prochaine connexion
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if typeof(data.Receipts) ~= "table" then
		data.Receipts = {}
	end
	if data.Receipts[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local handler = handlers[receipt.ProductId]
	if not handler then
		warn(`[PurchaseService] Unknown product {receipt.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, granted = pcall(handler, player, receipt)
	if not ok then
		warn(`[PurchaseService] Product {receipt.ProductId} failed: {granted}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	remember(data, receipt.PurchaseId)
	Analytics.Event(player, "RobuxPurchase", receipt.CurrencySpent or 0, tostring(receipt.ProductId))
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Même chemin que les reçus de Roblox (tests dans Studio : DevCommands "Receipt")
PurchaseService.HandleReceipt = processReceipt

local function packHandler(pack: Products.Pack, kind: string): Handler
	return function(player)
		local data = DataService.Get(player)
		if not data then
			return false
		end
		local amount = if kind == "Cash" then pack.amount or 0 else Products.MogAmount(pack, data.Stage)
		StatsService.Add(player, kind :: "Mog" | "Cash", amount)
		Remotes.PurchaseDone:FireClient(player, { kind = kind, amount = amount })
		return true
	end
end

-- Boss qui garde le stade du joueur, s'il n'est pas encore battu (celui qu'une victoire achetée fait passer)
local function blockingBoss(data): string?
	local stage = Stages.List[data.Stage]
	local boss = stage and stage.boss
	if boss and not boss.comingSoon and data.BossesBeaten[boss.id] ~= true then
		return boss.id
	end
	return nil
end

local function grantBossWin(player: Player, bossId: string): boolean
	if bossId == "PumpGod" then
		return PumpGodService.GrantPurchasedWin(player)
	end
	return BossService.GrantPurchasedWin(player, bossId)
end

local function bossWinHandler(player: Player): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	-- En plein combat : Roblox renverra le reçu plus tard (à la reconnexion au pire)
	if BossService.IsFighting(player) or PumpGodService.IsFighting(player) then
		return false
	end
	local wanted = pendingBoss[player]
	pendingBoss[player] = nil
	offers[player] = nil
	local bossId = blockingBoss(data)
	if bossId and (wanted == nil or wanted == bossId) and grantBossWin(player, bossId) then
		return true
	end
	-- Le boss payé n'est plus à battre (battu entre-temps) : le joueur n'a pas payé pour rien
	StatsService.Add(player, "Cash", BOSS_WIN.FallbackCash)
	Remotes.PurchaseDone:FireClient(player, { kind = "Cash", amount = BOSS_WIN.FallbackCash })
	return true
end

-- Appelé par BossService et PumpGodService après une défaite contre le boss du stade du joueur
function PurchaseService.OfferBossWin(player: Player, bossId: string)
	if BOSS_WIN.productId == 0 then
		return
	end
	local data = DataService.Get(player)
	if not data or blockingBoss(data) ~= bossId then
		return
	end
	offers[player] = { bossId = bossId, at = os.clock() }
	Remotes.BossWinOffer:FireClient(player, {
		bossId = bossId,
		productId = BOSS_WIN.productId,
		robux = BOSS_WIN.robux,
		delay = BOSS_WIN.OfferDelay,
		window = BOSS_WIN.OfferWindow,
	})
end

-- Le joueur accepte l'offre : vérifications, puis la fenêtre d'achat officielle de Roblox
local function onBuyBossWin(player: Player, bossId: unknown)
	local offer = offers[player]
	if typeof(bossId) ~= "string" or not offer or offer.bossId ~= bossId then
		return
	end
	if os.clock() - offer.at > BOSS_WIN.OfferWindow then
		offers[player] = nil
		return
	end
	local data = DataService.Get(player)
	if not data or blockingBoss(data) ~= bossId or MinigameService.IsBusy(player) then
		return
	end
	pendingBoss[player] = bossId
	MarketplaceService:PromptProductPurchase(player, BOSS_WIN.productId)
end

function PurchaseService.Init(services)
	DataService = services.DataService
	StatsService = services.StatsService
	BossService = services.BossService
	PumpGodService = services.PumpGodService
	MinigameService = services.MinigameService
end

function PurchaseService.Start()
	for _, kind in { "Cash", "Mog" } do
		for _, pack in (Products :: any)[kind] do
			PurchaseService.Register(pack.productId, packHandler(pack, kind))
		end
	end
	PurchaseService.Register(BOSS_WIN.productId, bossWinHandler)
	Remotes.BuyBossWin.OnServerEvent:Connect(onBuyBossWin)
	MarketplaceService.ProcessReceipt = processReceipt
	Players.PlayerRemoving:Connect(function(player)
		offers[player] = nil
		pendingBoss[player] = nil
	end)
end

return PurchaseService
