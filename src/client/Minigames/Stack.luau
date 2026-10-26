-- Mini-jeu « Stack » (aide : empiler les transats du maître-nageur, D81) : un transat glisse de gauche à droite
-- au-dessus de la pile ; toucher l'écran (n'importe où) pour le lâcher. La partie qui dépasse tombe : le transat
-- suivant est plus étroit. Pile parfaite = rien ne tombe ; complètement à côté = raté (le transat tombe).
-- La pile monte et la vue la suit ; le transat va plus vite à chaque niveau. Clavier : Espace ; manette : A.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Stack
local BLOCK_HEIGHT = 30
local SAND = 34
local COLORS = {
	Color3.fromRGB(255, 95, 95),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(90, 200, 120),
	Color3.fromRGB(90, 170, 255),
	Color3.fromRGB(200, 120, 255),
}

local Stack = {}

function Stack.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(340, 420))

	local area = Ui.create("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		BackgroundColor3 = Color3.fromRGB(120, 200, 245),
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 12)) })
	-- Tout ce qui monte avec la pile (sable compris) : la vue descend ce cadre quand la pile grandit
	local world = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = area,
	})
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, SAND),
		BackgroundColor3 = Color3.fromRGB(240, 215, 145),
		Parent = world,
	})

	local function block(x: number, width: number, height: number, color: Color3): Frame
		return Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(x, 0, 1, -SAND - height * BLOCK_HEIGHT),
			Size = UDim2.new(width, 0, 0, BLOCK_HEIGHT - 3),
			BackgroundColor3 = color,
			ZIndex = 2,
			Parent = world,
		}, {
			Ui.corner(UDim.new(0, 6)),
			Ui.stroke(Color3.new(1, 1, 1), 2, 0.4),
			-- Les lattes du transat
			Ui.create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -12, 0, 3),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
				ZIndex = 3,
			}),
		})
	end

	local placed = 1
	local topX = 0.5
	local width = SETTINGS.StartWidth
	block(topX, width, 0, COLORS[1])
	local moving = block(0.5, width, 1, COLORS[2])
	local movingX = 0.5
	local lockedUntil = 0
	local view = 0 -- décalage de la vue (en transats)
	local speed = 1 + SETTINGS.SpeedPerLevel * self.level
	local sweepStart = os.clock()

	-- Un morceau qui tombe (ce qui dépasse, ou le transat raté)
	local function drop(x: number, w: number, height: number, color: Color3)
		local piece = block(x, w, height, color)
		piece.ZIndex = 4
		TweenService:Create(piece, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = piece.Position + UDim2.fromOffset(0, 400),
			Rotation = if x > topX then 40 else -40,
			BackgroundTransparency = 1,
		}):Play()
		task.delay(0.65, function()
			piece:Destroy()
		end)
	end

	self:OnPress(function()
		local now = os.clock()
		if now < lockedUntil or not self:RepReady() then
			return
		end
		lockedUntil = now + 0.25
		local color = COLORS[placed % #COLORS + 1]
		local offset = movingX - topX
		local overlap = width - math.abs(offset)
		local quality = self:GradeError(math.abs(offset), SETTINGS.PerfectSnap, SETTINGS.GoodMax)
		if quality == "Miss" or overlap < SETTINGS.MinWidth * 0.5 then
			drop(movingX, width, placed, color)
			self:Rep("Miss", moving)
		else
			local newX = topX
			if quality ~= "Perfect" then
				-- Ce qui dépasse tombe ; le transat suivant garde la largeur posée
				local cut = math.abs(offset)
				newX = topX + offset / 2
				local side = if offset > 0 then 1 else -1
				drop(newX + side * (width - cut) / 2 + side * cut / 2, cut, placed, color)
				width = math.max(width - cut, SETTINGS.MinWidth)
			end
			block(newX, width, placed, color)
			topX = newX
			placed += 1
			self:Rep(quality, moving)
			-- La vue monte avec la pile
			local target = math.max(placed - SETTINGS.Visible, 0)
			if target ~= view then
				view = target
				TweenService:Create(world, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
					Position = UDim2.fromOffset(0, view * BLOCK_HEIGHT),
				}):Play()
			end
		end
		sweepStart = now
		moving.Size = UDim2.new(width, 0, 0, BLOCK_HEIGHT - 3)
		moving.BackgroundColor3 = COLORS[placed % #COLORS + 1]
	end)
	self:Guide(panel, "Tap")

	local wasAligned = false
	self:OnStep(function()
		local now = os.clock()
		local reach = 0.5 - width / 2 - 0.02
		movingX = 0.5 + reach * math.sin(2 * math.pi * (now - sweepStart) * speed / (interval * SETTINGS.SweepFactor))
		moving.Position = UDim2.new(movingX, 0, 1, -SAND - placed * BLOCK_HEIGHT - 26)
		moving.BackgroundTransparency = if self:RepReady() then 0 else 0.5
		local aligned = math.abs(movingX - topX) <= SETTINGS.PerfectSnap
		if aligned and not wasAligned then
			self:GuideCue()
		end
		wasAligned = aligned
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		return { movingX = movingX, topX = topX, ready = self:RepReady() and os.clock() >= lockedUntil }
	end

	return self
end

return Stack
