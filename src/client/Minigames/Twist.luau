-- Mini-jeu « Twist » (aide : ouvrir le bocal de maman, refait en D87) : le couvercle vu de dessus ; on le dévisse
-- en tournant le doigt autour de lui, dans le sens de la flèche (comme un vrai couvercle). Le couvercle tourne sous le
-- doigt, cran après cran (clics). Un quart de tour = une répétition : vite = Perfect, plus lentement = Good, trop
-- lentement = raté. Tourner dans le mauvais sens le revisse. Twist.NotchesPerJar quarts de tour : POP, le couvercle
-- s'envole, les cornichons jaillissent, maman fait la fête, un nouveau bocal arrive.
-- Surprise (niveau Twist.StiffLevel) : couvercle dur, il faut tourner plus loin.
-- Une main fantôme montre le geste tant que le joueur ne touche pas l'écran.
-- Souris : cliquer-glisser en cercle ; clavier : Espace (un cran par appui) ; manette : bouton A ou stick en cercle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Twist
local LID = Color3.fromRGB(240, 196, 64)
local LID_DARK = Color3.fromRGB(170, 120, 30)
local WRONG = Color3.fromRGB(240, 70, 60)
local GLASS = Color3.fromRGB(150, 215, 140)
local RIDGES = 12 -- crans dessinés sur le bord du couvercle
local LID_SIZE = 190

local Twist = {}

-- Écart d'angle ramené entre -180 et 180 degrés
local function wrap(degrees: number): number
	return (degrees + 180) % 360 - 180
end

function Twist.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(320, 390))
	local rng = self:Random()

	-- Le bocal vu de dessus : le verre (cercle vert, cornichons dedans), le couvercle par-dessus
	local jar = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 18),
		Size = UDim2.fromOffset(LID_SIZE + 46, LID_SIZE + 46),
		BackgroundColor3 = GLASS,
		BackgroundTransparency = 0.25,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(1, 1, 1), 3, 0.35) })
	for index = 1, 3 do
		local pickle = self:Emoji(jar, "🥒", 34, 2)
		local angle = math.rad(index * 120 + 20)
		pickle.Position =
			UDim2.new(0.5, math.cos(angle) * (LID_SIZE / 2 + 8), 0.5, math.sin(angle) * (LID_SIZE / 2 + 8))
		pickle.Rotation = index * 70
	end
	-- Le couvercle tourne d'un bloc (cadre tournant) : disque, crans sur le bord, reflet
	local lid = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(LID_SIZE, LID_SIZE),
		BackgroundColor3 = LID,
		ZIndex = 3,
		Parent = jar,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(LID_DARK, 5, 0) })
	local lidStroke = lid:FindFirstChildOfClass("UIStroke") :: UIStroke
	for index = 1, RIDGES do
		local angle = math.rad(index * 360 / RIDGES)
		Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(
				0.5,
				math.cos(angle) * (LID_SIZE / 2 - 12),
				0.5,
				math.sin(angle) * (LID_SIZE / 2 - 12)
			),
			Size = UDim2.fromOffset(8, 22),
			Rotation = math.deg(angle) + 90,
			BackgroundColor3 = LID_DARK,
			ZIndex = 4,
			Parent = lid,
		}, { Ui.corner(UDim.new(1, 0)) })
	end
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, -28, 0.5, -30),
		Size = UDim2.fromOffset(46, 22),
		Rotation = -35,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.45,
		ZIndex = 4,
		Parent = lid,
	}, { Ui.corner(UDim.new(1, 0)) })
	-- Le sens à suivre : deux flèches qui font le tour du couvercle (elles ne tournent pas avec lui)
	local arrows = { self:Emoji(jar, "➡️", 40, 6), self:Emoji(jar, "➡️", 40, 6) }
	-- Progression du quart de tour en cours : un arc de 3 pastilles qui s'allument autour du couvercle
	local dots = {}
	for index = 1, 3 do
		dots[index] = Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = Color3.fromRGB(60, 55, 80),
			ZIndex = 7,
			Parent = jar,
		}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.3) })
	end
	-- Quarts de tour du bocal : une pastille par quart, le bocal s'ouvre quand elles sont toutes pleines
	local pipsFrame = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(200, 26),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Ui.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 12),
		}),
	})
	local pips = {}
	for index = 1, SETTINGS.NotchesPerJar do
		pips[index] = Ui.create("Frame", {
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = Color3.fromRGB(60, 55, 80),
			LayoutOrder = index,
			Parent = pipsFrame,
		}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.4) })
	end
	local hand = self:Emoji(panel, "✊", 58, 9)
	local mom = self:Emoji(panel, "👩", 54, 8)
	mom.Position = UDim2.new(0, 34, 1, -34)
	local jarHome = jar.Position

	-- État
	local spin = 0 -- angle affiché du couvercle (degrés, sens de dévissage positif)
	local progress = 0 -- degrés tournés dans le quart en cours
	local need = SETTINGS.TurnAngle
	local repStart = os.clock() + interval * 0.3
	local quarters = 0 -- quarts faits sur ce bocal
	local started = false
	local lockedUntil = 0 -- petite pause après un quart (le couvercle « clique »)
	local popping = false
	local wrongUntil = 0
	local lastClick = 0
	local lastTouch = -math.huge
	local momCheerUntil = 0

	local function newQuarter(at: number)
		repStart = math.max(at, self:NextRepAt() - interval * 0.4)
		lockedUntil = repStart
		progress = 0
		need = SETTINGS.TurnAngle
		if self.level >= SETTINGS.StiffLevel and rng:NextNumber() < SETTINGS.StiffChance then
			need = SETTINGS.StiffAngle
			self:Announce("Minigame.Twist.Twist.Stiff")
		end
	end
	newQuarter(repStart)

	-- Le bocal s'ouvre : le couvercle s'envole, les cornichons jaillissent, puis un nouveau bocal arrive
	local function pop()
		popping = true
		Kit.Haptic("Strong")
		Kit.Sound("SceneImpact", 1.35)
		self:Shake(6)
		momCheerUntil = os.clock() + 1.2
		TweenService:Create(lid, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 90, 0.5, -230),
			Rotation = lid.Rotation - 540,
			BackgroundTransparency = 1,
		}):Play()
		for index = 1, 7 do
			local pickle = self:Emoji(panel, "🥒", 40, 19)
			pickle.Position = jar.Position
			local angle = math.rad(-160 + index * 20)
			TweenService:Create(pickle, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = jar.Position + UDim2.fromOffset(math.cos(angle) * 150, math.sin(angle) * 130),
				Rotation = 360,
				TextTransparency = 1,
			}):Play()
			task.delay(0.65, function()
				pickle:Destroy()
			end)
		end
		-- Nouveau bocal : il glisse depuis la droite, couvercle neuf
		task.delay(SETTINGS.PopTime * 0.6, function()
			if self.destroyed then
				return
			end
			quarters = 0
			lid.Position = UDim2.fromScale(0.5, 0.5)
			lid.BackgroundTransparency = 0
			jar.Position = jarHome + UDim2.fromOffset(320, 0)
			TweenService:Create(jar, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = jarHome,
			}):Play()
			popping = false
		end)
	end

	-- Le couvercle tourne de `degrees` (positif = dévisser)
	local function turn(degrees: number)
		local now = os.clock()
		if popping or now < lockedUntil or degrees == 0 then
			return
		end
		started = true
		lastTouch = now
		if degrees < 0 then
			-- Mauvais sens : il se revisse
			progress = math.max(progress + degrees * SETTINGS.WrongWay, 0)
			spin += degrees * SETTINGS.WrongWay
			if degrees < -4 then
				wrongUntil = now + 0.4
				self:Announce("Minigame.Twist.Twist.WrongWay")
			end
			return
		end
		progress += degrees
		spin += degrees
		-- Un clic tous les 15 degrés, de plus en plus aigu au fil du quart
		if spin - lastClick >= 15 then
			lastClick = spin
			Kit.Sound("SceneTouch", 0.9 + math.min(progress / need, 1) * 0.5)
			Kit.Haptic("Light")
		end
		if progress >= need then
			local took = (now - repStart) / interval * (SETTINGS.TurnAngle / need)
			local quality = if took <= SETTINGS.PerfectTime / self.timingScale
				then "Perfect"
				elseif took <= SETTINGS.MissTime then "Good"
				else "Miss"
			self:Rep(quality, lid)
			quarters += 1
			if quarters >= SETTINGS.NotchesPerJar then
				pop()
				newQuarter(now + SETTINGS.PopTime)
			else
				Kit.Sound("SceneImpact", 0.9 + quarters * 0.1)
				newQuarter(now + 0.15)
			end
		end
	end

	-- Doigt (ou souris bouton enfoncé) qui tourne autour du couvercle, où qu'il soit sur l'écran
	local touch: InputObject? = nil
	local lastAngle: number? = nil
	local function center(): Vector2
		return lid.AbsolutePosition + lid.AbsoluteSize / 2
	end
	local function track(position: Vector3)
		local offset = Vector2.new(position.X, position.Y) - center()
		-- Trop près du centre, l'angle n'a pas de sens
		if offset.Magnitude < 18 then
			lastAngle = nil
			return
		end
		local angle = math.deg(math.atan2(offset.Y, offset.X))
		if lastAngle then
			-- À l'écran (Y vers le bas), dévisser = sens inverse des aiguilles d'une montre = angle qui diminue
			local delta = math.clamp(-wrap(angle - lastAngle), -SETTINGS.MaxStep, SETTINGS.MaxStep)
			turn(delta)
		end
		lastAngle = angle
	end
	self:Connect(Kit.Input.InputBegan, function(input)
		local press = input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		if press and touch == nil and not self:_overButton(input.Position) then
			touch = input
			lastAngle = nil
			lastTouch = os.clock()
			track(input.Position)
		elseif input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			turn(SETTINGS.KeyStep)
		end
	end)
	self:Connect(Kit.Input.InputChanged, function(input)
		if touch and (input == touch or (input.UserInputType == Enum.UserInputType.MouseMovement)) then
			track(input.Position)
		elseif input.KeyCode == Enum.KeyCode.Thumbstick1 or input.KeyCode == Enum.KeyCode.Thumbstick2 then
			-- Stick en cercle : même calcul, autour du centre du stick
			local stick = Vector2.new(input.Position.X, -input.Position.Y)
			if stick.Magnitude > 0.6 then
				local angle = math.deg(math.atan2(stick.Y, stick.X))
				if lastAngle then
					turn(math.clamp(-wrap(angle - lastAngle), -SETTINGS.MaxStep, SETTINGS.MaxStep))
				end
				lastAngle = angle
				lastTouch = os.clock()
			else
				lastAngle = nil
			end
		end
	end)
	self:Connect(Kit.Input.InputEnded, function(input)
		if input == touch or (touch and input.UserInputType == Enum.UserInputType.MouseButton1) then
			touch = nil
			lastAngle = nil
		end
	end)

	self:OnStep(function()
		local now = os.clock()
		-- Trop lent : le quart est raté (une fois la partie commencée)
		if started and not popping and now > repStart and (now - repStart) / interval > SETTINGS.MissTime + 0.4 then
			self:Rep("Miss", lid)
			newQuarter(now)
		end
		-- Couvercle : il suit l'angle tourné, en douceur
		local target = -spin
		lid.Rotation += (target - lid.Rotation) * 0.5
		local wrong = now < wrongUntil
		local locked = now < lockedUntil and not popping
		lidStroke.Color = if wrong then WRONG elseif locked then Color3.new(1, 1, 1) else LID_DARK
		-- Flèches : elles font le tour dans le bon sens ; elles clignotent si on tourne à l'envers
		for index, arrow in arrows do
			local angle = -now * 2.2 + index * math.pi
			local radius = LID_SIZE / 2 + 10
			arrow.Position = UDim2.new(0.5, math.cos(angle) * radius, 0.5, math.sin(angle) * radius)
			arrow.Rotation = math.deg(math.atan2(-math.cos(angle), math.sin(angle)))
			arrow.TextTransparency = if wrong and math.floor(now * 10) % 2 == 0 then 0.8 else 0
			arrow.Visible = not popping
		end
		-- Progression du quart en cours (3 pastilles en arc au-dessus du couvercle)
		local share = math.clamp(progress / need, 0, 1)
		for index, dot in dots do
			local angle = math.rad(-90 - 40 + index * 20)
			dot.Position =
				UDim2.new(0.5, math.cos(angle) * (LID_SIZE / 2 + 22), 0.5, math.sin(angle) * (LID_SIZE / 2 + 22))
			dot.BackgroundColor3 = if share >= index / 3
				then Color3.fromRGB(255, 210, 60)
				else Color3.fromRGB(60, 55, 80)
		end
		for index, pip in pips do
			pip.BackgroundColor3 = if index <= quarters
				then Color3.fromRGB(90, 220, 100)
				else Color3.fromRGB(60, 55, 80)
		end
		-- Main : sur le doigt pendant le geste ; sinon une main fantôme montre le cercle à faire
		local panelOrigin = panel.AbsolutePosition
		local c = center() - panelOrigin
		local idle = now - lastTouch > 1.4 and not popping
		if touch and lastAngle then
			local angle = math.rad(lastAngle)
			hand.Position =
				UDim2.fromOffset(c.X + math.cos(angle) * LID_SIZE * 0.42, c.Y + math.sin(angle) * LID_SIZE * 0.42)
			hand.TextTransparency = 0
		elseif idle then
			local angle = -now * 3
			hand.Position =
				UDim2.fromOffset(c.X + math.cos(angle) * LID_SIZE * 0.42, c.Y + math.sin(angle) * LID_SIZE * 0.42)
			hand.TextTransparency = 0.35
		else
			hand.TextTransparency = 1
		end
		hand.Text = if touch then "✊" else "👆"
		local cheering = now < momCheerUntil
		mom.Text = if cheering then "🥳" elseif wrong then "😬" else "👩"
		mom.Rotation = if cheering then math.sin(now * 20) * 12 else 0
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		local now = os.clock()
		return {
			phase = "Free",
			resting = popping or now < lockedUntil,
			fill = progress / need,
		}
	end

	return self
end

return Twist
