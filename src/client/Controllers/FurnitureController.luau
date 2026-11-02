-- Meubles : catalogue du magasin (comptoir) et choix du meuble posé sur un emplacement de sa maison.
-- Le serveur vérifie tout (prix, stade, Cash, possession, maison) ; ce contrôleur n'affiche que l'état reçu.
-- Les prompts « Décorer » des maisons des autres joueurs sont cachés (on visite, on ne décore pas).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Furniture = require(ReplicatedStorage.Shared.Config.Furniture)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local SHOP_TAG = "FurnitureShop"
local SLOT_TAG = "FurnitureSlot"
local PLOT_TAG = "Plot"

local player = Players.LocalPlayer

local MinigameController

local panel: Frame
local titleLabel: TextLabel
local hintLabel: TextLabel
local cashLabel: TextLabel
local tabsFrame: Frame
local list: ScrollingFrame
local tabs: { [string]: TextButton } = {}

local mode: "Store" | "Home" = "Store"
local slot = Furniture.Slots[1]
local cash = 0
local stage = 1
local owned: { [string]: boolean } = {}
local placed: { [string]: string } = {}
local confirming: string? = nil

local FurnitureController = {}

local function itemsFor(slotName: string): { string }
	local ids = {}
	for id, item in Furniture.Items do
		if item.slot == slotName then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return Furniture.Items[a].order < Furniture.Items[b].order
	end)
	return ids
end

-- Boss à battre pour débloquer un stade (même règle que les exercices)
local function unlockingBoss(requiredStage: number): string
	local previous = Stages.List[requiredStage - 1]
	local bossId = previous and previous.boss and previous.boss.id or ""
	return Texts.Get(`Boss.{bossId}`)
end

local render

local function onItemButton(itemId: string)
	local item = Furniture.Items[itemId]
	if mode == "Home" then
		if placed[slot] == itemId then
			Remotes.PlaceFurniture:FireServer(slot, nil)
		elseif owned[itemId] then
			Remotes.PlaceFurniture:FireServer(slot, itemId)
		end
	elseif not owned[itemId] and stage >= (item.requiredStage or 1) then
		if confirming == itemId then
			confirming = nil
			Remotes.BuyFurniture:FireServer(itemId)
		else
			confirming = itemId
		end
	end
	render()
end

-- Texte et couleur du bouton d'un meuble selon le mode et l'état
local function buttonState(itemId: string): (string, Color3)
	local item = Furniture.Items[itemId]
	if mode == "Home" then
		if placed[slot] == itemId then
			return Texts.Get("Furniture.Placed"), Color3.fromRGB(60, 170, 80)
		elseif owned[itemId] then
			return Texts.Get("Furniture.Place"), Color3.fromRGB(60, 110, 200)
		end
		return Texts.Get("Furniture.AtStore"), Color3.fromRGB(60, 60, 60)
	end
	if owned[itemId] then
		return Texts.Get("Furniture.Owned"), Color3.fromRGB(60, 170, 80)
	end
	local requiredStage = item.requiredStage or 1
	if stage < requiredStage then
		return Texts.Get("Shop.BossReward", { boss = unlockingBoss(requiredStage) }), Color3.fromRGB(60, 60, 60)
	end
	local price = Format.Short(item.price)
	if confirming == itemId then
		return Texts.Get("Shop.Confirm", { price = price }), Color3.fromRGB(220, 120, 30)
	end
	local affordable = cash >= item.price
	return Texts.Get("Shop.Buy", { price = price }),
		if affordable then Color3.fromRGB(80, 80, 95) else Color3.fromRGB(110, 50, 50)
end

function render()
	cashLabel.Text = Texts.Get("Shop.Cash", { value = Format.Short(cash) })
	for name, tab in tabs do
		tab.BackgroundColor3 = if name == slot then Color3.fromRGB(220, 120, 30) else Color3.fromRGB(70, 70, 80)
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for index, itemId in itemsFor(slot) do
		local item = Furniture.Items[itemId]
		local compact = Ui.isPhonePortrait()
		local row = Ui.create("Frame", {
			Name = itemId,
			Size = UDim2.new(1, -12, 0, 58),
			BackgroundColor3 = Color3.fromRGB(40, 35, 55),
			BackgroundTransparency = 0.2,
			LayoutOrder = index,
			Parent = list,
		}, { Ui.corner(UDim.new(0, 10)) })
		-- Pastille de couleur : aperçu simple du meuble
		Ui.create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(36, 36),
			BackgroundColor3 = item.pieces[1].color,
			Parent = row,
		}, { Ui.corner(UDim.new(0, 8)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.3) })
		Ui.label({
			Position = UDim2.fromOffset(56, 8),
			Size = UDim2.new(1, if compact then -200 else -250, 1, -16),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = Texts.Get(`Furniture.{itemId}`),
			Parent = row,
		})
		local text, color = buttonState(itemId)
		local button = Ui.button({
			Name = "Action",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(if compact then 132 else 180, 44),
			BackgroundColor3 = color,
			Text = text,
			Parent = row,
		})
		button.Activated:Connect(function()
			onItemButton(itemId)
		end)
	end
end

local function open(newMode: "Store" | "Home", slotName: string?)
	mode = newMode
	slot = slotName or slot
	confirming = nil
	tabsFrame.Visible = mode == "Store"
	if mode == "Store" then
		titleLabel.Text = Texts.Get("Furniture.Title")
		hintLabel.Text = Texts.Get("Furniture.Hint")
		list.Position = UDim2.fromOffset(16, 134)
		list.Size = UDim2.new(1, -32, 1, -150)
	else
		titleLabel.Text = Texts.Get("Furniture.HomeTitle", { slot = Texts.Get(`Slot.{slot}`) })
		hintLabel.Text = Texts.Get("Furniture.HomeHint")
		list.Position = UDim2.fromOffset(16, 84)
		list.Size = UDim2.new(1, -32, 1, -100)
	end
	panel.Visible = true
	MinigameController.SetGameplayLocked(true, "Furniture")
	render()
end

local function close()
	panel.Visible = false
	MinigameController.SetGameplayLocked(false, "Furniture")
end

local function buildGui()
	local gui = Ui.create("ScreenGui", { Name = "Furniture", ResetOnSpawn = false, DisplayOrder = 4 })
	panel = Ui.panel({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = if Ui.isPhonePortrait() then UDim2.new(1, -20, 0, 480) else UDim2.fromOffset(600, 480),
		Visible = false,
		Parent = gui,
	})
	Ui.watchViewport(function()
		panel.Size = if Ui.isPhonePortrait() then UDim2.new(1, -20, 0, 480) else UDim2.fromOffset(600, 480)
	end)
	titleLabel = Ui.label({
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(0.62, -16, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 220, 120),
		Parent = panel,
	})
	cashLabel = Ui.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -64, 0, 12),
		Size = UDim2.new(0.38, -64, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(140, 255, 140),
		Parent = panel,
	})
	hintLabel = Ui.label({
		Position = UDim2.fromOffset(16, 52),
		Size = UDim2.new(1, -32, 0, 22),
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(200, 200, 210),
		Parent = panel,
	})

	-- Onglets des emplacements (2 lignes de 4), seulement au magasin
	tabsFrame = Ui.create("Frame", {
		Name = "Tabs",
		Position = UDim2.fromOffset(16, 80),
		Size = UDim2.new(1, -32, 0, 48),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Ui.create("UIGridLayout", {
			CellSize = UDim2.new(0.25, -6, 0.5, -3),
			CellPadding = UDim2.fromOffset(6, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for index, slotName in Furniture.Slots do
		local tab = Ui.button({
			Name = `Tab{slotName}`,
			LayoutOrder = index,
			Text = Texts.Get(`Slot.{slotName}`),
			Parent = tabsFrame,
		})
		local padding = tab:FindFirstChildOfClass("UIPadding")
		if padding then
			padding.PaddingTop = UDim.new(0, 2)
			padding.PaddingBottom = UDim.new(0, 2)
		end
		tab.Activated:Connect(function()
			slot = slotName
			confirming = nil
			render()
		end)
		tabs[slotName] = tab
	end

	list = Ui.create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	}, {
		Ui.create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local closeButton = Ui.closeButton({ Text = Texts.Get("Shop.Close"), Parent = panel })
	closeButton.Activated:Connect(close)

	gui.Parent = player:WaitForChild("PlayerGui")
end

-- Maison (tag Plot) qui contient cet objet
local function plotOf(instance: Instance): Instance?
	local current = instance.Parent
	while current and current ~= workspace do
		if CollectionService:HasTag(current, PLOT_TAG) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function isMine(instance: Instance): boolean
	local plot = plotOf(instance)
	return plot ~= nil and plot:GetAttribute("OwnerUserId") == player.UserId
end

-- Affiche le prompt « Décorer » seulement dans sa propre maison (changement local, non répliqué)
local function watchSlot(slotPart: Instance)
	local plot = plotOf(slotPart)
	if not plot then
		return
	end
	local function update()
		for _, prompt in slotPart:GetChildren() do
			if prompt:IsA("ProximityPrompt") then
				prompt.Enabled = isMine(slotPart)
			end
		end
	end
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(update)
	slotPart.ChildAdded:Connect(update)
	update()
end

function FurnitureController.Init(controllers)
	MinigameController = controllers.MinigameController
end

function FurnitureController.Start()
	buildGui()

	for _, slotPart in CollectionService:GetTagged(SLOT_TAG) do
		watchSlot(slotPart)
	end
	CollectionService:GetInstanceAddedSignal(SLOT_TAG):Connect(watchSlot)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local parent = prompt.Parent
		if not parent then
			return
		end
		if CollectionService:HasTag(parent, SHOP_TAG) then
			open("Store", nil)
		elseif CollectionService:HasTag(parent, SLOT_TAG) and isMine(parent) then
			local slotName = parent:GetAttribute("Slot")
			if typeof(slotName) == "string" then
				open("Home", slotName)
			end
		end
	end)
	Remotes.StatsChanged.OnClientEvent:Connect(function(stats)
		cash = stats.Cash
		stage = stats.Stage
		if panel.Visible then
			render()
		end
	end)
	Remotes.FurnitureState.OnClientEvent:Connect(function(state)
		owned = state.owned or {}
		placed = state.placed or {}
		if panel.Visible then
			render()
		end
	end)
end

return FurnitureController
