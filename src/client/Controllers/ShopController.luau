-- Boutiques de style (miroir de la boutique de vêtements ou du coiffeur) : catégories vendues par ce miroir,
-- achat avec confirmation, porter / retirer, et ESSAYAGE GRATUIT : un aperçu 3D (son propre corps de stade, ce
-- qu'on porte + l'article choisi) tourne à gauche de la liste. Toucher un article l'essaie.
-- Le serveur vérifie tout (prix, Cash, possession) ; ce contrôleur n'affiche que l'état reçu.
-- Garde-robe (bouton « Style » du HUD) : la même fenêtre, toutes catégories, seulement ce qu'on possède, pour
-- porter ou retirer ses objets n'importe où.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LookConfig = require(ReplicatedStorage.Shared.Config.Look)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local StyleItems = require(ReplicatedStorage.Shared.Config.StyleItems)
local StyleSets = require(ReplicatedStorage.Shared.Config.StyleSets)
local Look = require(ReplicatedStorage.Shared.Look)
local Outfit = require(ReplicatedStorage.Shared.Outfit)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Format = require(ReplicatedStorage.Shared.Format)
local Drip = require(ReplicatedStorage.Shared.Drip)
local Luxury = require(ReplicatedStorage.Shared.Config.Luxury)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local MIRROR_TAG = "Mirror"
local ALL_CATEGORIES = { "Hair", "Beard", "Face", "Top", "Bottom", "Accessory", "Trail", "Aura", "Entrance" }

local player = Players.LocalPlayer

local MinigameController
local UIController

local panel: Frame
local titleLabel: TextLabel
local cashLabel: TextLabel
local dripLabel: TextLabel
local list: ScrollingFrame
local tabArea: ScrollingFrame
local tabs: { [string]: TextButton } = {}
local viewport: ViewportFrame
local world: WorldModel
local previewLabel: TextLabel
local previewModel: Model? = nil
local previewKey = ""
local previewing: string? = nil -- article essayé (nil : sa tenue actuelle)
local previewSet: string? = nil -- ensemble essayé en un clic
local stageIndex = 1
local spin = 0

local categories: { string } = ALL_CATEGORIES
local category = "Hair"
local cash = 0
local owned: { [string]: boolean } = {}
local equipped: { [string]: string } = {}
local look: Look.LookData? = nil -- apparence du joueur (aperçu aux bonnes couleurs)
local confirming: string? = nil
local wardrobe = false -- garde-robe : seulement les objets possédés, rien à acheter

local ShopController = {}

local function sortedItems(cat: string): { string }
	local ids = {}
	for id, item in StyleItems do
		if
			item.category == cat
			and (not wardrobe or owned[id] or item.starter)
			and (not item.setId or StyleSets.Active)
			and (wardrobe or not StyleSets.Active or (cat ~= "Top" and cat ~= "Bottom"))
		then
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
	if previewSet then
		local set = StyleSets.ById[previewSet]
		outfit.Top = set.top
		outfit.Bottom = set.bottom
		name = Texts.Get("Shop.TryingOn", { item = Texts.Get(`StyleSet.{previewSet}`) })
	elseif previewing then
		local itemCategory = StyleItems[previewing].category
		outfit[itemCategory] = previewing
		name = if Luxury.ById[previewing]
			then Texts.Get(`Luxury.Desc.{itemCategory}`, { item = Texts.Get(`Style.{previewing}`) })
			else Texts.Get("Shop.TryingOn", { item = Texts.Get(`Style.{previewing}`) })
	end
	previewLabel.Text = name
	local stage = Stages.List[stageIndex]
	local items = {}
	for _, itemId in outfit do
		table.insert(items, itemId)
	end
	table.sort(items)
	local key = `{stage and stage.id}:{table.concat(items, ",")}:{look and Look.Key(look) or ""}`
	if key == previewKey then
		return
	end
	previewKey = key
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end
	local model = stage and Outfit.Build(stage.id, items, { look = look })
	if not model then
		return
	end
	model.Parent = world
	previewModel = model
	-- Cadrage : tout le corps, quel que soit le stade
	local head = Outfit.HeadCenter(stage.id, look) :: Vector3
	local center = head.Y * 0.55
	local distance = head.Y * 1.75 + 2
	local camera = viewport.CurrentCamera :: Camera
	camera.CFrame = CFrame.lookAt(Vector3.new(0, center + 0.4, -distance), Vector3.new(0, center, 0))
end

local render

-- Teintures du coiffeur (D106) : une rangée de pastilles au-dessus des coupes ; gratuites, la coupe portée prend la
-- couleur tout de suite (l'aperçu aussi, sans attendre le serveur)
local function addDyeRow()
	local current = look and look.Dye or ""
	local row = Ui.create("Frame", {
		Name = "DyeRow",
		Size = UDim2.new(1, -12, 0, 84),
		BackgroundColor3 = Color3.fromRGB(40, 35, 55),
		BackgroundTransparency = 0.2,
		LayoutOrder = 0,
		Parent = list,
	}, { Ui.corner(UDim.new(0, 10)) })
	Ui.label({
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 220, 120),
		Text = Texts.Get("Shop.HairColor"),
		Parent = row,
	})
	local strip = Ui.create("ScrollingFrame", {
		Position = UDim2.fromOffset(6, 30),
		Size = UDim2.new(1, -12, 0, 50),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 3,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		Parent = row,
	}, {
		Ui.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Ui.create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }),
	})
	local dyes = { "" }
	for _, id in LookConfig.HairDyes do
		table.insert(dyes, id)
	end
	for index, dye in dyes do
		local color = Look.DyeColor({ Dye = dye } :: any)
		local chosen = dye == current
		local swatch = Ui.create("TextButton", {
			Name = if dye == "" then "Original" else dye,
			Text = "",
			AutoButtonColor = true,
			Size = UDim2.fromOffset(if dye == "" then 78 else 42, 42), -- « Original » : une pilule, son nom lisible
			BackgroundColor3 = color or Color3.new(1, 1, 1),
			LayoutOrder = index,
			Parent = strip,
		}, {
			Ui.corner(UDim.new(1, 0)),
			Ui.stroke(
				if chosen then Color3.fromRGB(255, 215, 60) else Color3.new(1, 1, 1),
				if chosen then 4 else 2,
				if chosen then 0 else 0.4
			),
		})
		if dye == "" then
			-- Couleur d'origine : arc-en-ciel, le nom dessous
			Ui.gradient(Color3.fromRGB(255, 120, 160), Color3.fromRGB(120, 180, 255), 45).Parent = swatch
			Ui.label({
				Size = UDim2.fromScale(1, 1),
				Text = Texts.Get("Shop.HairColorOriginal"),
				Font = Enum.Font.GothamBold,
				Parent = swatch,
			})
		end
		swatch.Activated:Connect(function()
			if look then
				look.Dye = dye
			end
			Remotes.SetHairDye:FireServer(dye)
			render()
		end)
	end
end

local function onSetButton(setId: string)
	previewing = nil
	previewSet = setId
	local set = StyleSets.ById[setId]
	if not set then
		return
	end
	if owned[set.top] and owned[set.bottom] then
		Remotes.EquipStyleSet:FireServer(setId)
	elseif set.price then
		if confirming == setId then
			confirming = nil
			Remotes.BuyStyleSet:FireServer(setId)
		else
			confirming = setId
		end
	end
	render()
end

local function onItemButton(itemId: string)
	previewing = itemId
	previewSet = nil
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
	dripLabel.Text = Texts.Get("Style.Drip", { percent = Format.Gain(Drip.Bonus(equipped) * 100) })
	for cat, tab in tabs do
		tab.BackgroundColor3 = if cat == category then Color3.fromRGB(220, 120, 30) else Color3.fromRGB(70, 70, 80)
	end
	for _, child in list:GetChildren() do
		if child:IsA("GuiButton") or child.Name == "Empty" or child.Name == "DyeRow" then
			child:Destroy()
		end
	end
	refreshPreview()
	if category == "Sets" then
		for index, set in StyleSets.List do
			if wardrobe and not (owned[set.top] and owned[set.bottom]) then
				continue
			end
			local row = Ui.create("TextButton", {
				Text = "",
				AutoButtonColor = false,
				Name = set.id,
				Size = UDim2.new(1, -12, 0, 58),
				BackgroundColor3 = if previewSet == set.id
					then Color3.fromRGB(80, 60, 120)
					else Color3.fromRGB(40, 35, 55),
				BackgroundTransparency = 0.2,
				LayoutOrder = index,
				Parent = list,
			}, { Ui.corner(UDim.new(0, 10)) })
			row.Activated:Connect(function()
				previewing = nil
				previewSet = set.id
				confirming = nil
				render()
			end)
			Ui.create("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 10, 0.5, 0),
				Size = UDim2.fromOffset(36, 36),
				BackgroundColor3 = set.color,
				Parent = row,
			}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.3) })
			Ui.label({
				Position = UDim2.fromOffset(56, 8),
				Size = UDim2.new(1, -200, 1, -16),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = Texts.Get(`StyleSet.{set.id}`),
				Parent = row,
			})
			local text, color
			if equipped.Top == set.top and equipped.Bottom == set.bottom then
				text, color = Texts.Get("Shop.Equipped"), Color3.fromRGB(60, 170, 80)
			elseif owned[set.top] and owned[set.bottom] then
				text, color = Texts.Get("Shop.Equip"), Color3.fromRGB(60, 110, 200)
			elseif set.price then
				local price = Format.Short(set.price)
				text = Texts.Get(if confirming == set.id then "Shop.Confirm" else "Shop.Buy", { price = price })
				color = if cash >= set.price then Color3.fromRGB(80, 80, 95) else Color3.fromRGB(110, 50, 50)
			else
				text, color = Texts.Get("Shop.PendingPrice"), Color3.fromRGB(60, 60, 60)
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
				onSetButton(set.id)
			end)
		end
		return
	end

	local items = sortedItems(category)
	if category == "Hair" then
		addDyeRow()
	end
	if wardrobe and #items == 0 then
		Ui.label({
			Name = "Empty",
			Size = UDim2.new(1, -12, 0, 60),
			TextWrapped = true,
			Font = Enum.Font.GothamMedium,
			TextColor3 = Color3.fromRGB(200, 200, 215),
			Text = Texts.Get("Shop.WardrobeEmpty"),
			Parent = list,
		})
	end
	for index, itemId in items do
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
			BackgroundColor3 = item.swatch or item.pieces[1].color,
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
	tabArea.CanvasSize = UDim2.fromOffset(#categories * 100, 0)
	for index, cat in categories do
		local tab = Ui.button({
			Name = `Tab{cat}`,
			Position = UDim2.fromOffset((index - 1) * 100 + 3, 0),
			Size = UDim2.new(0, 94, 1, -6),
			Text = Texts.Get(`Shop.Category.{cat}`),
			Parent = tabArea,
		})
		tab.Activated:Connect(function()
			category = cat
			confirming = nil
			previewing = nil
			previewSet = nil
			render()
		end)
		tabs[cat] = tab
	end
end

local function open(mirror: Instance)
	wardrobe = false
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
	if StyleSets.Active and store == "Clothes" then
		categories = { "Sets", "Trail", "Aura", "Entrance" } -- luxe à effets (D112)
	end
	category = categories[1]
	previewing = nil
	previewSet = nil
	titleLabel.Text = Texts.Get(if typeof(store) == "string" then `Shop.Title.{store}` else "Shop.Title")
	buildTabs()
	confirming = nil
	panel.Visible = true
	UIController.SetStatsHidden(true, "Shop")
	MinigameController.SetGameplayLocked(true, "Shop")
	render()
end

local function close()
	panel.Visible = false
	UIController.SetStatsHidden(false, "Shop")
	MinigameController.SetGameplayLocked(false, "Shop")
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
		Position = UDim2.new(1, -64, 0, 12),
		Size = UDim2.new(0.4, -64, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(140, 255, 140),
		Parent = panel,
	})
	-- Drip de la tenue portée (D111) : ce que le style apporte contre les boss et au bras de fer
	dripLabel = Ui.label({
		Position = UDim2.fromOffset(16, 50),
		Size = UDim2.new(1, -32, 0, 20),
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(255, 200, 120),
		Parent = panel,
	})

	-- Essayage : aperçu 3D à gauche
	viewport = Ui.create("ViewportFrame", {
		Name = "Preview",
		Position = UDim2.fromOffset(16, 78),
		Size = UDim2.new(0.36, -16, 1, -124),
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
		Position = UDim2.new(0, 16, 1, -44),
		Size = UDim2.new(0.36, -16, 0, 26),
		TextColor3 = Color3.fromRGB(255, 220, 120),
		Text = Texts.Get("Shop.YourLook"),
		Parent = panel,
	})

	-- Liste à droite : onglets des catégories, puis les articles
	tabArea = Ui.create("ScrollingFrame", {
		Name = "Tabs",
		Position = UDim2.new(0.36, 8, 0, 78),
		Size = UDim2.new(0.64, -24, 0, 40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(),
		Parent = panel,
	})
	list = Ui.create("ScrollingFrame", {
		Name = "List",
		Position = UDim2.new(0.36, 8, 0, 126),
		Size = UDim2.new(0.64, -24, 1, -140),
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
	Ui.markModal(panel)
	Ui.onBack(closeButton, close)
	Ui.watchViewport(function()
		local camera = workspace.CurrentCamera
		local size = camera and camera.ViewportSize or Vector2.zero
		local shortLandscape = size.X > size.Y and size.Y < 500
		panel.Position = UDim2.fromScale(0.5, if shortLandscape then 0.5 else 0.53)
		panel.Size = if shortLandscape then UDim2.new(0.96, 0, 1, -16) else UDim2.fromScale(0.94, 0.86)
		if Ui.isPhonePortrait() then
			viewport.Position = UDim2.fromOffset(16, 78)
			viewport.Size = UDim2.new(1, -32, 0, 170)
			previewLabel.Position = UDim2.fromOffset(16, 252)
			previewLabel.Size = UDim2.new(1, -32, 0, 26)
			tabArea.Position = UDim2.fromOffset(16, 286)
			tabArea.Size = UDim2.new(1, -32, 0, 40)
			list.Position = UDim2.fromOffset(16, 334)
			list.Size = UDim2.new(1, -32, 1, -340)
		else
			viewport.Position = UDim2.fromOffset(16, 78)
			viewport.Size = UDim2.new(0.36, -16, 1, -124)
			previewLabel.Position = UDim2.new(0, 16, 1, -44)
			previewLabel.Size = UDim2.new(0.36, -16, 0, 26)
			tabArea.Position = UDim2.new(0.36, 8, 0, 78)
			tabArea.Size = UDim2.new(0.64, -24, 0, 40)
			list.Position = UDim2.new(0.36, 8, 0, 126)
			list.Size = UDim2.new(0.64, -24, 1, -140)
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

-- Ouvre la boutique d'un miroir (ou, plus tard, d'un vendeur : mêmes attributs Store et Categories)
function ShopController.Open(mirror: Instance)
	open(mirror)
end

-- Garde-robe : tout ce qu'on possède, à porter ou retirer
function ShopController.OpenWardrobe()
	wardrobe = true
	categories = if StyleSets.Active
		then { "Sets", "Top", "Bottom", "Hair", "Beard", "Face", "Accessory", "Trail", "Aura", "Entrance" }
		else ALL_CATEGORIES
	category = categories[1]
	previewing = nil
	previewSet = nil
	confirming = nil
	titleLabel.Text = Texts.Get("Shop.Title.Wardrobe")
	buildTabs()
	panel.Visible = true
	UIController.SetStatsHidden(true, "Shop")
	MinigameController.SetGameplayLocked(true, "Shop")
	render()
end

function ShopController.IsOpen(): boolean
	return panel ~= nil and panel.Visible
end

function ShopController.Init(controllers)
	MinigameController = controllers.MinigameController
	UIController = controllers.UIController
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
		look = state.look
		previewKey = nil
		if panel.Visible then
			render()
		end
	end)
end

return ShopController
