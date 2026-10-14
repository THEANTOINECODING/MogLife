-- Mini-jeu « Reaction » (boss : Kevin) : Kevin prend une pose, une flèche apparaît ;
-- copier sa pose le plus vite possible (flèches, ZQSD/WASD, croix, boutons). Mauvaise direction = Miss.

local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local Reaction = {}

function Reaction.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(340, 340))

	local arrow = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(160, 160),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 220, 60),
		Parent = panel,
	})

	local current: string? = nil
	local shownAt = 0
	local cycle = -1

	local function answer(direction: string)
		if not current then
			return
		end
		local reaction = os.clock() - shownAt
		local quality = if direction == current then self:GradeError(reaction, 0.45, 0.8) else "Miss"
		arrow.TextColor3 = if quality == "Miss" then Color3.fromRGB(255, 80, 80) else Color3.fromRGB(90, 230, 90)
		current = nil
		self:Rep(quality)
	end
	self:OnDirection(answer)
	self:AddDirectionButtons(Kit.DIRECTIONS, answer)

	self:OnStep(function(_, t)
		local index = math.floor(t / interval)
		if index > cycle then
			-- Pas de réponse avant la pose suivante : raté
			if current then
				current = nil
				self:Rep("Miss")
			end
			cycle = index
			current = Kit.DIRECTIONS[math.random(1, 4)]
			shownAt = os.clock()
			arrow.Text = Kit.ARROWS[current]
			arrow.TextColor3 = Color3.fromRGB(255, 220, 60)
		end
		local pop = math.clamp((os.clock() - shownAt) * 8, 0, 1)
		arrow.Size = UDim2.fromOffset(100 + 60 * pop, 100 + 60 * pop)
	end)

	return self
end

return Reaction
