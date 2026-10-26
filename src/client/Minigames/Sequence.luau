-- Mini-jeu « Sequence » (aide : indiquer le chemin au touriste perdu) : 3 flèches s'affichent
-- un instant, puis disparaissent ; les refaire de mémoire (flèches, ZQSD/WASD, croix, boutons).
-- Sans erreur et vite = Perfect, sans erreur = Good, une erreur = Miss.

local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local LENGTH = 3
local SHOW_TIME = 1.2

local Sequence = {}

function Sequence.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(380, 300))

	local slots = {}
	for i = 1, LENGTH do
		slots[i] = Ui.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new((i - 0.5) / LENGTH, 0, 0, 90),
			Size = UDim2.fromOffset(90, 90),
			BackgroundTransparency = 0.3,
			BackgroundColor3 = Color3.fromRGB(40, 40, 55),
			Parent = panel,
		})
		Ui.corner(UDim.new(0, 14)).Parent = slots[i]
	end
	local status = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.new(1, -30, 0, 40),
		Text = "🗺️",
		Parent = panel,
	})

	local sequence: { string } = {}
	local typed = 0
	local showingUntil = 0
	local inputStart = 0

	local function newSequence()
		sequence = {}
		for i = 1, LENGTH do
			sequence[i] = Kit.DIRECTIONS[math.random(1, 4)]
			slots[i].Text = Kit.ARROWS[sequence[i]]
			slots[i].TextColor3 = Color3.new(1, 1, 1)
		end
		typed = 0
		showingUntil = os.clock() + SHOW_TIME
		inputStart = showingUntil
		status.Text = "👀"
	end
	newSequence()

	local function input(direction: string)
		if os.clock() < showingUntil or typed >= LENGTH then
			return
		end
		typed += 1
		local slot = slots[typed]
		slot.Text = Kit.ARROWS[direction]
		if direction ~= sequence[typed] then
			slot.TextColor3 = Color3.fromRGB(255, 80, 80)
			self:Rep("Miss")
			task.delay(0.6, newSequence)
			typed = LENGTH
			return
		end
		slot.TextColor3 = Color3.fromRGB(90, 230, 90)
		if typed == LENGTH then
			self:Rep(self:GradeError(os.clock() - inputStart, 1.4, 3))
			task.delay(0.5, newSequence)
		end
	end
	self:OnDirection(input)
	self:AddDirectionButtons(Kit.DIRECTIONS, input)

	self:OnStep(function()
		if os.clock() >= showingUntil and typed == 0 and status.Text == "👀" then
			for i = 1, LENGTH do
				slots[i].Text = "?"
			end
			status.Text = "✍️"
		end
		if self.auto and os.clock() >= showingUntil + interval * 0.5 and typed < LENGTH then
			typed = LENGTH
			task.delay(0.3, newSequence)
		end
	end)

	return self
end

return Sequence
