-- Mini-jeu « Hammer » (aide : clous de la cabane du petit voisin, D81) : le marteau balaie la planche ; toucher
-- l'écran (n'importe où) quand il est pile au-dessus du clou. Le clou change de place à chaque coup.
-- Surprises : clou tordu (deux coups, le premier le redresse, niveau Hammer.BentLevel), pouce du petit voisin
-- posé sur la planche : le taper = raté (niveau Hammer.ThumbLevel). Clavier : Espace ; manette : bouton A.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Hammer
local QUALITY_RANK = { Miss = 0, Good = 1, Perfect = 2 }

local Hammer = {}

function Hammer.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(400, 260))
	local rng = self:Random()

	local plank = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 170),
		Size = UDim2.new(1, -40, 0, 44),
		BackgroundColor3 = Color3.fromRGB(170, 115, 60),
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 6)), Ui.stroke(Color3.fromRGB(110, 70, 30), 3, 0) })
	local nail = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(12, 40),
		BackgroundColor3 = Color3.fromRGB(200, 200, 210),
		ZIndex = 2,
		Parent = plank,
	}, { Ui.corner(UDim.new(0, 3)) })
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(24, 8),
		BackgroundColor3 = Color3.fromRGB(220, 220, 230),
		ZIndex = 3,
		Parent = nail,
	}, { Ui.corner(UDim.new(1, 0)) })
	-- Repère vertical sous le marteau : on voit tout de suite s'il est aligné avec le clou
	local guideLine = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(3, 80),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.6,
		ZIndex = 1,
		Parent = panel,
	})
	local thumb = self:Emoji(plank, "👍", 44, 4)
	local hammer = self:Emoji(panel, "🔨", 70, 5)

	local nailX = 0.5
	local hammerX = 0.5

	-- Le marteau traverse la planche de gauche à droite à vitesse constante (aller), puis remonte vite à gauche
	-- (retour : il est levé, on ne peut pas frapper). Un seul passage au-dessus du clou par pulsation.
	local sweep = interval * SETTINGS.SweepFraction
	local function positionAt(t: number): (number, boolean)
		local u = t % interval
		if u < sweep then
			return 0.05 + 0.9 * u / sweep, true
		end
		return 0.95 - 0.9 * (u - sweep) / (interval - sweep), false
	end
	-- Écart de temps (secondes) entre maintenant et le passage (aller) du marteau au-dessus de x
	local function timeTo(x: number, t: number): number
		local crossing = (x - 0.05) / 0.9 * sweep
		local offset = (t - crossing) % interval
		return math.min(offset, interval - offset)
	end
	local bent = false
	local bentQuality = "Perfect"
	local thumbX: number? = nil
	local strikeAt = -math.huge
	local strikeQuality = "Good"

	local function newNail()
		nailX = 0.12 + rng:NextNumber() * 0.76
		bent = self.level >= SETTINGS.BentLevel and rng:NextNumber() < SETTINGS.BentChance
		thumbX = nil
		if self.level >= SETTINGS.ThumbLevel and rng:NextNumber() < SETTINGS.ThumbChance then
			-- Le pouce, loin du clou
			local candidate = 0.12 + rng:NextNumber() * 0.76
			if math.abs(candidate - nailX) < 0.25 then
				candidate = (candidate + 0.5 - 0.12) % 0.76 + 0.12
			end
			if math.abs(candidate - nailX) >= 0.2 then
				thumbX = candidate
				self:Announce("Minigame.Twist.Hammer.Thumb")
			end
		end
		if bent then
			self:Announce("Minigame.Twist.Hammer.Bent")
		end
		nail.Position = UDim2.fromScale(nailX, 0)
		nail.Size = UDim2.fromOffset(12, 40)
		nail.Rotation = if bent then 35 else 0
		thumb.Visible = thumbX ~= nil
		if thumbX then
			thumb.Position = UDim2.fromScale(thumbX, 0.1)
		end
	end
	newNail()

	self:OnPress(function()
		local now = os.clock()
		if now - strikeAt < 0.3 or not self:RepReady() then
			return
		end
		strikeAt = now
		local t = now - self.startTime
		local _, forward = positionAt(t)
		if not forward then
			return
		end
		local toNail = timeTo(nailX, t)
		-- Le marteau est passé plus près (dans le temps) du pouce que du clou : aïe !
		if thumbX and timeTo(thumbX, t) < toNail then
			-- Aïe !
			strikeQuality = "Miss"
			thumb.Text = "😣"
			task.delay(0.4, function()
				thumb.Text = "👍"
			end)
			self:Rep("Miss", thumb)
			task.delay(0.3, newNail)
			return
		end
		local quality = self:GradeError(toNail, SETTINGS.PerfectTime, SETTINGS.GoodTime)
		strikeQuality = quality
		if bent and quality ~= "Miss" then
			-- Premier coup : le clou se redresse, il faut le frapper encore
			bent = false
			bentQuality = quality
			nail.Rotation = 0
			self:Burst(quality, nail)
			return
		end
		if QUALITY_RANK[bentQuality] < QUALITY_RANK[quality] then
			quality = bentQuality
		end
		bentQuality = "Perfect"
		if quality ~= "Miss" then
			nail.Size = UDim2.fromOffset(12, 8) -- enfoncé !
		end
		self:Rep(quality, nail)
		task.delay(0.3, newNail)
	end)
	self:Guide(panel, "Tap")

	local wasAligned = false
	self:OnStep(function(_, t)
		local now = os.clock()
		local forward
		hammerX, forward = positionAt(t)
		local plankLeft = plank.AbsolutePosition.X - panel.AbsolutePosition.X
		local x = plankLeft + hammerX * plank.AbsoluteSize.X
		local since = now - strikeAt
		local struck = since < 0.15
		hammer.Position = UDim2.fromOffset(x, if struck then 150 elseif forward then 96 else 60)
		hammer.Rotation = if struck then -45 else 10
		guideLine.Position = UDim2.fromOffset(x, 110)
		local aligned = forward and timeTo(nailX, t) <= SETTINGS.PerfectTime * self.timingScale
		guideLine.BackgroundColor3 = if aligned then Color3.fromRGB(255, 215, 40) else Color3.new(1, 1, 1)
		if aligned and not wasAligned then
			self:GuideCue()
		end
		wasAligned = aligned
		plank.Position = UDim2.new(0.5, if struck and strikeQuality ~= "Miss" then math.random(-2, 2) else 0, 0, 170)
		if not self:RepReady() or not forward then
			hammer.TextTransparency = 0.5
		else
			hammer.TextTransparency = 0
		end
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		local _, forward = positionAt(os.clock() - self.startTime)
		return {
			hammerX = hammerX,
			nailX = nailX,
			thumbX = thumbX,
			bent = bent,
			forward = forward,
			ready = self:RepReady(),
		}
	end

	return self
end

return Hammer
