-- Mini-jeu « Gauge » (duel entre joueurs, bras de fer, D68) : une aiguille balaie la jauge de force d'un bout à
-- l'autre, puis revient. À chaque balayage, une zone verte (au cœur doré) apparaît à un autre endroit : appuyer quand
-- l'aiguille est dedans pour pousser. Un appui par balayage ; un balayage sans appui est raté.
-- Toucher l'écran / clic sur le panneau, Espace, bouton A.
-- Les deux joueurs reçoivent la même graine (options.seed) : mêmes zones au même moment, mêmes fenêtres.
-- L'inclinaison des bras (qui gagne) est affichée par DuelController ; ici, seulement le geste.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Duels = require(ReplicatedStorage.Shared.Config.Duels)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local GREEN = Color3.fromRGB(80, 210, 100)
local GOLD = Color3.fromRGB(255, 210, 60)

local Gauge = {}

function Gauge.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local camera = workspace.CurrentCamera
	local tablet = UserInputService.TouchEnabled and camera and camera.ViewportSize.X >= 900
	local panel = self:Panel(if tablet then UDim2.fromOffset(500, 300) else UDim2.fromOffset(420, 250), true)

	local seed = (options and options.seed) or math.floor(os.clock() * 1000)
	local rng = Random.new(seed)
	local lead = interval * Duels.Lead
	local zoneHalf = Duels.ZoneHalf * self.timingScale
	local perfectHalf = Duels.PerfectHalf * self.timingScale

	local bar = Ui.create("Frame", {
		Name = "Gauge",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 34),
		Size = UDim2.new(1, -40, 0, 64),
		BackgroundColor3 = Color3.fromRGB(30, 25, 45),
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
	local needle = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 6, 1, 18),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 4,
		Parent = bar,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.fromRGB(30, 30, 30), 2, 0) })
	-- Le gros bouton : tout le panneau se touche, l'icône le rappelle
	local arm = self:Emoji(panel, "💪", 90, 4)
	arm.AnchorPoint = Vector2.new(0.5, 0)
	arm.Position = UDim2.new(0.5, 0, 0, 120)
	Ui.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -24, 0, 34),
		Text = Texts.Get("Duel.Go"),
		Parent = panel,
	})
	-- Un seul capteur transparent au-dessus de la jauge, de l'aiguille et de l'icône :
	-- les enfants visuels ne peuvent plus intercepter les appuis tactiles.
	local tapSurface = Ui.create("TextButton", {
		Name = "TapSurface",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 8,
		Parent = panel,
	})

	local zones: { number } = {}
	local resolved: { [number]: boolean } = {}
	local current = 1
	local lastSent = -math.huge
	local pending = 0

	-- Zone du balayage k : tirée dans l'ordre, la même suite pour les deux joueurs
	local function zoneOf(k: number): number
		while #zones < k do
			table.insert(zones, Duels.ZoneMin + rng:NextNumber() * (Duels.ZoneMax - Duels.ZoneMin))
		end
		return zones[k]
	end

	-- Envoi espacé : un appui tardif suivi d'un appui précoce au balayage suivant ne doit pas être refusé
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

	local function needleAt(t: number): (number, number)
		if t < lead then
			return 1, 0
		end
		local k = math.floor((t - lead) / interval) + 1
		local u = (t - lead) / interval - (k - 1)
		-- Aller, puis retour
		return k, if k % 2 == 1 then u else 1 - u
	end

	local function flash(color: Color3)
		bar.BackgroundColor3 = color
		task.delay(0.12, function()
			if bar.Parent then
				bar.BackgroundColor3 = Color3.fromRGB(30, 25, 45)
			end
		end)
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
		resolved[k] = true
		local quality = self:GradeError(math.abs(position - zoneOf(k)), Duels.PerfectHalf, Duels.ZoneHalf)
		flash(if quality == "Perfect" then GOLD elseif quality == "Good" then GREEN else Color3.fromRGB(110, 60, 60))
		zone.BackgroundTransparency = 0.6
		send(quality)
	end, tapSurface)

	self:OnStep(function(_, t)
		local k, position = needleAt(t)
		if k > current then
			-- Balayage terminé sans appui : raté
			for missed = current, k - 1 do
				if not resolved[missed] and not self.auto then
					resolved[missed] = true
					send("Miss")
				end
			end
			current = k
			zone.BackgroundTransparency = 0
		end
		zone.Position = UDim2.fromScale(zoneOf(k), 0.5)
		needle.Position = UDim2.fromScale(position, 0.5)
		-- Le bras se crispe quand l'aiguille entre dans la zone
		local inside = math.abs(position - zoneOf(k)) <= zoneHalf and not resolved[k]
		arm.Size = if inside then UDim2.fromOffset(104, 104) else UDim2.fromOffset(90, 90)
	end)

	return self
end

return Gauge
