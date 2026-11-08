-- Réglages : interrupteurs sauvegardés côté serveur (Config/Settings.luau), ouverts par le petit rond ⚙ du menu
-- (MenuController, D124). Ce contrôleur applique lui-même les noms et l'affichage des autres joueurs ; la musique et
-- les effets passent par SoundController ; les autres systèmes lisent SettingsController.Get (effets d'écran, gros
-- plan des activités).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Settings = require(ReplicatedStorage.Shared.Config.Settings)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local ON = Color3.fromRGB(70, 190, 90)
local OFF = Color3.fromRGB(90, 90, 100)

local player = Players.LocalPlayer

local SoundController
local MinigameController
local UIController
local OutfitFxController
local LuxuryController

local values: { [string]: boolean } = {}
local panel: Frame
local switches: { [string]: { track: Frame, knob: Frame, label: TextLabel } } = {}

local SettingsController = {}

local function layoutPanel()
	panel.Size = if Ui.isPhonePortrait() then UDim2.new(1, -20, 1, -20) else UDim2.new(0, 460, 1, -20)
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
	local gui = Ui.create("ScreenGui", { Name = "Settings", ResetOnSpawn = false, DisplayOrder = 4 })

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
	Ui.markModal(panel)
	Ui.onBack(closeButton, function()
		setPanel(false)
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	Ui.watchViewport(layoutPanel)
end

-- Petit rond ⚙ du menu (MenuController)
function SettingsController.Open()
	if not panel.Visible then
		setPanel(true)
	end
end

function SettingsController.Init(controllers)
	SoundController = controllers.SoundController
	MinigameController = controllers.MinigameController
	UIController = controllers.UIController
	OutfitFxController = controllers.OutfitFxController
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
