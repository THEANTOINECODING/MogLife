-- Mini-jeu « Tug » (duel entre joueurs, Tug of Mog, D67) : la corde défile vers tes mains. Les nœuds rouges se
-- saisissent d'un coup (appuyer quand le nœud est dans tes mains), les nœuds dorés se tirent : appuyer quand le début
-- arrive, maintenir, relâcher quand la fin arrive. Toucher l'écran / clic sur le panneau, Espace, bouton A.
-- Les deux joueurs reçoivent la même graine (options.seed) : même suite de nœuds, mêmes fenêtres.
-- La corde du duel (qui gagne) est affichée par DuelController ; ici, seulement le geste.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Duels = require(ReplicatedStorage.Shared.Config.Duels)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local GRIP_X = 0.8 -- position des mains sur la corde (fraction de la largeur)
local TAP_COLOR = Color3.fromRGB(235, 85, 60)
local HOLD_COLOR = Color3.fromRGB(255, 200, 60)
local QUALITY_RANK = { Perfect = 3, Good = 2, Miss = 1 }

type Knot = {
	hold: boolean,
	arrivesAt: number,
	tailAt: number,
	frame: Frame,
	pressed: boolean,
	headQuality: string?,
}

local Tug = {}

local function worst(a: string, b: string): string
	return if QUALITY_RANK[a] <= QUALITY_RANK[b] then a else b
end

function Tug.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(420, 250), true)

	-- Même graine pour les deux joueurs ; la manche (déduite de l'échelle des fenêtres) fixe la part de nœuds longs
	local seed = (options and options.seed) or math.floor(os.clock() * 1000)
	local rng = Random.new(seed)
	local round = table.find(Duels.TimingScaleByRound, self.timingScale) or 1
	local holdChance = Duels.HoldChanceByRound[round] or Duels.HoldChanceByRound[1]
	local fallTime = interval * Duels.Lead
	local holdTime = interval * Duels.HoldLength

	local lane = Ui.create("Frame", {
		Name = "Lane",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 30),
		Size = UDim2.new(1, -24, 0, 110),
		BackgroundColor3 = Color3.fromRGB(30, 25, 45),
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 12)) })
	-- La corde, d'un bout à l'autre
	local rope = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundColor3 = Color3.fromRGB(176, 128, 74),
		BorderSizePixel = 0,
		Parent = lane,
	})
	-- Les mains : la zone où l'on saisit
	local grip = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(GRIP_X, 0.5),
		Size = UDim2.new(0, 56, 1, -12),
		BackgroundColor3 = Color3.fromRGB(255, 220, 120),
		BackgroundTransparency = 0.8,
		ZIndex = 3,
		Parent = lane,
	}, { Ui.corner(UDim.new(0, 10)), Ui.stroke(Color3.fromRGB(255, 220, 120), 3, 0) })
	local fists = self:Emoji(panel, "✊✊", 56, 4)
	fists.AnchorPoint = Vector2.new(0.5, 0)
	fists.Position = UDim2.new(GRIP_X, -GRIP_X * 24 + 12, 0, 144)
	fists.Size = UDim2.fromOffset(96, 52)

	local knots: { Knot } = {}
	local nextArrival = fallTime
	local holding: Knot? = nil
	local lastSent = -math.huge
	local pending = 0 -- répétitions en attente d'envoi (espacées de MinRepGap)

	-- Envoi espacé : une fin de nœud long suivie de près par le nœud suivant ne doit pas être refusée par la cadence
	local function send(quality: string)
		local now = os.clock()
		local at = math.max(now, lastSent + Duels.MinRepGap + pending * Duels.MinRepGap)
		if at <= now then
			lastSent = now
			self:Rep(quality)
			return
		end
		pending += 1
		task.delay(at - now, function()
			pending -= 1
			lastSent = os.clock()
			self:Rep(quality)
		end)
	end

	local function remove(knot: Knot)
		local index = table.find(knots, knot)
		if index then
			table.remove(knots, index)
		end
		knot.frame:Destroy()
		if holding == knot then
			holding = nil
		end
	end

	local function flash(color: Color3)
		grip.BackgroundColor3 = color
		grip.BackgroundTransparency = 0.35
		task.delay(0.15, function()
			if grip.Parent then
				grip.BackgroundColor3 = Color3.fromRGB(255, 220, 120)
				grip.BackgroundTransparency = 0.8
			end
		end)
	end

	local function spawnKnot()
		local hold = rng:NextNumber() < holdChance
		local frame
		if hold then
			-- Nœud long : sa longueur à l'écran = sa durée (même vitesse de défilement que le reste)
			local width = holdTime / fallTime * GRIP_X
			frame = Ui.create("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Size = UDim2.new(width, 26, 0, 30),
				BackgroundColor3 = HOLD_COLOR,
				ZIndex = 2,
				Parent = lane,
			}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.2) })
		else
			frame = Ui.create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(34, 34),
				BackgroundColor3 = TAP_COLOR,
				ZIndex = 2,
				Parent = lane,
			}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.2) })
		end
		table.insert(knots, {
			hold = hold,
			arrivesAt = nextArrival,
			tailAt = nextArrival + (if hold then holdTime else 0),
			frame = frame,
			pressed = false,
			headQuality = nil,
		})
		nextArrival += interval
	end

	local function press()
		local now = os.clock() - self.startTime
		local best: Knot?, bestOffset = nil, math.huge
		for _, knot in knots do
			local offset = math.abs(knot.arrivesAt - now)
			if not knot.pressed and offset < bestOffset then
				best, bestOffset = knot, offset
			end
		end
		-- Appui dans le vide (aucun nœud proche) : ignoré
		if not best or bestOffset > interval * 0.5 then
			return
		end
		local quality = self:GradeOffset(bestOffset)
		if best.hold and quality ~= "Miss" then
			best.pressed = true
			best.headQuality = quality
			holding = best
			flash(HOLD_COLOR)
			return
		end
		remove(best)
		flash(if quality == "Miss" then Color3.fromRGB(150, 150, 150) else TAP_COLOR)
		send(quality)
	end

	local function release()
		local knot = holding
		if not knot or self.auto then
			return
		end
		local now = os.clock() - self.startTime
		local quality = worst(knot.headQuality or "Miss", self:GradeOffset(math.abs(now - knot.tailAt)))
		remove(knot)
		flash(if quality == "Miss" then Color3.fromRGB(150, 150, 150) else HOLD_COLOR)
		send(quality)
	end

	self:OnPress(press, panel)
	self:OnRelease(release)

	local goodWindow = Balance.TimingWindows.Good
	self:OnStep(function(_, t)
		while nextArrival - fallTime <= t do
			spawnKnot()
		end
		-- La corde « vibre » quand on tient un nœud long
		rope.Position = if holding then UDim2.new(0, 0, 0.5, math.sin(t * 40) * 2) else UDim2.fromScale(0, 0.5)
		for index = #knots, 1, -1 do
			local knot = knots[index]
			-- Le nœud avance vers les mains (x = GRIP_X à son arrivée), puis les dépasse
			local headX = (1 - (knot.arrivesAt - t) / fallTime) * GRIP_X
			if knot.hold then
				-- Repère à droite = la tête du nœud (elle atteint les mains la première)
				knot.frame.Position = UDim2.new(headX, 13, 0.5, 0)
			else
				knot.frame.Position = UDim2.fromScale(headX, 0.5)
			end
			if self.auto then
				if t >= knot.tailAt then
					remove(knot)
				end
			elseif knot.pressed then
				-- Maintenu bien après la fin du nœud : raté
				if t - knot.tailAt > goodWindow * self.timingScale then
					remove(knot)
					send("Miss")
				end
			elseif t - knot.arrivesAt > interval * 0.5 then
				-- Nœud passé sans être saisi
				remove(knot)
				send("Miss")
			end
		end
	end)

	return self
end

return Tug
