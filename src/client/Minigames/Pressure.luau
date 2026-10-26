-- Mini-jeu « Pressure » (aide : gonfler le pneu du livreur, D81) : chaque appui (n'importe où) pompe de l'air,
-- le pneu fuit. Garder l'aiguille dans la zone verte ; au-dessus du rouge, le pneu éclate (raté, la pression
-- retombe). La fuite change sans arrêt (le petit jet d'air le montre), plus forte à chaque niveau.
-- Noté à chaque pulsation, une fois le premier coup de pompe donné. Clavier : Espace ; manette : bouton A.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Pressure
local GREEN = Color3.fromRGB(90, 220, 100)
local RED = Color3.fromRGB(240, 60, 60)

local Pressure = {}

function Pressure.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(300, 400))
	local rng = self:Random()

	local gauge = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 24, 0.5, 0),
		Size = UDim2.new(0, 70, 1, -50),
		BackgroundColor3 = Color3.fromRGB(30, 25, 45),
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 14)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.5) })
	Ui.create("Frame", {
		Position = UDim2.fromScale(0, 1 - SETTINGS.GreenMax),
		Size = UDim2.fromScale(1, SETTINGS.GreenMax - SETTINGS.GreenMin),
		BackgroundColor3 = GREEN,
		BackgroundTransparency = 0.25,
		ZIndex = 2,
		Parent = gauge,
	})
	Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1 - SETTINGS.RedMin),
		BackgroundColor3 = RED,
		BackgroundTransparency = 0.2,
		ZIndex = 2,
		Parent = gauge,
	})
	local fill = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.3),
		BackgroundColor3 = Color3.fromRGB(120, 180, 255),
		BackgroundTransparency = 0.3,
		ZIndex = 3,
		Parent = gauge,
	})
	local needle = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 4,
		Parent = gauge,
	})
	local tire = self:Emoji(panel, "🛞", 110, 4)
	tire.Position = UDim2.fromScale(0.66, 0.45)
	local leakLabel = self:Emoji(panel, "💨", 40, 5)
	local pump = self:Emoji(panel, "⬇️", 44, 5)
	pump.Position = UDim2.fromScale(0.66, 0.82)

	local level = 0.3
	local leak = SETTINGS.LeakMin
	local nextLeakChange = 0
	local inside, total = 0, 0
	local nextPulse = math.huge -- la notation commence au premier coup de pompe
	local burst = false
	local pumpAt = -math.huge
	local burstAt = -math.huge

	self:OnPress(function()
		local now = os.clock()
		if now - burstAt < 0.4 then
			return
		end
		if nextPulse == math.huge then
			nextPulse = now + interval
		end
		pumpAt = now
		level = math.min(level + SETTINGS.Pump, 1)
	end)
	self:Guide(panel, "Tap")

	self:OnStep(function(dt, t)
		local now = os.clock()
		if t >= nextLeakChange then
			nextLeakChange = t + SETTINGS.LeakChange
			leak = SETTINGS.LeakMin
				+ rng:NextNumber() * (SETTINGS.LeakMax - SETTINGS.LeakMin)
				+ SETTINGS.LeakLevelBonus * self.level
		end
		level = math.max(level - leak * dt, 0)
		-- Trop gonflé : il éclate
		if level >= SETTINGS.RedMin then
			burst = true
			burstAt = now
			level = SETTINGS.ResetLevel
			self:Shake(10)
			self:Announce("Minigame.Twist.Pressure.Burst")
		end
		if nextPulse ~= math.huge then
			total += dt
			if level >= SETTINGS.GreenMin and level <= SETTINGS.GreenMax then
				inside += dt
			end
		end
		if now >= nextPulse then
			nextPulse += interval
			local fraction = if total > 0 then inside / total else 0
			inside, total = 0, 0
			local quality = if burst
				then "Miss"
				elseif fraction >= SETTINGS.PerfectInside then "Perfect"
				elseif fraction >= SETTINGS.GoodInside then "Good"
				else "Miss"
			burst = false
			self:Rep(quality, tire)
		end

		fill.Size = UDim2.fromScale(1, level)
		needle.Position = UDim2.fromScale(0, 1 - level)
		local inGreen = level >= SETTINGS.GreenMin and level <= SETTINGS.GreenMax
		needle.BackgroundColor3 = if inGreen then GREEN else Color3.new(1, 1, 1)
		-- Le pneu gonfle avec la pression, il tremble quand il est près du rouge, il est à plat après l'éclatement
		local size = 70 + 70 * level
		local danger = math.clamp((level - SETTINGS.GreenMax) / (SETTINGS.RedMin - SETTINGS.GreenMax), 0, 1)
		tire.Size = UDim2.fromOffset(size, size * (if now - burstAt < 0.5 then 0.5 else 1))
		tire.Rotation = math.random(-1, 1) * danger * 6
		-- Le jet d'air montre la force de la fuite
		leakLabel.Position = UDim2.fromScale(0.66 + 0.2 + 0.02 * math.sin(t * 20), 0.45)
		leakLabel.Size = UDim2.fromOffset(20 + leak * 60, 20 + leak * 60)
		local pressed = now - pumpAt < 0.1
		pump.Position = UDim2.fromScale(0.66, if pressed then 0.86 else 0.82)
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		return { level = level }
	end

	return self
end

return Pressure
