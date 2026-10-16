-- Émotes : bouton « Flex » (et touche G) sous le bouton Maison, qui ouvre les 5 poses de culturisme. Le serveur
-- valide (hors activité, délai entre deux poses) et tout le monde voit la pose (ActivityController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local player = Players.LocalPlayer

local menu: Frame

local EmoteController = {}

local function strike(index: number)
	menu.Visible = false
	Remotes.Emote:FireServer(index)
end

local function buildGui()
	local gui = Ui.create("ScreenGui", { Name = "Emotes", ResetOnSpawn = false, DisplayOrder = 1 })
	local button = Ui.button({
		Name = "Flex",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 64),
		Size = UDim2.fromOffset(120, 54),
		BackgroundColor3 = Color3.fromRGB(150, 70, 200),
		Text = Texts.Get("Emote.Button"),
		Parent = gui,
	})
	menu = Ui.panel({
		Name = "Poses",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 142, 0.5, 64),
		Size = UDim2.fromOffset(210, 44 * Balance.Emotes.Count + 20),
		Visible = false,
		Parent = gui,
	})
	Ui.create("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = menu,
	})
	Ui.create("UIPadding", { PaddingTop = UDim.new(0, 8), Parent = menu })
	for index = 1, Balance.Emotes.Count do
		local pose = Ui.button({
			Name = `Pose{index}`,
			Size = UDim2.new(1, -16, 0, 40),
			BackgroundColor3 = Color3.fromRGB(70, 60, 95),
			Text = Texts.Get(`Emote.Pose{index}`),
			LayoutOrder = index,
			Parent = menu,
		})
		pose.Activated:Connect(function()
			strike(index)
		end)
	end
	button.Activated:Connect(function()
		menu.Visible = not menu.Visible
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
end

function EmoteController.Start()
	buildGui()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.G then
			menu.Visible = not menu.Visible
		elseif menu.Visible then
			-- 1 à 5 : la pose correspondante, menu ouvert
			local index = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
			if index >= 1 and index <= Balance.Emotes.Count then
				strike(index)
			end
		end
	end)
end

return EmoteController
