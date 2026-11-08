-- Mini-jeu « Trace » (boss : Monsieur Pas-Les-Jambes, D110, remplace Wobble) : « Tracer la pose ». Une pose de
-- frime s'affiche en pointillés (V de la victoire, cercle, éclair, double biceps…) : poser le doigt sur le point de
-- départ et suivre le tracé jusqu'au bout avant la fin du temps. Plus le tracé est fidèle et complet, plus le coup
-- est fort (Perfect, Good) ; trop lent ou trop loin du tracé = raté.
-- D122 (« mieux, même concept ») : le tracé est un trait plein qui se remplit d'or, un anneau pulse sur le prochain
-- point à atteindre, une comète montre le sens au début, une flèche part du point vert ; doigt ou bouton lâché en
-- route : on reprend au dernier point atteint (seul le temps file).
-- Surprises : poses plus dures (niveau Trace.HardLevel), poses en miroir et tournées (niveau Trace.MirrorLevel) ;
-- le temps raccourcit à chaque manche.
-- Clavier et manette : maintenir Espace / A et guider le curseur avec les flèches, ZQSD/WASD ou la croix.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Trace
local GOLD = Color3.fromRGB(255, 210, 60)
local DOT = Color3.fromRGB(235, 225, 255)
local GREEN = Color3.fromRGB(90, 230, 90)
local INK = Color3.fromRGB(255, 120, 200)

-- Poses : lignes brisées dans un carré de 0 à 1 (x vers la droite, y vers le bas). Le cercle est calculé.
local function circle(): { Vector2 }
	local points = {}
	for i = 0, 16 do
		local a = -math.pi / 2 + i / 16 * math.pi * 2
		table.insert(points, Vector2.new(0.5 + math.cos(a) * 0.36, 0.5 + math.sin(a) * 0.36))
	end
	return points
end

local EASY = {
	-- V de la victoire (les deux bras en l'air)
	{ Vector2.new(0.15, 0.15), Vector2.new(0.5, 0.85), Vector2.new(0.85, 0.15) },
	-- Cercle (le gainage parfait)
	circle(),
	-- Triangle (le dos en V)
	{ Vector2.new(0.5, 0.12), Vector2.new(0.88, 0.85), Vector2.new(0.12, 0.85), Vector2.new(0.5, 0.12) },
	-- Le « L » (bras tendu, poing levé)
	{ Vector2.new(0.25, 0.12), Vector2.new(0.25, 0.85), Vector2.new(0.85, 0.85) },
}
local HARD = {
	-- Éclair
	{
		Vector2.new(0.62, 0.08),
		Vector2.new(0.3, 0.52),
		Vector2.new(0.6, 0.5),
		Vector2.new(0.36, 0.92),
	},
	-- Double biceps (un M)
	{
		Vector2.new(0.1, 0.85),
		Vector2.new(0.2, 0.15),
		Vector2.new(0.5, 0.6),
		Vector2.new(0.8, 0.15),
		Vector2.new(0.9, 0.85),
	},
	-- Étoile
	{
		Vector2.new(0.5, 0.08),
		Vector2.new(0.75, 0.9),
		Vector2.new(0.1, 0.38),
		Vector2.new(0.9, 0.38),
		Vector2.new(0.25, 0.9),
		Vector2.new(0.5, 0.08),
	},
	-- Zigzag (la vague de muscles)
	{
		Vector2.new(0.1, 0.2),
		Vector2.new(0.3, 0.8),
		Vector2.new(0.5, 0.2),
		Vector2.new(0.7, 0.8),
		Vector2.new(0.9, 0.2),
	},
}

-- Points régulièrement espacés le long d'une ligne brisée
local function resample(path: { Vector2 }, count: number): { Vector2 }
	local lengths, total = { 0 }, 0
	for i = 2, #path do
		total += (path[i] - path[i - 1]).Magnitude
		lengths[i] = total
	end
	local out = {}
	local segment = 2
	for k = 0, count - 1 do
		local d = total * k / (count - 1)
		while segment < #path and lengths[segment] < d do
			segment += 1
		end
		local a, b = path[segment - 1], path[segment]
		local span = lengths[segment] - lengths[segment - 1]
		local t = if span > 0 then (d - lengths[segment - 1]) / span else 0
		table.insert(out, a:Lerp(b, t))
	end
	return out
end

-- Distance d'un point à la ligne brisée
local function distanceToPath(point: Vector2, path: { Vector2 }): number
	local best = math.huge
	for i = 2, #path do
		local a, b = path[i - 1], path[i]
		local ab = b - a
		local t = if ab.Magnitude > 0 then math.clamp((point - a):Dot(ab) / ab:Dot(ab), 0, 1) else 0
		best = math.min(best, (point - (a + ab * t)).Magnitude)
	end
	return best
end

local Trace = {}

function Trace.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	-- D122 : zone plus grande à la souris (gestes plus amples et plus précis)
	local panelSize = if UserInputService.TouchEnabled then SETTINGS.PanelTouch else SETTINGS.PanelPc
	local panel = self:Panel(UDim2.fromOffset(panelSize.X, panelSize.Y))
	local rng = self:Random()
	local tolerance = 1 / math.max(self.timingScale, 0.5) -- combat serré : fenêtres un peu plus étroites
	local traceTime = interval * math.max(SETTINGS.TimeFactor - SETTINGS.TimePerLevel * self.level, SETTINGS.MinTime)

	-- Barre du temps restant
	local timeBack = Ui.create("Frame", {
		Position = UDim2.fromOffset(14, 12),
		Size = UDim2.new(1, -28, 0, 12),
		BackgroundColor3 = Color3.fromRGB(30, 25, 45),
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)) })
	local timeFill = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = GOLD,
		Parent = timeBack,
	}, { Ui.corner(UDim.new(1, 0)) })

	-- Zone de dessin (carrée)
	local board = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -24, 1, -48),
		BackgroundColor3 = Color3.fromRGB(45, 35, 70),
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 14)) })
	Ui.create("UIAspectRatioConstraint", { AspectRatio = 1, Parent = board })
	local layer = Ui.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = board })

	-- État de la pose en cours
	local path: { Vector2 } = {}
	local checkpoints: { Vector2 } = {}
	local dots: { Frame } = {}
	local reached = 0 -- points du tracé déjà parcourus, dans l'ordre
	local errorSum, samples = 0, 0
	local shownAt, deadline = 0, math.huge
	local drawing = false
	local resolved = true
	local cursor = Vector2.new(0.5, 0.5) -- clavier et manette
	local touch: InputObject? = nil
	local lastInk = 0
	local segments: { [number]: Frame } = {}
	local comet: Frame? = nil

	-- Trait entre deux points de la zone (carrée : mêmes angles en proportions et en pixels)
	local function segment(a: Vector2, b: Vector2, color: Color3, transparency: number, width: number, z: number): Frame
		local mid = (a + b) / 2
		local d = b - a
		return Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(mid.X, mid.Y),
			Size = UDim2.new(d.Magnitude, width, 0, width),
			Rotation = math.deg(math.atan2(d.Y, d.X)),
			BackgroundColor3 = color,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = layer,
		}, { Ui.corner(UDim.new(1, 0)) })
	end

	local startMark = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(SETTINGS.StartRadius * 2, SETTINGS.StartRadius * 2),
		BackgroundColor3 = GREEN,
		BackgroundTransparency = 0.25,
		ZIndex = 4,
		Parent = board,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(1, 1, 1), 3, 0) })
	local startArrow = self:Emoji(startMark, "👆", 30, 5)
	startArrow.Position = UDim2.fromScale(0.5, 0.5)
	-- Sens du tracé : une flèche juste après le point vert
	local headArrow = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(34, 34),
		Text = "➤",
		TextColor3 = GREEN,
		TextScaled = true,
		ZIndex = 5,
		Parent = board,
	})
	-- Anneau qui pulse sur le prochain point à atteindre
	local target = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Visible = false,
		Parent = board,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(GOLD, 3, 0) })
	local pen = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = INK,
		Visible = false,
		ZIndex = 6,
		Parent = board,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(1, 1, 1), 2, 0) })

	local function newPose()
		layer:ClearAllChildren()
		dots = {}
		segments = {}
		local pool = EASY
		if self.level >= SETTINGS.HardLevel and rng:NextNumber() < SETTINGS.HardChance then
			pool = HARD
			self:Announce("Minigame.Twist.Trace.Hard")
		end
		local shape = pool[rng:NextInteger(1, #pool)]
		local mirror = self.level >= SETTINGS.MirrorLevel and rng:NextNumber() < 0.5
		local angle = if self.level >= SETTINGS.MirrorLevel
			then math.rad(rng:NextNumber(-SETTINGS.MaxTurn, SETTINGS.MaxTurn))
			else 0
		if mirror then
			self:Announce("Minigame.Twist.Trace.Mirror")
		end
		-- Sens du tracé tiré au hasard : on ne mémorise pas le geste
		local reverse = rng:NextNumber() < 0.5
		path = {}
		for i = 1, #shape do
			local p = shape[if reverse then #shape + 1 - i else i] - Vector2.new(0.5, 0.5)
			if mirror then
				p = Vector2.new(-p.X, p.Y)
			end
			p = Vector2.new(
				p.X * math.cos(angle) - p.Y * math.sin(angle),
				p.X * math.sin(angle) + p.Y * math.cos(angle)
			)
			table.insert(path, p + Vector2.new(0.5, 0.5))
		end
		checkpoints = resample(path, SETTINGS.Checkpoints)
		-- Le tracé en trait plein (pâle) et un point par étape ; chaque trait s'allume en or quand on l'a parcouru
		for k = 2, #checkpoints do
			segments[k] = segment(checkpoints[k - 1], checkpoints[k], DOT, 0.55, SETTINGS.LineWidth, 1)
		end
		for _, point in checkpoints do
			table.insert(
				dots,
				Ui.create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(point.X, point.Y),
					Size = UDim2.fromOffset(12, 12),
					BackgroundColor3 = DOT,
					BackgroundTransparency = 0.1,
					ZIndex = 2,
					Parent = layer,
				}, { Ui.corner(UDim.new(1, 0)) })
			)
		end
		startMark.Position = UDim2.fromScale(path[1].X, path[1].Y)
		startMark.Visible = true
		-- La flèche pointe vers la suite du tracé
		local direction = checkpoints[math.min(3, #checkpoints)] - path[1]
		local unit = if direction.Magnitude > 0 then direction.Unit else Vector2.zero
		local arrowAt = path[1] + unit * SETTINGS.StartRadius * 1.9
		headArrow.Position = UDim2.fromScale(arrowAt.X, arrowAt.Y)
		headArrow.Rotation = math.deg(math.atan2(direction.Y, direction.X))
		headArrow.Visible = true
		target.Visible = false
		-- Comète qui parcourt le tracé une fois, dans le bon sens (le temps court déjà : on peut partir tout de suite)
		comet = Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(path[1].X, path[1].Y),
			Size = UDim2.fromOffset(20, 20),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 4,
			Parent = layer,
		}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(GOLD, 3, 0) })
		reached, errorSum, samples = 0, 0, 0
		drawing = false
		resolved = false
		shownAt = os.clock()
		deadline = shownAt + traceTime
	end

	-- Note de la pose : part du tracé parcourue et écart moyen avec lui
	local function finish()
		if resolved then
			return
		end
		resolved = true
		drawing = false
		touch = nil
		pen.Visible = false
		startMark.Visible = false
		headArrow.Visible = false
		target.Visible = false
		local coverage = reached / #checkpoints
		local meanError = if samples > 0 then errorSum / samples else 1
		local quality = "Miss"
		if coverage >= SETTINGS.PerfectCoverage and meanError <= SETTINGS.PerfectError * tolerance then
			quality = "Perfect"
		elseif coverage >= SETTINGS.GoodCoverage and meanError <= SETTINGS.GoodError * tolerance then
			quality = "Good"
		end
		local color = Kit.QUALITY_COLORS[quality]
		for _, dot in dots do
			dot.BackgroundColor3 = color
		end
		for _, line in segments do
			line.BackgroundColor3 = color
			line.BackgroundTransparency = 0.15
		end
		self:Rep(quality, board)
		-- Pose suivante : après une courte pause, jamais avant que le serveur accepte la répétition suivante
		local wait = math.max(SETTINGS.Pause, self:NextRepAt() - os.clock() - traceTime * 0.5)
		task.delay(wait, function()
			if not self.destroyed then
				newPose()
			end
		end)
	end

	local function toBoard(screen: Vector2): Vector2
		local size = board.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return Vector2.new(0.5, 0.5)
		end
		return (screen - board.AbsolutePosition) / size
	end

	-- Avance du doigt : les points du tracé atteints s'allument (dans l'ordre, on peut en sauter un ou deux)
	local function move(point: Vector2)
		if resolved or not drawing then
			return
		end
		pen.Position = UDim2.fromScale(point.X, point.Y)
		errorSum += distanceToPath(point, path)
		samples += 1
		for k = reached + 1, math.min(reached + SETTINGS.Skip + 1, #checkpoints) do
			if (checkpoints[k] - point).Magnitude <= SETTINGS.Reach * tolerance then
				for j = reached + 1, k do
					dots[j].BackgroundColor3 = GOLD
					dots[j].Size = UDim2.fromOffset(16, 16)
					local line = segments[j]
					if line then
						line.BackgroundColor3 = GOLD
						line.BackgroundTransparency = 0
					end
				end
				reached = k
				break
			end
		end
		-- Trace laissée par le doigt
		local now = os.clock()
		if now - lastInk > 0.03 then
			lastInk = now
			local ink = Ui.create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(point.X, point.Y),
				Size = UDim2.fromOffset(10, 10),
				BackgroundColor3 = INK,
				ZIndex = 3,
				Parent = layer,
			}, { Ui.corner(UDim.new(1, 0)) })
			task.delay(0.6, function()
				ink:Destroy()
			end)
		end
		if reached >= #checkpoints then
			finish()
		end
	end

	-- Point d'où (re)partir : le point vert, ou le dernier point atteint après un lâcher
	local function anchor(): (Vector2, number)
		if reached > 0 then
			return checkpoints[reached], SETTINGS.ResumeRadius
		end
		return path[1], SETTINGS.StartRadius * SETTINGS.StartGrace
	end

	local function begin(point: Vector2)
		if resolved or drawing then
			return
		end
		local from, radius = anchor()
		if (point - from).Magnitude > radius then
			self:Nope(startMark)
			return
		end
		drawing = true
		startMark.Visible = false
		headArrow.Visible = false
		pen.Visible = true
		move(point)
	end

	-- Lâché en route : on garde ce qui est tracé, le point vert attend au dernier point atteint
	local function pause()
		drawing = false
		touch = nil
		pen.Visible = false
		local from = anchor()
		startMark.Position = UDim2.fromScale(from.X, from.Y)
		startMark.Visible = true
	end

	local function isPress(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	self:Connect(Kit.Input.InputBegan, function(input)
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			cursor = if resolved then cursor else (anchor())
			begin(cursor)
		elseif isPress(input) and touch == nil and not self:_overButton(input.Position) then
			touch = input
			begin(toBoard(Vector2.new(input.Position.X, input.Position.Y)))
			if not drawing then
				touch = nil
			end
		end
	end)
	self:Connect(Kit.Input.InputChanged, function(input)
		local mouseMove = touch ~= nil
			and touch.UserInputType == Enum.UserInputType.MouseButton1
			and input.UserInputType == Enum.UserInputType.MouseMovement
		if input == touch or mouseMove then
			move(toBoard(Vector2.new(input.Position.X, input.Position.Y)))
		end
	end)
	self:Connect(Kit.Input.InputEnded, function(input)
		-- Doigt levé avant la fin du tracé : on pourra reprendre (la pose est notée à la fin du temps)
		local key = input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA
		if (input == touch or (key and touch == nil)) and drawing then
			pause()
		end
	end)
	self:Guide(board, "Drag")

	self:OnStep(function(dt)
		if resolved then
			return
		end
		local now = os.clock()
		local left = math.clamp((deadline - now) / traceTime, 0, 1)
		timeFill.Size = UDim2.fromScale(left, 1)
		timeFill.BackgroundColor3 = if left < 0.3 then Color3.fromRGB(255, 90, 70) else GOLD
		startArrow.Rotation = math.sin(now * 8) * 12
		-- Comète du début : parcourt le tracé en PreviewTime, puis s'efface
		local c = comet
		if c then
			local t = (now - shownAt) / SETTINGS.PreviewTime
			if t >= 1 then
				c:Destroy()
				comet = nil
			else
				local index = math.clamp(t * (#checkpoints - 1) + 1, 1, #checkpoints)
				local low = math.floor(index)
				local p = checkpoints[low]:Lerp(checkpoints[math.min(low + 1, #checkpoints)], index - low)
				c.Position = UDim2.fromScale(p.X, p.Y)
				c.BackgroundTransparency = t * 0.6
			end
		end
		-- Anneau sur le prochain point (une fois parti)
		local nextPoint = checkpoints[reached + 1]
		target.Visible = (drawing or reached > 0) and nextPoint ~= nil
		if nextPoint then
			local pulse = 1 + 0.25 * math.sin(now * SETTINGS.TargetPulse * math.pi * 2)
			target.Position = UDim2.fromScale(nextPoint.X, nextPoint.Y)
			target.Size = UDim2.fromOffset(30 * pulse, 30 * pulse)
		end
		-- Clavier et manette : le curseur suit la direction tenue
		if drawing and touch == nil then
			local direction = self:HeldDirection()
			if direction.Magnitude > 0 then
				cursor += direction.Unit * SETTINGS.CursorSpeed * dt
				cursor = Vector2.new(math.clamp(cursor.X, 0, 1), math.clamp(cursor.Y, 0, 1))
				move(cursor)
			end
		end
		if now >= deadline then
			finish()
		end
	end)

	newPose()

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		return {
			path = path,
			checkpoints = checkpoints,
			reached = reached,
			drawing = drawing,
			resolved = resolved,
			deadline = deadline,
			board = board,
		}
	end

	return self
end

return Trace
