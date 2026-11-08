-- Émotes : la case « Flex » du menu (MenuController) et la touche G ouvrent les 5 poses de culturisme, à côté de la
-- case. Le serveur valide (hors activité, délai entre deux poses) et tout le monde voit la pose (ActivityController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local player = Players.LocalPlayer

local menu: Frame
local menuScale: UIScale
local currentAnchor: GuiObject? = nil

local EmoteController = {}

local POSE_COLOR = Color3.fromRGB(225, 70, 190)

local function setOpen(open: boolean, anchor: GuiObject?)
	if open and anchor then
		-- La liste s'ouvre juste à droite de la case, centrée sur elle, sans sortir de l'écran
		local gui = menu.Parent :: ScreenGui
		local area = gui.AbsoluteSize
		local height = menu.AbsoluteSize.Y
		local x = anchor.AbsolutePosition.X + anchor.AbsoluteSize.X + 14
		local y = anchor.AbsolutePosition.Y + anchor.AbsoluteSize.Y / 2
		y = math.clamp(y, height / 2 + 8, math.max(area.Y - height / 2 - 8, height / 2 + 8))
		menu.Position = UDim2.fromOffset(x, y)
	end
	currentAnchor = if open then anchor else nil
	menu.Visible = open
	if open then
		menuScale.Scale = 0.7
		TweenService:Create(menuScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end
end

local function strike(index: number)
	setOpen(false)
	Remotes.Emote:FireServer(index)
end

-- Case « Flex » du menu : ouvre ou ferme la liste des poses à côté de `anchor`
function EmoteController.Toggle(anchor: GuiObject?)
	setOpen(not menu.Visible, anchor)
end

local function buildGui()
	local gui = Ui.create("ScreenGui", { Name = "Emotes", ResetOnSpawn = false, DisplayOrder = 1 })
	menu = Ui.panel({
		Name = "Poses",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 160, 0.5, 0),
		Size = UDim2.fromOffset(210, 46 * Balance.Emotes.Count + 16),
		Visible = false,
		Parent = gui,
	})
	menuScale = Ui.create("UIScale", { Parent = menu })
	Ui.create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = menu,
	})
	Ui.create("UIPadding", { PaddingTop = UDim.new(0, 8), Parent = menu })
	for index = 1, Balance.Emotes.Count do
		local pose = Ui.button({
			Name = `Pose{index}`,
			Size = UDim2.new(1, -16, 0, 40),
			BackgroundColor3 = Color3.new(1, 1, 1),
			AutoButtonColor = false,
			Text = Texts.Get(`Emote.Pose{index}`),
			LayoutOrder = index,
			Parent = menu,
		})
		Ui.gradient(Ui.shade(POSE_COLOR, 1.25), POSE_COLOR).Parent = pose
		Ui.stroke(Ui.Ink, 2.5).Parent = pose
		Ui.outline(pose, 2)
		Ui.juice(pose)
		pose.Activated:Connect(function()
			strike(index)
		end)
	end
	gui.Parent = player:WaitForChild("PlayerGui")
end

function EmoteController.Start()
	buildGui()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.G then
			setOpen(not menu.Visible)
		elseif menu.Visible then
			-- 1 à 5 : la pose correspondante, menu ouvert
			local index = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
			if index >= 1 and index <= Balance.Emotes.Count then
				strike(index)
			end
		end
	end)
	-- Un toucher ou un clic ailleurs referme la liste
	UserInputService.InputBegan:Connect(function(input)
		if not menu.Visible then
			return
		end
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.Touch and kind ~= Enum.UserInputType.MouseButton1 then
			return
		end
		local at = Vector2.new(input.Position.X, input.Position.Y)
		for _, guiObject in { menu, currentAnchor } do
			if guiObject then
				local corner, size = guiObject.AbsolutePosition, guiObject.AbsoluteSize
				if
					at.X >= corner.X
					and at.Y >= corner.Y
					and at.X <= corner.X + size.X
					and at.Y <= corner.Y + size.Y
				then
					return -- dans la liste, ou sur la case Flex (qui referme elle-même)
				end
			end
		end
		setOpen(false)
	end)
end

return EmoteController
