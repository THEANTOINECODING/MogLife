-- Mini-jeu « Stack » (aide : empiler les transats du maître-nageur) : un transat glisse de gauche à droite
-- au-dessus de la pile ; taper pour le lâcher pile au-dessus. Plus il est aligné, mieux c'est.

local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local BLOCK_WIDTH = 0.34
local BLOCK_HEIGHT = 26
local MAX_STACK = 7

local Stack = {}

function Stack.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(340, 400), true)

	local area = Ui.create("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		BackgroundColor3 = Color3.fromRGB(110, 190, 240),
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 12)) })
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Color3.fromRGB(240, 210, 140), -- sable
		Parent = area,
	})

	local colors = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 200, 60), Color3.fromRGB(90, 200, 120) }
	local placed = {}
	local topX = 0.5

	local function block(x: number, level: number, color: Color3): Frame
		return Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(x, 0, 1, -30 - level * BLOCK_HEIGHT),
			Size = UDim2.new(BLOCK_WIDTH, 0, 0, BLOCK_HEIGHT - 2),
			BackgroundColor3 = color,
			ZIndex = 2,
			Parent = area,
		}, { Ui.corner(UDim.new(0, 6)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.4) })
	end

	local function reset()
		for _, frame in placed do
			frame:Destroy()
		end
		placed = { block(0.5, 0, colors[1]) }
		topX = 0.5
	end
	reset()

	local moving = block(0.5, 1, colors[2])
	local movingX = 0.5
	local lockedUntil = 0

	self:OnPress(function()
		local now = os.clock()
		if now < lockedUntil then
			return
		end
		lockedUntil = now + 0.25
		local quality = self:GradeError(math.abs(movingX - topX), 0.025, 0.08)
		if quality ~= "Miss" then
			table.insert(placed, block(movingX, #placed, colors[#placed % #colors + 1]))
			topX = movingX
			if #placed >= MAX_STACK then
				task.delay(0.3, reset)
			end
		end
		self:Rep(quality)
	end, panel)

	self:OnStep(function(_, t)
		movingX = 0.5 + 0.32 * math.sin(2 * math.pi * t / interval)
		if self.auto then
			movingX = topX
		end
		moving.Position = UDim2.new(movingX, 0, 1, -30 - (#placed + 1) * BLOCK_HEIGHT - 20)
	end)

	return self
end

return Stack
