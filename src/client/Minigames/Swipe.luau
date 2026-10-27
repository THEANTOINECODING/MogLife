-- Mini-jeu « Swipe » (exercice : curl de pastèque, refait en D87) : la pastèque retombe vers les mains dorées en
-- bas ; glisser le pouce vers le haut (n'importe où sur l'écran) au moment où elle arrive dans les mains, pour la
-- relancer bien haut. Comme jongler : on voit la pastèque arriver, aucun repère à comprendre.
-- Une répétition par retombée ; une pastèque qui retombe sans geste (une fois la série commencée) est ratée : elle
-- s'écrase lourdement dans les mains et ne fait qu'un petit rebond.
-- Surprise (niveau Swipe.SlowLevel) : lancer lent (tortue), la pastèque monte plus haut et redescend plus tard.
-- Clavier : flèche haut / Z / W / Espace ; manette : coup de stick vers le haut ou bouton A.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Swipe
local HANDS_Y = 0.8 -- hauteur des mains (0 = haut de la piste)
local GOLD = Color3.fromRGB(255, 210, 60)
local SLOW_COLOR = Color3.fromRGB(120, 200, 255)

local Swipe = {}

function Swipe.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(300, 400))
	local rng = self:Random()

	local track = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.new(0, 150, 1, -28),
		BackgroundColor3 = Color3.fromRGB(25, 20, 40),
		BackgroundTransparency = 0.25,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 40)), Ui.stroke(Color3.fromRGB(255, 255, 255), 2, 0.7) })
	-- Les mains : un berceau doré qui brille quand la pastèque arrive
	local cradle = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, HANDS_Y + 0.07),
		Size = UDim2.fromOffset(130, 26),
		BackgroundColor3 = GOLD,
		ZIndex = 2,
		Parent = track,
	}, { Ui.corner(UDim.new(1, 0)) })
	local hands = self:Emoji(track, "🙌", 64, 6)
	hands.Position = UDim2.fromScale(0.5, HANDS_Y + 0.1)
	local shadow = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, HANDS_Y + 0.07),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.6,
		ZIndex = 3,
		Parent = track,
	}, { Ui.corner(UDim.new(1, 0)) })
	local melon = self:Emoji(track, "🍉", 78, 5)
	local turtle = self:Emoji(track, "🐢", 34, 7)
	local arrow = self:Emoji(track, "⬆️", 40, 4)
	arrow.Position = UDim2.fromScale(0.5, 0.45)

	-- Retombée en cours : elle part des mains (ou du haut au début) et y revient à cycleStart + cycleLength
	local cycleLength = interval
	local cycleStart = os.clock() + interval * 0.45 - cycleLength -- la première pastèque tombe du haut
	local slow = false
	local first = true
	local answered = false -- la retombée en cours a reçu son geste
	local prevHit = -math.huge -- retombée précédente (un geste juste après compte encore pour elle)
	local prevAnswered = true
	local strong = true -- le dernier lancer était réussi : la pastèque monte haut
	local started = false
	local throwAt = -math.huge
	local thudAt = -math.huge

	local function window(): number
		return Balance.TimingWindows.Good * self.timingScale
	end

	local function hitTime(): number
		return cycleStart + cycleLength
	end

	local function newCycle(at: number)
		cycleStart = at
		slow = self.level >= SETTINGS.SlowLevel and rng:NextNumber() < SETTINGS.SlowChance
		cycleLength = interval * (if slow then SETTINGS.SlowFactor else 1)
		answered = false
		first = false
		if slow then
			self:Announce("Minigame.Twist.Swipe.Slow")
		end
	end

	local function throw()
		local now = os.clock()
		-- Le geste va à la retombée la plus proche qui n'en a pas encore reçu
		local nextOffset = if answered then math.huge else math.abs(now - hitTime())
		local prevOffset = if prevAnswered then math.huge else math.abs(now - prevHit)
		if nextOffset == math.huge and prevOffset == math.huge then
			return
		end
		-- Un geste beaucoup trop tôt ne fait rien (on attend que la pastèque arrive)
		if math.min(nextOffset, prevOffset) > cycleLength * 0.45 then
			return
		end
		started = true
		local quality = self:GradeOffset(math.min(nextOffset, prevOffset))
		if prevOffset < nextOffset then
			prevAnswered = true
		else
			answered = true
		end
		strong = quality ~= "Miss"
		throwAt = now
		if quality == "Miss" then
			thudAt = now
		end
		self:Rep(quality, cradle)
	end
	self:OnSwipe(function(direction)
		if direction == "Up" then
			throw()
		end
	end)
	self:OnAction(throw)
	self:Guide(track, "SwipeUp")

	local cued = false
	self:OnStep(function()
		local now = os.clock()
		if now >= hitTime() then
			prevHit = hitTime()
			prevAnswered = answered
			newCycle(prevHit)
			cued = false
		end
		-- Retombée passée sans geste : ratée (sauf avant le tout premier geste, le temps de comprendre)
		if not prevAnswered and now > prevHit + window() then
			prevAnswered = true
			if started then
				strong = false
				thudAt = prevHit
				self:Rep("Miss", cradle)
			end
		end
		if not cued and now >= hitTime() - 0.05 then
			cued = true
			self:GuideCue()
		end
		-- Trajectoire : un arc des mains vers le haut et retour (plus haut après un bon lancer, petit rebond après un
		-- raté, très haut pour un lancer lent)
		local u = math.clamp((now - cycleStart) / cycleLength, 0, 1)
		if first then
			u = math.max(u, 0.5)
		end
		local height = (if strong then 0.66 else 0.28) * (if slow then 1.1 else 1)
		local y = HANDS_Y - height * 4 * u * (1 - u)
		melon.Position = UDim2.fromScale(0.5, math.max(y, 0.08))
		-- Elle tourne sur elle-même en l'air, s'écrase un instant en arrivant
		local sinceThud = now - thudAt
		local squash = if sinceThud < 0.18 then 1 + 0.35 * (1 - sinceThud / 0.18) else 1
		local catch = now - throwAt
		local stretch = if catch < 0.15 and strong then 1 + 0.25 * (1 - catch / 0.15) else 1
		melon.Size = UDim2.fromOffset(78 * squash / stretch, 78 * stretch / squash)
		melon.Rotation = if u > 0.02 and u < 0.98 then (now * 240) % 360 else 0
		turtle.Visible = slow
		turtle.Position = UDim2.fromScale(0.5, math.max(y, 0.08) - 0.12)
		-- Ombre et mains : de plus en plus nettes quand la pastèque approche ; le berceau brille au bon moment
		local near = 1 - math.clamp(math.abs(now - hitTime()) / (interval * 0.35), 0, 1)
		shadow.Size = UDim2.fromOffset(40 + 60 * (1 - (HANDS_Y - y)), 12)
		cradle.Size = UDim2.fromOffset(130 + 30 * near, 26 + 8 * near)
		cradle.BackgroundColor3 = if slow then SLOW_COLOR else GOLD
		cradle.BackgroundTransparency = 0.45 - 0.45 * near
		hands.Rotation = if catch < 0.2 then -15 * (1 - catch / 0.2) else 0
		arrow.TextTransparency = 0.85 - 0.6 * near
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		return { hitAt = hitTime(), answered = answered, cycleStart = cycleStart }
	end

	return self
end

return Swipe
