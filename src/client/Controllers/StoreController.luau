-- Boutique Robux (D122, Config/Products.luau) :
-- - un bouton « + » à côté du Mog et du Cash ouvre la fenêtre des packs (Cash : montant fixe ; Mog : grandit avec le
--   stade, le serveur recalcule au moment de l'achat) ; chaque pack ouvre la fenêtre d'achat officielle de Roblox ;
-- - après une défaite contre le boss de son stade, une carte propose de le passer en Robux (choix d'Antoine) ;
-- - un pack accordé fait s'envoler les billets ou les muscles vers le compteur.
-- Le client ne décide de rien : le serveur (PurchaseService) n'accorde que les reçus confirmés par Roblox.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 210, 60)
local GREEN = Color3.fromRGB(60, 190, 90)

local UIController
local MinigameController

local StoreController = {}

local gui: ScreenGui
local panel: Frame
local offerCard: Frame
local offerText: TextLabel
local offerButton: TextButton
local offerToken = 0
local currentOffer: { [string]: any }? = nil
local stage = 1
local cards: { { pack: Products.Pack, kind: string, amount: TextLabel, buy: TextButton } } = {}

-- Prix réels (Creator Hub), demandés une fois ; en attendant, le prix conseillé de Products
local prices: { [number]: number } = {}
local asked: { [number]: boolean } = {}
local function priceOf(productId: number, fallback: number, onReady: () -> ()): number
	if not asked[productId] then
		asked[productId] = true
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
			end)
			if ok and info and typeof(info.PriceInRobux) == "number" then
				prices[productId] = info.PriceInRobux
				onReady()
			end
		end)
	end
	return prices[productId] or fallback
end

local function anyPack(kind: string): boolean
	for _, pack in (Products :: any)[kind] do
		if pack.productId ~= 0 then
			return true
		end
	end
	return false
end

local function refresh()
	for _, card in cards do
		local value = if card.kind == "Cash" then card.pack.amount or 0 else Products.MogAmount(card.pack, stage)
		card.amount.Text = Texts.Get(`Store.{card.kind}Amount`, { amount = Format.Short(value) })
		card.buy.Text = Texts.Get("Shop.BuyRobux", { price = priceOf(card.pack.productId, card.pack.robux, refresh) })
	end
end

local function close()
	if not panel.Visible then
		return
	end
	panel.Visible = false
	UIController.SetStatsHidden(false, "Store")
end

local function open()
	if MinigameController.IsGameplayLocked() then
		return
	end
	refresh()
	panel.Visible = true
	UIController.SetStatsHidden(true, "Store")
end

local function buildCard(parent: Instance, pack: Products.Pack, kind: string, order: number)
	local card = Ui.create("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1 / 3, -8, 1, 0),
		BackgroundColor3 = Color3.fromRGB(35, 28, 55),
		Parent = parent,
	}, { Ui.corner(UDim.new(0, 14)), Ui.stroke(if kind == "Cash" then GREEN else GOLD, 2, 0.2) })
	Ui.label({
		Position = UDim2.fromScale(0.1, 0.04),
		Size = UDim2.fromScale(0.8, 0.36),
		Text = pack.icon,
		TextStrokeTransparency = 1,
		Parent = card,
	})
	local amount = Ui.label({
		Position = UDim2.fromScale(0.06, 0.42),
		Size = UDim2.fromScale(0.88, 0.2),
		TextColor3 = if kind == "Cash" then Color3.fromRGB(140, 255, 140) else GOLD,
		Parent = card,
	})
	local buy = Ui.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -12, 0.3, 0),
		BackgroundColor3 = GREEN,
		Parent = card,
	})
	buy.Activated:Connect(function()
		MarketplaceService:PromptProductPurchase(player, pack.productId)
	end)
	table.insert(cards, { pack = pack, kind = kind, amount = amount, buy = buy })
end

local function buildSection(kind: string, index: number)
	local row = Ui.create("Frame", {
		Position = UDim2.fromOffset(16, 62 + (index - 1) * 182),
		Size = UDim2.new(1, -32, 0, 30),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	Ui.label({
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = Texts.Get(`Store.{kind}Title`),
		Parent = row,
	})
	local list = Ui.create("Frame", {
		Position = UDim2.fromOffset(16, 96 + (index - 1) * 182),
		Size = UDim2.new(1, -32, 0, 140),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Ui.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, pack in (Products :: any)[kind] do
		if pack.productId ~= 0 then
			buildCard(list, pack, kind, order)
		end
	end
end

local function buildGui()
	gui = Ui.create("ScreenGui", { Name = "Store", ResetOnSpawn = false, DisplayOrder = 12 })
	panel = Ui.panel({
		Name = "Packs",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 440),
		Visible = false,
		Parent = gui,
	})
	Ui.fitToScreen(panel, 12)
	Ui.label({
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -80, 0, 40),
		TextColor3 = GOLD,
		Text = Texts.Get("Store.Title"),
		Parent = panel,
	})
	local closeButton = Ui.closeButton({ Text = Texts.Get("Shop.Close"), Parent = panel })
	Ui.onBack(closeButton, close)
	Ui.markModal(panel)
	local index = 0
	for _, kind in { "Mog", "Cash" } do
		if anyPack(kind) then
			index += 1
			buildSection(kind, index)
		end
	end

	-- Carte « passer ce boss » (après une défaite)
	offerCard = Ui.panel({
		Name = "BossWin",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(420, 150),
		Visible = false,
		Parent = gui,
	})
	offerText = Ui.label({
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 56),
		Parent = offerCard,
	})
	offerButton = Ui.button({
		Name = "Buy",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -12),
		Size = UDim2.new(0.6, -20, 0, 60),
		BackgroundColor3 = GREEN,
		Parent = offerCard,
	})
	local later = Ui.button({
		Name = "Later",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -12),
		Size = UDim2.new(0.4, -14, 0, 60),
		BackgroundColor3 = Color3.fromRGB(90, 90, 90),
		Text = Texts.Get("Store.NoThanks"),
		Parent = offerCard,
	})
	offerButton.Activated:Connect(function()
		local offer = currentOffer
		if offer then
			Remotes.BuyBossWin:FireServer(offer.bossId)
		end
	end)
	Ui.onBack(later, function()
		offerToken += 1
		currentOffer = nil
		offerCard.Visible = false
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function showOffer(offer)
	if typeof(offer) ~= "table" or typeof(offer.bossId) ~= "string" or typeof(offer.productId) ~= "number" then
		return
	end
	offerToken += 1
	local token = offerToken
	task.delay(tonumber(offer.delay) or 0, function()
		if token ~= offerToken then
			return
		end
		currentOffer = offer
		local function setText()
			if token == offerToken then
				offerButton.Text = Texts.Get(
					"Shop.BuyRobux",
					{ price = priceOf(offer.productId, tonumber(offer.robux) or 0, setText) }
				)
			end
		end
		offerText.Text = Texts.Get("Store.BossWin", { boss = Texts.Get(`Boss.{offer.bossId}`) })
		setText()
		offerCard.Visible = true
		local scale = offerCard:FindFirstChildOfClass("UIScale") or Ui.create("UIScale", { Parent = offerCard })
		scale.Scale = 0.6
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		-- L'offre disparaît d'elle-même à la fin de sa fenêtre (le serveur la refuse ensuite)
		task.delay(tonumber(offer.window) or 60, function()
			if token == offerToken then
				currentOffer = nil
				offerCard.Visible = false
			end
		end)
	end)
end

function StoreController.Init(controllers)
	UIController = controllers.UIController
	MinigameController = controllers.MinigameController
end

function StoreController.Start()
	buildGui()
	if anyPack("Mog") then
		UIController.AttachCounterButton("Mog", Color3.fromRGB(230, 160, 30), open)
	end
	if anyPack("Cash") then
		UIController.AttachCounterButton("Cash", GREEN, open)
	end
	Remotes.StatsChanged.OnClientEvent:Connect(function(stats)
		if typeof(stats) == "table" and typeof(stats.Stage) == "number" then
			stage = stats.Stage
			if panel.Visible then
				refresh()
			end
		end
	end)
	Remotes.PurchaseDone.OnClientEvent:Connect(function(result)
		if typeof(result) ~= "table" or typeof(result.amount) ~= "number" then
			return
		end
		local kind = if result.kind == "Mog" then "Mog" else "Cash"
		close()
		UIController.FlyToCounter(kind)
		UIController.Toast(Texts.Get(`Store.{kind}Got`, { amount = Format.Short(result.amount) }), 3)
	end)
	Remotes.BossWinOffer.OnClientEvent:Connect(showOffer)
	-- Victoire accordée (achetée ou gagnée) : l'offre n'a plus lieu d'être
	Remotes.BossUpdate.OnClientEvent:Connect(function(update)
		if typeof(update) == "table" and update.state == "Victory" then
			offerToken += 1
			currentOffer = nil
			offerCard.Visible = false
		end
	end)
end

return StoreController
