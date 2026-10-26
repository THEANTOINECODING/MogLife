-- Mini-jeu « Alternate » (exercice : tractions, D81) : une main après l'autre, sur le temps. Toucher la moitié
-- gauche ou droite de l'écran (un pouce de chaque côté) quand le cercle de la main allumée se referme.
-- Mauvaise main ou temps sans appui (une fois la série commencée) = raté.
-- Surprises : « les deux mains » (toucher les deux côtés ensemble, niveau Alternate.BothLevel), rythme irrégulier
-- (niveau Alternate.SwingLevel, jamais plus rapide que l'intervalle).
-- Clavier : A / D, flèches (les deux ensemble, ou Espace, pour « les deux mains ») ; manette : gâchettes, croix, A.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Alternate
local GOLD = Color3.fromRGB(255, 210, 60)
local QUALITY_RANK = { Miss = 0, Good = 1, Perfect = 2 }

local Alternate = {}

function Alternate.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(380, 320))
	local rng = self:Random()

	-- Barre de traction en haut
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 22),
		Size = UDim2.new(1, -40, 0, 12),
		BackgroundColor3 = Color3.fromRGB(190, 190, 200),
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)) })
	local face = self:Emoji(panel, "😤", 70, 3)
	face.Position = UDim2.new(0.5, 0, 0, 120)

	local function hand(x: number, emoji: string)
		local holder = Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(x, 0, 0, 200),
			Size = UDim2.fromOffset(110, 110),
			BackgroundColor3 = Color3.fromRGB(50, 45, 70),
			Parent = panel,
		}, { Ui.corner(UDim.new(1, 0)) })
		self:Emoji(holder, emoji, 64, 3).Position = UDim2.fromScale(0.5, 0.5)
		-- Cercle qui se referme jusqu'au temps
		local closing = Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.8, 1.8),
			BackgroundTransparency = 1,
			ZIndex = 4,
			Parent = holder,
		}, { Ui.corner(UDim.new(1, 0)) })
		local stroke = Ui.stroke(GOLD, 6, 0)
		stroke.Parent = closing
		return holder, closing, stroke
	end
	local leftHand, leftRing, leftStroke = hand(0.25, "🤛")
	local rightHand, rightRing, rightStroke = hand(0.75, "🤜")
	local hands = {
		Left = { holder = leftHand, ring = leftRing, stroke = leftStroke },
		Right = { holder = rightHand, ring = rightRing, stroke = rightStroke },
	}

	-- Temps en cours : moment, main attendue ("Left", "Right" ou "Both"), appuis reçus
	local beatAt = os.clock() + interval * 1.2
	local expected = "Left"
	local nextSingle = "Right"
	self.guideSide = "Left"
	local pressed: { [string]: number } = {}
	local resolved = false
	local started = false

	local function newBeat()
		local gap = interval
		if self.level >= SETTINGS.SwingLevel then
			gap = interval * (1 + rng:NextNumber() * SETTINGS.SwingMax)
			self:Announce("Minigame.Twist.Alternate.Swing")
		end
		beatAt += gap
		if self.level >= SETTINGS.BothLevel and rng:NextNumber() < SETTINGS.BothChance then
			expected = "Both"
			self:Announce("Minigame.Twist.Alternate.Both")
		else
			expected = nextSingle
			nextSingle = if nextSingle == "Left" then "Right" else "Left"
		end
		pressed = {}
		resolved = false
		self.guideSide = if expected == "Both" then nil else expected
	end

	local function finish(quality: string, at: GuiObject)
		resolved = true
		self:Rep(quality, at)
		face.Text = if quality == "Miss" then "😵" else "😤"
	end

	local function press(side: string)
		local now = os.clock()
		-- Un appui compte pour le temps en cours ; plus d'un demi-intervalle avant lui : ignoré
		if resolved or now < beatAt - interval * 0.5 then
			return
		end
		started = true
		local offset = math.abs(now - beatAt)
		if expected ~= "Both" then
			finish(if side == expected then self:GradeOffset(offset) else "Miss", hands[side].holder)
			return
		end
		pressed[side] = now
		local other = if side == "Left" then "Right" else "Left"
		if pressed[other] then
			if math.abs(pressed[other] - now) > SETTINGS.BothWindow then
				finish("Miss", hands[side].holder)
			else
				local worst = self:GradeOffset(math.abs(pressed[other] - beatAt))
				local this = self:GradeOffset(offset)
				if QUALITY_RANK[this] < QUALITY_RANK[worst] then
					worst = this
				end
				finish(worst, face)
			end
		end
	end
	self:OnSide(press)
	-- Espace / A : « les deux mains » au clavier et à la manette
	self:OnAction(function()
		if expected == "Both" and not resolved then
			press("Left")
			press("Right")
		end
	end)
	self:Guide(panel, "Sides")

	local cued = false
	self:OnStep(function()
		local now = os.clock()
		if now > beatAt + interval * 0.5 then
			if not resolved and started then
				finish("Miss", face)
			end
			newBeat()
			cued = false
		end
		local progress = 1 - math.clamp((beatAt - now) / interval, 0, 1)
		for side, entry in hands do
			local active = expected == side or expected == "Both"
			entry.ring.Visible = active and not resolved and pressed[side] == nil
			local size = 1.8 - 0.8 * progress
			entry.ring.Size = UDim2.fromScale(size, size)
			entry.holder.BackgroundColor3 = if active then Color3.fromRGB(110, 80, 160) else Color3.fromRGB(50, 45, 70)
			entry.stroke.Color = if expected == "Both" then Color3.fromRGB(255, 120, 60) else GOLD
		end
		if progress >= 1 and not cued then
			cued = true
			self:GuideCue()
		end
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		return { beatAt = beatAt, expected = expected, resolved = resolved }
	end

	return self
end

return Alternate
