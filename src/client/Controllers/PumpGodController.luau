-- Combat du Dieu du Pump au Colisée, côté client (D90, D91, D92). Le serveur (PumpGodService) décide de tout ; ici on
-- montre ce qu'il annonce (Remotes.PumpGodUpdate), à l'heure du serveur :
-- - zones au sol (PumpGod/Zones) et ce qui frappe ou sert à frapper (PumpGod/Fx) : éclairs, haltère, onde, cône,
--   javelot, disques dorés, cercle sacré, rayon de Mog ;
-- - le dieu animé (PumpGod/God) : glissades, poses d'attaque, essoufflement, recul, éjection, moquerie ;
-- - pour le combattant : vie du joueur et du dieu en bas de l'écran, bouton FLEX (F / Y à la manette) dont le texte
--   dit ce qu'il va faire, bouton ROULADE (Q / Ctrl gauche / X), conseils la première fois, flash rouge et petite
--   secousse quand il est touché (jamais de zoom) ;
-- - manches (titre, vie rendue, dieu géant en manche 3), finale (choc de rayons : FLEX sur le temps, le bouton bat la
--   mesure, la barre du dieu devient celle du choc), victoire en constellation ;
-- - pour les spectateurs proches : le même combat, un bandeau avec le nom du combattant, et le bouton ENCOURAGER avec
--   la jauge de la foule (jamais montrée au combattant) ; ce que fait la foule (amphore, pétales, chant) se voit sur la
--   piste.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Format = require(ReplicatedStorage.Shared.Format)
local PumpGod = require(ReplicatedStorage.Shared.Config.PumpGod)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Fx = require(script.Parent.Parent.PumpGod.Fx)
local God = require(script.Parent.Parent.PumpGod.God)
local Ui = require(script.Parent.Parent.Ui)
local Zones = require(script.Parent.Parent.PumpGod.Zones)

local player = Players.LocalPlayer
local ROLL = PumpGod.Roll
local ROLL_KEYS = { Enum.KeyCode.Q, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonX }
local FLEX_KEYS = { Enum.KeyCode.F, Enum.KeyCode.ButtonY }
local GOLD = Fx.Gold
local RED = Color3.fromRGB(255, 80, 60)
-- Barres de vie en bas au centre : le haut de l'écran est pris par le Mog, le Cash et l'objectif ; au téléphone, le
-- joystick est à gauche et les boutons à droite
local HUD_HOME = UDim2.new(0.5, 0, 1, -18)

type Fight = {
	fighter: Player,
	center: Vector3,
	maxHp: number,
	hp: number,
	god: any?,
	ended: boolean,
	zones: { [number]: { Destroy: () -> () } },
	things: { Instance },
	effects: { { Destroy: (any) -> () } },
	javelins: { [number]: any },
	discs: { [number]: any },
	discAt: { [number]: Vector3 },
	carrying: number?,
	sacred: { id: number, at: Vector3, radius: number, fx: any }?,
	windedUntil: number,
	beatFrom: number, -- fenêtre du 3e coup en rythme (heure locale)
	beatTo: number,
	tips: { [string]: boolean },
	round: number,
	finale: { beatStart: number, beat: number, fx: any }?,
	chantFx: { Destroy: (any) -> () }?,
	amphora: { id: number, fx: { Destroy: (any) -> () } }?,
	chant: boolean,
	crowd: number, -- jauge de la foule (spectateurs seulement)
	crowdStep: number,
	cheersLeft: number,
}

local fight: Fight? = nil
local rollReadyAt = 0
local rolling = false
local flexHeld: InputObject? = nil

-- Interface
local gui: ScreenGui
local hud: Frame
local hpFill: Frame
local hpText: TextLabel
local bossBar: Frame
local bossFill: Frame
local rollButton: TextButton
local rollShade: Frame
local flexButton: TextButton
local flexStroke: UIStroke
local banner: TextLabel
local flash: Frame
local cheerButton: TextButton
local cheerFill: Frame
local cheerLeft: TextLabel
local cheerPop = 0

local PumpGodController = {}

local function mine(): boolean
	return fight ~= nil and fight.fighter == player and not fight.ended
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

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function showBanner(text: string, time: number)
	banner.Text = text
	banner.Visible = true
	local stamp = os.clock()
	banner:SetAttribute("Stamp", stamp)
	task.delay(time, function()
		if banner:GetAttribute("Stamp") == stamp then
			banner.Visible = false
		end
	end)
end

-- Conseil la première fois qu'une façon de frapper apparaît dans ce combat
local function tip(key: string)
	local current = fight
	if current and current.fighter == player and not current.tips[key] then
		current.tips[key] = true
		showBanner(Texts.Get("PumpGod.Tip." .. key), 4)
	end
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

local function shakeIfNear(at: Vector3, distance: number, strength: number)
	local root = rootOf(player)
	if mine() and root and (root.Position - at).Magnitude < distance then
		shake(strength, 0.25)
	end
end

-- Poitrine du dieu, ou un point au-dessus de sa position au sol
local function godChest(current: Fight, fallback: Vector3): Vector3
	if current.god and current.god.model.Parent then
		return current.god:Chest()
	end
	return fallback + Vector3.new(0, 8, 0)
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

-- ------------------------------------------------------------------ bouton FLEX
local function flex(down: boolean)
	if mine() then
		Remotes.PumpGodFlex:FireServer(down)
	end
end

-- Ce que fera FLEX maintenant (même ordre que le serveur) : texte du bouton, et s'il faut le faire briller
local function flexContext(current: Fight, root: BasePart): (string, boolean)
	local now = Zones.ServerNow()
	if current.finale then
		return "PumpGod.Flex", false
	end
	local parry = PumpGod.Parry.Range * 1.6 * (if current.chant then PumpGod.Crowd.ChantRange else 1)
	for _, shot in current.javelins do
		if shot.flying and now > shot.impact then
			local s = (now - shot.impact) * shot.speed
			local tip_ = shot.at + shot.dir * s
			local ahead = flat(root.Position - shot.at):Dot(shot.dir) - s
			if ahead > -2 and flat(root.Position - tip_).Magnitude < parry then
				return "PumpGod.ParryNow", true
			end
		end
	end
	if now < current.windedUntil and current.god then
		local ground = current.god:Ground(now)
		local reach = if current.round == 3 then PumpGod.Winded.GiantRange else PumpGod.Winded.Range
		if flat(root.Position - ground).Magnitude < reach then
			return "PumpGod.PunchNow", true
		end
	end
	if current.carrying then
		return "PumpGod.ThrowNow", true
	end
	for _, at in current.discAt do
		if flat(root.Position - at).Magnitude < PumpGod.Disc.PickRange then
			return "PumpGod.GrabNow", true
		end
	end
	local sacred = current.sacred
	if sacred and flat(root.Position - sacred.at).Magnitude <= sacred.radius + 0.5 then
		return "PumpGod.HoldNow", true
	end
	return "PumpGod.Flex", false
end

-- ------------------------------------------------------------------ interface
local function setBar(fill: Frame, k: number)
	TweenService:Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(k, 1) }):Play()
end

local function setHp(hp: number, maxHp: number)
	local k = math.clamp(hp / math.max(maxHp, 1), 0, 1)
	setBar(hpFill, k)
	hpFill.BackgroundColor3 = if k > 0.5
		then Color3.fromRGB(110, 230, 110)
		elseif k > 0.25 then Color3.fromRGB(255, 200, 60)
		else Color3.fromRGB(255, 70, 60)
	hpText.Text = Texts.Get("PumpGod.Health", { hp = math.ceil(hp), max = maxHp })
end

local function hurt()
	flash.BackgroundTransparency = 0.55
	TweenService:Create(flash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
	task.spawn(function()
		for k = 1, 6 do
			hud.Position = HUD_HOME + UDim2.fromOffset((if k % 2 == 0 then 1 else -1) * (7 - k), 0)
			task.wait(0.03)
		end
		hud.Position = HUD_HOME
	end)
	shake(0.5, 0.3)
	-- Clignote pendant son invincibilité
	local character = player.Character
	if character then
		local stop = os.clock() + PumpGod.HitInvuln
		task.spawn(function()
			while os.clock() < stop and character.Parent do
				local hidden = math.floor(os.clock() * 12) % 2 == 0
				for _, p in character:GetDescendants() do
					if p:IsA("BasePart") then
						p.LocalTransparencyModifier = if hidden then 0.6 else 0
					end
				end
				task.wait(1 / 24)
			end
			for _, p in character:GetDescendants() do
				if p:IsA("BasePart") then
					p.LocalTransparencyModifier = 0
				end
			end
		end)
	end
end

local function layout()
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(800, 600)
	local phone = Ui.isPhonePortrait()
	local width = math.clamp(size.X * 0.55, 220, 380)
	hud.Size = UDim2.fromOffset(width, if phone then 30 else 34)
	bossBar.Size = UDim2.fromOffset(width, if phone then 24 else 26)
	-- ROULADE au-dessus de FLEX, à gauche du bouton de saut de Roblox et de celui de course (SprintController)
	local tall = not phone and size.X > size.Y and size.Y > 600
	rollButton.Position = if tall then UDim2.new(1, -112, 1, -230) else UDim2.new(1, -112, 1, -120)
	flexButton.Position = if tall then UDim2.new(1, -182, 1, -56) else UDim2.new(1, -110, 1, -22)
end

local function keyHint(button: TextButton, key: string)
	-- Touche du clavier en petit dans le coin (seulement s'il y a un clavier)
	Ui.label({
		Name = "Key",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 2),
		Size = UDim2.fromOffset(22, 18),
		Text = Texts.Get(key),
		TextColor3 = Color3.fromRGB(255, 240, 200),
		Visible = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled,
		ZIndex = 3,
		Parent = button,
	})
end

-- Spectateur : encourager le combattant (le serveur limite le rythme et le nombre)
local function cheer()
	local current = fight
	if not current or current.ended or current.fighter == player or current.cheersLeft <= 0 then
		return
	end
	Remotes.PumpGodCheer:FireServer()
	cheerPop = os.clock()
end

-- Le spectateur peut-il encourager (combat en cours, assez près de la piste) ?
local function canCheer(current: Fight): boolean
	local root = rootOf(player)
	return not current.ended
		and current.fighter ~= player
		and root ~= nil
		and flat(root.Position - current.center).Magnitude < PumpGod.Crowd.Range
end

local function buildGui()
	gui = Ui.create("ScreenGui", { Name = "PumpGod", ResetOnSpawn = false, DisplayOrder = 4 })
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
	-- Vie du dieu, juste au-dessus
	bossBar = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -60),
		BackgroundColor3 = Color3.fromRGB(25, 20, 35),
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(UDim.new(0.5, 0)), Ui.stroke(Color3.fromRGB(255, 120, 60), 2, 0.1) })
	bossFill = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 140, 40),
		BorderSizePixel = 0,
		Parent = bossBar,
	}, { Ui.corner(UDim.new(0.5, 0)), Ui.gradient(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 110, 30)) })
	Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		Text = Texts.Get("PumpGod.Name"),
		ZIndex = 2,
		Parent = bossBar,
	})
	banner = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(0.86, 0, 0, 44),
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
		Text = Texts.Get("PumpGod.Roll"),
		Visible = false,
		Parent = gui,
	})
	Ui.stroke(Color3.new(1, 1, 1), 2, 0.1).Parent = rollButton
	keyHint(rollButton, "PumpGod.KeyRoll")
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
	flexButton = Ui.button({
		Name = "Flex",
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(90, 90),
		BackgroundColor3 = Color3.fromRGB(255, 175, 35),
		TextColor3 = Color3.fromRGB(40, 25, 10),
		Text = Texts.Get("PumpGod.Flex"),
		Visible = false,
		Parent = gui,
	})
	flexStroke = Ui.stroke(Color3.new(1, 1, 1), 3, 0.1)
	flexStroke.Parent = flexButton
	keyHint(flexButton, "PumpGod.KeyFlex")
	rollButton.Activated:Connect(roll)
	-- FLEX se maintient (pose sacrée) : appui et relâché
	flexButton.InputBegan:Connect(function(input)
		if
			(input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1)
			and not flexHeld
		then
			flexHeld = input
			flex(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input == flexHeld then
			flexHeld = nil
			flex(false)
		end
	end)
	-- Spectateurs : ENCOURAGER, avec la jauge de la foule dessous
	cheerButton = Ui.button({
		Name = "Cheer",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -110, 1, -40),
		Size = UDim2.fromOffset(120, 64),
		BackgroundColor3 = Color3.fromRGB(255, 120, 170),
		Text = Texts.Get("PumpGod.Cheer"),
		Visible = false,
		Parent = gui,
	})
	Ui.stroke(Color3.new(1, 1, 1), 3, 0.1).Parent = cheerButton
	keyHint(cheerButton, "PumpGod.KeyFlex")
	local gauge = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 6),
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = Color3.fromRGB(25, 20, 35),
		BackgroundTransparency = 0.2,
		Parent = cheerButton,
	}, { Ui.corner(UDim.new(0.5, 0)) })
	cheerFill = Ui.create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		Parent = gauge,
	}, { Ui.corner(UDim.new(0.5, 0)) })
	cheerLeft = Ui.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -4),
		Size = UDim2.new(1.3, 0, 0, 18),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 240, 200),
		Parent = cheerButton,
	})
	cheerButton.Activated:Connect(cheer)
	Ui.watchViewport(layout)
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function showControls(visible: boolean)
	hud.Visible = visible
	bossBar.Visible = visible
	rollButton.Visible = visible and not (fight and fight.finale)
	flexButton.Visible = visible
	if not visible and flexHeld then
		flexHeld = nil
	end
end

-- ------------------------------------------------------------------ messages du serveur
local function clearField(current: Fight)
	for _, zone in current.zones do
		zone.Destroy()
	end
	table.clear(current.zones)
	for _, thing in current.things do
		thing:Destroy()
	end
	table.clear(current.things)
	for _, effect in current.effects do
		effect:Destroy()
	end
	table.clear(current.effects)
	for _, shot in current.javelins do
		shot.fx:Destroy()
	end
	table.clear(current.javelins)
	for _, disc in current.discs do
		disc:Destroy()
	end
	table.clear(current.discs)
	table.clear(current.discAt)
	if current.sacred then
		current.sacred.fx:Destroy()
		current.sacred = nil
	end
	if current.amphora then
		current.amphora.fx:Destroy()
		current.amphora = nil
	end
	current.carrying = nil
	current.windedUntil = 0
end

local function clear()
	local current = fight
	if not current then
		return
	end
	clearField(current)
	if current.god then
		current.god:Destroy()
	end
	if current.chantFx then
		current.chantFx:Destroy()
	end
	fight = nil
	showControls(false)
	cheerButton.Visible = false
end

local function findGod(message)
	local model = message.boss
	if typeof(model) ~= "Instance" then
		model = workspace:WaitForChild("ColosseumPumpGod", 5)
	end
	local current = fight
	if current and model and model:IsA("Model") and model.PrimaryPart and fight == current then
		current.god = God.new(model, message.bossAt)
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
		ended = false,
		zones = {},
		things = {},
		effects = {},
		javelins = {},
		discs = {},
		discAt = {},
		carrying = nil,
		sacred = nil,
		windedUntil = 0,
		beatFrom = 0,
		beatTo = 0,
		tips = {},
		round = 1,
		finale = nil,
		chantFx = nil,
		amphora = nil,
		chant = false,
		crowd = 0,
		crowdStep = PumpGod.Crowd.Step,
		cheersLeft = PumpGod.Crowd.Max,
	}
	task.spawn(findGod, message)
	if mine() then
		showControls(true)
		rollReadyAt = 0
		setHp(message.hp, message.maxHp)
		bossFill.Size = UDim2.fromScale(1, 1)
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

function handlers.Move(message)
	local current = fight
	if current and current.god then
		current.god:MoveTo(message.from, message.to, message.start, message.arrive)
	end
end

local function removeZone(current: Fight, id: number, at: number)
	task.delay(math.max(at - Zones.ServerNow(), 0) + 0.1, function()
		local zone = current.zones[id]
		if zone then
			current.zones[id] = nil
			zone.Destroy()
		end
	end)
end

local function atImpact(current: Fight, impact: number, callback: () -> ())
	task.delay(math.max(impact - Zones.ServerNow(), 0), function()
		if fight == current and not current.ended then
			callback()
		end
	end)
end

function handlers.Attack(message)
	local current = fight
	if not current or current.ended then
		return
	end
	if current.god then
		current.god:Play(message.kind, message.start, message.impact)
	end
	if not near(current.center) then
		return
	end
	local id = message.id
	local kind = message.kind
	if kind == "Bolt" then
		current.zones[id] = Zones.Circle(message.at, message.radius, message.start, message.impact)
		removeZone(current, id, message.impact)
		atImpact(current, message.impact, function()
			Fx.Bolt(message.at, message.radius, if current.god then current.god:Hand("Right") else message.at)
			shakeIfNear(message.at, 30, 0.35)
		end)
	elseif kind == "Dumbbell" then
		current.zones[id] = Zones.Band(message.a, message.b, message.width, message.start, message.impact)
		removeZone(current, id, message.impact + (message.b - message.a).Magnitude / message.speed)
		table.insert(
			current.things,
			Fx.Dumbbell(message, function()
				return fight == current
			end, function()
				shakeIfNear(message.a, 40, 0.25)
			end)
		)
	elseif kind == "Wave" then
		current.zones[id] =
			Zones.Ring(message.at, message.start, message.impact, message.speed, message.thickness, message.maxRadius)
		removeZone(current, id, message.impact + message.maxRadius / message.speed)
		atImpact(current, message.impact, function()
			Fx.GroundBurst(message.at, 10, 26, GOLD)
			shakeIfNear(message.at, 80, 0.3)
		end)
	elseif kind == "Slam" then
		current.zones[id] =
			Zones.Cone(message.at, message.dir, message.angle, message.length, message.start, message.impact)
		removeZone(current, id, message.impact)
		atImpact(current, message.impact, function()
			local fist = message.at + message.dir * 5
			Fx.GroundBurst(fist, 6, message.length * 1.2, Color3.fromRGB(230, 200, 150), 0.6)
			Fx.GroundBurst(fist, 4, 14, GOLD, 0.35)
			shakeIfNear(message.at, 60, 0.45)
		end)
	elseif kind == "Javelin" then
		-- Bande fine jusqu'au mur ; le javelot dans sa main, puis lancé
		local b = message.at + message.dir * message.length
		current.zones[id] = Zones.Band(message.at, b, message.radius * 2, message.start, message.impact)
		removeZone(current, id, message.impact + message.length / message.speed)
		local god = current.god
		local fx = Fx.Javelin(message, function()
			return if god and god.model.Parent then god:Hand("Right") else message.at + Vector3.new(0, 10, 0)
		end)
		current.javelins[id] = {
			fx = fx,
			at = message.at,
			dir = message.dir,
			speed = message.speed,
			impact = message.impact,
			flying = true,
		}
		task.delay(math.max(message.impact + message.length / message.speed - Zones.ServerNow(), 0) + 0.3, function()
			current.javelins[id] = nil
		end)
		tip("Javelin")
	elseif kind == "Column" then
		current.zones[id] = Zones.Band(message.a, message.b, message.width, message.start, message.impact)
		removeZone(current, id, message.impact)
		local column = Fx.Column(message.a, message.b, message.width, message.start, message.impact, function()
			return fight == current and not current.ended
		end)
		table.insert(current.effects, column)
		atImpact(current, message.impact, function()
			shakeIfNear((message.a + message.b) / 2, 40, 0.35)
		end)
	elseif kind == "Tiles" then
		current.zones[id] = Zones.Tiles(message.cells, message.cell, message.start, message.impact)
		removeZone(current, id, message.impact)
		atImpact(current, message.impact, function()
			Fx.TileBurst(message.cells, message.cell)
			shakeIfNear(current.center, 80, 0.25)
		end)
		tip("Tiles")
	elseif kind == "Chariot" then
		current.zones[id] = Zones.Band(message.a, message.b, message.width, message.start, message.impact)
		removeZone(current, id, message.impact + (message.b - message.a).Magnitude / message.speed)
		table.insert(
			current.things,
			Fx.Chariot(message, function()
				return fight == current
			end, function()
				shakeIfNear(message.a, 40, 0.3)
			end)
		)
	elseif kind == "Leap" then
		local fighter = current.fighter
		current.zones[id] = Zones.Chase(function()
			local root = rootOf(fighter)
			return if root then Vector3.new(root.Position.X, message.at.Y, root.Position.Z) else nil
		end, message.radius, message.start, message.impact)
		removeZone(current, id, message.impact)
		if current.god then
			current.god:Leap(message.start, message.rise, message.lock, message.impact)
		end
		atImpact(current, message.impact, function()
			local god = current.god
			local at = if god then god:Ground(Zones.ServerNow()) else message.at
			Fx.GroundBurst(at, 6, message.radius * 3, Color3.fromRGB(230, 200, 150), 0.6)
			Fx.GroundBurst(at, 4, message.radius * 2, GOLD, 0.4)
			shakeIfNear(at, 90, 0.6)
		end)
		tip("Leap")
	elseif kind == "Storm" then
		current.zones[id] =
			Zones.Storm(message.at, message.radius, message.safes, message.safeRadius, message.start, message.impact)
		removeZone(current, id, message.impact)
		atImpact(current, message.impact, function()
			local hand = if current.god then current.god:Hand("Right") else message.at + Vector3.new(0, 30, 0)
			Fx.Storm(message.at, message.radius, message.safes, message.safeRadius, hand)
			shakeIfNear(current.center, 120, 0.45)
		end)
		tip("Storm")
	elseif kind == "Gaze" then
		current.zones[id] = Zones.Sweep(
			message.at,
			message.from,
			message.to,
			message.width,
			message.length,
			message.start,
			message.impact,
			message.ends
		)
		removeZone(current, id, message.ends)
		local god = current.god
		table.insert(
			current.effects,
			Fx.Gaze(function()
				return if god and god.model.Parent then god:Eyes() else message.at + Vector3.new(0, 25, 0)
			end, message.at, message.from, message.to, message.length, message.impact, message.ends)
		)
		tip("Gaze")
	end
end

function handlers.LeapLock(message)
	local current = fight
	if not current or current.ended then
		return
	end
	local zone = current.zones[message.id]
	if zone and zone.Lock then
		zone.Lock(message.at)
	end
	local god = current.god
	if god then
		god:MoveTo(god:Ground(message.lock), message.at, message.lock, message.impact)
	end
end

-- Nouvelle manche : le terrain se vide, titre, vie rendue ; le dieu se replace (ou revient en géant)
function handlers.Round(message)
	local current = fight
	if not current or current.ended then
		return
	end
	clearField(current)
	current.round = message.round
	current.hp = message.hp
	local god = current.god
	if typeof(message.boss) == "Instance" and (not god or god.model ~= message.boss) then
		if god then
			god:Destroy()
			current.god = nil
		end
		task.spawn(findGod, message)
	elseif god then
		god:MoveTo(god:Ground(message.start), message.bossAt, message.start, message.start + 1.2)
	end
	if near(current.center) then
		showBanner(Texts.Get(message.title), 3.5)
		shakeIfNear(current.center, 200, 0.3)
	end
	if current.fighter == player then
		setHp(message.hp, message.maxHp)
		setBar(bossFill, 1)
	end
end

local function fighterChest(current: Fight): Vector3?
	local root = rootOf(current.fighter)
	return if root then root.Position + Vector3.new(0, 1.5, 0) else nil
end

-- Finale : le combattant ne bouge plus ; rayon contre éclair
function handlers.Finale(message)
	local current = fight
	if not current or current.ended then
		return
	end
	clearField(current)
	local god = current.god
	if god then
		god:Clash(true)
	end
	current.finale = {
		beatStart = message.beatStart,
		beat = message.beat,
		fx = if near(current.center)
			then Fx.Clash(function()
				return fighterChest(current)
			end, function()
				local g = current.god
				return if g and g.model.Parent then g:Hand("Right") else nil
			end)
			else nil,
	}
	if current.finale.fx then
		table.insert(current.effects, current.finale.fx)
	end
	if near(current.center) then
		showBanner(Texts.Get("PumpGod.Finale"), 2.5)
	end
	if current.fighter == player then
		rollButton.Visible = false
		bossFill.Size = UDim2.fromScale(message.k, 1)
		task.delay(2.5, function()
			tip("Finale")
		end)
	end
end

function handlers.Clash(message)
	local current = fight
	local finale = current and current.finale
	if not current or not finale then
		return
	end
	if finale.fx then
		finale.fx:Set(message.k)
	end
	if current.fighter == player then
		setBar(bossFill, message.k)
	end
end

function handlers.Pulse(message)
	local current = fight
	local finale = current and current.finale
	if not current or not finale then
		return
	end
	if finale.fx then
		finale.fx:Set(message.k)
		if message.good then
			finale.fx:Pulse()
		end
	end
	if current.fighter == player then
		setBar(bossFill, message.k)
		local root = rootOf(player)
		if root then
			Fx.Float(
				root.Position + Vector3.new(0, 4, 0),
				Texts.Get(if message.good then "PumpGod.Perfect" else "PumpGod.Miss"),
				if message.good then GOLD else RED,
				if message.good then 130 else 80
			)
		end
		if message.good then
			shake(0.15, 0.1)
		end
	end
end

-- ------------------------------------------------------------------ foule
local function crowdBanner(key: string)
	local current = fight
	if current and near(current.center) then
		showBanner(Texts.Get(key), 2.5)
	end
end

function handlers.Crowd(message)
	local current = fight
	if not current or current.fighter == player then
		return
	end
	current.crowd = message.gauge
	current.crowdStep = message.step
	current.cheersLeft = message.left
	setBar(cheerFill, math.clamp(message.gauge / math.max(message.step, 1), 0, 1))
	cheerLeft.Text = Texts.Get("PumpGod.CheerLeft", { left = message.left })
end

function handlers.Amphora(message)
	local current = fight
	if not current or current.ended then
		return
	end
	if current.amphora then
		current.amphora.fx:Destroy()
	end
	current.amphora = {
		id = message.id,
		fx = if near(current.center) then Fx.Amphora(message.at) else { Destroy = function() end },
	}
	crowdBanner("PumpGod.Crowd.Amphora")
end

function handlers.AmphoraGone(message)
	local current = fight
	if current and current.amphora and current.amphora.id == message.id then
		current.amphora.fx:Destroy()
		current.amphora = nil
	end
end

function handlers.Heal(message)
	local current = fight
	if not current or current.ended then
		return
	end
	handlers.AmphoraGone(message)
	current.hp = message.hp
	local root = rootOf(message.player)
	if root and near(current.center) then
		Fx.GroundBurst(root.Position - Vector3.new(0, 2.8, 0), 3, 12, Color3.fromRGB(255, 140, 200), 0.5)
		Fx.Float(
			root.Position + Vector3.new(0, 4, 0),
			Texts.Get("PumpGod.Heal", { hp = message.amount }),
			Color3.fromRGB(110, 230, 110),
			110
		)
	end
	if current.fighter == player then
		setHp(message.hp, current.maxHp)
	end
end

function handlers.Petals(message)
	local current = fight
	local god = current and current.god
	if not current or current.ended then
		return
	end
	if god and near(current.center) then
		Fx.Petals(function()
			return god:Top()
		end, message.ends)
	end
	crowdBanner("PumpGod.Crowd.Petals")
end

function handlers.Chant()
	local current = fight
	if not current or current.ended then
		return
	end
	current.chant = true
	if not current.chantFx and near(current.center) then
		local fighter = current.fighter
		current.chantFx = Fx.Chant(function()
			return rootOf(fighter)
		end)
	end
	crowdBanner("PumpGod.Crowd.Chant")
end

function handlers.ChantUsed()
	local current = fight
	if not current then
		return
	end
	current.chant = false
	if current.chantFx then
		current.chantFx:Destroy()
		current.chantFx = nil
	end
end

function handlers.Hit(message)
	local current = fight
	if not current or current.ended then
		return
	end
	current.hp = message.hp
	local root = rootOf(message.player)
	if root and near(current.center) then
		Fx.Float(
			root.Position + Vector3.new(0, 4, 0),
			Texts.Get("PumpGod.Damage", { damage = message.damage }),
			RED,
			90
		)
	end
	if mine() then
		setHp(message.hp, current.maxHp)
		hurt()
	end
end

function handlers.BossHit(message)
	local current = fight
	if not current then
		return
	end
	if current.fighter == player then
		setBar(bossFill, math.clamp(message.hp / math.max(message.maxHp, 1), 0, 1))
	end
	local god = current.god
	if god then
		god:Hurt(if message.kind == "PowerPunch" or message.kind == "Beam" then 1.5 else 1)
		if near(current.center) then
			local chest = god:Chest()
			Fx.Impact(chest, if message.kind == "PowerPunch" or message.kind == "Beam" then 2 else 1)
			Fx.Float(chest + Vector3.new(0, 3, 0), Texts.Get("PumpGod.Damage", { damage = message.damage }), GOLD)
		end
	end
end

function handlers.Winded(message)
	local current = fight
	if not current or current.ended then
		return
	end
	current.windedUntil = message.ends
	local god = current.god
	if god then
		god:Winded(message.start, message.ends)
		if near(current.center) then
			table.insert(
				current.effects,
				Fx.Stars(function()
					return god:Top()
				end, message.ends)
			)
		end
	end
	tip("Winded")
end

function handlers.Punch(message)
	local current = fight
	if not current or current.ended then
		return
	end
	local root = rootOf(message.player)
	if message.player.Character and near(current.center) then
		-- Petit élan vers l'avant du personnage (local)
		local god = current.god
		if root and god then
			local chest = god:Chest()
			Fx.Impact(root.Position:Lerp(chest, 0.5), 0.6)
		end
	end
	if message.power then
		if current.god and near(current.center) then
			Fx.Float(current.god:Chest() + Vector3.new(0, 6, 0), Texts.Get("PumpGod.PowerPunch"), GOLD, 170)
		end
		shakeIfNear(current.center, 200, 0.4)
	end
	if current.fighter == player then
		if message.combo == 2 then
			-- Le 3e coup en rythme : le bouton brille pendant la bonne fenêtre
			current.beatFrom = os.clock() + PumpGod.Punch.BeatFrom
			current.beatTo = os.clock() + PumpGod.Punch.BeatTo
			tip("Beat")
		else
			current.beatFrom, current.beatTo = 0, 0
		end
	end
end

function handlers.Parry(message)
	local current = fight
	if not current then
		return
	end
	local shot = current.javelins[message.id]
	if shot then
		shot.flying = false
		shot.fx:Reverse(message.from, function()
			return godChest(current, message.to)
		end, message.start, message.arrive)
	end
	local zone = current.zones[message.id]
	if zone then
		current.zones[message.id] = nil
		zone.Destroy()
	end
	if near(current.center) then
		Fx.Impact(message.from + Vector3.new(0, 3, 0), 1)
	end
	if current.fighter == player then
		shake(0.2, 0.15)
	end
end

function handlers.Disc(message)
	local current = fight
	if not current or current.ended then
		return
	end
	current.discAt[message.id] = message.at
	if near(current.center) then
		current.discs[message.id] = Fx.Disc(message.at)
		Fx.GroundBurst(message.at, 2, 8, GOLD, 0.4)
	end
	tip("Disc")
end

function handlers.DiscGone(message)
	local current = fight
	if not current then
		return
	end
	current.discAt[message.id] = nil
	local disc = current.discs[message.id]
	if disc then
		current.discs[message.id] = nil
		disc:Destroy()
	end
end

function handlers.DiscPick(message)
	local current = fight
	if not current then
		return
	end
	current.discAt[message.id] = nil
	if current.fighter == player then
		current.carrying = message.id
	end
	local disc = current.discs[message.id]
	if disc then
		disc:Carry(function()
			return rootOf(message.player)
		end)
	end
end

function handlers.DiscThrow(message)
	local current = fight
	if not current then
		return
	end
	if current.fighter == player then
		current.carrying = nil
	end
	local disc = current.discs[message.id]
	if disc then
		current.discs[message.id] = nil
		disc:Throw(message.from, function()
			return godChest(current, message.to)
		end, message.start, message.arrive, function() end)
	end
end

function handlers.Sacred(message)
	local current = fight
	if not current or current.ended then
		return
	end
	if current.sacred then
		current.sacred.fx:Destroy()
	end
	current.sacred = {
		id = message.id,
		at = message.at,
		radius = message.radius,
		fx = if near(current.center) then Fx.Sacred(message.at, message.radius) else { Destroy = function() end },
	}
	tip("Sacred")
end

function handlers.SacredGone(message)
	local current = fight
	if current and current.sacred and current.sacred.id == message.id then
		current.sacred.fx:Destroy()
		current.sacred = nil
	end
end

function handlers.Charge(message)
	local current = fight
	local sacred = current and current.sacred
	if sacred and sacred.fx.SetCharge then
		if message.cancel then
			sacred.fx:SetCharge(nil, nil)
		else
			sacred.fx:SetCharge(message.start, message.ends)
		end
	end
end

function handlers.Beam(message)
	local current = fight
	if not current then
		return
	end
	if current.sacred and current.sacred.id == message.id then
		current.sacred.fx:Destroy()
		current.sacred = nil
	end
	if near(current.center) then
		Fx.Beam(message.from + Vector3.new(0, 2, 0), godChest(current, message.to))
	end
	shakeIfNear(current.center, 200, 0.35)
end

function handlers.Roll(message)
	-- Pour les autres : la roulade du combattant (sa position arrive déjà par le serveur)
	if message.player ~= player and fight and near(fight.center) and message.player.Character then
		rollSpin(message.player.Character)
	end
end

function handlers.End(message)
	local current = fight
	if not current then
		return
	end
	local wasMine = current.fighter == player
	current.ended = true
	clearField(current)
	showControls(false)
	local god = current.god
	if message.reason == "Victory" then
		if god and god.rig and near(current.center) then
			-- Il devient une constellation qui pose (double biceps) au-dessus du Colisée
			god:Clash(false)
			god:Taunt()
			god:Step(Zones.ServerNow(), nil)
			local points = god:Skeleton()
			god.taunting = false
			local pivot = god.model:GetPivot().Position
			local sky = current.center + Vector3.new(0, 110, 0)
			local scale = 60 / math.max(god.height, 1)
			for name, at in points do
				points[name] = sky + (at - pivot) * scale
			end
			task.delay(2.2, function()
				Fx.Constellation(points, God.Links, 14)
			end)
		end
		if god then
			god:Clash(false)
			god:Eject()
			if near(current.center) then
				Fx.Impact(god:Chest(), 3)
			end
		end
		if wasMine then
			showBanner(Texts.Get("PumpGod.Victory"), 5)
		elseif near(current.center) then
			showBanner(Texts.Get("PumpGod.VictoryWatch", { name = message.player.DisplayName }), 4)
		end
	elseif message.reason == "Defeat" then
		if god then
			god:Taunt()
		end
		if wasMine then
			local text = if (message.mogLost or 0) > 0
				then Texts.Get("PumpGod.DefeatMog", { mog = Format.Short(message.mogLost) })
				else Texts.Get("PumpGod.Defeat")
			showBanner(text, 5)
		end
	elseif wasMine then
		showBanner(Texts.Get("PumpGod.Stopped"), 3)
	end
	-- Le dieu reste animé jusqu'à ce que le serveur le retire
	task.delay(PumpGod.EndDelay + 0.5, function()
		if fight == current then
			clear()
		end
	end)
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
		if processed then
			return
		end
		if table.find(ROLL_KEYS, input.KeyCode) then
			roll()
		elseif table.find(FLEX_KEYS, input.KeyCode) and not flexHeld then
			if mine() then
				flexHeld = input
				flex(true)
			elseif fight and cheerButton.Visible then
				cheer()
			end
		end
	end)
	-- Le dieu s'anime avant la physique (écriture des os, D86) ; puis les boutons
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
				god:Step(Zones.ServerNow(), if root then root.Position else nil)
			end
		end
		-- Spectateur : bouton ENCOURAGER (il gonfle un instant à chaque appui ; gris quand il n'en reste plus)
		local cheering = canCheer(current)
		cheerButton.Visible = cheering
		if cheering then
			local pop = math.max(1 - (os.clock() - cheerPop) / 0.2, 0)
			cheerButton.Size = UDim2.fromOffset(120 + 12 * pop, 64 + 8 * pop)
			cheerButton.BackgroundColor3 = if current.cheersLeft > 0
				then Color3.fromRGB(255, 120, 170)
				else Color3.fromRGB(120, 110, 120)
		end
		if not flexButton.Visible then
			return
		end
		local left = math.clamp((rollReadyAt - os.clock()) / ROLL.Cooldown, 0, 1)
		rollShade.Size = UDim2.fromScale(1, left)
		local root = rootOf(player)
		if root then
			local key, ready = flexContext(current, root)
			flexButton.Text = Texts.Get(key)
			local now = os.clock()
			local beat = now >= current.beatFrom and now <= current.beatTo
			local finale = current.finale
			if finale then
				-- Finale : le bouton bat la mesure (il brille pendant la fenêtre de chaque temps)
				local t = Zones.ServerNow()
				local phase = ((t - finale.beatStart) / finale.beat) % 1
				beat = t >= finale.beatStart - 0.1 and math.min(phase, 1 - phase) * finale.beat <= PumpGod.Finale.Window
			end
			local glow = beat or (ready and math.floor(now * 6) % 2 == 0)
			flexStroke.Color = if beat then GOLD elseif glow then Color3.fromRGB(255, 255, 200) else Color3.new(1, 1, 1)
			flexStroke.Thickness = if beat then 6 elseif glow then 4 else 3
			flexButton.BackgroundColor3 = if ready or beat
				then Color3.fromRGB(255, 205, 60)
				else Color3.fromRGB(255, 175, 35)
		end
	end)
end

return PumpGodController
