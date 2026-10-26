-- Mini-jeu « Reaction » (boss : Kevin, D81) : Kevin se prépare, puis lève le bras dans une direction ; glisser le
-- pouce (n'importe où) dans ce sens le plus vite possible. Trop tôt, mauvais sens ou trop lent = raté.
-- Surprise (niveau Reaction.FeintLevel) : feinte, la flèche grise tremblante change de sens ; glisser pendant la
-- feinte = raté. Clavier : flèches, ZQSD/WASD ; manette : croix, coup de stick.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Reaction
local ROTATION = { Up = 0, Right = 90, Down = 180, Left = 270 }
local GOLD = Color3.fromRGB(255, 215, 40)
local GRAY = Color3.fromRGB(150, 150, 160)

local Reaction = {}

function Reaction.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(340, 360))
	local rng = self:Random()

	local kevin = self:Emoji(panel, "😏", 120, 3)
	kevin.Position = UDim2.fromScale(0.5, 0.5)
	-- La flèche (le bras de Kevin) tourne autour de lui
	local pivot = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(280, 280),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = panel,
	})
	local arrow = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(110, 110),
		Text = "⬆",
		TextColor3 = GOLD,
		ZIndex = 5,
		Parent = pivot,
	})

	-- Manche : attente (Kevin se prépare), feinte éventuelle, puis le vrai geste
	local cycleStart = os.clock() + interval * 0.3
	local showAt = 0
	local feintUntil = 0
	local direction = "Up"
	local feintDirection = "Up"
	local resolved = false

	local function newCycle(at: number)
		cycleStart = at
		resolved = false
		local wait = SETTINGS.WaitMin + rng:NextNumber() * (SETTINGS.WaitMax - SETTINGS.WaitMin)
		direction = Kit.DIRECTIONS[rng:NextInteger(1, 4)]
		feintUntil = 0
		local feint = self.level >= SETTINGS.FeintLevel and rng:NextNumber() < SETTINGS.FeintChance
		if feint then
			repeat
				feintDirection = Kit.DIRECTIONS[rng:NextInteger(1, 4)]
			until feintDirection ~= direction
			feintUntil = at + wait + SETTINGS.FeintTime
			showAt = feintUntil
			self:Announce("Minigame.Twist.Reaction.Feint")
		else
			showAt = at + wait
		end
	end
	newCycle(cycleStart)

	local function finish(quality: string)
		resolved = true
		self:Rep(quality, kevin)
		kevin.Text = if quality == "Miss" then "😆" else "😵"
	end

	self:OnSwipe(function(swiped)
		local now = os.clock()
		if resolved or now < cycleStart then
			return
		end
		if now < showAt then
			-- Trop tôt (ou piégé par la feinte)
			finish("Miss")
			return
		end
		if swiped ~= direction then
			finish("Miss")
			return
		end
		finish(self:GradeError(now - showAt, SETTINGS.PerfectMax, SETTINGS.GoodMax))
	end)
	self:Guide(panel, "SwipeUp")

	local cued = false
	self:OnStep(function()
		local now = os.clock()
		if now >= cycleStart + interval then
			-- Combat de boss : ne rien faire est un raté (sinon la manche ne finirait jamais)
			if not resolved then
				finish("Miss")
			end
			newCycle(cycleStart + interval)
			cued = false
		end
		local feinting = now < feintUntil and now >= feintUntil - SETTINGS.FeintTime
		local shown = now >= showAt and not resolved
		arrow.Visible = feinting or shown
		if feinting then
			pivot.Rotation = ROTATION[feintDirection] + math.sin(now * 60) * 6
			arrow.TextColor3 = GRAY
		elseif shown then
			pivot.Rotation = ROTATION[direction]
			arrow.TextColor3 = GOLD
			self.guideDirection = direction
			if not cued then
				cued = true
				self:GuideCue()
			end
		end
		-- Kevin se prépare (il gonfle), puis frappe
		if not resolved then
			kevin.Text = if shown then "😤" else "😏"
			local charge = math.clamp((now - cycleStart) / math.max(showAt - cycleStart, 0.01), 0, 1)
			local size = 110 + 20 * charge
			kevin.Size = UDim2.fromOffset(size, size)
		end
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		return { showAt = showAt, direction = direction, resolved = resolved, cycleStart = cycleStart }
	end

	return self
end

return Reaction
