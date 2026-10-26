-- Mini-jeu « Ring » (pompes) : un anneau rétrécit vers un cercle cible ; taper au moment où il le touche.
-- Une seule frappe comptée par cycle. Entrées : clic / toucher sur la zone, Espace, bouton A de manette.
-- Interface commune : voir Swipe.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Ring
local ZONE_SIZE = 300
local TARGET_SIZE = 120
local START_SIZE = 280
local END_SIZE = 60

local Ring = {}
Ring.__index = Ring

function Ring.new(parent: GuiObject, interval: number, onRep: (string) -> ())
	local self = setmetatable({}, Ring)
	self.interval = interval
	self.timingScale = 1 -- resserré pendant la série par MinigameController
	self.onRep = onRep
	self.startTime = os.clock()
	self.auto = false
	self.lastHitIndex = -1
	self.connections = {}

	-- La zone entière est un bouton : un tap n'importe où dessus compte
	self.zone = Ui.create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -40, 0.5, 20),
		Size = UDim2.fromOffset(ZONE_SIZE, ZONE_SIZE),
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

	self.target = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(TARGET_SIZE, TARGET_SIZE),
		BackgroundColor3 = Color3.fromRGB(255, 200, 40),
		BackgroundTransparency = 0.1,
		ZIndex = 2,
		Parent = self.zone,
	}, {
		Ui.corner(UDim.new(1, 0)),
		Ui.stroke(Color3.new(1, 1, 1), 4, 0),
		Ui.label({
			Size = UDim2.fromScale(0.7, 0.7),
			Position = UDim2.fromScale(0.15, 0.15),
			Text = "💥",
			TextStrokeTransparency = 1,
			ZIndex = 2,
		}),
	})

	self.ring = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(START_SIZE, START_SIZE),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = self.zone,
	}, {
		Ui.corner(UDim.new(1, 0)),
	})
	self.ringStroke = Ui.stroke(Color3.fromRGB(120, 220, 255), 6, 0)
	self.ringStroke.Parent = self.ring

	table.insert(
		self.connections,
		self.zone.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				self:_press()
			end
		end)
	)
	table.insert(
		self.connections,
		UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
				self:_press()
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

-- Taille de l'anneau selon le moment du cycle : il atteint TARGET_SIZE à HitPhase
function Ring:_sizeAt(phase: number): number
	local hit = SETTINGS.HitPhase
	if phase <= hit then
		return START_SIZE + (TARGET_SIZE - START_SIZE) * (phase / hit)
	end
	return TARGET_SIZE + (END_SIZE - TARGET_SIZE) * ((phase - hit) / (1 - hit))
end

function Ring:_step()
	local t = os.clock() - self.startTime
	local phase = (t / self.interval) % 1
	local size = self:_sizeAt(phase)
	self.ring.Size = UDim2.fromOffset(size, size)

	-- Anneau grisé si la frappe de ce cycle est déjà utilisée
	local index = math.floor(t / self.interval - SETTINGS.HitPhase + 0.5)
	local used = index == self.lastHitIndex
	self.ringStroke.Transparency = if used and not self.auto then 0.7 else 0

	if self.auto and phase >= SETTINGS.HitPhase and self.lastHitIndex ~= index then
		-- En mode auto, juste un petit effet visuel au bon moment
		self.lastHitIndex = index
		self:_flash(Color3.fromRGB(120, 180, 255))
	end
end

function Ring:_flash(color: Color3)
	self.target.BackgroundColor3 = color
	task.delay(0.15, function()
		if self.target.Parent then
			self.target.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
		end
	end)
end

function Ring:_press()
	if self.auto then
		return
	end
	local t = os.clock() - self.startTime
	-- Index du « temps fort » le plus proche (un cycle = un temps fort)
	local beats = t / self.interval - SETTINGS.HitPhase
	local index = math.floor(beats + 0.5)
	if index == self.lastHitIndex or index < 0 then
		return
	end
	self.lastHitIndex = index

	local offset = math.abs(beats - index) * self.interval
	local quality = "Miss"
	if offset <= Balance.TimingWindows.Perfect * self.timingScale then
		quality = "Perfect"
	elseif offset <= Balance.TimingWindows.Good * self.timingScale then
		quality = "Good"
	end
	self:_flash(if quality == "Miss" then Color3.fromRGB(170, 170, 170) else Color3.fromRGB(90, 230, 90))
	self.onRep(quality)
end

function Ring:SetAuto(on: boolean)
	self.auto = on
end

function Ring:Destroy()
	for _, connection in self.connections do
		connection:Disconnect()
	end
	self.zone:Destroy()
end

return Ring
