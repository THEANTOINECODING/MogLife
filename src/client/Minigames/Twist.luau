-- Mini-jeu « Twist » (aide : ouvrir le bocal de maman) : dévisser le couvercle en tournant
-- autour du bocal, un tour complet par pulsation. Souris / doigt en cercle, ou A / D (le couvercle résiste).

local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local Twist = {}

local function wrap(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

function Twist.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(320, 320))
	self:TrackPointer()

	-- Pulsation qui donne le rythme d'un tour
	local pulse = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(240, 240),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)) })
	local pulseStroke = Ui.stroke(Color3.fromRGB(120, 220, 255), 4, 0)
	pulseStroke.Parent = pulse

	local lid = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(180, 180),
		BackgroundColor3 = Color3.fromRGB(200, 60, 50),
		ZIndex = 2,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(1, 1, 1), 4, 0) })
	-- Poignée pour voir le couvercle tourner
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.04),
		Size = UDim2.fromOffset(30, 46),
		BackgroundColor3 = Color3.fromRGB(255, 220, 120),
		ZIndex = 3,
		Parent = lid,
	}, { Ui.corner(UDim.new(0, 8)) })
	local pickle = self:Emoji(lid, "🥒", 80, 3)
	pickle.Position = UDim2.fromScale(0.5, 0.55)

	local lastAngle: number? = nil
	local turned = 0
	local lastTurnAt = os.clock()
	local resistance = 1

	self:OnStep(function(dt, t)
		local phase = (t / interval) % 1
		pulse.Size = UDim2.fromOffset(190 + 110 * phase, 190 + 110 * phase)
		pulseStroke.Transparency = phase

		if self.auto then
			lid.Rotation += 360 * dt / interval
			return
		end

		local delta = 0
		local held = self:HeldDirection().X
		if held ~= 0 then
			-- Au clavier, le couvercle résiste plus ou moins à chaque tour : il faut ajuster
			delta = held * 2 * math.pi * dt / interval * resistance
			lastAngle = nil
		elseif self.pointerActive then
			local center = lid.AbsolutePosition + lid.AbsoluteSize / 2
			local offset = self.pointer - center
			if offset.Magnitude > 25 then
				local angle = math.atan2(offset.Y, offset.X)
				if lastAngle then
					delta = wrap(angle - lastAngle)
				end
				lastAngle = angle
			else
				lastAngle = nil
			end
		end

		turned += delta
		lid.Rotation += math.deg(delta)
		if math.abs(turned) >= 2 * math.pi then
			local now = os.clock()
			local duration = now - lastTurnAt
			lastTurnAt = now
			turned = 0
			resistance = 0.7 + math.random() * 0.6
			self:Rep(self:GradeError(math.abs(duration - interval) / interval, 0.15, 0.35))
		end
	end)

	return self
end

return Twist
