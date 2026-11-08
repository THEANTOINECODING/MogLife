-- Déplacements rapides : menu des destinations aux arrêts de bus (le retour à la maison est une case du menu,
-- MenuController).
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
local STOPS = { "Plaza", "Shops", "Gym", "Park", "Arena", "Colosseum" }

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

	panel = Ui.panel({
		Name = "Bus",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(360, 360),
		Visible = false,
		Parent = gui,
	})
	Ui.fitToScreen(panel)
	Ui.label({
		Position = UDim2.fromOffset(60, 12),
		Size = UDim2.new(1, -120, 0, 40),
		TextColor3 = Color3.fromRGB(255, 220, 120),
		Text = Texts.Get("Bus.Title"),
		Parent = panel,
	})
	list = Ui.create("Frame", {
		Position = UDim2.fromOffset(20, 64),
		Size = UDim2.new(1, -40, 1, -80),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Ui.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local closeButton = Ui.closeButton({ Text = Texts.Get("Shop.Close"), Parent = panel })
	Ui.markModal(panel)
	Ui.onBack(closeButton, close)

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
