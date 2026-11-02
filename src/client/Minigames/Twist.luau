-- Mini-jeu « Twist » (aide : ouvrir le bocal de maman, refait en D106) : le truc de grand-mère.
-- 1. TAPER : toucher l'écran (n'importe où) pour taper le couvercle ; au bout de Twist.Taps tapes, PSSHT, l'air sort.
-- 2. TOURNER : un seul glissé (dans n'importe quel sens) dévisse le couvercle : POP, les cornichons jaillissent,
--    maman fait la fête, un nouveau bocal arrive. Un bocal ouvert = une répétition : vite = Perfect, plus lentement =
--    Good, trop lent = raté (le bocal suivant arrive).
-- Glisser avant d'avoir assez tapé : le couvercle ne bouge pas (« tape d'abord ! »).
-- Surprise : couvercle coriace (niveau Twist.TightLevel), il faut plus de tapes (Twist.TightTaps).
-- Clavier : Espace pour taper, flèches pour tourner. Manette : A pour taper, croix ou stick pour tourner.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Twist
local LID = Color3.fromRGB(240, 196, 64)
local LID_DARK = Color3.fromRGB(170, 120, 30)
local LID_READY = Color3.fromRGB(255, 236, 140)
local GLASS = Color3.fromRGB(150, 215, 140)
local DOT_OFF = Color3.fromRGB(60, 55, 80)
local DOT_ON = Color3.fromRGB(90, 220, 100)
local RIDGES = 7

local Twist = {}

function Twist.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(340, 390))
	local rng = self:Random()

	-- Le bocal (de face), ses cornichons et son couvercle
	local jar = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(160, 200),
		BackgroundColor3 = GLASS,
		BackgroundTransparency = 0.2,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 28)), Ui.stroke(Color3.new(1, 1, 1), 3, 0.3) })
	local jarHome = jar.Position
	for index = 1, 3 do
		local pickle = self:Emoji(jar, "🥒", 54, 2)
		pickle.Position = UDim2.fromScale(0.25 + (index - 1) * 0.25, 0.52 + (index % 2) * 0.18)
		pickle.Rotation = index * 50
	end
	local lid = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.new(1, 22, 0, 54),
		BackgroundColor3 = LID,
		ClipsDescendants = true,
		ZIndex = 3,
		Parent = jar,
	}, { Ui.corner(UDim.new(0, 12)), Ui.stroke(LID_DARK, 3, 0) })
	local lidHome = lid.Position
	local lidScale = Ui.create("UIScale", { Parent = lid })
	local ridges = {}
	for index = 1, RIDGES do
		ridges[index] = Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.04 + (index - 1) / (RIDGES - 1) * 0.92, 0.5),
			Size = UDim2.new(0, 7, 1, -12),
			BackgroundColor3 = LID_DARK,
			ZIndex = 4,
			Parent = lid,
		}, { Ui.corner(UDim.new(1, 0)) })
	end

	-- Tapes du bocal en cours (une pastille par tape à faire), au-dessus du couvercle
	local dotsFrame = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(240, 28),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Ui.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
		}),
	})
	local dots: { Frame } = {}

	-- Consigne du moment, au-dessus du bocal : TAPE ! puis TOURNE ! avec la flèche qui tourne
	local cue = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(200, 40),
		TextColor3 = LID_READY,
		ZIndex = 8,
		Parent = panel,
	})
	local spinArrow = self:Emoji(panel, "🔄", 64, 9)
	local mom = self:Emoji(panel, "👩", 50, 8)
	mom.Position = UDim2.new(1, -32, 0, 76)

	-- État
	local phase: "Tap" | "Twist" | "Pop" = "Tap"
	local taps = 0
	local need = SETTINGS.Taps
	local repStart = os.clock() + interval * 0.3
	local started = false
	local tapAt = -math.huge
	local readyAt = -math.huge -- l'air est sorti : le couvercle attend son glissé
	local stuckAt = -math.huge -- glissé trop tôt : le couvercle résiste
	local momCheerUntil = 0

	local function setDots(count: number)
		for _, dot in dots do
			dot:Destroy()
		end
		table.clear(dots)
		for index = 1, count do
			dots[index] = Ui.create("Frame", {
				Size = UDim2.fromOffset(28, 28),
				BackgroundColor3 = DOT_OFF,
				LayoutOrder = index,
				Parent = dotsFrame,
			}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.4) })
		end
	end

	-- Petit mot qui saute du couvercle (TOK !, PSSHT !)
	local function pop(text: string, color: Color3)
		local word = Ui.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, rng:NextInteger(-50, 50), 0, 120),
			Size = UDim2.fromOffset(120, 36),
			Text = text,
			TextColor3 = color,
			ZIndex = 20,
			Parent = panel,
		})
		TweenService:Create(word, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = word.Position - UDim2.fromOffset(0, 50),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		task.delay(0.5, function()
			word:Destroy()
		end)
	end

	local function newJar(at: number)
		phase = "Tap"
		taps = 0
		repStart = at
		need = SETTINGS.Taps
		if self.level >= SETTINGS.TightLevel and rng:NextNumber() < SETTINGS.TightChance then
			need = SETTINGS.TightTaps
			self:Announce("Minigame.Twist.Twist.Tight")
		end
		setDots(need)
		lid.Position = lidHome
		lid.Rotation = 0
	end
	newJar(repStart)

	-- Bocal ouvert : le couvercle saute, les cornichons jaillissent, puis un nouveau bocal arrive
	local function open(now: number)
		phase = "Pop"
		local took = (now - repStart) / interval
		local quality = if took <= SETTINGS.PerfectTime / self.timingScale
			then "Perfect"
			elseif took <= SETTINGS.MissTime then "Good"
			else "Miss"
		self:Rep(quality, lid)
		Kit.Haptic("Strong")
		Kit.Sound("SceneImpact", 1.35)
		self:Shake(6)
		momCheerUntil = now + 1.2
		TweenService:Create(lid, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = lidHome + UDim2.fromOffset(90, -210),
			Rotation = 420,
		}):Play()
		for index = 1, 7 do
			local pickle = self:Emoji(panel, "🥒", 40, 19)
			pickle.Position = jar.Position - UDim2.fromOffset(0, 200)
			local angle = math.rad(-160 + index * 20)
			TweenService:Create(pickle, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = pickle.Position + UDim2.fromOffset(math.cos(angle) * 150, math.sin(angle) * 120),
				Rotation = 360,
				TextTransparency = 1,
			}):Play()
			task.delay(0.65, function()
				pickle:Destroy()
			end)
		end
		task.delay(SETTINGS.PopTime, function()
			if self.destroyed then
				return
			end
			jar.Position = jarHome + UDim2.fromOffset(340, 0)
			newJar(os.clock() + 0.3)
			TweenService:Create(jar, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = jarHome,
			}):Play()
		end)
	end

	-- 1. Une tape sur le couvercle
	self:OnPress(function()
		local now = os.clock()
		if phase ~= "Tap" or now < repStart then
			return
		end
		started = true
		taps += 1
		tapAt = now
		Kit.Haptic("Light")
		if dots[taps] then
			dots[taps].BackgroundColor3 = DOT_ON
		end
		if taps < need then
			Kit.Sound("SceneTouch", 1 + taps * 0.12)
			pop(Texts.Get("Minigame.Twist.Tok"), Color3.new(1, 1, 1))
			return
		end
		-- Dernière tape : l'air sort, le couvercle est prêt à tourner
		phase = "Twist"
		readyAt = now
		Kit.Sound("SceneImpact", 1.6)
		pop(Texts.Get("Minigame.Twist.Pssht"), Color3.fromRGB(170, 230, 255))
	end)

	-- 2. Le glissé qui dévisse (n'importe quel sens)
	self:OnSwipe(function()
		local now = os.clock()
		if phase == "Twist" then
			open(now)
		elseif phase == "Tap" and now >= repStart then
			stuckAt = now
			self:Nope(lid)
			self:Announce("Minigame.Twist.Twist.TapFirst")
		end
	end)
	self:Guide(panel, "Tap")

	self:OnStep(function()
		local now = os.clock()
		-- Trop lent : le bocal est raté, le suivant arrive (une fois la partie commencée)
		if started and phase ~= "Pop" and (now - repStart) / interval > SETTINGS.MissTime + 0.4 then
			self:Rep("Miss", lid)
			newJar(now + 0.2)
		end
		-- Couvercle : il s'écrase un peu à chaque tape ; prêt, il brille et pulse ; il résiste à un glissé trop tôt
		local sinceTap = now - tapAt
		local squash = if sinceTap < 0.12 then 1 - sinceTap / 0.12 else 0
		local ready = phase == "Twist"
		lidScale.Scale = 1 - squash * 0.08 + (if ready then 0.04 * math.sin(now * 14) else 0)
		lid.BackgroundColor3 = if ready then LID_READY else LID
		local stuck = now - stuckAt
		lid.Rotation = if phase == "Pop" then lid.Rotation elseif stuck < 0.3 then math.sin(stuck * 60) * 4 else 0
		jar.Position = if phase == "Pop" or sinceTap > 0.12
			then jar.Position
			else jarHome + UDim2.fromOffset(0, squash * 5)
		-- Consigne et flèche qui tourne
		cue.Text = if phase == "Tap"
			then Texts.Get("Minigame.Twist.TapCue")
			elseif ready then Texts.Get("Minigame.Twist.TwistCue")
			else ""
		local lidCenter = lid.AbsolutePosition + lid.AbsoluteSize / 2 - panel.AbsolutePosition
		spinArrow.Visible = ready
		spinArrow.Position = UDim2.fromOffset(lidCenter.X, lidCenter.Y)
		spinArrow.Rotation = -((now - readyAt) * 360) % 360
		-- Maman : elle attend, elle grimace si le couvercle résiste, elle fait la fête au POP
		local cheering = now < momCheerUntil
		mom.Text = if cheering then "🥳" elseif stuck < 0.6 then "😬" elseif ready then "😮" else "👩"
		mom.Rotation = if cheering then math.sin(now * 20) * 12 else 0
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		return { phase = phase, taps = taps, need = need, waiting = os.clock() < repStart }
	end

	return self
end

return Twist
