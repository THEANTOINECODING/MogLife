-- Mini-jeu « Pressure » (aide : gonfler le pneu du livreur) : chaque appui pompe de l'air,
-- le pneu fuit en permanence. Garder l'aiguille dans la zone verte. Noté sur chaque pulsation.

local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local PUMP = 0.13
local LEAK = 0.42 -- par seconde
local BAND_MIN, BAND_MAX = 0.55, 0.8

local Pressure = {}

function Pressure.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.new(0, 220, 0.6, 0), true)

	local gauge = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.new(0, 70, 1, -90),
		BackgroundColor3 = Color3.fromRGB(30, 30, 35),
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 12)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.5) })
	Ui.create("Frame", {
		Position = UDim2.fromScale(0, 1 - BAND_MAX),
		Size = UDim2.fromScale(1, BAND_MAX - BAND_MIN),
		BackgroundColor3 = Color3.fromRGB(90, 230, 90),
		BackgroundTransparency = 0.35,
		ZIndex = 2,
		Parent = gauge,
	})
	local fill = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.3),
		BackgroundColor3 = Color3.fromRGB(120, 180, 255),
		BackgroundTransparency = 0.25,
		ZIndex = 3,
		Parent = gauge,
	}, { Ui.corner(UDim.new(0, 12)) })
	local tire = self:Emoji(panel, "🛞", 60, 4)
	tire.Position = UDim2.new(0.5, 0, 1, -34)

	local level = 0.3
	local inside, total = 0, 0
	local cycle = 0

	self:OnPress(function()
		level = math.min(level + PUMP, 1)
		tire.Size = UDim2.fromOffset(72, 72)
	end, panel)

	self:OnStep(function(dt, t)
		if self.auto then
			level = (BAND_MIN + BAND_MAX) / 2 + math.sin(t * 3) * 0.05
		else
			level = math.max(level - LEAK * dt, 0)
		end
		fill.Size = UDim2.fromScale(1, level)
		tire.Size = tire.Size:Lerp(UDim2.fromOffset(60, 60), 0.2)

		total += dt
		if level >= BAND_MIN and level <= BAND_MAX then
			inside += dt
		end
		local current = math.floor(t / interval)
		if current > cycle then
			cycle = current
			local fraction = if total > 0 then inside / total else 0
			inside, total = 0, 0
			self:Rep(self:GradeError(1 - fraction, 0.2, 0.5))
		end
	end)

	return self
end

return Pressure
