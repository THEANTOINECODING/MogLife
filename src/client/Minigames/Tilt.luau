-- Mini-jeu « Tilt » (squat) : la barre penche aléatoirement, il faut la garder droite.
-- Contrôles : A / D (ou flèches), souris ou doigt à gauche / droite de la zone, stick gauche de manette.
-- Chaque répétition est notée selon l'inclinaison moyenne pendant sa durée.
-- Interface commune : voir Swipe.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Tilt
local MAX_ANGLE = 35

local Tilt = {}
Tilt.__index = Tilt

function Tilt.new(parent: GuiObject, interval: number, onRep: (string) -> ())
	local self = setmetatable({}, Tilt)
	self.interval = interval
	self.onRep = onRep
	self.auto = false
	self.tilt = 0
	self.drift = 0
	self.nextDriftAt = 0
	self.repStart = os.clock()
	self.tiltSum = 0
	self.samples = 0
	self.pointerControl = 0
	self.pointerActive = false
	self.stickControl = 0
	self.connections = {}

	self.zone = Ui.panel({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -40, 0.5, 20),
		Size = UDim2.fromOffset(360, 300),
		Active = true,
		Parent = parent,
	})

	-- La barre de squat, qui tourne avec l'inclinaison
	self.bar = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(280, 14),
		BackgroundColor3 = Color3.fromRGB(200, 200, 210),
		ZIndex = 2,
		Parent = self.zone,
	}, { Ui.corner(UDim.new(1, 0)) })
	for _, side in { 0, 1 } do
		Ui.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(side, 0.5),
			Size = UDim2.fromOffset(70, 70),
			Text = "🛞",
			TextStrokeTransparency = 1,
			ZIndex = 3,
			Parent = self.bar,
		})
	end

	-- Indicateur d'équilibre : zone verte au centre, curseur selon l'inclinaison
	local meter = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(1, -60, 0, 26),
		BackgroundColor3 = Color3.fromRGB(200, 70, 70),
		BackgroundTransparency = 0.3,
		ZIndex = 2,
		Parent = self.zone,
	}, { Ui.corner(UDim.new(1, 0)) })
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(SETTINGS.GoodMax, 1),
		BackgroundColor3 = Color3.fromRGB(90, 230, 90),
		BackgroundTransparency = 0.2,
		ZIndex = 3,
		Parent = meter,
	}, { Ui.corner(UDim.new(1, 0)) })
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(SETTINGS.PerfectMax, 1),
		BackgroundColor3 = Color3.fromRGB(255, 215, 40),
		BackgroundTransparency = 0.1,
		ZIndex = 4,
		Parent = meter,
	})
	self.cursor = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(16, 40),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 5,
		Parent = meter,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(0, 0, 0), 2, 0.3) })

	local function onInput(input: InputObject)
		local inputType = input.UserInputType
		if inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.Touch then
			local left = self.zone.AbsolutePosition.X
			local width = self.zone.AbsoluteSize.X
			if width > 0 then
				-- Position par rapport au centre de la zone : -1 (gauche) … 1 (droite)
				self.pointerControl = math.clamp(((input.Position.X - left) / width - 0.5) * 2, -1, 1)
				self.pointerActive = true
			end
		elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
			self.stickControl = if math.abs(input.Position.X) > 0.15 then input.Position.X else 0
		end
	end
	table.insert(self.connections, UserInputService.InputChanged:Connect(onInput))
	table.insert(self.connections, UserInputService.InputBegan:Connect(onInput))
	table.insert(
		self.connections,
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				self.pointerControl = 0
			end
		end)
	)
	table.insert(
		self.connections,
		RunService.RenderStepped:Connect(function(dt)
			self:_step(dt)
		end)
	)

	return self
end

function Tilt:_control(): number
	local left = UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left)
	local right = UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right)
	if left or right then
		return (if right then 1 else 0) - (if left then 1 else 0)
	end
	if self.stickControl ~= 0 then
		return self.stickControl
	end
	return if self.pointerActive then self.pointerControl else 0
end

function Tilt:_step(dt: number)
	local now = os.clock()
	if self.auto then
		self.tilt = 0
	else
		if now >= self.nextDriftAt then
			self.drift = (math.random() * 2 - 1) * SETTINGS.DriftStrength
			self.nextDriftAt = now + SETTINGS.DriftChangeTime
		end
		-- Le joueur pousse vers le côté opposé à l'inclinaison : D (droite) compense une barre qui penche à gauche
		local velocity = self.drift + self.tilt * SETTINGS.Instability + self:_control() * SETTINGS.ControlStrength
		self.tilt = math.clamp(self.tilt + velocity * dt, -1, 1)
	end

	self.bar.Rotation = self.tilt * MAX_ANGLE
	self.cursor.Position = UDim2.fromScale(0.5 + self.tilt / 2, 0.5)

	if self.auto then
		return
	end
	self.tiltSum += math.abs(self.tilt) * dt
	self.samples += dt
	if now - self.repStart >= self.interval then
		local average = if self.samples > 0 then self.tiltSum / self.samples else 1
		self.repStart = now
		self.tiltSum = 0
		self.samples = 0
		local quality = "Miss"
		-- Mêmes seuils que les zones jaune (Perfect) et verte (Good) de l'indicateur
		if average <= SETTINGS.PerfectMax then
			quality = "Perfect"
		elseif average <= SETTINGS.GoodMax then
			quality = "Good"
		end
		self.onRep(quality)
	end
end

function Tilt:SetAuto(on: boolean)
	self.auto = on
	self.tilt = 0
	self.repStart = os.clock()
	self.tiltSum = 0
	self.samples = 0
end

function Tilt:Destroy()
	for _, connection in self.connections do
		connection:Disconnect()
	end
	self.zone:Destroy()
end

return Tilt
