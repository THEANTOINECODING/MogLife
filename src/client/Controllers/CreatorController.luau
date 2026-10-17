-- Menu de création de personnage (D55). Ouvert par le serveur (OpenCreator) : au premier passage (« Create »),
-- puis au miroir de sa maison (« Edit », gratuit). Aperçu 3D à gauche (on le tourne en le faisant glisser),
-- réglages à droite par onglets : corps (masculin / féminin), peau, cheveux (coupe + couleur), yeux, visage
-- (expression), tenue de départ (couleurs du haut et du short), surnom (prénom + titre dans une liste).
-- Boutons « Aléatoire » et « Voir mon futur moi » (aperçu en GOD MOGGER). Rien n'est décidé ici : à la validation,
-- le client envoie l'apparence au serveur (SetLook), qui vérifie chaque champ. La taille n'est pas au choix.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local LookConfig = require(ReplicatedStorage.Shared.Config.Look)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local StyleItems = require(ReplicatedStorage.Shared.Config.StyleItems)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Look = require(ReplicatedStorage.Shared.Look)
local Outfit = require(ReplicatedStorage.Shared.Outfit)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local GOLD = Color3.fromRGB(255, 210, 60)
local TAB_ON = Color3.fromRGB(220, 120, 30)
local TAB_OFF = Color3.fromRGB(70, 60, 95)
local OPTION = Color3.fromRGB(55, 45, 80)
local LOCKED = Color3.fromRGB(45, 42, 55) -- titre exclusif pas encore débloqué
local TABS = { "Body", "Skin", "Hair", "Eyes", "Face", "Outfit", "Name" }
local CLOSE_UP = { Eyes = true, Face = true, Hair = true } -- onglets où l'aperçu cadre la tête
-- Aperçu au repos : il fait face au joueur et se balance doucement ; on peut le tourner en le faisant glisser,
-- puis il revient de face au bout de quelques secondes
local SWAY_ANGLE = 0.45 -- radians de part et d'autre de la face
local SWAY_SPEED = 0.6
local RETURN_DELAY = 3 -- secondes après un glissé avant de revenir de face

local player = Players.LocalPlayer

local MinigameController

local gui: ScreenGui
local titleLabel: TextLabel
local hintLabel: TextLabel
local viewport: ViewportFrame
local world: WorldModel
local camera: Camera
local nickLabel: TextLabel
local captionLabel: TextLabel
local futureButton: TextButton
local doneButton: TextButton
local cancelButton: TextButton
local tabButtons: { [string]: TextButton } = {}
local content: ScrollingFrame

local look: Look.LookData = Look.Default()
local hair = ""
local mode = "Create"
local tab = "Body"
local future = false
local stageIndex = 1
local owned: { [string]: boolean } = {}
local equipped: { [string]: string } = {}
local previewModel: Model? = nil
local previewKey: string? = nil
local angle = 0 -- 0 = face au joueur (la caméra regarde vers +Z, le modèle vers -Z)
local dragging = false
local lastDrag = 0
local spinConnection: RBXScriptConnection? = nil
local hiddenGuis: { ScreenGui } = {}
-- Titres exclusifs débloqués (trophées de la semaine, victoires en duel), envoyés par le serveur (D67)
local unlockedTitles: { [string]: boolean } = {}

local CreatorController = {}

-- ------------------------------------------------------------------ aperçu 3D

local function previewStage(): string
	if future then
		return LookConfig.FutureStage
	end
	local stage = Stages.List[stageIndex]
	return if stage then stage.id else "Normie"
end

-- Tenue de l'aperçu : ce que le joueur porte déjà, avec la coupe choisie dans le menu
local function previewItems(): { string }
	local items = {}
	for category, itemId in equipped do
		if category ~= "Hair" then
			table.insert(items, itemId)
		end
	end
	if hair ~= "" then
		table.insert(items, hair)
	end
	table.sort(items)
	return items
end

local function frameCamera(stageId: string)
	local head = Outfit.HeadCenter(stageId, look)
	if not head then
		return
	end
	local closeUp = CLOSE_UP[tab] == true
	local center = if closeUp then head.Y else head.Y * 0.55
	local distance = if closeUp then 4.2 + head.Y * 0.15 else head.Y * 1.75 + 2
	camera.CFrame = CFrame.lookAt(Vector3.new(0, center + 0.3, -distance), Vector3.new(0, center, 0))
end

local function refreshPreview()
	local stageId = previewStage()
	local items = previewItems()
	local key = `{stageId}:{table.concat(items, ",")}:{Look.Key(look)}`
	if key ~= previewKey then
		previewKey = key
		if previewModel then
			previewModel:Destroy()
			previewModel = nil
		end
		local model = Outfit.Build(stageId, items, { look = look })
		if model then
			model:PivotTo(CFrame.Angles(0, angle, 0))
			model.Parent = world
			previewModel = model
		end
	end
	frameCamera(stageId)
	nickLabel.Text = Look.Nickname(look)
	captionLabel.Visible = future
	futureButton.Text = Texts.Get(if future then "Creator.Now" else "Creator.Future")
end

-- ------------------------------------------------------------------ réglages

local render

local function section(titleKey: string, order: number)
	Ui.label({
		Name = "Title_" .. titleKey,
		Size = UDim2.new(1, -8, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GOLD,
		Text = Texts.Get(titleKey),
		LayoutOrder = order,
		Parent = content,
	})
end

-- Grille de boutons (pastilles de couleur ou boutons de texte)
local function grid(order: number, cellSize: UDim2): Frame
	local frame = Ui.create("Frame", {
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = content,
	})
	Ui.create("UIGridLayout", {
		CellSize = cellSize,
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = frame,
	})
	return frame
end

local function selectedStroke(button: GuiObject, selected: boolean)
	Ui.stroke(if selected then GOLD else Color3.new(1, 1, 1), if selected then 4 else 2, if selected then 0 else 0.6).Parent =
		button
end

local function swatches(order: number, list: { any }, field: string, fantasy: boolean)
	local frame = grid(order, UDim2.fromOffset(46, 46))
	local index = 0
	for _, swatch in list do
		if (swatch.fantasy == true) ~= fantasy then
			continue
		end
		index += 1
		local button = Ui.create("TextButton", {
			Name = swatch.id,
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = swatch.color,
			LayoutOrder = index,
			Parent = frame,
		}, { Ui.corner(UDim.new(1, 0)) })
		selectedStroke(button, (look :: any)[field] == swatch.id)
		button.Activated:Connect(function()
			(look :: any)[field] = swatch.id
			render()
		end)
	end
end

local function choices(
	order: number,
	values: { string },
	current: string,
	textOf: (string) -> string,
	onPick: (string) -> (),
	width: number?
)
	local frame = grid(order, UDim2.fromOffset(width or 150, 44))
	for index, value in values do
		local button = Ui.button({
			Name = if value == "" then "Base" else value,
			BackgroundColor3 = if value == current then TAB_ON else OPTION,
			Text = textOf(value),
			LayoutOrder = index,
			Parent = frame,
		})
		selectedStroke(button, value == current)
		button.Activated:Connect(function()
			onPick(value)
			render()
		end)
	end
end

-- Coupes proposées : coupe de base, coupes de départ, puis celles déjà achetées chez le coiffeur
local function hairChoices(): { string }
	local list = table.clone(LookConfig.StarterHair)
	local bought = {}
	for itemId in owned do
		local item = StyleItems[itemId]
		if item and item.category == "Hair" and not item.starter then
			table.insert(bought, itemId)
		end
	end
	table.sort(bought, function(a, b)
		return StyleItems[a].order < StyleItems[b].order
	end)
	for _, itemId in bought do
		table.insert(list, itemId)
	end
	return list
end

local function hairName(itemId: string): string
	return if itemId == "" then Texts.Get("Creator.BaseHair") else Texts.Get(`Style.{itemId}`)
end

local function fillContent()
	for _, child in content:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	if tab == "Body" then
		choices(1, LookConfig.Genders, look.Gender, function(value)
			return Texts.Get(`Creator.Gender.{value}`)
		end, function(value)
			look.Gender = value
		end, 190)
		Ui.label({
			Size = UDim2.new(1, -8, 0, 56),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamMedium,
			Text = Texts.Get("Creator.BodyHint"),
			LayoutOrder = 2,
			Parent = content,
		})
	elseif tab == "Skin" then
		section("Creator.SkinTone", 1)
		swatches(2, LookConfig.Skins, "Skin", false)
		section("Creator.FunColors", 3)
		swatches(4, LookConfig.Skins, "Skin", true)
	elseif tab == "Hair" then
		section("Creator.HairStyle", 1)
		choices(2, hairChoices(), hair, hairName, function(value)
			hair = value
		end)
		section("Creator.HairColor", 3)
		swatches(4, LookConfig.HairColors, "Hair", false)
		section("Creator.FunColors", 5)
		swatches(6, LookConfig.HairColors, "Hair", true)
		Ui.label({
			Size = UDim2.new(1, -8, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamMedium,
			TextColor3 = Color3.fromRGB(200, 200, 215),
			Text = Texts.Get("Creator.MoreHair"),
			LayoutOrder = 7,
			Parent = content,
		})
	elseif tab == "Eyes" then
		section("Creator.EyeColor", 1)
		swatches(2, LookConfig.EyeColors, "Eyes", false)
	elseif tab == "Face" then
		section("Creator.Expression", 1)
		choices(2, LookConfig.Expressions, look.Expression, function(value)
			return Texts.Get(`Creator.Expression.{value}`)
		end, function(value)
			look.Expression = value
		end, 170)
	elseif tab == "Outfit" then
		section("Creator.TopColor", 1)
		swatches(2, LookConfig.ClothesColors, "Top", false)
		section("Creator.ShortsColor", 3)
		swatches(4, LookConfig.ClothesColors, "Shorts", false)
	elseif tab == "Name" then
		section("Creator.FirstName", 1)
		choices(2, LookConfig.NickFirst, look.First, function(value)
			return Texts.Get(`Nick.First.{value}`)
		end, function(value)
			look.First = value
		end, 110)
		section("Creator.NickTitle", 3)
		choices(4, LookConfig.NickTitle, look.Title, function(value)
			return Texts.Get(`Nick.Title.{value}`)
		end, function(value)
			look.Title = value
		end, 160)
		-- Titres exclusifs : ceux qui ne sont pas encore débloqués montrent comment les obtenir
		section("Creator.RewardTitles", 5)
		local frame = grid(6, UDim2.new(1, -8, 0, 54))
		for index, entry in LookConfig.RewardTitles do
			local unlocked = unlockedTitles[entry.id] == true
			local name = Texts.Get(`Nick.Title.{entry.id}`)
			local text = if unlocked
				then name
				elseif entry.trophies then Texts.Get(
					"Creator.TitleNeedsTrophies",
					{ title = name, count = entry.trophies }
				)
				else Texts.Get("Creator.TitleNeedsWins", { title = name, count = entry.duelWins })
			local button = Ui.button({
				Name = entry.id,
				BackgroundColor3 = if look.Title == entry.id then TAB_ON elseif unlocked then OPTION else LOCKED,
				TextColor3 = if unlocked then Color3.new(1, 1, 1) else Color3.fromRGB(170, 170, 185),
				AutoButtonColor = unlocked,
				Text = text,
				LayoutOrder = index,
				Parent = frame,
			})
			selectedStroke(button, look.Title == entry.id)
			if unlocked then
				button.Activated:Connect(function()
					look.Title = entry.id
					render()
				end)
			end
		end
	end
	content.CanvasPosition = Vector2.zero
end

local lastTab: string? = nil
function render()
	for name, button in tabButtons do
		button.BackgroundColor3 = if name == tab then TAB_ON else TAB_OFF
	end
	-- On ne reconstruit la liste que si l'onglet change ou après un choix (garde la position de défilement)
	local scroll = content.CanvasPosition
	fillContent()
	if lastTab == tab then
		content.CanvasPosition = scroll
	end
	lastTab = tab
	refreshPreview()
end

-- ------------------------------------------------------------------ ouverture / fermeture

local function setOthersHidden(hidden: boolean)
	if hidden then
		for _, other in player:WaitForChild("PlayerGui"):GetChildren() do
			if other:IsA("ScreenGui") and other ~= gui and other.Enabled then
				other.Enabled = false
				table.insert(hiddenGuis, other)
			end
		end
	else
		for _, other in hiddenGuis do
			other.Enabled = true
		end
		table.clear(hiddenGuis)
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, not hidden)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not hidden)
	end)
end

local function close()
	if not gui.Enabled then
		return
	end
	gui.Enabled = false
	setOthersHidden(false)
	MinigameController.SetGameplayLocked(false)
	if spinConnection then
		spinConnection:Disconnect()
		spinConnection = nil
	end
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end
	previewKey = nil
end

local function open(request: { [string]: any })
	mode = if request.mode == "Edit" then "Edit" else "Create"
	look = Look.Sanitize(request.look, nil)
	hair = if typeof(request.hair) == "string" then request.hair else ""
	unlockedTitles = if typeof(request.titles) == "table" then request.titles else {}
	tab = "Body"
	lastTab = nil
	future = false
	angle = 0
	titleLabel.Text = Texts.Get(if mode == "Edit" then "Creator.EditTitle" else "Creator.Title")
	hintLabel.Visible = mode == "Create"
	doneButton.Text = Texts.Get(if mode == "Edit" then "Creator.Save" else "Creator.Done")
	cancelButton.Visible = mode == "Edit"
	if not gui.Enabled then
		setOthersHidden(true)
		gui.Enabled = true
	end
	MinigameController.SetGameplayLocked(true)
	if not spinConnection then
		spinConnection = RunService.RenderStepped:Connect(function(dt)
			if not dragging and os.clock() - lastDrag > RETURN_DELAY then
				-- Revient doucement de face (par le chemin le plus court), en se balançant
				local target = math.sin(os.clock() * SWAY_SPEED) * SWAY_ANGLE
				local delta = (target - angle + math.pi) % (2 * math.pi) - math.pi
				angle += delta * math.min(dt * 2.5, 1)
			end
			if previewModel then
				previewModel:PivotTo(CFrame.Angles(0, angle, 0))
			end
		end)
	end
	render()
end

-- ------------------------------------------------------------------ interface

local function buildGui()
	gui = Ui.create("ScreenGui", {
		Name = "Creator",
		ResetOnSpawn = false,
		DisplayOrder = 30,
		IgnoreGuiInset = true,
		Enabled = false,
	})
	Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = gui,
	}, { Ui.gradient(Color3.fromRGB(60, 38, 98), Color3.fromRGB(18, 14, 30)) })

	titleLabel = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromScale(0.6, 0.065),
		TextColor3 = GOLD,
		Parent = gui,
	})
	hintLabel = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.083),
		Size = UDim2.fromScale(0.6, 0.03),
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(205, 200, 225),
		Text = Texts.Get("Creator.MirrorHint"),
		Parent = gui,
	})

	-- Aperçu
	local previewCard = Ui.panel({
		Position = UDim2.fromScale(0.03, 0.12),
		Size = UDim2.fromScale(0.4, 0.7),
		Parent = gui,
	})
	viewport = Ui.create("ViewportFrame", {
		Position = UDim2.fromScale(0.03, 0.03),
		Size = UDim2.fromScale(0.94, 0.8),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(185, 182, 195),
		LightColor = Color3.fromRGB(255, 248, 235),
		LightDirection = Vector3.new(-0.4, -1, 0.6),
		Parent = previewCard,
	})
	world = Ui.create("WorldModel", { Parent = viewport })
	camera = Ui.create("Camera", { FieldOfView = 35, Parent = viewport })
	viewport.CurrentCamera = camera
	captionLabel = Ui.label({
		Position = UDim2.fromScale(0.05, 0.02),
		Size = UDim2.fromScale(0.9, 0.07),
		TextColor3 = GOLD,
		Text = Texts.Get("Creator.FutureCaption"),
		Visible = false,
		Parent = previewCard,
	})
	Ui.label({
		Position = UDim2.fromScale(0.05, 0.83),
		Size = UDim2.fromScale(0.9, 0.06),
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(210, 210, 225),
		Text = Texts.Get("Creator.NamePreview"),
		Parent = previewCard,
	})
	nickLabel = Ui.label({
		Position = UDim2.fromScale(0.05, 0.89),
		Size = UDim2.fromScale(0.9, 0.09),
		Parent = previewCard,
	})

	-- Tourner l'aperçu en le faisant glisser (souris ou doigt)
	local lastX: number? = nil
	viewport.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			dragging = true
			lastX = input.Position.X
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging or not lastX then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch then
			angle += (input.Position.X - lastX) * 0.012
			lastDrag = os.clock()
			lastX = input.Position.X
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			dragging = false
			lastX = nil
		end
	end)

	-- Boutons sous l'aperçu
	local randomButton = Ui.button({
		Position = UDim2.fromScale(0.03, 0.84),
		Size = UDim2.fromScale(0.19, 0.08),
		BackgroundColor3 = Color3.fromRGB(70, 110, 200),
		Text = Texts.Get("Creator.Random"),
		Parent = gui,
	})
	randomButton.Activated:Connect(function()
		local rng = Random.new()
		local random = Look.Random(rng)
		random.Created = look.Created
		look = random
		local cuts = LookConfig.StarterHair
		hair = cuts[rng:NextInteger(1, #cuts)]
		render()
	end)
	futureButton = Ui.button({
		Position = UDim2.fromScale(0.24, 0.84),
		Size = UDim2.fromScale(0.19, 0.08),
		BackgroundColor3 = Color3.fromRGB(150, 90, 200),
		Text = Texts.Get("Creator.Future"),
		Parent = gui,
	})
	futureButton.Activated:Connect(function()
		future = not future
		refreshPreview()
	end)

	-- Réglages
	local settings = Ui.panel({
		Position = UDim2.fromScale(0.46, 0.12),
		Size = UDim2.fromScale(0.51, 0.7),
		Parent = gui,
	})
	local tabBar = Ui.create("Frame", {
		Position = UDim2.fromScale(0.02, 0.02),
		Size = UDim2.fromScale(0.96, 0.1),
		BackgroundTransparency = 1,
		Parent = settings,
	})
	Ui.create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0.008, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabBar,
	})
	for index, name in TABS do
		local button = Ui.button({
			Name = name,
			Size = UDim2.fromScale(1 / #TABS - 0.008, 1),
			BackgroundColor3 = TAB_OFF,
			Text = Texts.Get(`Creator.Tab.{name}`),
			LayoutOrder = index,
			Parent = tabBar,
		})
		button.Activated:Connect(function()
			tab = name
			render()
		end)
		tabButtons[name] = button
	end
	content = Ui.create("ScrollingFrame", {
		Position = UDim2.fromScale(0.03, 0.15),
		Size = UDim2.fromScale(0.94, 0.82),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = settings,
	})
	Ui.create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = content,
	})
	Ui.create("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		Parent = content,
	})

	-- Valider / annuler
	doneButton = Ui.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.97, 0.84),
		Size = UDim2.fromScale(0.22, 0.1),
		BackgroundColor3 = TAB_ON,
		Text = Texts.Get("Creator.Done"),
		Parent = gui,
	})
	doneButton.Activated:Connect(function()
		Remotes.SetLook:FireServer(look, hair)
		close()
	end)
	cancelButton = Ui.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.73, 0.84),
		Size = UDim2.fromScale(0.15, 0.1),
		BackgroundColor3 = Color3.fromRGB(80, 80, 95),
		Text = Texts.Get("Creator.Cancel"),
		Visible = false,
		Parent = gui,
	})
	cancelButton.Activated:Connect(close)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function CreatorController.IsOpen(): boolean
	return gui ~= nil and gui.Enabled
end

function CreatorController.Init(controllers)
	MinigameController = controllers.MinigameController
end

function CreatorController.Start()
	buildGui()
	Remotes.OpenCreator.OnClientEvent:Connect(function(request)
		if typeof(request) == "table" then
			open(request)
		end
	end)
	Remotes.StyleState.OnClientEvent:Connect(function(state)
		owned = state.owned or {}
		equipped = state.equipped or {}
	end)
	Remotes.StatsChanged.OnClientEvent:Connect(function(stats)
		stageIndex = stats.Stage or stageIndex
	end)
end

return CreatorController
