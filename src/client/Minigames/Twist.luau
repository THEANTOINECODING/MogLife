-- Mini-jeu « Twist » (aide : ouvrir le bocal de maman, refait en D88) : comme pour de vrai, il faut deux mains.
-- Un pouce TIENT le bocal (rester appuyé sur la gauche du panneau ou de l'écran), l'autre DÉVISSE le couvercle (glisser
-- vers la gauche sur la droite). Sans tenir le bocal, il tourne avec le couvercle : rien ne se dévisse.
-- Un coup de couvercle = un quart de tour = une répétition : vite = Perfect, plus lentement = Good, trop lent = raté.
-- 4 quarts : POP, le couvercle saute, les cornichons jaillissent, maman fait la fête, un nouveau bocal arrive.
-- Surprises : bocal mouillé (niveau Twist.WetLevel) : la main glisse, il faut lâcher le bocal et le reprendre ;
-- couvercle dur (niveau Twist.TightLevel) : deux coups pour ce quart.
-- Clavier : maintenir Espace ou Maj pour tenir, flèche gauche (ou A / Q) pour dévisser. Manette : maintenir L1 / L2,
-- bouton X ou stick à gauche pour dévisser.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Twist
local LID = Color3.fromRGB(240, 196, 64)
local LID_DARK = Color3.fromRGB(170, 120, 30)
local GLASS = Color3.fromRGB(150, 215, 140)
local GRIP_ON = Color3.fromRGB(90, 220, 100)
local GRIP_OFF = Color3.fromRGB(70, 65, 95)
local WET = Color3.fromRGB(90, 170, 255)
local RIDGES = 7

local GRIP_KEYS = {
	[Enum.KeyCode.Space] = true,
	[Enum.KeyCode.LeftShift] = true,
	[Enum.KeyCode.RightShift] = true,
	[Enum.KeyCode.ButtonL1] = true,
	[Enum.KeyCode.ButtonL2] = true,
}
local TWIST_KEYS = {
	[Enum.KeyCode.Left] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.Q] = true,
	[Enum.KeyCode.ButtonX] = true,
	[Enum.KeyCode.DPadLeft] = true,
}

local Twist = {}

function Twist.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(340, 390))
	local rng = self:Random()

	-- Main gauche : la prise du bocal (verte quand on tient, bleue quand le bocal est mouillé)
	local grip = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.56, 0),
		Size = UDim2.fromOffset(78, 78),
		BackgroundColor3 = GRIP_OFF,
		ZIndex = 4,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(1, 1, 1), 3, 0.2) })
	local gripIcon = self:Emoji(grip, "✋", 48, 5)
	gripIcon.Position = UDim2.fromScale(0.5, 0.5)
	local holdLabel = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 4),
		Size = UDim2.fromOffset(110, 22),
		Text = Texts.Get("Minigame.Twist.Hold"),
		ZIndex = 5,
		Parent = grip,
	})

	-- Le bocal (de face) et son couvercle
	local jar = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.6, 0, 1, -26),
		Size = UDim2.fromOffset(150, 190),
		BackgroundColor3 = GLASS,
		BackgroundTransparency = 0.2,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 26)), Ui.stroke(Color3.new(1, 1, 1), 3, 0.3) })
	for index = 1, 3 do
		local pickle = self:Emoji(jar, "🥒", 50, 2)
		pickle.Position = UDim2.fromScale(0.25 + (index - 1) * 0.25, 0.5 + (index % 2) * 0.18)
		pickle.Rotation = index * 50
	end
	local drops = self:Emoji(jar, "💦", 46, 6)
	drops.Position = UDim2.fromScale(0.82, 0.25)
	local lid = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.new(1, 18, 0, 50),
		BackgroundColor3 = LID,
		ClipsDescendants = true,
		ZIndex = 3,
		Parent = jar,
	}, { Ui.corner(UDim.new(0, 12)), Ui.stroke(LID_DARK, 3, 0) })
	local lidHome = lid.Position
	local ridges = {}
	for index = 1, RIDGES do
		ridges[index] = Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, 7, 1, -12),
			BackgroundColor3 = LID_DARK,
			ZIndex = 4,
			Parent = lid,
		}, { Ui.corner(UDim.new(1, 0)) })
	end
	-- Flèche du geste : glisser vers la gauche sur le couvercle
	local arrow = self:Emoji(panel, "⬅️", 46, 7)
	-- Quarts de tour du bocal en cours
	local pipsFrame = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
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
	local mom = self:Emoji(panel, "👩", 50, 8)
	mom.Position = UDim2.new(1, -30, 0, 66)
	local jarHome = jar.Position

	-- État
	local grips: { [InputObject]: number } = {} -- doigts (ou souris) qui tiennent le bocal : moment de la prise
	local keyGripAt: number? = nil -- touche de prise maintenue (clavier, manette)
	local lidTouches: { [InputObject]: Vector2 } = {} -- doigts posés sur le couvercle : point de départ
	local lidFired: { [InputObject]: boolean } = {}
	local quarters = 0
	local strokes = 0 -- coups faits sur le quart en cours (couvercle dur : 2)
	local need = 1
	local repStart = os.clock() + interval * 0.3
	local lockedUntil = repStart
	local wetAt: number? = nil -- bocal mouillé : il faut une prise prise APRÈS ce moment
	local popping = false
	local started = false
	local spunAt = -math.huge -- le bocal a tourné tout seul (pas tenu)
	local twistAt = -math.huge
	local turned = 0 -- position des stries du couvercle
	local momCheerUntil = 0
	local quarterId = 0

	-- Le bocal est-il bien tenu ? (une prise, et si le bocal est mouillé, une prise reprise depuis)
	local function holding(): boolean
		local latest = keyGripAt
		for _, at in grips do
			latest = if latest then math.max(latest, at) else at
		end
		if not latest then
			return false
		end
		return wetAt == nil or latest > wetAt
	end

	local function newQuarter(at: number)
		repStart = at
		lockedUntil = repStart
		strokes = 0
		need = 1
		wetAt = nil
		quarterId += 1
		local id = quarterId
		if self.level >= SETTINGS.TightLevel and rng:NextNumber() < SETTINGS.TightChance then
			need = 2
			self:Announce("Minigame.Twist.Twist.Tight")
		end
		if self.level >= SETTINGS.WetLevel and rng:NextNumber() < SETTINGS.WetChance then
			-- Le bocal devient glissant un peu après le début du quart
			task.delay(math.max(repStart + interval * SETTINGS.WetDelay - os.clock(), 0), function()
				if not self.destroyed and quarterId == id and not popping then
					wetAt = os.clock()
					Kit.Sound("SceneTouch", 0.5)
					self:Announce("Minigame.Twist.Twist.Wet")
				end
			end)
		end
	end
	newQuarter(repStart)

	-- Le bocal s'ouvre : le couvercle saute, les cornichons jaillissent, puis un nouveau bocal arrive
	local function pop()
		popping = true
		Kit.Haptic("Strong")
		Kit.Sound("SceneImpact", 1.35)
		self:Shake(6)
		momCheerUntil = os.clock() + 1.2
		TweenService:Create(lid, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = lidHome + UDim2.fromOffset(80, -200),
			Rotation = 400,
		}):Play()
		for index = 1, 7 do
			local pickle = self:Emoji(panel, "🥒", 40, 19)
			pickle.Position = jar.Position - UDim2.fromOffset(0, 190)
			local angle = math.rad(-160 + index * 20)
			TweenService:Create(pickle, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = pickle.Position + UDim2.fromOffset(math.cos(angle) * 150, math.sin(angle) * 120),
				Rotation = 360,
				TextTransparency = 1,
			}):Play()
			task.delay(0.65, function()
				pickle:Destroy()
			end)
		end
		task.delay(SETTINGS.PopTime * 0.6, function()
			if self.destroyed then
				return
			end
			quarters = 0
			lid.Position = lidHome
			lid.Rotation = 0
			jar.Position = jarHome + UDim2.fromOffset(320, 0)
			TweenService:Create(jar, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = jarHome,
			}):Play()
			popping = false
		end)
	end

	-- Un coup sur le couvercle
	local function twist()
		local now = os.clock()
		if popping or now < lockedUntil then
			self:Nope(lid)
			return
		end
		started = true
		if not holding() then
			-- Pas tenu (ou mouillé et pas repris) : le bocal tourne avec le couvercle, rien ne se dévisse
			spunAt = now
			Kit.Sound("SceneTouch", 0.6)
			self:Announce(if wetAt then "Minigame.Twist.Twist.Wet" else "Minigame.Twist.Twist.NoGrip")
			return
		end
		twistAt = now
		turned += 1
		strokes += 1
		Kit.Sound("SceneTouch", 0.9 + strokes * 0.2)
		Kit.Haptic("Light")
		if strokes < need then
			return
		end
		local took = (now - repStart) / interval
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

	-- Gestes : à gauche (prise du bocal et tout ce qui est à sa gauche), on tient ; à droite, on glisse vers la gauche
	local function divider(): number
		return grip.AbsolutePosition.X + grip.AbsoluteSize.X + 10
	end
	local function swipeDistance(): number
		local camera = workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 600
		return math.max(30, height * SETTINGS.SwipeFraction)
	end
	local function checkSwipe(key: InputObject, position: Vector3)
		local start = lidTouches[key]
		if start and not lidFired[key] and start.X - position.X >= swipeDistance() then
			lidFired[key] = true
			twist()
		end
	end
	local mouse: InputObject? = nil -- bouton de souris enfoncé sur le couvercle
	self:Connect(Kit.Input.InputBegan, function(input)
		local press = input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		if press and not self:_overButton(input.Position) then
			if input.Position.X < divider() then
				grips[input] = os.clock()
				Kit.Haptic("Light")
			else
				lidTouches[input] = Vector2.new(input.Position.X, input.Position.Y)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					mouse = input
				end
			end
		elseif GRIP_KEYS[input.KeyCode] then
			keyGripAt = os.clock()
		elseif TWIST_KEYS[input.KeyCode] then
			twist()
		end
	end)
	self:Connect(Kit.Input.InputChanged, function(input)
		if lidTouches[input] then
			checkSwipe(input, input.Position)
		elseif input.UserInputType == Enum.UserInputType.MouseMovement and mouse then
			checkSwipe(mouse, input.Position)
		elseif input.KeyCode == Enum.KeyCode.Thumbstick1 or input.KeyCode == Enum.KeyCode.Thumbstick2 then
			if input.Position.X < -0.7 and not lidFired[input] then
				lidFired[input] = true
				twist()
			elseif input.Position.X > -0.3 then
				lidFired[input] = nil
			end
		end
	end)
	self:Connect(Kit.Input.InputEnded, function(input)
		grips[input] = nil
		lidTouches[input] = nil
		lidFired[input] = nil
		if input == mouse then
			mouse = nil
		end
		if GRIP_KEYS[input.KeyCode] then
			keyGripAt = nil
		end
	end)

	self:OnStep(function()
		local now = os.clock()
		-- Trop lent : le quart est raté (une fois la partie commencée)
		if started and not popping and now > repStart and (now - repStart) / interval > SETTINGS.MissTime + 0.4 then
			self:Rep("Miss", lid)
			newQuarter(now)
		end
		local held = holding()
		local anyGrip = keyGripAt ~= nil or next(grips) ~= nil
		grip.BackgroundColor3 = if held then GRIP_ON elseif wetAt and anyGrip then WET else GRIP_OFF
		gripIcon.Text = if held then "✊" else "✋"
		grip.Size = if held then UDim2.fromOffset(84, 84) else UDim2.fromOffset(78, 78)
		holdLabel.TextTransparency = if held then 0.6 else 0
		drops.Visible = wetAt ~= nil
		drops.Rotation = math.sin(now * 8) * 10
		-- Couvercle : ses stries défilent à chaque coup
		local since = now - twistAt
		local shift = turned * 0.07 + (if since < 0.15 then since / 0.15 * 0.07 else 0)
		for index, ridge in ridges do
			ridge.Position = UDim2.fromScale(0.04 + (((index - 1) / RIDGES + shift) % 1) * 0.92, 0.5)
		end
		-- Bocal pas tenu : il tourne avec le couvercle
		local spin = now - spunAt
		jar.Rotation = if spin < 0.4 then math.sin(spin * 40) * 12 * (1 - spin / 0.4) else 0
		-- Flèche : elle glisse vers la gauche au-dessus du couvercle (pâle tant que le bocal n'est pas tenu)
		local lidCenter = lid.AbsolutePosition + lid.AbsoluteSize / 2 - panel.AbsolutePosition
		local slide = (now * 1.5) % 1
		arrow.Position = UDim2.fromOffset(lidCenter.X + 30 - slide * 60, lidCenter.Y - 44)
		arrow.TextTransparency = if popping then 1 elseif held then 0.1 else 0.65
		for index, pip in pips do
			pip.BackgroundColor3 = if index <= quarters
				then Color3.fromRGB(90, 220, 100)
				elseif index == quarters + 1 and strokes > 0 then Color3.fromRGB(255, 210, 60)
				else Color3.fromRGB(60, 55, 80)
		end
		local cheering = now < momCheerUntil
		mom.Text = if cheering then "🥳" elseif spin < 0.6 then "😬" else "👩"
		mom.Rotation = if cheering then math.sin(now * 20) * 12 else 0
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		local now = os.clock()
		return {
			phase = "Free",
			resting = popping or now < lockedUntil,
			holding = holding(),
			wet = wetAt ~= nil,
			fill = strokes / need,
		}
	end

	return self
end

return Twist
