-- Mini-jeu « Spotlight » (boss : Brayan le Bronzé, D81) : garder sa crème solaire dans le soleil pour bronzer.
-- Glisser le pouce (n'importe où, la crème suit le déplacement du doigt). Le soleil saute d'un coup ; un cercle
-- annonce sa prochaine place juste avant. Surprise (niveau Spotlight.CloudLevel) : Brayan souffle des nuages ;
-- sous un nuage, on ne bronze pas. Noté à chaque pulsation, une fois la partie commencée (premier mouvement).
-- Clavier : ZQSD/WASD, flèches ; manette : stick.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Spotlight
local KEY_SPEED = 1.1
local CLOUD_RADIUS = 0.13

local Spotlight = {}

function Spotlight.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(360, 360))
	local rng = self:Random()
	self:TrackDrag()

	local area = Ui.create("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		BackgroundColor3 = Color3.fromRGB(40, 30, 65),
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 12)) })
	local radius = SETTINGS.Radius * self.timingScale
	local sun = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(radius * 2, radius * 2),
		BackgroundColor3 = Color3.fromRGB(255, 200, 60),
		BackgroundTransparency = 0.2,
		Parent = area,
	}, { Ui.corner(UDim.new(1, 0)) })
	local nextSpot = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(radius * 2, radius * 2),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = area,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.fromRGB(255, 220, 120), 3, 0.2) })
	local cursor = self:Emoji(area, "🧴", 46, 6)
	local brayan = self:Emoji(panel, "😎", 56, 7)
	brayan.Position = UDim2.new(1, -30, 0, 30)

	local sunPos = Vector2.new(0.25, 0.3) -- loin de la crème au départ : il faut bouger
	local nextPos = sunPos
	local nextJump = os.clock() + SETTINGS.JumpEvery
	local cursorPos = Vector2.new(0.5, 0.5)
	local clouds = {} -- { pos, velocity, label }
	local nextCloud = os.clock() + interval
	local started = false
	local nextPulse = 0
	local inside, total = 0, 0

	local function pickSpot(): Vector2
		-- Assez loin du soleil et de la crème pour qu'il faille vraiment bouger
		for _ = 1, 20 do
			local candidate = Vector2.new(0.2 + rng:NextNumber() * 0.6, 0.2 + rng:NextNumber() * 0.6)
			if (candidate - sunPos).Magnitude > 0.3 and (candidate - cursorPos).Magnitude > 0.3 then
				return candidate
			end
		end
		return Vector2.new(1 - sunPos.X, 1 - sunPos.Y)
	end
	nextPos = pickSpot()
	self:Guide(panel, "Drag")

	self:OnStep(function(dt)
		local now = os.clock()
		local drag = self:ConsumeDrag()
		local held = self:HeldDirection()
		-- La partie commence au premier mouvement, ou d'elle-même après un intervalle (une manche de boss doit finir)
		if not started and (drag.Magnitude > 2 or held.Magnitude > 0 or now - self.startTime > interval) then
			started = true
			nextPulse = now + interval
			self:HideGuide()
		end
		if area.AbsoluteSize.X > 0 then
			cursorPos += drag * Balance.Minigames.DragSensitivity / area.AbsoluteSize
		end
		cursorPos += held * KEY_SPEED * dt
		cursorPos = Vector2.new(math.clamp(cursorPos.X, 0.03, 0.97), math.clamp(cursorPos.Y, 0.03, 0.97))
		cursor.Position = UDim2.fromScale(cursorPos.X, cursorPos.Y)

		-- Le soleil saute ; sa prochaine place s'affiche juste avant
		if started and now >= nextJump then
			sunPos = nextPos
			nextPos = pickSpot()
			nextJump = now + SETTINGS.JumpEvery / (2 - self.timingScale)
			brayan.Text = "😤"
		end
		nextSpot.Visible = started and nextJump - now <= SETTINGS.JumpWarn
		nextSpot.Position = UDim2.fromScale(nextPos.X, nextPos.Y)
		sun.Position = UDim2.fromScale(sunPos.X, sunPos.Y)

		-- Nuages soufflés par Brayan
		if started and self.level >= SETTINGS.CloudLevel and now >= nextCloud then
			nextCloud = now + interval * (1.2 + rng:NextNumber())
			self:Announce("Minigame.Twist.Spotlight.Cloud")
			local fromLeft = rng:NextNumber() < 0.5
			table.insert(clouds, {
				pos = Vector2.new(if fromLeft then -0.15 else 1.15, 0.15 + rng:NextNumber() * 0.7),
				velocity = Vector2.new(if fromLeft then SETTINGS.CloudSpeed else -SETTINGS.CloudSpeed, 0),
				label = self:Emoji(area, "☁️", 90, 8),
			})
		end
		local shaded = false
		for index = #clouds, 1, -1 do
			local cloud = clouds[index]
			cloud.pos += cloud.velocity * dt
			cloud.label.Position = UDim2.fromScale(cloud.pos.X, cloud.pos.Y)
			if (cloud.pos - cursorPos).Magnitude < CLOUD_RADIUS then
				shaded = true
			end
			if cloud.pos.X < -0.3 or cloud.pos.X > 1.3 then
				cloud.label:Destroy()
				table.remove(clouds, index)
			end
		end

		local tanning = (cursorPos - sunPos).Magnitude <= radius and not shaded
		cursor.Rotation = if tanning then math.sin(now * 12) * 10 else 0
		if not started then
			return
		end
		total += dt
		if tanning then
			inside += dt
		end
		if now >= nextPulse then
			nextPulse += interval
			local fraction = if total > 0 then inside / total else 0
			inside, total = 0, 0
			local quality = if fraction >= SETTINGS.PerfectInside
				then "Perfect"
				elseif fraction >= SETTINGS.GoodInside then "Good"
				else "Miss"
			brayan.Text = if quality == "Miss" then "😎" else "😠"
			self:Rep(quality, cursor)
		end
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		return { cursor = cursorPos, sun = sunPos, size = area.AbsoluteSize }
	end

	return self
end

return Spotlight
