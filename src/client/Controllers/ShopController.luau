-- Boutiques de style (miroir de la boutique de vêtements ou du coiffeur) : catégories vendues par ce miroir,
-- achat avec confirmation, porter / retirer, et ESSAYAGE GRATUIT : un aperçu 3D (son propre corps de stade, ce
-- qu'on porte + l'article choisi) tourne à gauche de la liste. Toucher un article l'essaie.
-- Le serveur vérifie tout (prix, Cash, possession) ; ce contrôleur n'affiche que l'état reçu.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local StyleItems = require(ReplicatedStorage.Shared.Config.StyleItems)
local Outfit = require(ReplicatedStorage.Shared.Outfit)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local MIRROR_TAG = "Mirror"
local ALL_CATEGORIES = { "Hair", "Beard", "Face", "Top", "Bottom", "Accessory" }

local player = Players.LocalPlayer

local MinigameController

local panel: Frame
local titleLabel: TextLabel
local cashLabel: TextLabel
local list: ScrollingFrame
local tabArea: Frame
local tabs: { [string]: TextButton } = {}
local viewport: ViewportFrame
local world: WorldModel
local previewLabel: TextLabel
local previewModel: Model? = nil
local previewKey = ""
local previewing: string? = nil -- article essayé (nil : sa tenue actuelle)
local stageIndex = 1
local spin = 0

local categories: { string } = ALL_CATEGORIES
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

-- Aperçu : son corps de stade, sa tenue, et l'article essayé à la place de celui de la même catégorie
local function refreshPreview()
	local outfit = table.clone(equipped)
	local name = Texts.Get("Shop.YourLook")
	if previewing then
		outfit[StyleItems[previewing].category] = previewing
		name = Texts.Get("Shop.TryingOn", { item = Texts.Get(`Style.{previewing}`) })
	end
	previewLabel.Text = name
	local stage = Stages.List[stageIndex]
	local items = {}
	for _, itemId in outfit do
		table.insert(items, itemId)
	end
	table.sort(items)
	local key = `{stage and stage.id}:{table.concat(items, ",")}`
	if key == previewKey then
		return
	end
	previewKey = key
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end
	local model = stage and Outfit.Build(stage.id, items)
	if not model then
		return
	end
	model.Parent = world
	previewModel = model
	-- Cadrage : tout le corps, quel que soit le stade
	local head = Outfit.HeadCenter(stage.id) :: Vector3
	local center = head.Y * 0.55
	local distance = head.Y * 1.75 + 2
	local camera = viewport.CurrentCamera :: Camera
	camera.CFrame = CFrame.lookAt(Vector3.new(0, center + 0.4, -distance), Vector3.new(0, center, 0))
end

local render

local function onItemButton(itemId: string)
	previewing = itemId
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
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	refreshPreview()

	for index, itemId in sortedItems(category) do
		local item = StyleItems[itemId]
		local row = Ui.create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Name = itemId,
			Size = UDim2.new(1, -12, 0, 58),
			BackgroundColor3 = if previewing == itemId then Color3.fromRGB(80, 60, 120) else Color3.fromRGB(40, 35, 55),
			BackgroundTransparency = 0.2,
			LayoutOrder = index,
			Parent = list,
		}, { Ui.corner(UDim.new(0, 10)) })
		-- Toucher la ligne : essayer l'article
		row.Activated:Connect(function()
			previewing = itemId
			confirming = nil
			render()
		end)

		-- Pastille de couleur : rappel de la couleur de l'objet
		Ui.create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(36, 36),
			BackgroundColor3 = item.pieces[1].color,
			Parent = row,
		}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.3) })

		Ui.label({
			Position = UDim2.fromOffset(56, 8),
			Size = UDim2.new(1, -200, 1, -16),
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
			Size = UDim2.fromOffset(132, 44),
			BackgroundColor3 = color,
			Text = text,
			Parent = row,
		})
		button.Activated:Connect(function()
			onItemButton(itemId)
		end)
	end
end

-- Onglets des catégories vendues par ce miroir
local function buildTabs()
	for _, tab in tabs do
		tab:Destroy()
	end
	tabs = {}
	local count = #categories
	for index, cat in categories do
		local tab = Ui.button({
			Name = `Tab{cat}`,
			Position = UDim2.new((index - 1) / count, 3, 0, 0),
			Size = UDim2.new(1 / count, -6, 1, 0),
			Text = Texts.Get(`Shop.Category.{cat}`),
			Parent = tabArea,
		})
		tab.Activated:Connect(function()
			category = cat
			confirming = nil
			previewing = nil
			render()
		end)
		tabs[cat] = tab
	end
end

local function open(mirror: Instance)
	local store = mirror:GetAttribute("Store")
	local listed = mirror:GetAttribute("Categories")
	categories = {}
	if typeof(listed) == "string" then
		for _, cat in ALL_CATEGORIES do
			if table.find(string.split(listed, ","), cat) then
				table.insert(categories, cat)
			end
		end
	end
	if #categories == 0 then
		categories = ALL_CATEGORIES
	end
	category = categories[1]
	previewing = nil
	titleLabel.Text = Texts.Get(if typeof(store) == "string" then `Shop.Title.{store}` else "Shop.Title")
	buildTabs()
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

	-- Taille relative à l'écran (mobile d'abord), bornée sur grand écran
	panel = Ui.panel({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromScale(0.94, 0.86),
		Visible = false,
		Parent = gui,
	})
	Ui.create("UISizeConstraint", { MaxSize = Vector2.new(900, 560), MinSize = Vector2.new(320, 260), Parent = panel })
	titleLabel = Ui.label({
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
		Position = UDim2.fromOffset(16, 50),
		Size = UDim2.new(1, -32, 0, 20),
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(200, 200, 210),
		Text = Texts.Get("Shop.Cosmetic"),
		Parent = panel,
	})

	-- Essayage : aperçu 3D à gauche
	viewport = Ui.create("ViewportFrame", {
		Name = "Preview",
		Position = UDim2.fromOffset(16, 78),
		Size = UDim2.new(0.36, -16, 1, -184),
		BackgroundColor3 = Color3.fromRGB(30, 26, 44),
		BackgroundTransparency = 0.1,
		Ambient = Color3.fromRGB(150, 150, 160),
		LightColor = Color3.fromRGB(255, 245, 230),
		LightDirection = Vector3.new(-0.5, -1, 0.6),
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 12)) })
	world = Ui.create("WorldModel", { Parent = viewport })
	viewport.CurrentCamera = Ui.create("Camera", { FieldOfView = 35, Parent = viewport })
	previewLabel = Ui.label({
		Position = UDim2.new(0, 16, 1, -104),
		Size = UDim2.new(0.36, -16, 0, 26),
		TextColor3 = Color3.fromRGB(255, 220, 120),
		Text = Texts.Get("Shop.YourLook"),
		Parent = panel,
	})

	-- Liste à droite : onglets des catégories, puis les articles
	tabArea = Ui.create("Frame", {
		Name = "Tabs",
		Position = UDim2.new(0.36, 8, 0, 78),
		Size = UDim2.new(0.64, -24, 0, 40),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	list = Ui.create("ScrollingFrame", {
		Name = "List",
		Position = UDim2.new(0.36, 8, 0, 126),
		Size = UDim2.new(0.64, -24, 1, -200),
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
		Size = UDim2.fromOffset(200, 50),
		BackgroundColor3 = Color3.fromRGB(90, 90, 90),
		Text = Texts.Get("Shop.Close"),
		Parent = panel,
	})
	closeButton.Activated:Connect(close)

	gui.Parent = player:WaitForChild("PlayerGui")
end

-- Ouvre la boutique d'un miroir (ou, plus tard, d'un vendeur : mêmes attributs Store et Categories)
function ShopController.Open(mirror: Instance)
	open(mirror)
end

function ShopController.Init(controllers)
	MinigameController = controllers.MinigameController
end

function ShopController.Start()
	buildGui()

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local parent = prompt.Parent
		if parent and CollectionService:HasTag(parent, MIRROR_TAG) then
			open(parent)
		end
	end)
	-- L'aperçu tourne lentement
	RunService.RenderStepped:Connect(function(dt)
		if panel.Visible and previewModel then
			spin += dt * 0.7
			previewModel:PivotTo(CFrame.Angles(0, spin, 0))
		end
	end)
	Remotes.StatsChanged.OnClientEvent:Connect(function(stats)
		cash = stats.Cash
		stageIndex = stats.Stage or stageIndex
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
