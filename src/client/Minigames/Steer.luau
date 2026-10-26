-- Mini-jeu « Steer » (aide : pousser la voiture du voisin, D81) : la route serpente ; glisser le pouce à gauche ou à
-- droite (n'importe où, la voiture suit le déplacement du doigt) pour rester sur la route et éviter les obstacles
-- (poubelle, chat, flaque). Noté à chaque pulsation : obstacle touché ou sortie de route = raté, sinon selon la
-- distance au milieu de la route. La partie commence au premier mouvement.
-- Les virages et les obstacles augmentent avec les niveaux. Clavier : A / D, flèches ; manette : stick.
-- D82 : route plus large et virages plus doux ; bordures, ligne centrale qui défile, décor sur les côtés, ombre et
-- fumée de la voiture, mains qui poussent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Steer
local SEGMENTS = 28
local CAR_Y = 0.8
local KEY_SPEED = 1.4 -- largeur de route par seconde
local OBSTACLES = { "🗑️", "🐈", "💧" }
local DECOR = { "🌳", "🌲", "🏠", "🌳", "🚏", "🌼" }
local CURB_RED = Color3.fromRGB(220, 60, 60)
local CURB_WHITE = Color3.fromRGB(245, 245, 245)

local Steer = {}

function Steer.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(320, 400))
	local rng = self:Random()
	self:TrackDrag()

	local field = Ui.create("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		BackgroundColor3 = Color3.fromRGB(70, 150, 70),
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 12)) })
	-- La route : des tranches, chacune avec ses deux bordures (rouge / blanc) et un tiret de la ligne centrale
	local segments = {}
	for index = 1, SEGMENTS do
		local segment = Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(SETTINGS.RoadWidth, 0, 1 / SEGMENTS, 2),
			BackgroundColor3 = Color3.fromRGB(70, 70, 82),
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = field,
		})
		local parts = { frame = segment, curbs = {}, dash = nil :: Frame? }
		for _, side in { 0, 1 } do
			parts.curbs[side] = Ui.create("Frame", {
				AnchorPoint = Vector2.new(side, 0.5),
				Position = UDim2.fromScale(side, 0.5),
				Size = UDim2.new(0, 7, 1, 0),
				BorderSizePixel = 0,
				ZIndex = 3,
				Parent = segment,
			})
		end
		parts.dash = Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 4, 1, 0),
			BackgroundColor3 = Color3.fromRGB(245, 220, 110),
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = segment,
		})
		segments[index] = parts
	end
	local shadow = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(34, 58),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.6,
		ZIndex = 4,
		Parent = field,
	}, { Ui.corner(UDim.new(0, 12)) })
	local car = self:Emoji(field, "🚗", 54, 6)
	car.Rotation = -90
	local hands = self:Emoji(field, "🙌", 30, 6)
	local decor = {} -- { s, side, label }
	local nextDecor = 0
	local nextPuff = 0
	local shownRotation = -90

	local amplitude = SETTINGS.CurveAmplitude + SETTINGS.CurvePerLevel * math.min(self.level, 4)
	local function roadCenter(s: number): number
		return 0.5 + amplitude * math.sin(s * 1.3) + amplitude * 0.45 * math.sin(s * 3.1 + 1)
	end

	local carX = 0.5
	local distance = 0 -- route parcourue
	local started = false
	local errorSum, total = 0, 0
	local hit = false
	local dodged = false -- un obstacle est passé à côté de la voiture pendant cette pulsation
	local nextPulse = 0
	local pulses = 0
	local obstacles = {} -- { s = position sur la route, offset = décalage latéral, label }
	local every = math.max(SETTINGS.ObstacleEvery - math.floor(self.level / 2), SETTINGS.ObstacleEveryMin)

	local function spawnObstacle()
		local offset = (rng:NextNumber() - 0.5) * SETTINGS.RoadWidth * 0.7
		table.insert(obstacles, {
			s = distance + 2.2,
			offset = offset,
			label = self:Emoji(field, OBSTACLES[rng:NextInteger(1, #OBSTACLES)], 40, 4),
		})
	end
	self:Guide(panel, "Drag")

	self:OnStep(function(dt)
		local now = os.clock()
		local drag = self:ConsumeDrag()
		local held = self:HeldDirection().X
		if not started and (drag.Magnitude > 2 or held ~= 0) then
			started = true
			nextPulse = now + interval
			self:HideGuide()
		end
		if field.AbsoluteSize.X > 0 then
			carX += drag.X * Balance.Minigames.DragSensitivity / field.AbsoluteSize.X
		end
		carX = math.clamp(carX + held * KEY_SPEED * SETTINGS.RoadWidth * 2 * dt, 0.04, 0.96)

		if started then
			distance += SETTINGS.ScrollSpeed * dt
		end
		-- La route défile : le bas de l'écran est la position actuelle. Bordures et tirets défilent avec elle.
		local stripe = math.floor(distance * SEGMENTS / 2)
		for index, parts in segments do
			local y = (index - 0.5) / SEGMENTS
			parts.frame.Position = UDim2.fromScale(roadCenter(distance + (1 - y) * 2), y)
			local odd = (index + stripe) % 2 == 0
			for _, curb in parts.curbs do
				curb.BackgroundColor3 = if odd then CURB_RED else CURB_WHITE
			end
			if parts.dash then
				parts.dash.Visible = (index + stripe) % 3 ~= 0
			end
		end
		-- Décor sur les côtés (arbres, maisons) : il défile avec la route
		if distance >= nextDecor then
			nextDecor = distance + 0.35 + rng:NextNumber() * 0.3
			table.insert(decor, {
				s = distance + 2.2,
				side = if rng:NextNumber() < 0.5 then -1 else 1,
				gap = 0.08 + rng:NextNumber() * 0.12,
				label = self:Emoji(field, DECOR[rng:NextInteger(1, #DECOR)], 36, 1),
			})
		end
		for index = #decor, 1, -1 do
			local item = decor[index]
			local y = 1 - (item.s - distance) / 2
			local x = roadCenter(item.s) + item.side * (SETTINGS.RoadWidth / 2 + item.gap)
			item.label.Position = UDim2.fromScale(x, y)
			if y > 1.15 then
				item.label:Destroy()
				table.remove(decor, index)
			end
		end
		local center = roadCenter(distance + (1 - CAR_Y) * 2)
		local offset = math.abs(carX - center)
		car.Position = UDim2.fromScale(carX, CAR_Y)
		-- La voiture penche doucement dans le sens où on la pousse
		local targetRotation = -90 + math.clamp(drag.X * 1.5 + held * 15, -22, 22)
		shownRotation += (targetRotation - shownRotation) * math.min(dt * 12, 1)
		car.Rotation = shownRotation
		shadow.Position = UDim2.new(carX, 4, CAR_Y, 6)
		shadow.Rotation = shownRotation + 90
		hands.Position = UDim2.fromScale(carX, CAR_Y + 0.11)
		-- Petits nuages derrière la voiture
		if started and now >= nextPuff then
			nextPuff = now + 0.22
			local puff = self:Emoji(field, "💨", 22, 2)
			puff.Position = UDim2.fromScale(carX + (rng:NextNumber() - 0.5) * 0.04, CAR_Y + 0.13)
			puff.Rotation = 90
			TweenService:Create(puff, TweenInfo.new(0.5), {
				Position = puff.Position + UDim2.fromScale(0, 0.1),
				TextTransparency = 1,
			}):Play()
			task.delay(0.55, function()
				puff:Destroy()
			end)
		end

		for index = #obstacles, 1, -1 do
			local obstacle = obstacles[index]
			local y = 1 - (obstacle.s - distance) / 2
			local x = roadCenter(obstacle.s) + obstacle.offset
			obstacle.label.Position = UDim2.fromScale(x, y)
			if not obstacle.done and math.abs(y - CAR_Y) < 0.04 and math.abs(x - carX) < SETTINGS.HitRadius then
				obstacle.done = true
				hit = true
				obstacle.label.Text = "💥"
				self:Shake(8)
			end
			if not obstacle.done and y > CAR_Y + 0.05 then
				-- Évité : s'écarter du milieu pour l'esquiver n'est pas une faute
				obstacle.done = true
				dodged = true
			end
			if y > 1.1 then
				obstacle.label:Destroy()
				table.remove(obstacles, index)
			end
		end

		if not started then
			return
		end
		errorSum += offset * dt
		total += dt
		if now >= nextPulse then
			nextPulse += interval
			pulses += 1
			if pulses % every == 0 then
				spawnObstacle()
			end
			local average = if total > 0 then errorSum / total else 1
			errorSum, total = 0, 0
			local quality = if hit then "Miss" else self:GradeError(average, SETTINGS.PerfectMax, SETTINGS.GoodMax)
			if dodged and quality == "Good" then
				quality = "Perfect"
			end
			hit = false
			dodged = false
			self:Rep(quality, car)
		end
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		local list = {}
		for _, obstacle in obstacles do
			table.insert(list, {
				x = roadCenter(obstacle.s) + obstacle.offset,
				y = 1 - (obstacle.s - distance) / 2,
				offset = obstacle.offset,
			})
		end
		return {
			carX = carX,
			center = roadCenter(distance + (1 - CAR_Y) * 2),
			obstacles = list,
			width = field.AbsoluteSize.X,
		}
	end

	return self
end

return Steer
