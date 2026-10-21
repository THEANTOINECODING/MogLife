-- Déplacements rapides : bouton « Maison » toujours visible, et menu des destinations aux arrêts de bus.
-- Le serveur vérifie tout (délai, distance à l'arrêt, pas en pleine série ni en combat).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local STOP_TAG = "BusStop"
-- Ordre d'affichage des destinations du bus
local STOPS = { "Plaza", "Shops", "Gym", "Park", "Arena" }

local player = Players.LocalPlayer

local MinigameController

local panel: Frame
local list: Frame

local TravelController = {}

local function close()
	panel.Visible = false
	MinigameController.SetGameplayLocked(false, "Travel")
end

local function openBus(currentStop: string?)
	for _, child in list:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for index, stopId in STOPS do
		if stopId == currentStop then
			continue
		end
		local button = Ui.button({
			Name = stopId,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 50),
			BackgroundColor3 = Color3.fromRGB(60, 110, 200),
			Text = Texts.Get(`Bus.Stop.{stopId}`),
			Parent = list,
		})
		button.Activated:Connect(function()
			close()
			Remotes.TakeBus:FireServer(stopId)
		end)
	end
	panel.Visible = true
	MinigameController.SetGameplayLocked(true, "Travel")
end

local function buildGui()
	local gui = Ui.create("ScreenGui", { Name = "Travel", ResetOnSpawn = false, DisplayOrder = 3 })

	-- Bouton « Maison » à gauche de l'écran
	local home = Ui.button({
		Name = "Home",
		AnchorPoint = Vector2.new(0, 0.5),
		-- Colonne de gauche, centrée : Maison, Flex, Style, Settings (64 px d'écart)
		Position = UDim2.new(0, 12, 0.5, -64),
		Size = UDim2.fromOffset(120, 54),
		BackgroundColor3 = Color3.fromRGB(220, 120, 30),
		Text = Texts.Get("Travel.Home"),
		Parent = gui,
	})
	home.Activated:Connect(function()
		Remotes.GoHome:FireServer()
	end)

	panel = Ui.panel({
		Name = "Bus",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(360, 420),
		Visible = false,
		Parent = gui,
	})
	Ui.label({
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -32, 0, 40),
		TextColor3 = Color3.fromRGB(255, 220, 120),
		Text = Texts.Get("Bus.Title"),
		Parent = panel,
	})
	list = Ui.create("Frame", {
		Position = UDim2.fromOffset(20, 64),
		Size = UDim2.new(1, -40, 1, -140),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Ui.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
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

function TravelController.Init(controllers)
	MinigameController = controllers.MinigameController
end

function TravelController.Start()
	buildGui()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local parent = prompt.Parent
		if parent and CollectionService:HasTag(parent, STOP_TAG) then
			local stopId = parent:GetAttribute("Stop")
			openBus(if typeof(stopId) == "string" then stopId else nil)
		end
	end)
end

return TravelController
