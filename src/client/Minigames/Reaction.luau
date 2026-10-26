-- Mini-jeu « Reaction » (boss : Kevin, D81, D82) : Kevin se prépare, puis tend le bras dans une direction ; glisser le
-- pouce (n'importe où) dans ce sens le plus vite possible. Un cercle autour de lui montre le temps qui reste.
-- Trop tôt, mauvais sens ou trop lent = raté. Réussi : Kevin encaisse (étoiles) ; raté : il se moque.
-- Manche 1 : gauche ou droite seulement ; manche 2 : les 4 directions (Reaction.FourLevel) ; manche 3 : feintes
-- (Reaction.FeintLevel), la flèche grise tremblante change de sens, glisser pendant la feinte = raté.
-- Clavier : flèches, ZQSD/WASD ; manette : croix, coup de stick.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Reaction
local OFFSET =
	{ Up = Vector2.new(0, -1), Down = Vector2.new(0, 1), Left = Vector2.new(-1, 0), Right = Vector2.new(1, 0) }
local ROTATION = { Up = 0, Right = 90, Down = 180, Left = 270 }
local GOLD = Color3.fromRGB(255, 215, 40)
local GRAY = Color3.fromRGB(150, 150, 160)
local SIDES = { "Left", "Right" }

local Reaction = {}

function Reaction.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(360, 360))
	local rng = self:Random()
	local directions = if self.level >= SETTINGS.FourLevel then Kit.DIRECTIONS else SIDES

	local arena = Ui.create("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		BackgroundColor3 = Color3.fromRGB(45, 35, 70),
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 12)) })
	-- Cercle du temps qui reste
	local timerRing = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(200, 200),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = arena,
	}, { Ui.corner(UDim.new(1, 0)) })
	local timerStroke = Ui.stroke(GOLD, 6, 0)
	timerStroke.Parent = timerRing
	local kevin = self:Emoji(arena, "😏", 120, 4)
	kevin.Position = UDim2.fromScale(0.5, 0.5)
	-- Son bras : le poing part dans la direction, avec une grosse flèche
	local fist = self:Emoji(arena, "👊", 64, 5)
	local arrow = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(90, 90),
		Text = "⬆",
		TextColor3 = GOLD,
		ZIndex = 6,
		Parent = arena,
	})
	local stars = self:Emoji(arena, "💫", 60, 7)
	stars.Position = UDim2.fromScale(0.5, 0.28)
	stars.Visible = false

	local cycleStart = os.clock() + interval * 0.4
	local showAt = 0
	local feintUntil = 0
	local direction = "Left"
	local feintDirection = "Left"
	local resolved = false
	local resultAt = -math.huge
	local success = false

	local function newCycle(at: number)
		cycleStart = at
		resolved = false
		local wait = SETTINGS.WaitMin + rng:NextNumber() * (SETTINGS.WaitMax - SETTINGS.WaitMin)
		direction = directions[rng:NextInteger(1, #directions)]
		feintUntil = 0
		if self.level >= SETTINGS.FeintLevel and rng:NextNumber() < SETTINGS.FeintChance then
			repeat
				feintDirection = directions[rng:NextInteger(1, #directions)]
			until feintDirection ~= direction
			feintUntil = at + wait + SETTINGS.FeintTime
			showAt = feintUntil
			self:Announce("Minigame.Twist.Reaction.Feint")
		else
			showAt = at + wait
		end
	end
	newCycle(cycleStart)
	if #directions == 4 then
		self:Announce("Minigame.Twist.Reaction.Four")
	end

	local function finish(quality: string)
		resolved = true
		success = quality ~= "Miss"
		resultAt = os.clock()
		self:Rep(quality, kevin)
		if success then
			-- Kevin encaisse : il recule et voit des étoiles
			kevin.Text = "😵"
			local push = OFFSET[direction] * 0.12
			kevin.Position = UDim2.fromScale(0.5 + push.X, 0.5 + push.Y)
			TweenService:Create(kevin, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(0.5, 0.5),
			}):Play()
		else
			kevin.Text = "😆"
		end
	end

	self:OnSwipe(function(swiped)
		local now = os.clock()
		if resolved or now < cycleStart then
			return
		end
		if now < showAt or swiped ~= direction then
			-- Trop tôt (ou piégé par la feinte), ou mauvais sens
			finish("Miss")
			return
		end
		finish(self:GradeError(now - showAt, SETTINGS.PerfectMax, SETTINGS.GoodMax))
	end)
	self:Guide(panel, "SwipeLeft")

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
		local feinting = feintUntil > 0 and now < feintUntil and now >= feintUntil - SETTINGS.FeintTime
		local shown = now >= showAt and not resolved
		local pointing = if feinting then feintDirection elseif shown then direction else nil
		arrow.Visible = pointing ~= nil
		fist.Visible = pointing ~= nil
		if pointing then
			local offset = OFFSET[pointing]
			local wobble = if feinting then math.sin(now * 60) * 0.015 else 0
			-- Le poing jaillit vers le bord, la flèche le suit
			local since = now - (if feinting then feintUntil - SETTINGS.FeintTime else showAt)
			local reach = math.clamp(since * 8, 0, 1)
			fist.Position = UDim2.fromScale(0.5 + offset.X * 0.3 * reach + wobble, 0.5 + offset.Y * 0.3 * reach)
			fist.Rotation = ROTATION[pointing] - 90
			arrow.Position = UDim2.fromScale(0.5 + offset.X * 0.38, 0.5 + offset.Y * 0.38)
			arrow.Rotation = ROTATION[pointing]
			arrow.TextColor3 = if feinting then GRAY else GOLD
			if shown then
				self.guideDirection = direction
				if not cued then
					cued = true
					self:GuideCue()
				end
			end
		end
		-- Temps qui reste pour répondre : le cercle se resserre
		local limit = SETTINGS.GoodMax * self.timingScale
		local left = if shown then 1 - math.clamp((now - showAt) / limit, 0, 1) else 1
		local ringSize = 120 + 90 * left
		timerRing.Size = UDim2.fromOffset(ringSize, ringSize)
		timerRing.Visible = shown
		timerStroke.Color = if left < 0.35 then Color3.fromRGB(255, 90, 90) else GOLD
		-- Étoiles après un coup réussi ; Kevin se prépare (il gonfle) tant qu'il n'a pas frappé
		local sinceResult = now - resultAt
		stars.Visible = success and sinceResult < 0.6
		stars.Rotation = sinceResult * 300
		if not resolved and sinceResult > 0.5 then
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
