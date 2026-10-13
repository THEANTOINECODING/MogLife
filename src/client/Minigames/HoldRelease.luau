-- Mini-jeu « HoldRelease » (développé couché) : maintenir pour pousser la barre (la jauge monte),
-- relâcher quand elle est dans la zone verte. Au centre de la zone = Perfect.
-- Entrées : maintenir clic / doigt sur la zone, Espace, bouton A de manette.
-- Interface commune : voir Swipe.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.HoldRelease

local HoldRelease = {}
HoldRelease.__index = HoldRelease

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isKey(input: InputObject): boolean
	return input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA
end

function HoldRelease.new(parent: GuiObject, interval: number, onRep: (string) -> ())
	local self = setmetatable({}, HoldRelease)
	self.fillTime = interval * SETTINGS.FillFactor
	self.onRep = onRep
	self.holdStart = nil :: number?
	self.fill = 0
	self.auto = false
	self.autoStart = os.clock()
	self.interval = interval
	self.connections = {}

	self.zone = Ui.create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -40, 0.5, 20),
		Size = UDim2.new(0, 220, 0.6, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.15,
		AutoButtonColor = false,
		Text = "",
		Parent = parent,
	}, {
		Ui.corner(UDim.new(0, 18)),
		Ui.gradient(Color3.fromRGB(70, 45, 110), Color3.fromRGB(25, 20, 40)),
		Ui.stroke(Color3.fromRGB(255, 220, 120), 3, 0.2),
	})

	-- Jauge verticale
	self.gauge = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 70, 1, -40),
		BackgroundColor3 = Color3.fromRGB(30, 30, 35),
		Parent = self.zone,
	}, { Ui.corner(UDim.new(0, 12)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.5) })

	-- Zone verte et bande « Perfect » au centre (0 = bas, 1 = haut)
	local zoneCenter = (SETTINGS.ZoneMin + SETTINGS.ZoneMax) / 2
	Ui.create("Frame", {
		Position = UDim2.fromScale(0, 1 - SETTINGS.ZoneMax),
		Size = UDim2.fromScale(1, SETTINGS.ZoneMax - SETTINGS.ZoneMin),
		BackgroundColor3 = Color3.fromRGB(90, 230, 90),
		BackgroundTransparency = 0.4,
		ZIndex = 2,
		Parent = self.gauge,
	})
	Ui.create("Frame", {
		Position = UDim2.fromScale(0, 1 - zoneCenter - SETTINGS.PerfectHalfWidth),
		Size = UDim2.fromScale(1, SETTINGS.PerfectHalfWidth * 2),
		BackgroundColor3 = Color3.fromRGB(255, 215, 40),
		BackgroundTransparency = 0.2,
		ZIndex = 2,
		Parent = self.gauge,
	})

	self.fillFrame = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.fromRGB(120, 180, 255),
		BackgroundTransparency = 0.25,
		ZIndex = 3,
		Parent = self.gauge,
	}, { Ui.corner(UDim.new(0, 12)) })

	-- La barre (haltère) monte avec la jauge
	self.bar = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(90, 50),
		Text = "🏋️",
		TextStrokeTransparency = 1,
		ZIndex = 4,
		Parent = self.gauge,
	})

	table.insert(
		self.connections,
		self.zone.InputBegan:Connect(function(input)
			if isPress(input) then
				self:_press()
			end
		end)
	)
	table.insert(
		self.connections,
		UserInputService.InputBegan:Connect(function(input)
			if isKey(input) then
				self:_press()
			end
		end)
	)
	table.insert(
		self.connections,
		UserInputService.InputEnded:Connect(function(input)
			if isPress(input) or isKey(input) then
				self:_release()
			end
		end)
	)
	table.insert(
		self.connections,
		RunService.RenderStepped:Connect(function()
			self:_step()
		end)
	)

	return self
end

function HoldRelease:_press()
	if self.auto or self.holdStart then
		return
	end
	self.holdStart = os.clock()
end

function HoldRelease:_release()
	if not self.holdStart then
		return
	end
	self.holdStart = nil
	local fill = self.fill
	self.fill = 0

	local center = (SETTINGS.ZoneMin + SETTINGS.ZoneMax) / 2
	local quality = "Miss"
	if math.abs(fill - center) <= SETTINGS.PerfectHalfWidth then
		quality = "Perfect"
	elseif fill >= SETTINGS.ZoneMin and fill <= SETTINGS.ZoneMax then
		quality = "Good"
	end
	self.onRep(quality)
end

function HoldRelease:_step()
	if self.auto then
		-- Animation automatique : la jauge monte jusqu'au centre de la zone à chaque répétition
		local phase = ((os.clock() - self.autoStart) / self.interval) % 1
		self.fill = math.min(phase / SETTINGS.FillFactor, 1) * (SETTINGS.ZoneMin + SETTINGS.ZoneMax) / 2
	elseif self.holdStart then
		self.fill = math.min((os.clock() - self.holdStart) / self.fillTime, 1)
		-- Trop tard : la barre retombe, répétition ratée
		if self.fill >= 1 then
			self:_release()
		end
	else
		self.fill = math.max(self.fill - 0.08, 0)
	end
	self.fillFrame.Size = UDim2.fromScale(1, self.fill)
	self.bar.Position = UDim2.fromScale(0.5, 1 - self.fill)
end

function HoldRelease:SetAuto(on: boolean)
	self.auto = on
	self.holdStart = nil
	self.autoStart = os.clock()
end

function HoldRelease:Destroy()
	for _, connection in self.connections do
		connection:Disconnect()
	end
	self.zone:Destroy()
end

return HoldRelease
