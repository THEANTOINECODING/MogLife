-- Mini-jeu « Twist » (aide : ouvrir le bocal de maman, D81) : taper vite (n'importe où) pour dévisser le couvercle
-- d'un cran. Quand il tremble en orange, s'arrêter : il devient rouge et résiste ; taper pendant le rouge fait glisser
-- la main (raté). Cran fini vite = Perfect, plus lentement = Good, beaucoup trop lentement = raté.
-- Le moment d'alerte (orange) raccourcit avec les niveaux. Clavier : Espace ; manette : bouton A.
-- Satisfaisant (D82) : un clic à chaque appui, de plus en plus aigu ; Twist.NotchesPerJar crans par bocal (pastilles) ;
-- au dernier, POP : le couvercle s'envole, les cornichons jaillissent, maman applaudit, un nouveau bocal arrive.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Twist
local LID = Color3.fromRGB(230, 190, 60)
local WARN = Color3.fromRGB(255, 150, 40)
local RED = Color3.fromRGB(240, 60, 60)
local NOTCHES = 8 -- graduations dessinées sur le couvercle

local Twist = {}

function Twist.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(320, 380))
	local rng = self:Random()

	local jar = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -60),
		Size = UDim2.fromOffset(170, 190),
		BackgroundColor3 = Color3.fromRGB(150, 210, 140),
		BackgroundTransparency = 0.2,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 26)), Ui.stroke(Color3.new(1, 1, 1), 3, 0.3) })
	self:Emoji(jar, "🥒", 70, 2).Position = UDim2.fromScale(0.5, 0.55)
	local lid = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(1, 16, 0, 48),
		BackgroundColor3 = LID,
		ZIndex = 3,
		Parent = jar,
	}, { Ui.corner(UDim.new(0, 12)), Ui.stroke(Color3.fromRGB(120, 90, 20), 3, 0) })
	-- Graduations qui défilent quand le couvercle tourne
	local ridges = {}
	for index = 1, NOTCHES do
		ridges[index] = Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, 6, 1, -12),
			BackgroundColor3 = Color3.fromRGB(150, 110, 30),
			ZIndex = 4,
			Parent = lid,
		})
	end
	local hand = self:Emoji(panel, "✊", 60, 6)
	-- Jauge du cran en cours
	local meter = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 18),
		Size = UDim2.new(1, -60, 0, 22),
		BackgroundColor3 = Color3.fromRGB(30, 25, 45),
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.5) })
	local meterFill = Ui.create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(90, 220, 100),
		Parent = meter,
	}, { Ui.corner(UDim.new(1, 0)) })
	-- Crans du bocal : une pastille par cran, le bocal s'ouvre quand elles sont toutes pleines
	local pipsFrame = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 48),
		Size = UDim2.fromOffset(160, 22),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Ui.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
		}),
	})
	local pips = {}
	for index = 1, SETTINGS.NotchesPerJar do
		pips[index] = Ui.create("Frame", {
			Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = Color3.fromRGB(60, 55, 80),
			LayoutOrder = index,
			Parent = pipsFrame,
		}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.4) })
	end
	local mom = self:Emoji(panel, "👩", 56, 6)
	mom.Position = UDim2.new(0, 36, 1, -40)
	local notchesDone = 0
	local momCheerUntil = 0
	local jarHome = jar.Position

	-- Le bocal s'ouvre : le couvercle s'envole, les cornichons jaillissent, puis un nouveau bocal arrive
	local function pop()
		Kit.Haptic("Strong")
		Kit.Sound("SceneImpact", 1.35)
		self:Shake(6)
		momCheerUntil = os.clock() + 1.2
		local flying = lid:Clone()
		flying.Parent = panel
		flying.ZIndex = 20
		flying.AnchorPoint = Vector2.new(0.5, 0.5)
		flying.Position = UDim2.fromOffset(
			lid.AbsolutePosition.X - panel.AbsolutePosition.X + lid.AbsoluteSize.X / 2,
			lid.AbsolutePosition.Y - panel.AbsolutePosition.Y + lid.AbsoluteSize.Y / 2
		)
		flying.Size = UDim2.fromOffset(lid.AbsoluteSize.X, lid.AbsoluteSize.Y)
		lid.Visible = false
		TweenService:Create(flying, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = flying.Position + UDim2.fromOffset(70, -260),
			Rotation = 540,
			BackgroundTransparency = 1,
		}):Play()
		task.delay(0.75, function()
			flying:Destroy()
		end)
		for index = 1, 6 do
			local pickle = self:Emoji(panel, "🥒", 40, 19)
			pickle.Position = flying.Position
			local angle = math.rad(-150 + index * 20)
			TweenService:Create(pickle, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = flying.Position + UDim2.fromOffset(math.cos(angle) * 140, math.sin(angle) * 120),
				Rotation = 360,
				TextTransparency = 1,
			}):Play()
			task.delay(0.65, function()
				pickle:Destroy()
			end)
		end
		-- Nouveau bocal : il glisse depuis la droite
		task.delay(0.6, function()
			if self.destroyed then
				return
			end
			notchesDone = 0
			lid.Visible = true
			jar.Position = jarHome + UDim2.fromOffset(300, 0)
			TweenService:Create(jar, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = jarHome,
			}):Play()
		end)
	end

	local fill = 0
	local turned = 0 -- tours affichés (graduations)
	local notchStart = os.clock()
	local warnAt: number? = nil -- début de l'alerte orange (puis rouge)
	local slipUntil = 0
	local settledUntil = 0 -- le couvercle vient de tourner : petite pause
	local started = false
	local tapAt = -math.huge

	local function warnTime(): number
		return math.max(SETTINGS.WarnTime - SETTINGS.WarnShrinkPerLevel * self.level, 0.2)
	end

	-- Nouveau cran : il commence quand le serveur accepte la répétition suivante (le couvercle se repose avant)
	local function newNotch(at: number)
		local begin = math.max(at, self:NextRepAt())
		fill = 0
		notchStart = begin
		settledUntil = begin
		warnAt = nil
		if rng:NextNumber() < SETTINGS.RedChance then
			-- Le rouge arrive pendant le cran, après quelques appuis
			warnAt = begin + interval * (0.2 + rng:NextNumber() * 0.5)
		end
	end
	newNotch(os.clock() + interval * 0.3)

	local function phase(now: number): string
		if not warnAt or now < warnAt then
			return "Free"
		elseif now < warnAt + warnTime() then
			return "Warn"
		elseif now < warnAt + warnTime() + SETTINGS.RedTime then
			return "Red"
		end
		return "Free"
	end

	self:OnPress(function()
		local now = os.clock()
		if now < settledUntil or now < slipUntil then
			return
		end
		started = true
		tapAt = now
		if phase(now) == "Red" then
			-- La main glisse sur le couvercle bloqué : raté, le cran recommence
			slipUntil = now + 0.5
			self:Rep("Miss", lid)
			newNotch(now + 0.5)
			return
		end
		fill = math.min(fill + SETTINGS.TapFill, 1)
		turned += 1
		-- Clic du couvercle, de plus en plus aigu à mesure qu'il se desserre
		Kit.Sound("SceneTouch", 0.85 + fill * 0.6)
		if fill >= 1 then
			local took = (now - notchStart) / interval
			local quality = if took <= SETTINGS.PerfectTime / self.timingScale
				then "Perfect"
				elseif took <= SETTINGS.MissTime then "Good"
				else "Miss"
			self:Rep(quality, lid)
			notchesDone += 1
			if notchesDone >= SETTINGS.NotchesPerJar then
				pop()
				newNotch(now + SETTINGS.PopTime)
			else
				Kit.Sound("SceneImpact", 0.9 + notchesDone * 0.1)
				newNotch(now + 0.25)
			end
		end
	end)
	self:Guide(panel, "Tap")

	self:OnStep(function()
		local now = os.clock()
		local current = phase(now)
		if current == "Warn" then
			self:Announce("Minigame.Twist.Twist.Red")
		end
		-- Trop lent : le cran est raté (seulement une fois la partie commencée)
		if started and now > notchStart and (now - notchStart) / interval > SETTINGS.MissTime + 0.5 then
			self:Rep("Miss", lid)
			newNotch(now)
		end
		local shake = if current == "Warn" then 4 elseif current == "Red" then 2 else 0
		local resting = now < settledUntil
		lid.BackgroundColor3 = if current == "Warn" then WARN elseif current == "Red" then RED else LID
		lid.BackgroundTransparency = if resting then 0.4 else 0
		lid.Position = UDim2.new(0.5, math.random(-1, 1) * shake, 0, 12)
		for index, ridge in ridges do
			local x = ((index - 1) / NOTCHES + turned * 0.04) % 1
			ridge.Position = UDim2.fromScale(0.05 + x * 0.9, 0.5)
		end
		meterFill.Size = UDim2.fromScale(fill, 1)
		meterFill.BackgroundColor3 = if current == "Red" then RED else Color3.fromRGB(90, 220, 100)
		-- La main tourne le couvercle à chaque appui, glisse quand c'est raté
		local lidCenter = lid.AbsolutePosition + lid.AbsoluteSize / 2 - panel.AbsolutePosition
		local since = now - tapAt
		local twist = if since < 0.12 then -30 * (1 - since / 0.12) else 0
		hand.Position = UDim2.fromOffset(lidCenter.X, lidCenter.Y - 34)
		hand.Rotation = if now < slipUntil then 60 else twist
		hand.Text = if now < slipUntil then "🖐️" else "✊"
		hand.Visible = lid.Visible
		for index, pip in pips do
			pip.BackgroundColor3 = if index <= notchesDone
				then Color3.fromRGB(255, 210, 60)
				else Color3.fromRGB(60, 55, 80)
		end
		local cheering = now < momCheerUntil
		mom.Text = if cheering then "🥳" elseif current == "Red" then "😬" else "👩"
		mom.Rotation = if cheering then math.sin(now * 20) * 12 else 0
		-- Le bocal frémit à chaque appui
		local wiggle = if since < 0.08 then (1 - since / 0.08) * 3 else 0
		jar.Rotation = wiggle * (if turned % 2 == 0 then 1 else -1)
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		return {
			phase = phase(os.clock()),
			resting = os.clock() < settledUntil or os.clock() < slipUntil,
			fill = fill,
		}
	end

	return self
end

return Twist
