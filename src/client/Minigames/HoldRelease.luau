-- Mini-jeu « HoldRelease » (exercice : développé couché, D81) : maintenir le doigt (n'importe où) pour pousser
-- la barre, la jauge monte ; relâcher quand elle est dans la zone verte (au centre doré = Perfect).
-- La zone change de place à chaque répétition. Au-dessus de la zone, la barre tremble ; tout en haut, elle retombe
-- (raté). Surprise (niveau HoldRelease.DriftLevel) : la zone bouge pendant qu'on pousse.
-- La zone dessinée est exactement la zone notée (elle se resserre avec la série et les niveaux).
-- Clavier : maintenir Espace ; manette : maintenir A.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.HoldRelease
local GREEN = Color3.fromRGB(90, 220, 100)
local GOLD = Color3.fromRGB(255, 210, 60)
local FILL = Color3.fromRGB(120, 190, 255)
local REST = Color3.fromRGB(90, 90, 110)

local HoldRelease = {}

function HoldRelease.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(260, 420))
	local rng = self:Random()

	local gauge = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.new(0, 96, 1, -110),
		BackgroundColor3 = Color3.fromRGB(25, 20, 40),
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 18)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.6) })
	local zone = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromScale(1, 0.2),
		BackgroundColor3 = GREEN,
		BackgroundTransparency = 0.15,
		ZIndex = 2,
		Parent = gauge,
	})
	local perfect = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1, 0.3),
		BackgroundColor3 = GOLD,
		ZIndex = 3,
		Parent = zone,
	})
	local fill = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = FILL,
		BackgroundTransparency = 0.25,
		ZIndex = 4,
		Parent = gauge,
	})
	-- La barre (haltère) au sommet de la jauge
	local bar = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 40, 0, 12),
		BackgroundColor3 = Color3.fromRGB(220, 220, 230),
		ZIndex = 6,
		Parent = gauge,
	}, { Ui.corner(UDim.new(1, 0)) })
	for _, x in { 0, 1 } do
		Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.5),
			Size = UDim2.fromOffset(18, 38),
			BackgroundColor3 = Color3.fromRGB(60, 60, 70),
			ZIndex = 7,
			Parent = bar,
		}, { Ui.corner(UDim.new(0, 5)) })
	end
	local button = self:Emoji(panel, "✊", 64, 5)
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -12)

	local holding = false
	local level = 0 -- remplissage de la jauge (0 à 1)
	local center = 0.65
	local overSince: number? = nil
	local dropUntil = 0 -- la barre retombe (raté), on attend avant la suivante

	local function halfWidth(): number
		local base = SETTINGS.ZoneHalfWidth - SETTINGS.ZoneShrinkPerLevel * math.min(self.level, 4)
		return math.max(base, SETTINGS.PerfectHalfWidth * 1.4) * self.timingScale
	end
	local function newZone()
		center = SETTINGS.ZoneCenterMin + rng:NextNumber() * (SETTINGS.ZoneCenterMax - SETTINGS.ZoneCenterMin)
	end
	newZone()

	local function release()
		if not holding then
			return
		end
		holding = false
		if level <= 0.05 then
			level = 0
			return
		end
		local quality =
			self:GradeError(math.abs(level - center), SETTINGS.PerfectHalfWidth, halfWidth() / self.timingScale)
		self:Rep(quality, bar)
		level = 0
		overSince = nil
		newZone()
	end

	self:OnPress(function()
		holding = true
	end)
	self:OnRelease(release)
	self:Guide(panel, "Hold")

	self:OnStep(function(dt, t)
		local now = os.clock()
		local ready = self:RepReady() and now >= dropUntil
		if holding and ready then
			level = math.min(level + dt / (interval * SETTINGS.FillFactor), 1)
			if self.level >= SETTINGS.DriftLevel then
				self:Announce("Minigame.Twist.HoldRelease.Drift")
				center = math.clamp(
					center + SETTINGS.DriftSpeed * dt * math.sin(t * 2.3),
					SETTINGS.ZoneCenterMin,
					SETTINGS.ZoneCenterMax
				)
			end
		elseif not holding then
			level = math.max(level - dt * 2, 0)
		end
		local half = halfWidth()
		-- Au-dessus de la zone : la barre tremble ; tout en haut, elle retombe
		if holding and level > center + half then
			overSince = overSince or now
		else
			overSince = nil
		end
		if holding and level >= 1 then
			holding = false
			level = 0
			overSince = nil
			dropUntil = now + interval * 0.5
			self:Rep("Miss", bar)
			newZone()
		end

		zone.Position = UDim2.fromScale(0, 1 - center)
		zone.Size = UDim2.fromScale(1, half * 2)
		perfect.Size = UDim2.fromScale(1, math.min(SETTINGS.PerfectHalfWidth * self.timingScale / half, 1))
		fill.Size = UDim2.fromScale(1, level)
		fill.BackgroundColor3 = if ready then FILL else REST
		local shake = 0
		if overSince then
			shake = math.min((now - overSince) / SETTINGS.ShakeStart, 1) * 6
		end
		bar.Position = UDim2.new(0.5, math.random(-1, 1) * shake, 1 - level, 0)
		bar.Rotation = math.random(-1, 1) * shake * 0.6
		button.Size = if holding then UDim2.fromOffset(56, 56) else UDim2.fromOffset(64, 64)
		button.TextTransparency = if ready then 0 else 0.6
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		return {
			fill = level,
			center = center,
			half = halfWidth(),
			ready = self:RepReady() and os.clock() >= dropUntil,
			holding = holding,
		}
	end

	return self
end

return HoldRelease
