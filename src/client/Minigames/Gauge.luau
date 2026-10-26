-- Mini-jeu « Gauge » (duel entre joueurs, bras de fer, D68, D81) : une aiguille balaie la jauge de force d'un bout à
-- l'autre, puis revient. À chaque balayage, une zone verte (au cœur doré) apparaît à un autre endroit : toucher
-- l'écran (n'importe où) quand l'aiguille est dedans pour pousser. Un appui par balayage ; un balayage sans appui
-- est raté. Dernier effort (D81) : le dernier balayage de la manche a 3 petites zones à toucher à la suite.
-- Clavier : Espace ; manette : bouton A.
-- Les deux joueurs reçoivent la même graine (options.seed) : mêmes zones au même moment, mêmes fenêtres.
-- L'inclinaison des bras (qui gagne) est affichée par DuelController ; ici, seulement le geste.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Duels = require(ReplicatedStorage.Shared.Config.Duels)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local GREEN = Color3.fromRGB(80, 210, 100)
local GOLD = Color3.fromRGB(255, 210, 60)
local ORANGE = Color3.fromRGB(255, 140, 50)
local BAR = Color3.fromRGB(30, 25, 45)

local Gauge = {}

function Gauge.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(420, 250))

	local seed = (options and options.seed) or math.floor(os.clock() * 1000)
	local rng = Random.new(seed)
	local lead = interval * Duels.Lead
	local zoneHalf = Duels.ZoneHalf * self.timingScale
	local perfectHalf = Duels.PerfectHalf * self.timingScale
	local effortHalf = Duels.LastEffort.Half * self.timingScale
	local lastSweep = self.total

	local bar = Ui.create("Frame", {
		Name = "Gauge",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 34),
		Size = UDim2.new(1, -40, 0, 64),
		BackgroundColor3 = BAR,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 12)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.5) })
	local zone = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(zoneHalf * 2, 0, 1, -10),
		BackgroundColor3 = GREEN,
		ZIndex = 2,
		Parent = bar,
	}, { Ui.corner(UDim.new(0, 8)) })
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(perfectHalf / zoneHalf, 1),
		BackgroundColor3 = GOLD,
		ZIndex = 3,
		Parent = zone,
	}, { Ui.corner(UDim.new(0, 6)) })
	-- Les 3 zones du dernier effort
	local effortZones = {}
	for index, x in Duels.LastEffort.Zones do
		effortZones[index] = Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.5),
			Size = UDim2.new(effortHalf * 2, 0, 1, -10),
			BackgroundColor3 = ORANGE,
			ZIndex = 2,
			Visible = false,
			Parent = bar,
		}, { Ui.corner(UDim.new(0, 8)) })
	end
	local needle = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 6, 1, 18),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 4,
		Parent = bar,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.fromRGB(30, 30, 30), 2, 0) })
	local arm = self:Emoji(panel, "💪", 90, 4)
	arm.AnchorPoint = Vector2.new(0.5, 0)
	arm.Position = UDim2.new(0.5, 0, 0, 120)

	local zones: { number } = {}
	local resolved: { [number]: boolean } = {}
	local effortHits: { [number]: number } = {} -- zones touchées pendant le dernier effort
	local current = 1
	local pushAt = -math.huge

	-- Zone du balayage k : tirée dans l'ordre, la même suite pour les deux joueurs
	local function zoneOf(k: number): number
		while #zones < k do
			table.insert(zones, Duels.ZoneMin + rng:NextNumber() * (Duels.ZoneMax - Duels.ZoneMin))
		end
		return zones[k]
	end

	local function needleAt(t: number): (number, number)
		if t < lead then
			return 1, 0
		end
		local k = math.floor((t - lead) / interval) + 1
		local u = (t - lead) / interval - (k - 1)
		-- Aller, puis retour
		return k, if k % 2 == 1 then u else 1 - u
	end

	local function isEffort(k: number): boolean
		return lastSweep ~= nil and k % lastSweep == 0
	end

	-- Zones du dernier effort dans l'ordre où l'aiguille les traverse
	local function effortOrder(k: number): { number }
		local ordered = table.clone(Duels.LastEffort.Zones)
		if k % 2 == 0 then
			table.sort(ordered, function(a, b)
				return a > b
			end)
		end
		return ordered
	end

	local function push(quality: string)
		pushAt = os.clock()
		bar.BackgroundColor3 = if quality == "Perfect" then GOLD elseif quality == "Good" then GREEN else BAR
		task.delay(0.12, function()
			if bar.Parent then
				bar.BackgroundColor3 = BAR
			end
		end)
		self:Rep(quality, arm)
	end

	self:OnPress(function()
		local t = os.clock() - self.startTime
		if t < lead then
			return
		end
		local k, position = needleAt(t)
		if resolved[k] then
			return
		end
		if isEffort(k) then
			local hits = effortHits[k] or 0
			local target = effortOrder(k)[hits + 1]
			if target and math.abs(position - target) <= effortHalf then
				effortHits[k] = hits + 1
				self:Burst("Good", needle)
				if hits + 1 == #Duels.LastEffort.Zones then
					resolved[k] = true
					push("Perfect")
				end
			else
				-- Raté pendant le dernier effort : il compte ce qui a été touché
				resolved[k] = true
				push(if hits >= 2 then "Good" else "Miss")
			end
			return
		end
		resolved[k] = true
		local quality = self:GradeError(math.abs(position - zoneOf(k)), Duels.PerfectHalf, Duels.ZoneHalf)
		zone.BackgroundTransparency = 0.6
		push(quality)
	end)
	self:Guide(panel, "Tap")

	local cued = false
	self:OnStep(function(_, t)
		local k, position = needleAt(t)
		if k > current then
			-- Balayage terminé sans appui (ou dernier effort inachevé)
			for missed = current, k - 1 do
				if not resolved[missed] then
					resolved[missed] = true
					local hits = effortHits[missed] or 0
					push(if isEffort(missed) and hits >= 2 then "Good" else "Miss")
				end
			end
			current = k
			zone.BackgroundTransparency = 0
			cued = false
		end
		local effort = isEffort(k)
		if effort then
			self:Announce("Minigame.Twist.Gauge.Last")
		end
		zone.Visible = not effort
		local hits = effortHits[k] or 0
		local order = effortOrder(k)
		for index, frame in effortZones do
			frame.Visible = effort
			local rank = table.find(order, Duels.LastEffort.Zones[index])
			local done = rank ~= nil and rank <= hits
			frame.BackgroundColor3 = if done then GOLD else ORANGE
		end
		zone.Position = UDim2.fromScale(zoneOf(k), 0.5)
		needle.Position = UDim2.fromScale(position, 0.5)
		-- Le bras se crispe et tremble quand l'aiguille entre dans la zone
		local inside = not resolved[k] and not effort and math.abs(position - zoneOf(k)) <= zoneHalf
		local shaking = inside or (effort and not resolved[k])
		local pushed = os.clock() - pushAt < 0.15
		arm.Size = if pushed
			then UDim2.fromOffset(112, 112)
			elseif inside then UDim2.fromOffset(102, 102)
			else UDim2.fromOffset(90, 90)
		arm.Rotation = if shaking then math.random(-4, 4) else 0
		if inside and not cued and math.abs(position - zoneOf(k)) <= perfectHalf then
			cued = true
			self:GuideCue()
		end
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		local k, position = needleAt(os.clock() - self.startTime)
		return {
			k = k,
			position = position,
			zone = zoneOf(k),
			effort = isEffort(k),
			targets = effortOrder(k),
			hits = effortHits[k] or 0,
			resolved = resolved[k] == true,
			half = effortHalf,
			perfectHalf = perfectHalf,
		}
	end

	return self
end

return Gauge
