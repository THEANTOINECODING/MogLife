-- Mini-jeu « Swipe » (curl) : glisser de haut en bas en suivant le rythme de l'haltère.
-- Une répétition = descendre en bas de la piste puis remonter en haut.
-- La qualité dépend de l'écart entre ton arrivée en haut et celle de l'haltère fantôme.
--
-- Interface commune des mini-jeux :
--   Minigame.new(parent: GuiObject, interval: number, onRep: (quality: string) -> ())
--   minigame:SetAuto(on: boolean)   -- en mode auto, le mini-jeu s'anime tout seul et ne note rien
--   minigame:Destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Ui = require(script.Parent.Parent.Ui)

-- Hauteurs (0 = bas de la piste, 1 = haut) qui valident le bas et le haut d'une répétition
local BOTTOM = 0.2
local TOP = 0.8
-- Moment du cycle où le fantôme franchit TOP en montant (fraction de l'intervalle)
local TARGET_PHASE = math.acos(1 - 2 * TOP) / (2 * math.pi)

local Swipe = {}
Swipe.__index = Swipe

local function circle(size: number, color: Color3, transparency: number, emoji: string, zIndex: number)
	return Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		ZIndex = zIndex,
	}, {
		Ui.corner(UDim.new(1, 0)),
		Ui.label({
			Size = UDim2.fromScale(0.8, 0.8),
			Position = UDim2.fromScale(0.1, 0.1),
			Text = emoji,
			TextStrokeTransparency = 1,
			ZIndex = zIndex,
		}),
	})
end

local function zone(positionY: number, height: number, color: Color3, arrow: string)
	return Ui.create("Frame", {
		Position = UDim2.new(0, 8, positionY, 0),
		Size = UDim2.new(1, -16, height, 0),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.55,
	}, {
		Ui.corner(UDim.new(0, 12)),
		Ui.label({
			Size = UDim2.fromScale(1, 1),
			Text = arrow,
			TextTransparency = 0.3,
			TextStrokeTransparency = 1,
		}),
	})
end

function Swipe.new(parent: GuiObject, interval: number, onRep: (string) -> ())
	local self = setmetatable({}, Swipe)
	self.interval = interval
	self.onRep = onRep
	self.startTime = os.clock()
	self.pointerY = 0
	self.armed = false
	self.auto = false
	self.connections = {}

	self.track = Ui.panel({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -40, 0.5, 20),
		Size = UDim2.new(0, 130, 0.6, 0),
		Parent = parent,
	})

	local topZone = zone(0.02, 1 - TOP - 0.02, Color3.fromRGB(90, 230, 90), "▲")
	topZone.Parent = self.track
	local bottomZone = zone(1 - BOTTOM, BOTTOM - 0.02, Color3.fromRGB(120, 160, 255), "▼")
	bottomZone.Parent = self.track

	self.ghost = circle(64, Color3.new(1, 1, 1), 0.65, "🍉", 2)
	self.ghost.Parent = self.track
	self.marker = circle(84, Color3.fromRGB(255, 200, 40), 0, "💪", 3)
	self.markerStroke = Ui.stroke(Color3.new(1, 1, 1), 4, 0)
	self.markerStroke.Parent = self.marker
	self.marker.Parent = self.track

	local function onInput(input: InputObject)
		local inputType = input.UserInputType
		if inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.Touch then
			self:_setPointerFromScreen(input.Position)
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			self.pointerY = math.clamp((input.Position.Y + 1) / 2, 0, 1)
		end
	end

	table.insert(self.connections, UserInputService.InputChanged:Connect(onInput))
	table.insert(self.connections, UserInputService.InputBegan:Connect(onInput))
	table.insert(
		self.connections,
		RunService.RenderStepped:Connect(function()
			self:_step()
		end)
	)

	return self
end

function Swipe:_setPointerFromScreen(position: Vector3)
	local top = self.track.AbsolutePosition.Y
	local height = self.track.AbsoluteSize.Y
	if height <= 0 then
		return
	end
	self.pointerY = 1 - math.clamp((position.Y - top) / height, 0, 1)
end

function Swipe:_grade(t: number): string
	local target = TARGET_PHASE * self.interval
	local phase = (t - target) % self.interval
	local offset = math.min(phase, self.interval - phase)
	if offset <= Balance.TimingWindows.Perfect then
		return "Perfect"
	elseif offset <= Balance.TimingWindows.Good then
		return "Good"
	end
	return "Miss"
end

function Swipe:_step()
	local t = os.clock() - self.startTime
	local ghostY = (1 - math.cos(2 * math.pi * t / self.interval)) / 2
	self.ghost.Position = UDim2.fromScale(0.5, 0.9 - 0.8 * ghostY)

	local y = if self.auto then ghostY else self.pointerY
	self.marker.Position = UDim2.fromScale(0.5, 0.9 - 0.8 * y)
	-- Contour vert quand la répétition est « armée » (on est passé par le bas)
	self.markerStroke.Color = if self.armed then Color3.fromRGB(90, 230, 90) else Color3.new(1, 1, 1)

	if self.auto then
		return
	end
	if y < BOTTOM then
		self.armed = true
	elseif self.armed and y > TOP then
		self.armed = false
		self.onRep(self:_grade(t))
	end
end

function Swipe:SetAuto(on: boolean)
	self.auto = on
	self.armed = false
end

function Swipe:Destroy()
	for _, connection in self.connections do
		connection:Disconnect()
	end
	self.track:Destroy()
end

return Swipe
