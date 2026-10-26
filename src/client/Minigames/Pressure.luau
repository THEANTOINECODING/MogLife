-- Mini-jeu « Pressure » (aide : gonfler le pneu du coursier stressé, refait en D82) : une vraie pompe à vélo.
-- Glisser le pouce vers le bas (n'importe où) enfonce la poignée et envoie de l'air : un grand coup = beaucoup d'air,
-- un petit coup = un peu ; la poignée remonte quand on relâche ou qu'on glisse vers le haut. S'arrêter avec l'aiguille
-- dans la zone verte (au centre doré = Perfect) : après un court instant sans pomper, le coursier repart et un
-- nouveau pneu arrive. Trop d'air : le pneu éclate (raté). Trop long : le coursier part sans attendre (raté).
-- Niveaux : chaque pneu prend l'air différemment (Pressure.VaryLevel), il fuit plus et la zone rétrécit
-- (Pressure.LeakLevel). Clavier : maintenir Espace / flèche bas ; manette : maintenir A.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Pressure
local GREEN = Color3.fromRGB(90, 220, 100)
local GOLD = Color3.fromRGB(255, 210, 60)
local RED = Color3.fromRGB(240, 60, 60)
local PUSH_KEYS = { Enum.KeyCode.Space, Enum.KeyCode.Down, Enum.KeyCode.S }
local TIRE_X = 0.62

local Pressure = {}

function Pressure.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(340, 420))
	local rng = self:Random()
	self:TrackDrag()

	-- La pompe (à gauche) : un corps, une tige et une poignée qui suit le pouce
	local pump = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.22, 0, 1, -24),
		Size = UDim2.fromOffset(46, 200),
		BackgroundColor3 = Color3.fromRGB(60, 130, 230),
		ZIndex = 3,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 10)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.4) })
	local rod = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(10, 120),
		BackgroundColor3 = Color3.fromRGB(200, 200, 210),
		ZIndex = 2,
		Parent = panel,
	})
	local handle = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(110, 22),
		BackgroundColor3 = Color3.fromRGB(40, 40, 50),
		ZIndex = 4,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.3) })
	-- Le tuyau qui va au pneu
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.22, 0, 1, -40),
		Size = UDim2.new(0.38, 0, 0, 6),
		BackgroundColor3 = Color3.fromRGB(30, 30, 35),
		ZIndex = 2,
		Parent = panel,
	})

	-- Le pneu (à droite), le coursier et la jauge de pression
	local tire = self:Emoji(panel, "🛞", 120, 4)
	local courier = self:Emoji(panel, "😰", 56, 5)
	local gauge = Ui.create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.new(0, 34, 1, -100),
		BackgroundColor3 = Color3.fromRGB(30, 25, 45),
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 10)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.5) })
	Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1 - SETTINGS.Burst),
		BackgroundColor3 = RED,
		BackgroundTransparency = 0.2,
		ZIndex = 2,
		Parent = gauge,
	})
	local zone = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromScale(1, 0.1),
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
		BackgroundColor3 = Color3.fromRGB(120, 190, 255),
		BackgroundTransparency = 0.3,
		ZIndex = 4,
		Parent = gauge,
	})
	local needle = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(1, 0, 0, 5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 5,
		Parent = gauge,
	})

	local stroke = 0 -- poignée : 0 = en haut, 1 = enfoncée
	local pressure = 0
	local center = 0.6
	local airPerStroke = SETTINGS.AirPerStroke
	local tireStart = 0
	-- Stabilité : la pression ne doit pas monter de plus de Pressure.Jitter pendant HoldTime (un pouce posé tremble
	-- toujours un peu : ces micro-mouvements ne comptent pas comme pomper)
	local holdBase = 0
	local holdSince = 0
	local state = "Waiting" -- "Waiting" (pneu suivant), "Pumping", "Leaving" (le coursier repart)
	local stateAt = os.clock()
	local burstAt = -math.huge
	local strokeAir = 0 -- air envoyé pendant le coup en cours (pour le son)

	local function halfWidth(): number
		local base = SETTINGS.ZoneHalf - SETTINGS.ZoneShrinkPerLevel * math.min(self.level, 3)
		return math.max(base, SETTINGS.PerfectHalf * 1.5) * self.timingScale
	end
	local function leak(): number
		return SETTINGS.Leak + (if self.level >= SETTINGS.LeakLevel then SETTINGS.LeakLevelBonus else 0)
	end

	local function newTire()
		state = "Waiting"
		-- Le pneu suivant arrive quand le serveur peut accepter la répétition suivante
		stateAt = math.max(os.clock() + 0.2, self:NextRepAt() - interval * 0.5)
		pressure = 0
		center = SETTINGS.CenterMin + rng:NextNumber() * (SETTINGS.CenterMax - SETTINGS.CenterMin)
		airPerStroke = SETTINGS.AirPerStroke
		if self.level >= SETTINGS.VaryLevel then
			airPerStroke *= 0.7 + rng:NextNumber() * 0.6
			self:Announce("Minigame.Twist.Pressure.Vary")
		end
	end
	newTire()

	local function finish(quality: string)
		self:Rep(quality, tire)
		if quality == "Miss" then
			newTire()
			return
		end
		-- Le coursier repart sur son vélo
		state = "Leaving"
		stateAt = os.clock()
		Kit.Sound("SceneImpact", 1.3)
		task.delay(0.6, function()
			if not self.destroyed then
				newTire()
			end
		end)
	end

	local function keyDown(): boolean
		for _, key in PUSH_KEYS do
			if UserInputService:IsKeyDown(key) then
				return true
			end
		end
		for _, input in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
			if input.KeyCode == Enum.KeyCode.ButtonA and input.UserInputState == Enum.UserInputState.Begin then
				return true
			end
		end
		return false
	end

	self:Guide(panel, "SwipeDown")

	self:OnStep(function(dt)
		local now = os.clock()
		if state == "Waiting" and now >= stateAt then
			state = "Pumping"
			tireStart = now
			holdBase = 0
			holdSince = now
		end
		-- La poignée suit le pouce (glisser vers le bas l'enfonce) ; au clavier, maintenir l'enfonce
		local drag = self:ConsumeDrag()
		local camera = workspace.CurrentCamera
		local range = (if camera then camera.ViewportSize.Y else 600) * SETTINGS.StrokeFraction
		local before = stroke
		if self.dragging then
			stroke += drag.Y * Balance.Minigames.DragSensitivity / range
		elseif keyDown() then
			stroke += SETTINGS.KeySpeed * dt
		else
			stroke -= SETTINGS.ReturnSpeed * dt
		end
		stroke = math.clamp(stroke, 0, 1)

		local half = halfWidth()
		if state == "Pumping" then
			-- Seule la descente pousse de l'air
			local pushed = math.max(stroke - before, 0)
			if pushed > 0 then
				pressure += pushed * airPerStroke
				strokeAir += pushed
			elseif strokeAir > 0.15 and stroke < before then
				-- Fin d'un coup de pompe : « pssht », plus aigu quand le pneu est gonflé
				Kit.Sound("SceneTouch", 0.8 + pressure * 0.6)
				strokeAir = 0
			end
			pressure = math.max(pressure - leak() * dt, 0)
			if pressure > holdBase + SETTINGS.Jitter then
				holdBase = pressure
				holdSince = now
			elseif pressure < holdBase then
				holdBase = pressure
			end
			if pressure >= SETTINGS.Burst then
				-- Trop d'air : il éclate
				burstAt = now
				Kit.Sound("SceneImpact", 0.6)
				self:Shake(12)
				self:Announce("Minigame.Twist.Pressure.Burst")
				finish("Miss")
			elseif math.abs(pressure - center) <= half and now - holdSince >= SETTINGS.HoldTime then
				-- Dans le vert sans pomper : le coursier prend son vélo
				finish(self:GradeError(math.abs(pressure - center), SETTINGS.PerfectHalf, half / self.timingScale))
			elseif now - tireStart > interval * SETTINGS.TireTime then
				-- Trop long : il part sans attendre
				finish("Miss")
			end
		end

		-- Dessin : la poignée, la jauge et le pneu qui gonfle
		local pumpTop = pump.AbsolutePosition.Y - panel.AbsolutePosition.Y
		local pumpX = pump.AbsolutePosition.X - panel.AbsolutePosition.X + pump.AbsoluteSize.X / 2
		local handleY = pumpTop - 90 + 80 * stroke
		handle.Position = UDim2.fromOffset(pumpX, handleY)
		rod.Position = UDim2.fromOffset(pumpX, pumpTop + 10)
		rod.Size = UDim2.fromOffset(10, math.max(pumpTop + 10 - handleY, 4))
		zone.Position = UDim2.fromScale(0, 1 - center)
		zone.Size = UDim2.fromScale(1, half * 2)
		perfect.Size = UDim2.fromScale(1, math.min(SETTINGS.PerfectHalf * self.timingScale / half, 1))
		fill.Size = UDim2.fromScale(1, math.min(pressure, 1))
		needle.Position = UDim2.fromScale(0, 1 - math.min(pressure, 1))
		local inZone = math.abs(pressure - center) <= half
		needle.BackgroundColor3 = if inZone then GREEN else Color3.new(1, 1, 1)
		local danger = math.clamp((pressure - (center + half)) / math.max(SETTINGS.Burst - center - half, 0.01), 0, 1)
		local flat = now - burstAt < 0.5
		local size = 70 + 80 * math.min(pressure, 1)
		tire.Size = UDim2.fromOffset(size, if flat then size * 0.45 else size)
		tire.Text = if flat then "💥" else "🛞"
		tire.Rotation = math.random(-1, 1) * danger * 8
		-- Le pneu arrive en roulant ; le coursier repart avec lui
		local x = TIRE_X
		if state == "Leaving" then
			x += math.clamp((now - stateAt) / 0.5, 0, 1) * 0.6
		elseif state == "Pumping" then
			x += (1 - math.clamp((now - tireStart) / 0.25, 0, 1)) * 0.5
		end
		tire.Position = UDim2.fromScale(x, 0.58)
		courier.Position = UDim2.fromScale(x, 0.26)
		courier.Text = if state == "Leaving"
			then "🚴"
			elseif inZone then "🤩"
			elseif danger > 0.3 then "😱"
			else "😰"
		tire.Visible = state ~= "Waiting" or flat
		courier.Visible = state ~= "Waiting"
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		return {
			state = state,
			pressure = pressure,
			center = center,
			half = halfWidth(),
			stroke = stroke,
			airPerStroke = airPerStroke,
		}
	end

	return self
end

return Pressure
