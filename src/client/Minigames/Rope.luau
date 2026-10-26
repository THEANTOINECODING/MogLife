-- Mini-jeu « Rope » (exercice : corde à sauter, D81) : la corde tourne ; toucher l'écran (n'importe où) pour sauter
-- quand elle passe sous les pieds. Un saut par tour ; si la corde passe sans saut (une fois la série commencée),
-- on trébuche (raté). Un tour ne va jamais plus vite que l'intervalle.
-- Surprises : tours rapides (rouges, niveau Rope.FastLevel), fausses accélérations : la corde fonce puis ralentit
-- juste avant les pieds (niveau Rope.FakeLevel). Clavier : Espace ; manette : bouton A.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Rope
local NORMAL = Color3.fromRGB(255, 90, 160)
local FAST = Color3.fromRGB(255, 60, 60)

local Rope = {}

-- Avancement du tour (0 à 1, 0,5 = sous les pieds) selon le temps écoulé u (0 à 1).
-- Fausse accélération : très rapide au début, puis lente juste avant les pieds.
local function turnProgress(u: number, fake: boolean): number
	if not fake then
		return u
	end
	if u < 0.3 then
		return u / 0.3 * 0.42
	elseif u < 0.5 then
		return 0.42 + (u - 0.3) / 0.2 * 0.08
	end
	return u
end

function Rope.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(320, 360))
	local rng = self:Random()

	local circle = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromOffset(240, 240),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)) })
	local circleStroke = Ui.stroke(Color3.fromRGB(90, 90, 120), 3, 0.3)
	circleStroke.Parent = circle
	-- Zone de saut sous les pieds
	local floor = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(80, 26),
		BackgroundColor3 = Color3.fromRGB(90, 230, 90),
		BackgroundTransparency = 0.25,
		ZIndex = 2,
		Parent = circle,
	}, { Ui.corner(UDim.new(1, 0)) })
	local jumper = self:Emoji(circle, "🏃", 84, 3)
	local handle = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = NORMAL,
		ZIndex = 4,
		Parent = circle,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(1, 1, 1), 3, 0) })

	-- Tour en cours : début, durée, moment où la corde passe sous les pieds
	local turnStart = os.clock() + interval * 0.3
	local period = interval * SETTINGS.PeriodMax
	local fast, fake = false, false
	local bottomAt = 0
	local previousBottom = -math.huge
	local jumped = false
	local previousJumped = true
	local started = false
	local jumpAt = -math.huge
	local tripAt = -math.huge

	local function newTurn(at: number)
		previousBottom = bottomAt
		previousJumped = jumped
		turnStart = at
		fast = self.level >= SETTINGS.FastLevel and rng:NextNumber() < SETTINGS.FastChance
		fake = not fast and self.level >= SETTINGS.FakeLevel and rng:NextNumber() < SETTINGS.FakeChance
		period = interval
			* (
				if fast
					then SETTINGS.PeriodMin
					else SETTINGS.PeriodMin + rng:NextNumber() * (SETTINGS.PeriodMax - SETTINGS.PeriodMin)
			)
		-- turnProgress atteint 0,5 (sous les pieds) à mi-tour, fausse accélération ou non
		bottomAt = turnStart + period * 0.5
		jumped = false
		if fast then
			self:Announce("Minigame.Twist.Rope.Fast")
		elseif fake then
			self:Announce("Minigame.Twist.Rope.Fake")
		end
	end
	newTurn(turnStart)

	self:OnPress(function()
		local now = os.clock()
		if now - jumpAt < 0.25 then
			return
		end
		-- Le saut est pour le passage le plus proche (celui qui vient, ou celui qui vient de passer)
		local forPrevious = not previousJumped and math.abs(now - previousBottom) < math.abs(now - bottomAt)
		if forPrevious then
			previousJumped = true
		elseif jumped then
			return
		else
			jumped = true
		end
		started = true
		jumpAt = now
		local offset = math.abs(now - (if forPrevious then previousBottom else bottomAt))
		local quality = self:GradeError(offset, SETTINGS.PerfectTime, SETTINGS.GoodTime)
		if quality == "Miss" then
			tripAt = now
		end
		self:Rep(quality, floor)
	end)
	self:Guide(panel, "Tap")

	local cued = false
	local missChecked = true
	self:OnStep(function()
		local now = os.clock()
		if now >= turnStart + period then
			newTurn(turnStart + period)
			cued = false
			missChecked = false
		end
		-- La corde est passée sans saut (fenêtre Good dépassée) : on trébuche
		if not missChecked and now > previousBottom + SETTINGS.GoodTime * self.timingScale then
			missChecked = true
			if not previousJumped and started then
				previousJumped = true
				tripAt = now
				self:Rep("Miss", floor)
			end
		end
		if not cued and now >= bottomAt then
			cued = true
			self:GuideCue()
		end
		local u = math.clamp((now - turnStart) / period, 0, 1)
		local angle = turnProgress(u, fake) * 2 * math.pi
		handle.Position = UDim2.fromScale(0.5 + 0.5 * math.sin(angle), 0.5 - 0.5 * math.cos(angle))
		handle.BackgroundColor3 = if fast then FAST else NORMAL
		circleStroke.Color = if fast then FAST else Color3.fromRGB(90, 90, 120)
		-- Le sauteur : en l'air après un saut, penché après un raté
		local air = now - jumpAt
		local height = if air < 0.3 then math.sin(air / 0.3 * math.pi) * 0.2 else 0
		jumper.Position = UDim2.fromScale(0.5, 0.62 - height)
		jumper.Rotation = if now - tripAt < 0.4 then 30 else 0
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		return { bottomAt = bottomAt, jumped = jumped }
	end

	return self
end

return Rope
