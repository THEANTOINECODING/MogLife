-- Mini-jeu « Rope » (exercice : corde à sauter) : la corde tourne à vitesse variable ;
-- sauter (clic / toucher, Espace, bouton A) quand elle passe sous les pieds.

local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local Rope = {}

function Rope.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(320, 340), true)

	local center = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromOffset(240, 240),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.fromRGB(90, 90, 110), 3, 0) })
	-- Zone de saut en bas du cercle
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(70, 26),
		BackgroundColor3 = Color3.fromRGB(90, 230, 90),
		BackgroundTransparency = 0.3,
		Parent = center,
	}, { Ui.corner(UDim.new(1, 0)) })
	local jumper = self:Emoji(center, "🧍", 70, 3)
	jumper.Position = UDim2.fromScale(0.5, 0.5)
	local handle = self:Emoji(center, "🔴", 30, 4)

	-- Angle 0 = en haut, π = sous les pieds. Un tour dure entre 1 et 1,5 pulsation (jamais plus vite).
	local angle = 0
	local period = interval
	local lastBottomAt = -math.huge
	local jumpedThisTurn = false
	local jumpUntil = 0

	self:OnPress(function()
		if jumpedThisTurn then
			return
		end
		jumpedThisTurn = true
		jumpUntil = os.clock() + 0.3
		local speed = 2 * math.pi / period
		-- Écart avec le passage sous les pieds le plus proche (à venir ou tout juste passé)
		local untilBottom = ((math.pi - angle) % (2 * math.pi)) / speed
		local sinceBottom = os.clock() - lastBottomAt
		self:Rep(self:GradeOffset(math.min(untilBottom, sinceBottom)))
	end, panel)

	self:OnStep(function(dt)
		local before = angle
		angle = (angle + 2 * math.pi * dt / period) % (2 * math.pi)
		-- Passage sous les pieds
		if before < math.pi and angle >= math.pi then
			lastBottomAt = os.clock()
			if self.auto then
				jumpUntil = os.clock() + 0.3
			end
		end
		-- Nouveau tour : nouvelle vitesse, nouveau saut autorisé
		if angle < before then
			period = interval * (1 + math.random() * 0.5)
			jumpedThisTurn = false
		end
		handle.Position = UDim2.fromScale(0.5 + 0.5 * math.sin(angle), 0.5 - 0.5 * math.cos(angle))
		jumper.Position = UDim2.fromScale(0.5, if os.clock() < jumpUntil then 0.32 else 0.5)
	end)

	return self
end

return Rope
