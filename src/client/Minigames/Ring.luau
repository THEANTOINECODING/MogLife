-- Mini-jeu « Ring » (exercice : pompes, D81) : un anneau se resserre vers le cercle doré ; toucher l'écran
-- (n'importe où) au moment où il le touche. Une répétition par cycle ; un cycle sans appui est raté.
-- Surprises : anneau double (deux appuis rapides, niveau Ring.DoubleLevel), anneau rouge (ne pas toucher,
-- niveau Ring.RedLevel ; le laisser passer = Perfect). Clavier : Espace ; manette : bouton A.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Ring
local TARGET_SIZE = 120
local START_SIZE = 300
local GOLD = Color3.fromRGB(255, 200, 40)
local RED = Color3.fromRGB(255, 70, 70)
local BLUE = Color3.fromRGB(120, 220, 255)
local QUALITY_RANK = { Miss = 0, Good = 1, Perfect = 2 }

local Ring = {}

function Ring.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(330, 330))
	local rng = self:Random()

	local target = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(TARGET_SIZE, TARGET_SIZE),
		BackgroundColor3 = GOLD,
		BackgroundTransparency = 0.1,
		ZIndex = 2,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(1, 1, 1), 4, 0) })
	local icon = self:Emoji(target, "💪", 64, 3)
	icon.Position = UDim2.fromScale(0.5, 0.5)

	local function newRing(): (Frame, UIStroke)
		local frame = Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(START_SIZE, START_SIZE),
			BackgroundTransparency = 1,
			ZIndex = 4,
			Parent = panel,
		}, { Ui.corner(UDim.new(1, 0)) })
		local stroke = Ui.stroke(BLUE, 7, 0)
		stroke.Parent = frame
		return frame, stroke
	end
	local rings = { { newRing() }, { newRing() } }

	-- Cycle : type ("Normal", "Double", "Red"), moments de contact, appuis reçus
	local cycleStart = os.clock() + interval * 0.4
	local kind = "Normal"
	local hits: { number } = {}
	local presses: { string } = {}
	local pressedRed = false
	local started = false
	local resolved = false

	local function newCycle(at: number)
		cycleStart = at
		kind = "Normal"
		if self.level >= SETTINGS.RedLevel and rng:NextNumber() < SETTINGS.RedChance then
			kind = "Red"
			self:Announce("Minigame.Twist.Ring.Red")
		elseif self.level >= SETTINGS.DoubleLevel and rng:NextNumber() < SETTINGS.DoubleChance then
			kind = "Double"
			self:Announce("Minigame.Twist.Ring.Double")
		end
		hits = { at + interval * SETTINGS.HitPhase }
		if kind == "Double" then
			table.insert(hits, hits[1] + interval * SETTINGS.DoubleGap)
		end
		presses = {}
		pressedRed = false
		resolved = false
	end
	newCycle(cycleStart)

	local function finish(quality: string)
		resolved = true
		self:Rep(quality, target)
	end

	self:OnPress(function()
		local now = os.clock()
		if resolved or now < cycleStart then
			return
		end
		started = true
		if kind == "Red" then
			pressedRed = true
			finish("Miss")
			return
		end
		local index = #presses + 1
		local hit = hits[index]
		if not hit then
			return
		end
		local quality = self:GradeOffset(math.abs(now - hit))
		presses[index] = quality
		-- Anneau double : la note est la moins bonne des deux ; un raté termine tout de suite
		if quality == "Miss" or index == #hits then
			local worst = quality
			for _, previous in presses do
				if QUALITY_RANK[previous] < QUALITY_RANK[worst] then
					worst = previous
				end
			end
			finish(worst)
		else
			self:Burst(quality, target)
		end
	end)
	self:Guide(panel, "Tap")

	local cued = false
	self:OnStep(function()
		local now = os.clock()
		if now >= cycleStart + interval then
			if not resolved then
				if kind == "Red" and not pressedRed then
					-- Anneau rouge laissé passer : bien joué (seulement en jouant : attendre sans rien faire ne paie pas)
					if started then
						finish("Perfect")
					end
				elseif started then
					finish("Miss")
				end
			end
			newCycle(cycleStart + interval)
			cued = false
		end
		for index, pair in rings do
			local frame, stroke = pair[1], pair[2]
			local hit = hits[index]
			frame.Visible = hit ~= nil and not resolved and (presses[index] == nil)
			if hit then
				-- L'anneau part de START_SIZE et touche la cible à `hit`, puis continue de rétrécir
				local lead = interval * SETTINGS.HitPhase
				local progress = (now - (hit - lead)) / lead
				local size = START_SIZE + (TARGET_SIZE - START_SIZE) * progress
				frame.Size = UDim2.fromOffset(math.max(size, 40), math.max(size, 40))
				stroke.Color = if kind == "Red" then RED else BLUE
				stroke.Transparency = if progress < 0 then 1 else 0
			end
		end
		target.BackgroundColor3 = if kind == "Red" then RED else GOLD
		icon.Text = if kind == "Red" then "✋" else "💪"
		if not cued and now >= hits[1] then
			cued = true
			self:GuideCue()
		end
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		return { hits = hits, presses = #presses, kind = kind, resolved = resolved, cycleStart = cycleStart }
	end

	return self
end

return Ring
