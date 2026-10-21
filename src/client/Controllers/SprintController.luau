-- Bouton tactile « maintenir pour courir » ; Shift sur clavier.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local player = Players.LocalPlayer
local button: TextButton
local heldTouch: InputObject? = nil
local keyHeld = false
local locked = false
local sprinting = false
local sentLocked = false

local SprintController = {}

local function update()
	local busy = locked or player:GetAttribute("InRun") == true or player:GetAttribute("InDuel") == true
	local wanted = not busy and (heldTouch ~= nil or keyHeld)
	if button then
		button.Visible = UserInputService.TouchEnabled and not busy
		button.BackgroundColor3 = if wanted then Color3.fromRGB(100, 225, 110) else Color3.fromRGB(255, 175, 35)
	end
	if wanted == sprinting and locked == sentLocked then
		return
	end
	sprinting = wanted
	sentLocked = locked
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and not locked then
		humanoid.WalkSpeed = if wanted then Balance.Movement.SprintSpeed else Balance.Movement.WalkSpeed
	end
	Remotes.SetSprint:FireServer(wanted, locked)
end

function SprintController.SetLocked(value: boolean)
	if value and sprinting then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = Balance.Movement.WalkSpeed
		end
	end
	locked = value
	if value then
		heldTouch = nil
		keyHeld = false
	end
	update()
end

function SprintController.Start()
	local gui = Ui.create("ScreenGui", { Name = "Sprint", ResetOnSpawn = false, DisplayOrder = 2 })
	button = Ui.button({
		Name = "Run",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -30, 1, -120),
		Size = UDim2.fromOffset(72, 72),
		BackgroundColor3 = Color3.fromRGB(255, 175, 35),
		TextColor3 = Color3.fromRGB(30, 24, 38),
		Text = Texts.Get("Movement.Run"),
		Visible = UserInputService.TouchEnabled,
		Parent = gui,
	})
	Ui.stroke(Color3.new(1, 1, 1), 2, 0.1).Parent = button
	Ui.watchViewport(function()
		local camera = workspace.CurrentCamera
		local size = camera and camera.ViewportSize or Vector2.zero
		button.Position = if not Ui.isPhonePortrait()
				and size.X > size.Y
				and size.Y > 600
			then UDim2.new(1, -30, 1, -230)
			else UDim2.new(1, -30, 1, -120)
	end)
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			heldTouch = input
			update()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input == heldTouch then
			heldTouch = nil
			update()
		elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			keyHeld = false
			update()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and (input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift) then
			keyHeld = true
			update()
		end
	end)
	player.CharacterAdded:Connect(function()
		heldTouch = nil
		keyHeld = false
		sprinting = false
		update()
	end)
	player:GetAttributeChangedSignal("InRun"):Connect(update)
	player:GetAttributeChangedSignal("InDuel"):Connect(update)
	gui.Parent = player:WaitForChild("PlayerGui")
	update()
end

return SprintController
