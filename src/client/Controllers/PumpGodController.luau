-- Combat du Dieu du Pump au Colisée, côté client (D90, tranche 2). Le serveur (PumpGodService) décide de tout ; ici
-- on montre ce qu'il annonce (Remotes.PumpGodUpdate), à l'heure du serveur :
-- - zones au sol (PumpGod/Zones) et ce qui frappe : éclairs, haltère géant qui roule, onde ;
-- - le dieu animé (PumpGod/God) : chaque attaque a sa pose de préparation et de frappe ;
-- - pour le combattant : barre de vie, bouton ROULADE (Q / Ctrl gauche / X à la manette ; bouton à l'écran au
--   tactile), flash rouge et petite secousse quand il est touché (jamais de zoom) ;
-- - pour les spectateurs proches : le même combat, plus un bandeau avec le nom du combattant.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local PumpGod = require(ReplicatedStorage.Shared.Config.PumpGod)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local God = require(script.Parent.Parent.PumpGod.God)
local Ui = require(script.Parent.Parent.Ui)
local Zones = require(script.Parent.Parent.PumpGod.Zones)

local player = Players.LocalPlayer
local ROLL = PumpGod.Roll
local ROLL_KEYS = { Enum.KeyCode.Q, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonX }
local BOLT_COLOR = Color3.fromRGB(190, 225, 255)
local GOLD = Color3.fromRGB(255, 210, 90)
local IRON = Color3.fromRGB(70, 70, 80)
-- Barre de vie en bas au centre : le haut de l'écran est pris par le Mog, le Cash et l'objectif ; au téléphone, le
-- joystick est à gauche et les boutons à droite
local HUD_HOME = UDim2.new(0.5, 0, 1, -18)

type Fight = {
	fighter: Player,
	center: Vector3,
	maxHp: number,
	hp: number,
	god: any?,
	zones: { [number]: { Destroy: () -> () } },
	things: { Instance },
}

local fight: Fight? = nil
local rollReadyAt = 0
local rolling = false

-- Interface
local gui: ScreenGui
local hud: Frame
local hpFill: Frame
local hpText: TextLabel
local rollButton: TextButton
local rollShade: Frame
local banner: TextLabel
local flash: Frame

local PumpGodController = {}

local function mine(): boolean
	return fight ~= nil and fight.fighter == player
end

local function near(position: Vector3): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude < Balance.Colosseum.FireRange * 1.5
end

local function rootOf(who: Player): BasePart?
	local character = who.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function effectPart(size: Vector3, color: Color3, transparency: number, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	p.Size = size
	if shape then
		p.Shape = shape
	end
	p.Parent = workspace
	return p
end

local function fadeOut(p: BasePart, time: number, grow: Vector3?)
	local goal: { [string]: any } = { Transparency = 1 }
	if grow then
		goal.Size = grow
	end
	TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(p, time + 0.05)
end

local function showBanner(text: string, time: number)
	banner.Text = text
	banner.Visible = true
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.3
	local stamp = os.clock()
	banner:SetAttribute("Stamp", stamp)
	task.delay(time, function()
		if banner:GetAttribute("Stamp") == stamp then
			banner.Visible = false
		end
	end)
end

-- Petite secousse de caméra (décalage du Humanoid, revient toujours à zéro ; aucun zoom)
local function shake(strength: number, time: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - start) / time
		if k >= 1 or not humanoid.Parent then
			humanoid.CameraOffset = Vector3.zero
			connection:Disconnect()
			return
		end
		local a = strength * (1 - k)
		humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * a
	end)
end

-- ------------------------------------------------------------------ ce qui frappe
local function bolt(at: Vector3, radius: number, from: Vector3)
	-- Éclair en zigzag tombé du ciel (passant au-dessus de la main du dieu), puis poussière dorée au sol
	local top = Vector3.new(at.X, at.Y + 70, at.Z):Lerp(from, 0.25)
	local points = { top }
	local count = 7
	for k = 1, count - 1 do
		local p = top:Lerp(at, k / count)
		points[k + 1] = p + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 5
	end
	points[count + 1] = at
	for k = 1, count do
		local a, b = points[k], points[k + 1]
		local seg = effectPart(Vector3.new(0.7, 0.7, (b - a).Magnitude), BOLT_COLOR, 0)
		seg.CFrame = CFrame.lookAt((a + b) / 2, b)
		fadeOut(seg, 0.3)
	end
	local disc = effectPart(Vector3.new(0.3, radius, radius), GOLD, 0.1, Enum.PartType.Cylinder)
	disc.CFrame = CFrame.new(at + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	fadeOut(disc, 0.45, Vector3.new(0.3, radius * 2.4, radius * 2.4))
	local light = Instance.new("PointLight")
	light.Color = BOLT_COLOR
	light.Range = 24
	light.Brightness = 6
	light.Parent = disc
	if mine() then
		local root = rootOf(player)
		if root and (root.Position - at).Magnitude < 30 then
			shake(0.35, 0.25)
		end
	end
end

-- Haltère géant : il tombe du ciel au début de la bande, rebondit, puis roule jusqu'au bout
local function dumbbell(message)
	local a, b = message.a :: Vector3, message.b :: Vector3
	local plate = message.height :: number
	local width = message.width :: number
	local model = Instance.new("Model")
	model.Name = "PumpGodDumbbell"
	local bar = effectPart(
		Vector3.new(width, plate * 0.22, plate * 0.22),
		Color3.fromRGB(200, 200, 210),
		0,
		Enum.PartType.Cylinder
	)
	bar.Material = Enum.Material.Metal
	bar.Parent = model
	local plates = {}
	for k, x in { -1, 1 } do
		local disc = effectPart(Vector3.new(width * 0.16, plate, plate), IRON, 0, Enum.PartType.Cylinder)
		disc.Material = Enum.Material.SmoothPlastic
		disc.Parent = model
		local rim = effectPart(Vector3.new(width * 0.17, plate * 0.45, plate * 0.45), GOLD, 0, Enum.PartType.Cylinder)
		rim.Parent = model
		plates[k] = { disc = disc, rim = rim, x = x * width * 0.4 }
	end
	model.Parent = workspace
	local frame = CFrame.lookAt(a, b)
	local length = (b - a).Magnitude
	local landed = false
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local now = Zones.ServerNow()
		local s = (now - message.impact) * message.speed
		if s > length + 4 or not fight then
			connection:Disconnect()
			model:Destroy()
			return
		end
		local y = plate / 2
		if s < 0 then
			-- Chute pendant la dernière demi-seconde d'avertissement (avant : haut dans le ciel, invisible)
			local fall = math.clamp(-s / message.speed / 0.5, 0, 1)
			y += fall * fall * 60
			s = 0
		elseif not landed then
			landed = true
			local dust =
				effectPart(Vector3.new(0.3, width, width), Color3.fromRGB(230, 200, 150), 0.2, Enum.PartType.Cylinder)
			dust.Material = Enum.Material.SmoothPlastic
			dust.CFrame = CFrame.new(a + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			fadeOut(dust, 0.5, Vector3.new(0.3, width * 2.5, width * 2.5))
			if mine() then
				shake(0.25, 0.2)
			end
		end
		local spin = -s / (plate / 2)
		local base = frame * CFrame.new(0, y, -s) * CFrame.Angles(spin, 0, 0)
		bar.CFrame = base
		for _, p in plates do
			p.disc.CFrame = base * CFrame.new(p.x, 0, 0)
			p.rim.CFrame = base * CFrame.new(p.x * 1.06, 0, 0)
		end
	end)
	return model
end

local function waveSlam(at: Vector3)
	local disc = effectPart(Vector3.new(0.4, 10, 10), GOLD, 0, Enum.PartType.Cylinder)
	disc.CFrame = CFrame.new(at + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	fadeOut(disc, 0.5, Vector3.new(0.4, 26, 26))
	if mine() then
		shake(0.3, 0.3)
	end
end

-- ------------------------------------------------------------------ roulade
-- Le corps fait un tour complet vers l'avant (rotation locale du torse, rien ne se réplique de ce côté)
local function rollSpin(character: Model)
	local lower = character:FindFirstChild("LowerTorso")
	local joint = lower and lower:FindFirstChild("Root")
	if not joint or not joint:IsA("Motor6D") then
		return
	end
	local original = joint.C0
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - start) / ROLL.Time
		if k >= 1 or not joint.Parent then
			joint.C0 = original
			connection:Disconnect()
			return
		end
		local e = k * k * (3 - 2 * k)
		local tuck = math.sin(k * math.pi)
		joint.C0 = original * CFrame.new(0, -1.3 * tuck, 0) * CFrame.Angles(-2 * math.pi * e, 0, 0)
	end)
end

local function roll()
	if not mine() or rolling or os.clock() < rollReadyAt then
		return
	end
	local character = player.Character
	local root = rootOf(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	rollReadyAt = os.clock() + ROLL.Cooldown
	rolling = true
	Remotes.PumpGodRoll:FireServer()
	local dir = humanoid.MoveDirection * Vector3.new(1, 0, 1)
	if dir.Magnitude < 0.1 then
		dir = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	dir = dir.Unit
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local push = Instance.new("LinearVelocity")
	push.Attachment0 = attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	push.PrimaryTangentAxis = Vector3.xAxis
	push.SecondaryTangentAxis = Vector3.zAxis
	push.PlaneVelocity = Vector2.new(dir.X, dir.Z) * (ROLL.Distance / ROLL.Time)
	push.MaxForce = 1e6
	push.Parent = root
	rollSpin(character :: Model)
	task.delay(ROLL.Time, function()
		push:Destroy()
		attachment:Destroy()
		rolling = false
	end)
end

-- ------------------------------------------------------------------ interface
local function setHp(hp: number, maxHp: number)
	local k = math.clamp(hp / math.max(maxHp, 1), 0, 1)
	TweenService:Create(hpFill, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(k, 1) }):Play()
	hpFill.BackgroundColor3 = if k > 0.5
		then Color3.fromRGB(110, 230, 110)
		elseif k > 0.25 then Color3.fromRGB(255, 200, 60)
		else Color3.fromRGB(255, 70, 60)
	hpText.Text = Texts.Get("PumpGod.Health", { hp = math.ceil(hp), max = maxHp })
end

local function hurt()
	flash.BackgroundTransparency = 0.55
	TweenService:Create(flash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
	local home = HUD_HOME
	task.spawn(function()
		for k = 1, 6 do
			hud.Position = home + UDim2.fromOffset((if k % 2 == 0 then 1 else -1) * (7 - k), 0)
			task.wait(0.03)
		end
		hud.Position = home
	end)
	shake(0.5, 0.3)
	-- Clignote pendant son invincibilité
	local character = player.Character
	if character then
		local stop = os.clock() + PumpGod.HitInvuln
		task.spawn(function()
			while os.clock() < stop and character.Parent do
				local hidden = math.floor(os.clock() * 12) % 2 == 0
				for _, part in character:GetDescendants() do
					if part:IsA("BasePart") then
						part.LocalTransparencyModifier = if hidden then 0.6 else 0
					end
				end
				task.wait(1 / 24)
			end
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = 0
				end
			end
		end)
	end
end

-- Chiffre de dégâts au-dessus du combattant (tout le monde le voit)
local function floatDamage(who: Player, damage: number)
	local root = rootOf(who)
	if not root then
		return
	end
	local billboard = Ui.create("BillboardGui", {
		Size = UDim2.fromOffset(90, 44),
		StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0),
		AlwaysOnTop = true,
		Adornee = root,
		Parent = workspace,
	})
	local label = Ui.label({
		Size = UDim2.fromScale(1, 1),
		Text = Texts.Get("PumpGod.Damage", { damage = damage }),
		TextColor3 = Color3.fromRGB(255, 80, 60),
		Parent = billboard,
	})
	TweenService:Create(billboard, TweenInfo.new(0.8), { StudsOffsetWorldSpace = Vector3.new(0, 6, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(billboard, 0.85)
end

local function layout()
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(800, 600)
	hud.Size = UDim2.fromOffset(math.clamp(size.X * 0.55, 220, 380), if Ui.isPhonePortrait() then 30 else 34)
	-- Même hauteur que le bouton de course, juste à sa gauche (SprintController)
	local tall = not Ui.isPhonePortrait() and size.X > size.Y and size.Y > 600
	rollButton.Position = if tall then UDim2.new(1, -112, 1, -230) else UDim2.new(1, -112, 1, -120)
end

local function buildGui()
	gui = Ui.create("ScreenGui", { Name = "PumpGod", ResetOnSpawn = false, DisplayOrder = 4, Enabled = true })
	flash = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 30, 20),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = gui,
	})
	hud = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = HUD_HOME,
		BackgroundColor3 = Color3.fromRGB(25, 20, 35),
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(UDim.new(0.5, 0)), Ui.stroke(GOLD, 2, 0.1) })
	hpFill = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(110, 230, 110),
		BorderSizePixel = 0,
		Parent = hud,
	}, { Ui.corner(UDim.new(0.5, 0)) })
	Ui.label({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.new(0, 30, 1, 4),
		Text = Texts.Get("PumpGod.HealthIcon"),
		ZIndex = 2,
		Parent = hud,
	})
	hpText = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.8),
		Text = "",
		ZIndex = 2,
		Parent = hud,
	})
	banner = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(0.8, 0, 0, 40),
		Text = "",
		TextColor3 = GOLD,
		Visible = false,
		Parent = gui,
	})
	Ui.create("UITextSizeConstraint", { MaxTextSize = 30, Parent = banner })
	rollButton = Ui.button({
		Name = "Roll",
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(78, 78),
		BackgroundColor3 = Color3.fromRGB(255, 90, 70),
		TextColor3 = Color3.new(1, 1, 1),
		Text = Texts.Get("PumpGod.Roll"),
		Visible = false,
		Parent = gui,
	})
	Ui.stroke(Color3.new(1, 1, 1), 2, 0.1).Parent = rollButton
	-- Voile sombre qui se vide pendant la recharge
	rollShade = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Parent = rollButton,
	}, { Ui.corner() })
	rollButton.Activated:Connect(roll)
	Ui.watchViewport(layout)
	gui.Parent = player:WaitForChild("PlayerGui")
end

-- ------------------------------------------------------------------ messages du serveur
local function clear()
	local current = fight
	if not current then
		return
	end
	for _, zone in current.zones do
		zone.Destroy()
	end
	for _, thing in current.things do
		thing:Destroy()
	end
	if current.god then
		current.god:Destroy()
	end
	fight = nil
	hud.Visible = false
	rollButton.Visible = false
end

local function findGod(message)
	local model = message.boss
	if typeof(model) ~= "Instance" then
		model = workspace:WaitForChild("ColosseumPumpGod", 5)
	end
	local current = fight
	if current and model and model:IsA("Model") and model.PrimaryPart and fight == current then
		current.god = God.new(model)
	end
end

local handlers = {}

function handlers.Start(message)
	clear()
	fight = {
		fighter = message.player,
		center = message.center,
		maxHp = message.maxHp,
		hp = message.hp,
		god = nil,
		zones = {},
		things = {},
	}
	task.spawn(findGod, message)
	if mine() then
		hud.Visible = true
		rollButton.Visible = UserInputService.TouchEnabled
		rollReadyAt = 0
		setHp(message.hp, message.maxHp)
		-- Caméra derrière lui, tournée vers la piste et le dieu (le serveur l'a téléporté face au centre)
		task.delay(0.15, function()
			local root = rootOf(player)
			local camera = workspace.CurrentCamera
			if root and camera then
				local ahead = (message.center - root.Position) * Vector3.new(1, 0, 1)
				ahead = if ahead.Magnitude > 1 then ahead.Unit else root.CFrame.LookVector
				local eye = root.Position - ahead * 9 + Vector3.new(0, 5, 0)
				camera.CFrame = CFrame.lookAt(eye, root.Position + ahead * 12)
			end
		end)
		showBanner(Texts.Get("PumpGod.Intro"), 3.5)
	elseif near(message.center) then
		showBanner(Texts.Get("PumpGod.Watching", { name = message.player.DisplayName }), 3)
	end
end

function handlers.Attack(message)
	local current = fight
	if not current then
		return
	end
	if current.god then
		current.god:Play(message.kind, message.start, message.impact)
	end
	if not near(current.center) then
		return
	end
	local id = message.id
	local life -- secondes (heure du serveur) pendant lesquelles la zone reste affichée
	if message.kind == "Bolt" then
		current.zones[id] = Zones.Circle(message.at, message.radius, message.start, message.impact)
		life = message.impact
		task.delay(math.max(message.impact - Zones.ServerNow(), 0), function()
			if fight == current then
				bolt(message.at, message.radius, if current.god then current.god:Hand("Right") else message.at)
			end
		end)
	elseif message.kind == "Dumbbell" then
		current.zones[id] = Zones.Band(message.a, message.b, message.width, message.start, message.impact)
		life = message.impact + (message.b - message.a).Magnitude / message.speed
		table.insert(current.things, dumbbell(message))
	elseif message.kind == "Wave" then
		current.zones[id] =
			Zones.Ring(message.at, message.start, message.impact, message.speed, message.thickness, message.maxRadius)
		life = message.impact + message.maxRadius / message.speed
		task.delay(math.max(message.impact - Zones.ServerNow(), 0), function()
			if fight == current then
				waveSlam(message.at)
			end
		end)
	end
	if life then
		task.delay(math.max(life - Zones.ServerNow(), 0) + 0.1, function()
			local zone = current.zones[id]
			if zone then
				current.zones[id] = nil
				zone.Destroy()
			end
		end)
	end
end

function handlers.Hit(message)
	local current = fight
	if not current then
		return
	end
	current.hp = message.hp
	if near(current.center) then
		floatDamage(message.player, message.damage)
	end
	if mine() then
		setHp(message.hp, current.maxHp)
		hurt()
	end
end

function handlers.Roll(message)
	-- Pour les autres : la roulade du combattant (sa position arrive déjà par le serveur)
	if message.player ~= player and fight and near(fight.center) and message.player.Character then
		rollSpin(message.player.Character)
	end
end

function handlers.End(message)
	local wasMine = mine()
	clear()
	if wasMine then
		local key = if message.reason == "Defeat" then "PumpGod.Defeat" else "PumpGod.Stopped"
		showBanner(Texts.Get(key), 4)
	end
end

function PumpGodController.Start()
	buildGui()
	Remotes.PumpGodUpdate.OnClientEvent:Connect(function(message)
		if typeof(message) ~= "table" then
			return
		end
		local handler = handlers[message.state]
		if handler then
			handler(message)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and table.find(ROLL_KEYS, input.KeyCode) then
			roll()
		end
	end)
	-- Le dieu s'anime avant la physique (écriture des os, D86) ; la recharge du bouton suit
	RunService.PreSimulation:Connect(function()
		local current = fight
		if not current then
			return
		end
		local god = current.god
		if god then
			if not god.model.Parent then
				current.god = nil
			else
				local root = rootOf(current.fighter)
				local target = if root then root.Position else nil
				god:Step(Zones.ServerNow(), target, target)
			end
		end
		if rollButton.Visible then
			local left = math.clamp((rollReadyAt - os.clock()) / ROLL.Cooldown, 0, 1)
			rollShade.Size = UDim2.fromScale(1, left)
		end
	end)
end

return PumpGodController
