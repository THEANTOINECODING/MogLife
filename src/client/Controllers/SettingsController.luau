-- Menu (D96) : un rond ☰ ouvre un petit tiroir de cases (Maison, Flex, Style, Maisons, Settings). Le tiroir se ferme d'un
-- toucher ailleurs, quand on choisit une case, quand le personnage se met à bouger ou quand une activité commence.
-- Les boutons Maison (TravelController) et Flex (EmoteController) sont rangés dans le tiroir.
-- - Style : la garde-robe (ShopController.OpenWardrobe) pour porter ou retirer ce qu'on possède, n'importe où.
-- - Settings : interrupteurs sauvegardés côté serveur (Config/Settings.luau). Ce contrôleur applique lui-même les
--   noms et l'affichage des autres joueurs ; la musique et les effets passent par SoundController ; les autres
--   systèmes lisent SettingsController.Get (effets d'écran, gros plan des activités).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Settings = require(ReplicatedStorage.Shared.Config.Settings)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local ON = Color3.fromRGB(70, 190, 90)
local OFF = Color3.fromRGB(90, 90, 100)

local player = Players.LocalPlayer

local ShopController
local SoundController
local MinigameController
local UIController
local OutfitFxController
local ObjectiveController
local HouseController
local LuxuryController

local values: { [string]: boolean } = {}
local panel: Frame
local switches: { [string]: { track: Frame, knob: Frame, label: TextLabel } } = {}
local menuGui: ScreenGui
local menuButton: TextButton
local drawer: Frame
local drawerGrid: UIGridLayout
local menuOpen = false

local SettingsController = {}

local function layoutMenu()
	local slots = Ui.menuSlots()
	menuButton.AnchorPoint = slots.buttonAnchor
	menuButton.Position = slots.buttonPosition
	menuButton.Size = slots.buttonSize
	drawer.AnchorPoint = slots.drawerAnchor
	drawer.Position = slots.drawerPosition
	drawerGrid.CellSize = UDim2.fromOffset(slots.tileSize.X, slots.tileSize.Y)
	-- 3 colonnes, autant de rangées que nécessaire
	local tiles = 0
	for _, child in drawer:GetChildren() do
		if child:IsA("GuiButton") then
			tiles += 1
		end
	end
	local rows = math.max(math.ceil(tiles / 3), 1)
	drawer.Size = UDim2.fromOffset(slots.tileSize.X * 3 + 12 + 16, slots.tileSize.Y * rows + 6 * (rows - 1) + 16)
	panel.Size = if Ui.isPhonePortrait() then UDim2.new(1, -20, 1, -20) else UDim2.new(0, 460, 1, -20)
end

local function setMenuOpen(open: boolean)
	if open == menuOpen then
		return
	end
	menuOpen = open
	menuButton.Text = Texts.Get(if open then "Menu.Close" else "Menu.Open")
	ObjectiveController.SetMenuOpen(open)
	if open then
		drawer.Visible = true
		local scale = drawer:FindFirstChildOfClass("UIScale") :: UIScale
		scale.Scale = 0.85
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	else
		drawer.Visible = false
	end
end

-- Réglage en cours (activé tant que le serveur n'a rien envoyé)
function SettingsController.Get(key: string): boolean
	return values[key] ~= false
end

-- ------------------------------------------------------------------ application

local function applyToCharacter(other: Player)
	if other == player then
		return
	end
	local character = other.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = if SettingsController.Get("Names")
			then Enum.HumanoidDisplayDistanceType.Viewer
			else Enum.HumanoidDisplayDistanceType.None
	end
	local hidden = not SettingsController.Get("Players")
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("Decal") then
			part.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

local function applyAll()
	SoundController.SetMusicEnabled(SettingsController.Get("Music"))
	SoundController.SetSoundsEnabled(SettingsController.Get("Sounds"))
	for _, other in Players:GetPlayers() do
		applyToCharacter(other)
	end
end

local function watchPlayer(other: Player)
	if other == player then
		return
	end
	other.CharacterAdded:Connect(function(character)
		task.wait(0.5)
		applyToCharacter(other)
		-- Les pièces du corps arrivent après l'apparition (corps de stade, habits)
		character.DescendantAdded:Connect(function(part)
			if (part:IsA("BasePart") or part:IsA("Decal")) and not SettingsController.Get("Players") then
				part.LocalTransparencyModifier = 1
			end
		end)
	end)
end

-- ------------------------------------------------------------------ interface

local function renderSwitch(key: string)
	local switch = switches[key]
	local on = SettingsController.Get(key)
	switch.track.BackgroundColor3 = if on then ON else OFF
	TweenService:Create(switch.knob, TweenInfo.new(0.15), {
		Position = if on then UDim2.new(1, -30, 0.5, 0) else UDim2.new(0, 4, 0.5, 0),
	}):Play()
	switch.label.Text = Texts.Get(if on then "Settings.On" else "Settings.Off")
end

local function toggle(key: string)
	values[key] = not SettingsController.Get(key)
	renderSwitch(key)
	applyAll()
	OutfitFxController.Refresh()
	LuxuryController.Refresh()
	Remotes.SetSetting:FireServer(key, values[key])
end

local function setPanel(visible: boolean)
	panel.Visible = visible
	UIController.SetStatsHidden(visible, "Settings")
	MinigameController.SetGameplayLocked(visible, "Settings")
end

local function buildGui()
	local gui = Ui.create("ScreenGui", { Name = "Menu", ResetOnSpawn = false, DisplayOrder = 1 })

	menuGui = gui
	local styleButton = Ui.button({
		Name = "Style",
		BackgroundColor3 = Color3.fromRGB(40, 140, 200),
		Text = Texts.Get("Menu.Style"),
	})
	styleButton.Activated:Connect(function()
		if not panel.Visible then
			ShopController.OpenWardrobe()
		end
	end)
	local housesButton = Ui.button({
		Name = "Houses",
		BackgroundColor3 = Color3.fromRGB(200, 70, 110),
		Text = Texts.Get("Menu.Houses"),
	})
	housesButton.Activated:Connect(function()
		if not panel.Visible then
			HouseController.Open()
		end
	end)
	local settingsButton = Ui.button({
		Name = "Settings",
		BackgroundColor3 = Color3.fromRGB(80, 80, 95),
		Text = Texts.Get("Menu.Settings"),
	})
	settingsButton.Activated:Connect(function()
		if not ShopController.IsOpen() and not HouseController.IsOpen() then
			setPanel(not panel.Visible)
		end
	end)
	menuButton = Ui.button({
		Name = "MenuButton",
		BackgroundColor3 = Color3.fromRGB(40, 35, 55),
		BackgroundTransparency = 0.12,
		Text = Texts.Get("Menu.Open"),
		Parent = gui,
	})
	menuButton:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	Ui.stroke(Color3.new(1, 1, 1), 2, 0.5).Parent = menuButton
	menuButton.Activated:Connect(function()
		setMenuOpen(not menuOpen)
	end)
	drawer = Ui.panel({
		Name = "Drawer",
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = gui,
	})
	Ui.create("UIScale", { Parent = drawer })
	Ui.create("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = drawer,
	})
	drawerGrid = Ui.create("UIGridLayout", {
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = drawer,
	})
	-- Les 4 cases : icône au-dessus, nom dessous (les boutons gardent leurs actions d'origine)
	local playerGui = player:WaitForChild("PlayerGui")
	local tiles = {
		{
			button = playerGui:WaitForChild("Travel"):WaitForChild("Home") :: TextButton,
			icon = "Menu.IconHome",
			name = "Menu.Home",
		},
		{
			button = playerGui:WaitForChild("Emotes"):WaitForChild("Flex") :: TextButton,
			icon = "Menu.IconFlex",
			name = "Emote.Button",
		},
		{ button = styleButton, icon = "Menu.IconStyle", name = "Menu.Style" },
		{ button = housesButton, icon = "Menu.IconHouses", name = "Menu.Houses" },
		{ button = settingsButton, icon = "Menu.IconSettings", name = "Menu.Settings" },
	}
	for index, tile in tiles do
		local button = tile.button
		button.Text = ""
		button.LayoutOrder = index
		button.AnchorPoint = Vector2.zero
		local padding = button:FindFirstChildOfClass("UIPadding")
		if padding then
			padding:Destroy()
		end
		Ui.label({
			Name = "Icon",
			Position = UDim2.fromScale(0, 0.06),
			Size = UDim2.fromScale(1, 0.5),
			Text = Texts.Get(tile.icon),
			TextStrokeTransparency = 1,
			Parent = button,
		})
		Ui.label({
			Name = "Caption",
			Position = UDim2.fromScale(0.08, 0.58),
			Size = UDim2.fromScale(0.84, 0.34),
			Text = Texts.Get(tile.name),
			Parent = button,
		})
		button.Parent = drawer
		button.Activated:Connect(function()
			setMenuOpen(false)
		end)
	end
	-- Fermeture : un toucher ou un clic hors du tiroir et du rond
	UserInputService.InputBegan:Connect(function(input)
		if not menuOpen then
			return
		end
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.Touch and kind ~= Enum.UserInputType.MouseButton1 then
			return
		end
		local at = Vector2.new(input.Position.X, input.Position.Y)
		for _, guiObject in { drawer, menuButton } do
			local corner = guiObject.AbsolutePosition
			local size = guiObject.AbsoluteSize
			if at.X >= corner.X and at.Y >= corner.Y and at.X <= corner.X + size.X and at.Y <= corner.Y + size.Y then
				return
			end
		end
		setMenuOpen(false)
	end)
	-- Touche M (clavier) et bouton Select (manette)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and (input.KeyCode == Enum.KeyCode.M or input.KeyCode == Enum.KeyCode.ButtonSelect) then
			setMenuOpen(not menuOpen)
		end
	end)
	-- Il se referme quand le personnage bouge ou qu'une activité range le menu
	RunService.Heartbeat:Connect(function()
		if not menuOpen then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not menuGui.Enabled or (humanoid and humanoid.MoveDirection.Magnitude > 0.1) then
			setMenuOpen(false)
		end
	end)

	panel = Ui.panel({
		Name = "SettingsPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(460, 60 + #Settings.List * 64 + 16),
		Visible = false,
		Parent = gui,
	})
	Ui.create("UISizeConstraint", { MaxSize = Vector2.new(460, 640), Parent = panel })
	Ui.label({
		Position = UDim2.fromOffset(60, 12),
		Size = UDim2.new(1, -120, 0, 40),
		TextColor3 = Color3.fromRGB(255, 220, 120),
		Text = Texts.Get("Settings.Title"),
		Parent = panel,
	})
	local rowList = Ui.create("ScrollingFrame", {
		Name = "Options",
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.new(1, -32, 1, -76),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.fromOffset(0, #Settings.List * 64),
		Parent = panel,
	})
	Ui.create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = rowList,
	})
	for index, key in Settings.List do
		local row = Ui.create("Frame", {
			Name = key,
			LayoutOrder = index,
			Size = UDim2.new(1, -8, 0, 56),
			BackgroundColor3 = Color3.fromRGB(40, 35, 55),
			BackgroundTransparency = 0.2,
			Parent = rowList,
		}, { Ui.corner(UDim.new(0, 10)) })
		Ui.label({
			Position = UDim2.fromOffset(12, 4),
			Size = UDim2.new(1, -140, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = Texts.Get(`Settings.{key}`),
			Parent = row,
		})
		Ui.label({
			Position = UDim2.fromOffset(12, 31),
			Size = UDim2.new(1, -140, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamMedium,
			TextColor3 = Color3.fromRGB(195, 195, 210),
			Text = Texts.Get(`Settings.{key}.Hint`),
			Parent = row,
		})
		-- Interrupteur : piste colorée et bouton qui glisse
		local track = Ui.create("TextButton", {
			Name = "Switch",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(64, 34),
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = ON,
			Parent = row,
		}, { Ui.corner(UDim.new(1, 0)) })
		local knob = Ui.create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(1, -30, 0.5, 0),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = track,
		}, { Ui.corner(UDim.new(1, 0)) })
		local stateLabel = Ui.label({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -84, 0.5, 0),
			Size = UDim2.fromOffset(40, 24),
			Font = Enum.Font.GothamMedium,
			Parent = row,
		})
		switches[key] = { track = track, knob = knob, label = stateLabel }
		track.Activated:Connect(function()
			toggle(key)
		end)
		renderSwitch(key)
	end
	local closeButton = Ui.closeButton({ Text = Texts.Get("Shop.Close"), Parent = panel })
	closeButton.Activated:Connect(function()
		setPanel(false)
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	Ui.watchViewport(layoutMenu)
end

function SettingsController.Init(controllers)
	ShopController = controllers.ShopController
	SoundController = controllers.SoundController
	MinigameController = controllers.MinigameController
	UIController = controllers.UIController
	OutfitFxController = controllers.OutfitFxController
	ObjectiveController = controllers.ObjectiveController
	HouseController = controllers.HouseController
	LuxuryController = controllers.LuxuryController
end

function SettingsController.Start()
	buildGui()
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Remotes.SettingsState.OnClientEvent:Connect(function(state)
		if typeof(state) ~= "table" then
			return
		end
		for _, key in Settings.List do
			if typeof(state[key]) == "boolean" then
				values[key] = state[key]
			end
		end
		for key in switches do
			renderSwitch(key)
		end
		applyAll()
		OutfitFxController.Refresh()
	end)
end

return SettingsController
