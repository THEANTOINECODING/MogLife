-- Mini-jeu « Hammer » (aide : clous de la cabane du petit voisin) : le marteau balaie la planche
-- de gauche à droite ; taper quand il est pile au-dessus du clou. Le clou change de place à chaque coup.

local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local Hammer = {}

function Hammer.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(380, 240), true)

	local plank = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.new(1, -40, 0, 36),
		BackgroundColor3 = Color3.fromRGB(160, 110, 60),
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 6)) })
	local nail = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(10, 34),
		BackgroundColor3 = Color3.fromRGB(190, 190, 200),
		ZIndex = 2,
		Parent = plank,
	}, { Ui.corner(UDim.new(0, 3)) })
	local hammer = self:Emoji(panel, "🔨", 64, 4)

	local nailX = 0.5
	local hammerX = 0.5
	local lockedUntil = 0

	local function newNail()
		nailX = 0.15 + math.random() * 0.7
		nail.Position = UDim2.fromScale(nailX, 0)
		nail.Size = UDim2.fromOffset(10, 34)
	end
	newNail()

	self:OnPress(function()
		local now = os.clock()
		if now < lockedUntil then
			return
		end
		lockedUntil = now + 0.35
		local distance = math.abs(hammerX - nailX)
		local quality = self:GradeError(distance, 0.03, 0.08)
		if quality ~= "Miss" then
			nail.Size = UDim2.fromOffset(10, 6) -- enfoncé !
		end
		task.delay(0.3, newNail)
		self:Rep(quality)
	end, panel)

	self:OnStep(function(_, t)
		-- Un aller-retour complet par pulsation
		hammerX = 0.5 + 0.45 * math.sin(2 * math.pi * t / interval)
		if self.auto then
			hammerX = nailX
		end
		local plankLeft = plank.AbsolutePosition.X - panel.AbsolutePosition.X
		local x = plankLeft + hammerX * plank.AbsoluteSize.X
		local struck = os.clock() < lockedUntil
		hammer.Position = UDim2.fromOffset(x, if struck then 130 else 90)
		hammer.Rotation = if struck then -40 else 0
	end)

	return self
end

return Hammer
