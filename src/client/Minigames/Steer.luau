-- Mini-jeu « Steer » (aide : pousser la voiture du voisin) : la route serpente, garder la voiture
-- au milieu. Souris / doigt à gauche-droite, ou A / D, ou stick. Noté sur chaque pulsation.

local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SEGMENTS = 14
local CAR_Y = 0.82
local ROAD_WIDTH = 0.3
local KEY_SPEED = 1.4 -- largeur de panneau par seconde

local Steer = {}

local function roadCenter(s: number): number
	return 0.5 + 0.22 * math.sin(s * 1.3) + 0.1 * math.sin(s * 3.1 + 1)
end

function Steer.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(320, 380))
	self:TrackPointer()

	local road = Ui.create("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		BackgroundColor3 = Color3.fromRGB(60, 140, 60),
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 12)) })

	local segments = {}
	for i = 1, SEGMENTS do
		segments[i] = Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(ROAD_WIDTH, 0, 1 / SEGMENTS, 2),
			BackgroundColor3 = Color3.fromRGB(70, 70, 80),
			BorderSizePixel = 0,
			Parent = road,
		})
	end
	local car = self:Emoji(road, "🚗", 56, 4)
	car.Rotation = -90

	local carX = 0.5
	local errorSum, total = 0, 0
	local cycle = 0

	self:OnStep(function(dt, t)
		local scroll = t * 1.2
		for i, segment in segments do
			local y = (i - 0.5) / SEGMENTS
			segment.Position = UDim2.fromScale(roadCenter(scroll + (1 - y) * 2), y)
		end
		local target = roadCenter(scroll + (1 - CAR_Y) * 2)

		if self.auto then
			carX = target
		else
			local held = self:HeldDirection().X
			if held ~= 0 then
				carX += held * KEY_SPEED * dt
			elseif self.pointerActive then
				carX = self:PointerIn(road).X
			end
			carX = math.clamp(carX, 0.05, 0.95)
		end
		car.Position = UDim2.fromScale(carX, CAR_Y)

		errorSum += math.abs(carX - target) * dt
		total += dt
		local current = math.floor(t / interval)
		if current > cycle then
			cycle = current
			local average = if total > 0 then errorSum / total else 1
			errorSum, total = 0, 0
			self:Rep(self:GradeError(average, 0.05, 0.12))
		end
	end)

	return self
end

return Steer
