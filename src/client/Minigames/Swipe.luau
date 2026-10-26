-- Mini-jeu « Swipe » (exercice : curl de pastèque, D81) : un repère monte le long de la piste ; glisser le pouce
-- vers le haut (n'importe où sur l'écran) au moment où il touche la ligne dorée. La pastèque part en l'air.
-- Une répétition par cycle ; un cycle sans geste (une fois la série commencée) est raté.
-- Surprise (niveau Swipe.SlowLevel) : répétitions lentes (tortue), le repère monte plus doucement.
-- Clavier : flèche haut / Z / W / Espace ; manette : coup de stick vers le haut ou bouton A.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Swipe
local LINE_Y = 0.18 -- hauteur de la ligne dorée (0 = haut de la piste)
local REST_Y = 0.86 -- pastèque au repos
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
		Size = UDim2.new(0, 120, 1, -28),
		BackgroundColor3 = Color3.fromRGB(25, 20, 40),
		BackgroundTransparency = 0.2,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 60)), Ui.stroke(Color3.fromRGB(255, 255, 255), 2, 0.7) })
	local line = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, LINE_Y),
		Size = UDim2.new(1, 40, 0, 8),
		BackgroundColor3 = GOLD,
		ZIndex = 2,
		Parent = track,
	}, { Ui.corner(UDim.new(1, 0)) })
	-- Le repère : un anneau qui monte et touche la ligne au bon moment
	local marker = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(84, 84),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = track,
	}, { Ui.corner(UDim.new(1, 0)) })
	local markerStroke = Ui.stroke(Color3.new(1, 1, 1), 5, 0)
	markerStroke.Parent = marker
	local turtle = self:Emoji(marker, "🐢", 34, 4)
	turtle.Position = UDim2.fromScale(0.5, 0.5)
	local melon = self:Emoji(track, "🍉", 78, 5)
	melon.Position = UDim2.fromScale(0.5, REST_Y)
	local arrow = self:Emoji(track, "⬆️", 40, 2)
	arrow.Position = UDim2.fromScale(0.5, 0.55)
	arrow.TextTransparency = 0.6

	-- Cycle en cours : début, durée, moment où le repère touche la ligne
	local cycleStart = os.clock() + interval * 0.4 -- petit temps pour lire avant le premier repère
	local cycleLength = interval
	local slow = false
	local answered = false
	local started = false
	local liftAt = -math.huge -- dernier lancer de pastèque (animation)
	local liftQuality = "Good"

	local function hitTime(): number
		return cycleStart + cycleLength * SETTINGS.HitPhase
	end

	local function newCycle(at: number)
		cycleStart = at
		slow = self.level >= SETTINGS.SlowLevel and rng:NextNumber() < SETTINGS.SlowChance
		cycleLength = interval * (if slow then SETTINGS.SlowFactor else 1)
		answered = false
		if slow then
			self:Announce("Minigame.Twist.Swipe.Slow")
		end
	end

	local function lift()
		local now = os.clock()
		if answered or now < cycleStart then
			return
		end
		started = true
		answered = true
		local quality = self:GradeOffset(math.abs(now - hitTime()))
		liftAt = now
		liftQuality = quality
		self:Rep(quality, line)
	end
	self:OnSwipe(function(direction)
		if direction == "Up" then
			lift()
		end
	end)
	self:OnAction(lift)
	self:Guide(track, "SwipeUp")

	local cued = false
	self:OnStep(function()
		local now = os.clock()
		if now >= cycleStart + cycleLength then
			-- Cycle fini sans geste : raté (sauf avant le tout premier geste, le temps de comprendre)
			if not answered and started then
				self:Rep("Miss", line)
			end
			newCycle(cycleStart + cycleLength)
			cued = false
		end
		local phase = math.clamp((now - cycleStart) / cycleLength, 0, 1)
		local hit = SETTINGS.HitPhase
		-- Le repère monte du bas jusqu'à la ligne (à HitPhase), puis s'efface au-dessus
		local y = if phase <= hit
			then REST_Y + (LINE_Y - REST_Y) * (phase / hit)
			else LINE_Y - 0.1 * ((phase - hit) / (1 - hit))
		marker.Position = UDim2.fromScale(0.5, y)
		markerStroke.Color = if slow then SLOW_COLOR else Color3.new(1, 1, 1)
		markerStroke.Transparency = if answered then 0.75 elseif phase > hit then (phase - hit) / (1 - hit) else 0
		turtle.Visible = slow and not answered
		if not cued and now >= hitTime() then
			cued = true
			self:GuideCue()
		end
		-- Près de la ligne, elle brille : c'est le moment
		local closeness = 1 - math.clamp(math.abs(now - hitTime()) / (interval * 0.3), 0, 1)
		line.Size = UDim2.new(1, 40 + 24 * closeness, 0, 8 + 6 * closeness)

		-- Pastèque : monte d'un coup à la ligne, puis redescend
		local since = now - liftAt
		local up = if since < 0.12 then since / 0.12 elseif since < 0.45 then 1 - (since - 0.12) / 0.33 else 0
		local top = if liftQuality == "Miss" then 0.45 else LINE_Y
		melon.Position = UDim2.fromScale(0.5, REST_Y + (top - REST_Y) * math.clamp(up, 0, 1))
		melon.Rotation = if since < 0.45 then 25 * math.sin(since * 20) else 0
		local squash = if since < 0.2 and liftQuality ~= "Miss" then 1.2 else 1
		melon.Size = UDim2.fromOffset(78 * squash, 78 / squash)
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		return { hitAt = hitTime(), answered = answered, cycleStart = cycleStart }
	end

	return self
end

return Swipe
