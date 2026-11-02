-- Mini-jeu « Pressure » (aide : gonfler le pneu du coursier stressé, refait en D106) : une grosse pompe à pied.
-- La pédale remonte toute seule, au rythme de la pulsation ; un cercle se resserre sur la botte et se ferme quand la
-- pédale est tout en haut. Toucher l'écran (n'importe où) à ce moment : la botte écrase la pédale, PFOUH, le pneu
-- gonfle d'un cran. Un coup = une répétition, noté sur l'écart avec le haut (fenêtres de Balance.TimingWindows).
-- Trop tôt (pédale à mi-course) ou pédale laissée en haut : coup raté, pas d'air. Pneu plein (Pressure.Steps crans) :
-- le coursier repart content, un pneu à plat arrive.
-- Surprises : pneu qui fuit (niveau Pressure.LeakLevel, un raté fait perdre un cran), gros pneu de cargo (niveau
-- Pressure.BigLevel, Pressure.BigSteps crans). Clavier : Espace ; manette : A.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Pressure
local RUBBER = Color3.fromRGB(40, 40, 46)
local PUMP = Color3.fromRGB(220, 60, 60)
local STEP_OFF = Color3.fromRGB(60, 55, 80)
local STEP_ON = Color3.fromRGB(90, 220, 100)
local RING = Color3.fromRGB(255, 215, 60)
local PEDAL_LOW = 52 -- pixels au-dessus du bas du panneau : pédale enfoncée
local PEDAL_HIGH = 150 -- pédale tout en haut

local Pressure = {}

function Pressure.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(340, 420))
	local rng = self:Random()

	-- Le pneu du vélo (en haut à droite) et le coursier
	local tire = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.68, 0, 0, 200),
		Size = UDim2.fromOffset(150, 90),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(RUBBER, 20, 0) })
	local tireHome = tire.Position
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.42, 0.42),
		BackgroundColor3 = Color3.fromRGB(200, 200, 210),
		Parent = tire,
	}, { Ui.corner(UDim.new(1, 0)) })
	local courier = self:Emoji(panel, "😰", 54, 6)
	courier.Position = UDim2.new(0.68, 0, 0, 44)
	-- Crans de pression, sous le pneu
	local stepsFrame = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.68, 0, 0, 212),
		Size = UDim2.fromOffset(170, 20),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Ui.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
		}),
	})
	local steps: { Frame } = {}

	-- La pompe (en bas à gauche) : corps rouge, tuyau vers le pneu, pédale qui monte et botte posée dessus
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.3, 0, 1, -PEDAL_LOW + 4),
		Size = UDim2.fromOffset(44, 120),
		BackgroundColor3 = PUMP,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 10)), Ui.stroke(Color3.fromRGB(120, 20, 20), 3, 0) })
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.3, 22, 1, -PEDAL_LOW - 90),
		Size = UDim2.new(0.38, -22, 0, 8),
		BackgroundColor3 = RUBBER,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)) })
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.68, 0, 0, 200),
		Size = UDim2.new(0, 8, 1, -PEDAL_LOW - 290),
		BackgroundColor3 = RUBBER,
		Parent = panel,
	})
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -PEDAL_LOW + 4),
		Size = UDim2.new(1, -30, 0, 10),
		BackgroundColor3 = Color3.fromRGB(90, 80, 70),
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)) })
	local pedal = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(120, 16),
		BackgroundColor3 = Color3.fromRGB(70, 70, 80),
		ZIndex = 4,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 6)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.5) })
	local boot = self:Emoji(panel, "🦶", 64, 5)
	local ring = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)) })
	local ringStroke = Ui.stroke(RING, 5, 0)
	ringStroke.Parent = ring

	-- État
	local firstBeat = self.startTime + interval * SETTINGS.FirstBeat
	local beat = 0 -- numéro du temps visé (sa pédale tout en haut à firstBeat + beat × interval)
	local answered = false -- ce temps a déjà eu son coup
	local stompAt = -math.huge
	local filled = 0
	local need = SETTINGS.Steps
	local riding = false -- pneu plein : le vélo s'en va, le suivant arrive
	local happyUntil = 0
	local started = false

	local function beatAt(index: number): number
		return firstBeat + index * interval
	end

	local function setSteps(count: number)
		for _, step in steps do
			step:Destroy()
		end
		table.clear(steps)
		local width = math.floor((170 - (count - 1) * 6) / count)
		for index = 1, count do
			steps[index] = Ui.create("Frame", {
				Size = UDim2.fromOffset(width, 20),
				BackgroundColor3 = STEP_OFF,
				LayoutOrder = index,
				Parent = stepsFrame,
			}, { Ui.corner(UDim.new(0, 6)) })
		end
	end

	-- Le pneu s'arrondit à chaque cran (à plat : écrasé ; plein : bien rond)
	local function showTire()
		local full = filled / need
		local width = if need > SETTINGS.Steps then 170 else 150
		tire.Size = UDim2.fromOffset(width, math.floor(width * (0.55 + 0.45 * full)))
		for index, step in steps do
			step.BackgroundColor3 = if index <= filled then STEP_ON else STEP_OFF
		end
	end

	local function newTire()
		filled = 0
		need = SETTINGS.Steps
		if self.level >= SETTINGS.BigLevel and rng:NextNumber() < SETTINGS.BigChance then
			need = SETTINGS.BigSteps
			self:Announce("Minigame.Twist.Pressure.Big")
		end
		setSteps(need)
		showTire()
	end
	newTire()

	-- Mot qui sort du pneu ou de la pompe (PFOUH !, pfff…)
	local function puff(text: string, color: Color3, at: UDim2)
		local word = Ui.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = at,
			Size = UDim2.fromOffset(120, 34),
			Text = text,
			TextColor3 = color,
			ZIndex = 20,
			Parent = panel,
		})
		TweenService:Create(word, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = at - UDim2.fromOffset(0, 46),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		task.delay(0.5, function()
			word:Destroy()
		end)
	end

	-- Pneu plein : le coursier fait la fête, le vélo file, un pneu à plat arrive
	local function ride()
		riding = true
		happyUntil = os.clock() + SETTINGS.RideTime + 0.4
		Kit.Sound("SceneImpact", 1.3)
		Kit.Haptic("Strong")
		TweenService
			:Create(tire, TweenInfo.new(SETTINGS.RideTime * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = tireHome + UDim2.fromOffset(260, 0),
				Rotation = 360,
			})
			:Play()
		task.delay(SETTINGS.RideTime * 0.6, function()
			if self.destroyed then
				return
			end
			tire.Rotation = 0
			tire.Position = tireHome - UDim2.fromOffset(260, 0)
			newTire()
			TweenService:Create(tire, TweenInfo.new(SETTINGS.RideTime * 0.4, Enum.EasingStyle.Back), {
				Position = tireHome,
			}):Play()
			riding = false
		end)
	end

	-- Un coup de botte sur la pédale (ou un temps laissé passer : raté sans coup)
	local function grade(quality: string, stomped: boolean)
		answered = true
		if quality == "Miss" then
			self:Rep("Miss", if stomped then boot else tire)
			puff(Texts.Get("Minigame.Twist.Pressure.Weak"), Color3.fromRGB(200, 200, 215), UDim2.new(0.3, 0, 1, -230))
			if self.level >= SETTINGS.LeakLevel and filled > 0 and not riding then
				filled -= 1
				self:Announce("Minigame.Twist.Pressure.Leak")
				showTire()
			end
			return
		end
		self:Rep(quality, tire)
		Kit.Sound("SceneTouch", 0.8 + filled * 0.1)
		puff(Texts.Get("Minigame.Twist.Pressure.Puff"), Color3.fromRGB(170, 230, 255), UDim2.new(0.68, 0, 0, 150))
		if not riding then
			filled = math.min(filled + 1, need)
			showTire()
			if filled >= need then
				ride()
			end
		end
	end

	self:OnPress(function()
		local now = os.clock()
		if answered or now < firstBeat - interval * 0.5 then
			return
		end
		started = true
		stompAt = now
		Kit.Haptic("Light")
		grade(self:GradeOffset(math.abs(now - beatAt(beat))), true)
	end)
	self:Guide(panel, "Tap")

	local wasTop = false
	self:OnStep(function()
		local now = os.clock()
		-- Temps suivant : après la fenêtre « Good » du temps visé ; laissé sans coup, il est raté
		local windowEnd = beatAt(beat) + Balance.TimingWindows.Good * self.timingScale
		if now > windowEnd then
			if not answered and started then
				grade("Miss", false)
			end
			beat += 1
			answered = false
		end
		-- Pédale : elle monte pendant la pulsation jusqu'au temps visé, retombe d'un coup sous la botte
		local target = beatAt(beat)
		local since = now - stompAt
		local rise = math.clamp(1 - (target - now) / interval, 0, 1)
		if answered and since < interval then
			rise = math.max(0, 1 - since / 0.08) * rise
		end
		local height = PEDAL_LOW + (PEDAL_HIGH - PEDAL_LOW) * rise
		pedal.Position = UDim2.new(0.3, 0, 1, -height)
		boot.Position = UDim2.new(0.3, 4, 1, -height - 34)
		boot.Rotation = if since < 0.12 then -12 else 6
		-- Cercle : il se resserre sur la botte et se ferme au temps visé
		local closing = math.clamp((target - now) / (interval * 0.8), 0, 1)
		local size = 78 + closing * 110
		ring.Size = UDim2.fromOffset(size, size)
		ring.Position = boot.Position
		ringStroke.Transparency = if answered then 1 else 0.6 * closing
		local top = not answered and math.abs(now - target) <= Balance.TimingWindows.Perfect * self.timingScale
		ringStroke.Color = if top then Color3.fromRGB(90, 230, 100) else RING
		if top and not wasTop then
			self:GuideCue()
		end
		wasTop = top
		-- Pneu qui tremble un peu sous la pression, coursier qui se détend
		if not riding then
			tire.Rotation = math.sin(now * 30) * filled * 0.4
		end
		courier.Text = if now < happyUntil then "😄" elseif filled >= need - 1 then "🙂" else "😰"
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		return { beatAt = beatAt(beat), answered = answered, filled = filled, need = need }
	end

	return self
end

return Pressure
