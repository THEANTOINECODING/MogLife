-- Mini-jeu « Wobble » (boss : Monsieur Pas-Les-Jambes) : tenir en équilibre sur ses jambes minuscules.
-- La bille dérive dans tous les sens ; la ramener au centre (souris / doigt = direction de la poussée,
-- ou ZQSD/WASD / stick). Noté sur chaque pulsation selon la distance moyenne au centre.

local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local DRIFT = 0.55
local INSTABILITY = 1.1
local CONTROL = 1.6

local Wobble = {}

function Wobble.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(340, 340))
	self:TrackPointer()

	local plate = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(290, 290),
		BackgroundColor3 = Color3.fromRGB(200, 70, 70),
		BackgroundTransparency = 0.3,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)) })
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		BackgroundColor3 = Color3.fromRGB(90, 230, 90),
		BackgroundTransparency = 0.3,
		Parent = plate,
	}, { Ui.corner(UDim.new(1, 0)) })
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.3, 0.3),
		BackgroundColor3 = Color3.fromRGB(255, 215, 40),
		BackgroundTransparency = 0.2,
		Parent = plate,
	}, { Ui.corner(UDim.new(1, 0)) })
	local ball = self:Emoji(plate, "🦵", 50, 4)

	-- Position de la bille : (0,0) = centre, rayon 1 = bord du plateau
	local position = Vector2.zero
	local drift = Vector2.zero
	local nextDrift = 0
	local errorSum, total = 0, 0
	local cycle = 0
	local strength = DRIFT / self.timingScale

	self:OnStep(function(dt, t)
		if self.auto then
			position = Vector2.zero
		else
			if t >= nextDrift then
				local angle = math.random() * 2 * math.pi
				drift = Vector2.new(math.cos(angle), math.sin(angle)) * strength
				nextDrift = t + 0.7
			end
			local control = self:HeldDirection()
			if control.Magnitude == 0 and self.pointerActive then
				-- Le pointeur indique où pousser, par rapport au centre du plateau
				local relative = self:PointerIn(plate) * 2 - Vector2.one
				control = if relative.Magnitude > 1 then relative.Unit else relative
			end
			local velocity = drift + position * INSTABILITY + control * CONTROL
			position += velocity * dt
			if position.Magnitude > 1 then
				position = position.Unit
			end
		end
		ball.Position = UDim2.fromScale(0.5 + position.X * 0.45, 0.5 + position.Y * 0.45)

		errorSum += position.Magnitude * dt
		total += dt
		local current = math.floor(t / interval)
		if current > cycle then
			cycle = current
			local average = if total > 0 then errorSum / total else 1
			errorSum, total = 0, 0
			self:Rep(self:GradeError(average, 0.15, 0.35))
		end
	end)

	return self
end

return Wobble
