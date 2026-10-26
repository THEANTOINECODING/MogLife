-- Mini-jeu « Spotlight » (boss : Brayan le Bronzé) : le soleil se déplace ; garder son curseur
-- dedans pour bronzer (souris / doigt, ou ZQSD/WASD / stick). Noté sur chaque pulsation.

local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local RADIUS = 0.16 -- rayon du soleil, en fraction de la zone
local KEY_SPEED = 1.1

local Spotlight = {}

function Spotlight.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(360, 360))
	self:TrackPointer()

	local area = Ui.create("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		BackgroundColor3 = Color3.fromRGB(40, 30, 60),
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 12)) })
	local sun = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(RADIUS * 2, RADIUS * 2),
		BackgroundColor3 = Color3.fromRGB(255, 200, 60),
		BackgroundTransparency = 0.25,
		Parent = area,
	}, { Ui.corner(UDim.new(1, 0)) })
	local cursor = self:Emoji(area, "🧴", 44, 4)

	local cursorPos = Vector2.new(0.5, 0.5)
	local inside, total = 0, 0
	local cycle = 0
	-- Vitesse du soleil : plus rapide si les fenêtres sont serrées (boss plus dur)
	local speed = 1 / self.timingScale

	self:OnStep(function(dt, t)
		local s = t * speed
		local sunPos = Vector2.new(0.5 + 0.3 * math.sin(s * 1.1), 0.5 + 0.3 * math.sin(s * 1.7 + 0.8))
		sun.Position = UDim2.fromScale(sunPos.X, sunPos.Y)

		if self.auto then
			cursorPos = sunPos
		else
			local held = self:HeldDirection()
			if held.Magnitude > 0 then
				cursorPos += held * KEY_SPEED * dt
			elseif self.pointerActive then
				cursorPos = self:PointerIn(area)
			end
			cursorPos = Vector2.new(math.clamp(cursorPos.X, 0, 1), math.clamp(cursorPos.Y, 0, 1))
		end
		cursor.Position = UDim2.fromScale(cursorPos.X, cursorPos.Y)

		total += dt
		if (cursorPos - sunPos).Magnitude <= RADIUS then
			inside += dt
		end
		local current = math.floor(t / interval)
		if current > cycle then
			cycle = current
			local fraction = if total > 0 then inside / total else 0
			inside, total = 0, 0
			self:Rep(self:GradeError(1 - fraction, 0.15, 0.4))
		end
	end)

	return self
end

return Spotlight
