-- Boutique de style (miroir) : catégories, achat avec confirmation, porter / retirer.
-- Le serveur vérifie tout (prix, Cash, possession) ; ce contrôleur n'affiche que l'état reçu.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StyleItems = require(ReplicatedStorage.Shared.Config.StyleItems)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local MIRROR_TAG = "Mirror"
local CATEGORIES = { "Hair", "Top", "Accessory" }

local player = Players.LocalPlayer

local MinigameController

local panel: Frame
local cashLabel: TextLabel
local list: ScrollingFrame
local tabs: { [string]: TextButton } = {}

local category = "Hair"
local cash = 0
local owned: { [string]: boolean } = {}
local equipped: { [string]: string } = {}
local confirming: string? = nil

local ShopController = {}

local function sortedItems(cat: string): { string }
	local ids = {}
	for id, item in StyleItems do
		if item.category == cat then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return StyleItems[a].order < StyleItems[b].order
	end)
	return ids
end

local render

local function onItemButton(itemId: string)
	local item = StyleItems[itemId]
	if equipped[item.category] == itemId then
		Remotes.EquipStyle:FireServer(item.category, nil)
	elseif owned[itemId] then
		Remotes.EquipStyle:FireServer(item.category, itemId)
	elseif item.price then
		if confirming == itemId then
			confirming = nil
			Remotes.BuyStyle:FireServer(itemId)
		else
			confirming = itemId
		end
	end
	render()
end

function render()
	cashLabel.Text = Texts.Get("Shop.Cash", { value = Format.Short(cash) })
	for cat, tab in tabs do
		tab.BackgroundColor3 = if cat == category then Color3.fromRGB(220, 120, 30) else Color3.fromRGB(70, 70, 80)
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for index, itemId in sortedItems(category) do
		local item = StyleItems[itemId]
		local row = Ui.create("Frame", {
			Name = itemId,
			Size = UDim2.new(1, -12, 0, 58),
			BackgroundColor3 = Color3.fromRGB(40, 35, 55),
			BackgroundTransparency = 0.2,
			LayoutOrder = index,
			Parent = list,
		}, { Ui.corner(UDim.new(0, 10)) })

		-- Pastille de couleur : aperçu simple de l'objet
		Ui.create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(36, 36),
			BackgroundColor3 = item.pieces[1].color,
			Parent = row,
		}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.3) })

		Ui.label({
			Position = UDim2.fromOffset(56, 8),
			Size = UDim2.new(1, -250, 1, -16),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = Texts.Get(`Style.{itemId}`),
			Parent = row,
		})

		local text, color
		if equipped[item.category] == itemId then
			text, color = Texts.Get("Shop.Equipped"), Color3.fromRGB(60, 170, 80)
		elseif owned[itemId] then
			text, color = Texts.Get("Shop.Equip"), Color3.fromRGB(60, 110, 200)
		elseif item.price then
			local price = Format.Short(item.price)
			if confirming == itemId then
				text, color = Texts.Get("Shop.Confirm", { price = price }), Color3.fromRGB(220, 120, 30)
			else
				local affordable = cash >= item.price
				text = Texts.Get("Shop.Buy", { price = price })
				color = if affordable then Color3.fromRGB(80, 80, 95) else Color3.fromRGB(110, 50, 50)
			end
		else
			text = Texts.Get("Shop.BossReward", { boss = Texts.Get(`Boss.{item.bossId}`) })
			color = Color3.fromRGB(60, 60, 60)
		end

		local button = Ui.button({
			Name = "Action",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(180, 44),
			BackgroundColor3 = color,
			Text = text,
			Parent = row,
		})
		button.Activated:Connect(function()
			onItemButton(itemId)
		end)
	end
end

local function open()
	confirming = nil
	panel.Visible = true
	MinigameController.SetGameplayLocked(true)
	render()
end

local function close()
	panel.Visible = false
	MinigameController.SetGameplayLocked(false)
end

local function buildGui()
	local gui = Ui.create("ScreenGui", { Name = "Shop", ResetOnSpawn = false, DisplayOrder = 4 })

	panel = Ui.panel({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(560, 470),
		Visible = false,
		Parent = gui,
	})
	Ui.label({
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(0.6, -16, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 220, 120),
		Text = Texts.Get("Shop.Title"),
		Parent = panel,
	})
	cashLabel = Ui.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.new(0.4, -16, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(140, 255, 140),
		Parent = panel,
	})
	Ui.label({
		Position = UDim2.fromOffset(16, 52),
		Size = UDim2.new(1, -32, 0, 22),
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(200, 200, 210),
		Text = Texts.Get("Shop.Cosmetic"),
		Parent = panel,
	})

	for index, cat in CATEGORIES do
		local tab = Ui.button({
			Name = `Tab{cat}`,
			Position = UDim2.new((index - 1) / 3, if index == 1 then 16 else 6, 0, 82),
			Size = UDim2.new(1 / 3, -16, 0, 44),
			Text = Texts.Get(`Shop.Category.{cat}`),
			Parent = panel,
		})
		tab.Activated:Connect(function()
			category = cat
			confirming = nil
			render()
		end)
		tabs[cat] = tab
	end

	list = Ui.create("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(16, 134),
		Size = UDim2.new(1, -32, 1, -214),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	}, {
		Ui.create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local closeButton = Ui.button({
		Name = "Close",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(200, 52),
		BackgroundColor3 = Color3.fromRGB(90, 90, 90),
		Text = Texts.Get("Shop.Close"),
		Parent = panel,
	})
	closeButton.Activated:Connect(close)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function ShopController.Init(controllers)
	MinigameController = controllers.MinigameController
end

function ShopController.Start()
	buildGui()

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local parent = prompt.Parent
		if parent and CollectionService:HasTag(parent, MIRROR_TAG) then
			open()
		end
	end)
	Remotes.StatsChanged.OnClientEvent:Connect(function(stats)
		cash = stats.Cash
		if panel.Visible then
			render()
		end
	end)
	Remotes.StyleState.OnClientEvent:Connect(function(state)
		owned = state.owned or {}
		equipped = state.equipped or {}
		if panel.Visible then
			render()
		end
	end)
end

return ShopController
