-- Mini-jeu « Combo » (boss : le Roi du Quartier) : une combinaison de 4 flèches s'affiche ;
-- la taper dans l'ordre le plus vite possible avant que son ventilateur ne l'efface. Une erreur = Miss.

local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local LENGTH = 4

local Combo = {}

function Combo.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(420, 300))

	local slots = {}
	for i = 1, LENGTH do
		local slot = Ui.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new((i - 0.5) / LENGTH, 0, 0, 80),
			Size = UDim2.fromOffset(80, 80),
			BackgroundTransparency = 0.3,
			BackgroundColor3 = Color3.fromRGB(40, 40, 55),
			Parent = panel,
		})
		Ui.corner(UDim.new(0, 14)).Parent = slot
		slots[i] = slot
	end
	local timer = Ui.create("Frame", {
		Position = UDim2.fromOffset(16, 140),
		Size = UDim2.new(1, -32, 0, 14),
		BackgroundColor3 = Color3.fromRGB(120, 200, 255),
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)) })

	local combo: { string } = {}
	local typed = 0
	local startedAt = 0
	local active = false

	local function newCombo()
		combo = {}
		for i = 1, LENGTH do
			combo[i] = Kit.DIRECTIONS[math.random(1, 4)]
			slots[i].Text = Kit.ARROWS[combo[i]]
			slots[i].TextColor3 = Color3.new(1, 1, 1)
		end
		typed = 0
		startedAt = os.clock()
		active = true
	end
	newCombo()

	local function finish(quality: string)
		active = false
		self:Rep(quality)
		task.delay(0.35, newCombo)
	end

	local function input(direction: string)
		if not active then
			return
		end
		typed += 1
		local slot = slots[typed]
		if direction ~= combo[typed] then
			slot.TextColor3 = Color3.fromRGB(255, 80, 80)
			finish("Miss")
			return
		end
		slot.TextColor3 = Color3.fromRGB(90, 230, 90)
		if typed == LENGTH then
			finish(self:GradeError(os.clock() - startedAt, interval * 0.4, interval * 0.7))
		end
	end
	self:OnDirection(input)
	self:AddDirectionButtons(Kit.DIRECTIONS, input)

	self:OnStep(function()
		local elapsed = os.clock() - startedAt
		timer.Size = UDim2.new(math.clamp(1 - elapsed / interval, 0, 1), -32, 0, 14)
		if active and elapsed >= interval then
			if self.auto then
				active = false
				task.delay(0.35, newCombo)
			else
				finish("Miss")
			end
		end
	end)

	return self
end

return Combo
