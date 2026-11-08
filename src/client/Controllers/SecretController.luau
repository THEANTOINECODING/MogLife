-- Secrets de la ville (D121, scènes refaites en D122), côté client : l'annonce « SECRET FOUND » pour celui qui le
-- trouve (Remotes.SecretFound) et les scènes vues par tous (Remotes.SecretFx). Celui qui trouve le secret a en plus
-- un court plan de caméra (CutsceneController, qu'on peut passer).
-- - GhostLifter : un fantôme apparaît, attrape l'haltère fantôme, enchaîne trois curls, dit « booo... nice form » et
--   s'envole en tournoyant avant de se dissoudre.
-- - StatueBeliever : chaque tape fait trembler la statue (sans rien révéler) ; à la dixième, elle se tourne vers le
--   joueur, cligne de l'œil et fait un double biceps, avec une onde dorée.
-- - SewerGains : vapeur et lueur verte sous la plaque, le rat compte ses pompes, se dresse et gonfle les bras.
-- - NeverForget : la glace du coiffeur scintille, le reflet du Normie apparaît, fait coucou puis se dissout.
-- Purement visuel : le serveur a déjà tout validé (SecretService).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Secrets = require(ReplicatedStorage.Shared.Config.Secrets)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Outfit = require(ReplicatedStorage.Shared.Outfit)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local GOLD = Color3.fromRGB(255, 210, 60)
local GHOST_BLUE = Color3.fromRGB(170, 220, 255)
local SEWER_GREEN = Color3.fromRGB(120, 255, 120)
local MAX_DISTANCE = 150
local ICONS = { GhostLifter = "👻", StatueBeliever = "🗿", SewerGains = "🐀", NeverForget = "🪞" }

local player = Players.LocalPlayer

local MinigameController
local CutsceneController
local SoundController

local banner: Frame
local bannerBack: Frame
local bannerIcon: TextLabel
local bannerTitle: TextLabel
local bannerSub: TextLabel
local bannerCount: TextLabel
local bannerRays: Frame
local bannerToken = 0

local SecretController = {}
SecretController.Shown = 0 -- scènes jouées (tests dans Studio)

local function near(position: Vector3): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude <= MAX_DISTANCE
end

local function ease(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function sfx(name: string, pitch: number?)
	if SoundController then
		SoundController.Play(name, pitch)
	end
end

local function fxPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Name = "SecretFx"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = props.Parent or workspace
	return part
end

-- Point invisible dans le monde (support de bulle ou de particules), détruit après `life` secondes
local function anchorAt(position: Vector3, life: number): Part
	local part = fxPart({ Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), Position = position })
	task.delay(life, function()
		part:Destroy()
	end)
	return part
end

-- Ellipsoïde (pièce + maillage sphérique) : corps du fantôme, yeux de la statue
local function ellipsoid(
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	transparency: number
): (Part, SpecialMesh)
	local part = fxPart({
		Size = size,
		Color = color,
		Material = material,
		Transparency = transparency,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part, mesh
end

local function burst(at: BasePart, texture: string, color: Color3, count: number, size: number, speed: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.5
	emitter.Size = NumberSequence.new(size, size * 1.6)
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 3
	emitter.Rate = 0
	emitter.Parent = at
	emitter:Emit(count)
end

-- Jet continu (vapeur de l'égout, traînée du fantôme), arrêté au bout de `life` secondes (nil : jamais)
local function stream(
	at: BasePart,
	texture: string,
	color: Color3,
	rate: number,
	size: number,
	up: number,
	life: number?
)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.3
	emitter.Size = NumberSequence.new(size * 0.6, size * 1.8)
	emitter.Transparency = NumberSequence.new(0.35, 1)
	emitter.Lifetime = NumberRange.new(0.9, 1.6)
	emitter.Speed = NumberRange.new(up * 0.6, up)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.SpreadAngle = Vector2.new(18, 18)
	emitter.Rate = rate
	emitter.Parent = at
	if life then
		task.delay(life, function()
			emitter.Enabled = false
		end)
	end
	return emitter
end

-- Onde au sol : un disque lumineux qui s'élargit et s'efface
local function shockwave(position: Vector3, color: Color3, radius: number, duration: number)
	local disc = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, 1, 1),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	})
	local tween = TweenService:Create(disc, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.12, radius * 2, radius * 2),
		Transparency = 1,
	})
	tween.Completed:Connect(function()
		disc:Destroy()
	end)
	tween:Play()
end

local function light(parent: Instance, color: Color3, brightness: number, range: number, life: number): PointLight
	local point = Instance.new("PointLight")
	point.Color = color
	point.Brightness = brightness
	point.Range = range
	point.Shadows = false
	point.Parent = parent
	task.delay(life, function()
		TweenService:Create(point, TweenInfo.new(0.4), { Brightness = 0 }):Play()
	end)
	return point
end

-- Bulle de parole au-dessus d'une pièce, qui s'ouvre en rebondissant et disparaît d'elle-même
local function bubble(adornee: BasePart, text: string, height: number, duration: number)
	local billboard = Ui.create("BillboardGui", {
		Name = "SecretBubble",
		Size = UDim2.fromOffset(0, 0),
		StudsOffsetWorldSpace = Vector3.new(0, height, 0),
		AlwaysOnTop = true,
		MaxDistance = 90,
		Adornee = adornee,
		Parent = adornee,
	})
	local frame = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = billboard,
	}, { Ui.corner(UDim.new(0, 16)), Ui.stroke(Color3.fromRGB(40, 35, 55), 3, 0) })
	Ui.label({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 1, -12),
		TextColor3 = Color3.fromRGB(30, 28, 40),
		TextStrokeTransparency = 1,
		Text = text,
		Parent = frame,
	})
	TweenService:Create(billboard, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(250, 66) })
		:Play()
	task.delay(duration, function()
		local close = TweenService:Create(billboard, TweenInfo.new(0.2), { Size = UDim2.fromOffset(0, 0) })
		close.Completed:Connect(function()
			billboard:Destroy()
		end)
		close:Play()
	end)
end

-- Petit symbole (émoji, chiffre) qui jaillit au-dessus d'une pièce puis s'efface
local function pop(adornee: BasePart, text: string, height: number, color: Color3?)
	local billboard = Ui.create("BillboardGui", {
		Size = UDim2.fromOffset(70, 70),
		StudsOffsetWorldSpace = Vector3.new(0, height, 0),
		AlwaysOnTop = true,
		MaxDistance = 90,
		Adornee = adornee,
		Parent = adornee,
	})
	local label = Ui.label({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = color or Color3.new(1, 1, 1),
		Parent = billboard,
	})
	local scale = Ui.create("UIScale", { Scale = 0.2, Parent = label })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(billboard, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(0, height + 1.4, 0),
	}):Play()
	task.delay(0.5, function()
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(0.85, function()
		billboard:Destroy()
	end)
end

-- Animation image par image pendant `duration` secondes : step(t, dt) ; fin : done()
local function animate(duration: number, step: (number, number) -> (), done: (() -> ())?)
	local start = os.clock()
	local last = start
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local t = now - start
		local ok = pcall(step, math.min(t, duration), now - last)
		last = now
		if not ok or t >= duration then
			connection:Disconnect()
			if done then
				done()
			end
		end
	end)
end

-- Est-ce à ce joueur de voir le plan de caméra du secret ? (celui qui l'a trouvé, s'il n'est pas déjà occupé)
local function isFinder(data): boolean
	return data.player == player and not MinigameController.IsGameplayLocked() and not CutsceneController.IsPlaying()
end

-- Teinte d'ambiance pour celui qui a trouvé le secret, le temps de la scène (D122)
local function mood(color: Color3, duration: number)
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "SecretMood"
	effect.Parent = Lighting
	local info = TweenInfo.new(0.35)
	TweenService:Create(effect, info, { TintColor = color, Saturation = 0.15, Contrast = 0.1 }):Play()
	task.delay(math.max(duration - 0.4, 0.1), function()
		local back =
			TweenService:Create(effect, info, { TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0 })
		back.Completed:Connect(function()
			effect:Destroy()
		end)
		back:Play()
	end)
end

-- Point de vue dégagé (ni mur, ni joueur) pour filmer `focus`, en partant de `eye`
local function eyeOn(focus: Vector3, eye: Vector3, ignore: { Instance }): Vector3
	return CutsceneController.FindEye(focus, eye, ignore)
end

-- Plan de caméra pour celui qui a trouvé le secret (jamais pendant une série ou une autre cinématique), puis retour
-- en douceur à sa caméra. Chaque plan donne son sujet (focus) : son personnage s'efface s'il le cache.
local function film(data, shots: { any }, tint: Color3?)
	if not isFinder(data) then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local home = camera.CFrame
	local total = 0
	for _, shot in shots do
		total += shot.duration
	end
	table.insert(shots, {
		from = shots[#shots].to,
		to = home,
		duration = 0.6,
		fovFrom = shots[#shots].fovTo,
		fovTo = camera.FieldOfView,
	})
	if tint then
		mood(tint, total + 0.3)
	end
	CutsceneController.Play(shots)
end

local function shake(data, strength: number, duration: number)
	if data.player == player and CutsceneController.IsPlaying() then
		CutsceneController.Shake(strength, duration)
	end
end

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

-- ------------------------------------------------------------------ haltère fantôme

local ghosts: { [BasePart]: CFrame } = {}

local function watchGhost(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	ghosts[part] = part.CFrame
	local glow = Instance.new("PointLight")
	glow.Color = GHOST_BLUE
	glow.Brightness = 1.2
	glow.Range = 10
	glow.Parent = part
	part.Color = GHOST_BLUE
	part.Material = Enum.Material.Neon
	part.Transparency = 0.55
	-- Volutes qui s'échappent sans arrêt : on le repère de loin, dans la nuit
	local wisps = stream(part, SMOKE, GHOST_BLUE, 6, 0.8, 1.2, nil)
	wisps.LightEmission = 0.8
	part.Destroying:Connect(function()
		ghosts[part] = nil
	end)
end

local function floatGhosts()
	local t = os.clock()
	for part, base in ghosts do
		if part.Parent then
			-- Il flotte, tourne et vacille comme une flamme
			local flicker = 0.5 + math.noise(t * 3, 0, 0) * 0.25
			part.Transparency = flicker
			part.CFrame = base
				* CFrame.new(0, math.sin(t * 1.6) * 0.5, 0)
				* CFrame.Angles(0, t * 0.6, math.sin(t) * 0.15)
		end
	end
end

-- Le fantôme : un corps ovale translucide dans un halo, une queue, deux bras, de grands yeux et une bouche en « o »
local function buildGhost(
	at: CFrame
): { body: Part, parts: { [Part]: CFrame }, base: { [Part]: number }, all: { Part } }
	local parts: { [Part]: CFrame } = {}
	local base: { [Part]: number } = {}
	local all: { Part } = {}
	local function add(part: Part, offset: CFrame, opacity: number)
		parts[part] = offset
		base[part] = opacity
		table.insert(all, part)
	end
	local skin = Color3.fromRGB(228, 238, 255)
	local ink = Color3.fromRGB(25, 30, 55)
	local plain = Enum.Material.SmoothPlastic
	local body = ellipsoid(Vector3.new(2.2, 3.2, 2.2), skin, plain, 1)
	add(body, CFrame.new(), 0.12)
	add((ellipsoid(Vector3.new(2.9, 3.9, 2.9), GHOST_BLUE, Enum.Material.ForceField, 1)), CFrame.new(), 0)
	-- Queue en volute qui se perd vers le bas
	add((ellipsoid(Vector3.new(1.5, 1.6, 1.5), skin, plain, 1)), CFrame.new(0, -1.8, 0.25), 0.3)
	add((ellipsoid(Vector3.new(0.8, 1, 0.8), skin, plain, 1)), CFrame.new(0.2, -2.6, 0.55), 0.5)
	for _, sx in { -1, 1 } do
		add(
			(ellipsoid(Vector3.new(0.65, 1.3, 0.65), skin, plain, 1)),
			CFrame.new(sx * 1.15, 0.05, -0.1) * CFrame.Angles(0, 0, sx * math.rad(-35)),
			0.15
		)
		add((ellipsoid(Vector3.new(0.42, 0.62, 0.22), ink, plain, 1)), CFrame.new(sx * 0.42, 0.7, -1.0), 0)
		-- Reflet dans l'œil
		add(
			(ellipsoid(Vector3.new(0.14, 0.16, 0.1), Color3.new(1, 1, 1), Enum.Material.Neon, 1)),
			CFrame.new(sx * 0.42 + 0.08, 0.84, -1.1),
			0
		)
	end
	add((ellipsoid(Vector3.new(0.36, 0.46, 0.2), ink, plain, 1)), CFrame.new(0, 0.05, -1.04), 0)
	for part, offset in parts do
		part.CFrame = at * offset
	end
	light(body, GHOST_BLUE, 1.6, 14, 3)
	return { body = body, parts = parts, base = base, all = all }
end

local function ghostFx(data)
	if typeof(data.position) ~= "Vector3" or not near(data.position) then
		return
	end
	local cfg = Secrets.GhostLifter
	local duration = cfg.Scene
	local dumbbell = if typeof(data.dumbbell) == "Instance" and data.dumbbell:IsA("BasePart")
		then data.dumbbell
		else nil
	if dumbbell then
		ghosts[dumbbell] = nil -- le fantôme le prend en main : il ne flotte plus tout seul
	end
	local hold = dumbbell and dumbbell.CFrame
	-- Le fantôme apparaît derrière l'haltère, tourné vers celui qui l'a soulevé
	local who = if typeof(data.player) == "Instance" and data.player:IsA("Player") then data.player else nil
	local whoRoot = who and who.Character and who.Character:FindFirstChild("HumanoidRootPart")
	local toward = if whoRoot and whoRoot:IsA("BasePart")
		then Vector3.new(whoRoot.Position.X - data.position.X, 0, whoRoot.Position.Z - data.position.Z)
		else Vector3.new(0, 0, -1)
	if toward.Magnitude < 0.1 then
		toward = Vector3.new(0, 0, -1)
	end
	local center = data.position - toward.Unit * 1.6
	local facing = CFrame.lookAt(center, center + toward.Unit)
	local ghost = buildGhost(facing * CFrame.new(0, -3, 0))
	local at = anchorAt(data.position, duration + 1.5)
	burst(at, SMOKE, GHOST_BLUE, 18, 1.4, 4)
	sfx("EventWhoosh", 0.7)
	task.delay(0.9, function()
		bubble(ghost.body, Texts.Get("Secret.GhostLifter.Line"), 2.6, duration - 1.4)
	end)
	local spunUp = false
	animate(duration, function(t)
		-- 0 à 0,5 s : il sort du sol ; 0,5 à 2,6 s : trois curls ; ensuite : il s'envole en tournoyant
		local rise = ease(t / 0.5)
		local fly = ease((t - (duration - 1)) / 0.9)
		local spin = fly * math.pi * 4
		local bob = math.sin(t * 4) * 0.25
		local frame = facing * CFrame.new(0, -3 + 3 * rise + bob + fly * 7, 0) * CFrame.Angles(0, spin, 0)
		local fade = math.clamp((1 - rise) + fly, 0, 1)
		for part, offset in ghost.parts do
			part.CFrame = frame * offset
			local opacity = ghost.base[part] or 0
			part.Transparency = opacity + (1 - opacity) * fade
		end
		if dumbbell and dumbbell.Parent and hold then
			-- Dans sa main droite : l'haltère monte et descend (trois curls), puis s'envole avec lui
			local curl = if t > 0.5 and t < duration - 1 then (1 - math.cos((t - 0.5) * math.pi * 2 / 0.7)) / 2 else 0
			local hand = frame * CFrame.new(1.5, -0.3 + curl * 1.3, -0.6 - curl * 0.5)
			local grab = ease((t - 0.3) / 0.3)
			dumbbell.CFrame = hold:Lerp(CFrame.new(hand.Position) * hold.Rotation, grab) * CFrame.Angles(0, spin, 0)
			dumbbell.Transparency = math.clamp(0.4 + 0.6 * fly, 0, 1)
		end
		if fly > 0 and not spunUp then
			spunUp = true
			sfx("EventWhoosh", 1.2)
			shake(data, 0.35, 0.4)
			local trail = stream(ghost.body, SPARKLE, GHOST_BLUE, 40, 0.6, 2, 1)
			trail.LightEmission = 1
		end
	end, function()
		local last = anchorAt(ghost.body.Position, 2)
		burst(last, SPARKLE, Color3.new(1, 1, 1), 40, 0.7, 10)
		burst(last, SMOKE, GHOST_BLUE, 20, 1.6, 5)
		for _, part in ghost.all do
			part:Destroy()
		end
	end)
	-- 1. Gros plan sur l'haltère qui s'agite ; 2. de profil, le fantôme au centre pendant ses curls (point de vue
	-- dégagé, le joueur s'efface s'il gêne) ; 3. on lève les yeux quand il s'envole
	local ignore: { Instance } = table.clone(ghost.all)
	if dumbbell then
		table.insert(ignore, dumbbell)
	end
	local camAt = data.position + Vector3.new(0, 1.2, 0)
	local side = facing.RightVector
	local close = eyeOn(data.position, data.position + side * 4 + toward.Unit * 2.5 + Vector3.new(0, 1, 0), ignore)
	local eye = eyeOn(camAt, camAt + side * 9 + toward.Unit * 3 + Vector3.new(0, 1.5, 0), ignore)
	local sky = camAt + Vector3.new(0, 7, 0)
	film(data, {
		{
			from = CFrame.lookAt(close + (close - data.position).Unit * 1.5, data.position),
			to = CFrame.lookAt(close, data.position),
			duration = 0.6,
			focus = data.position,
			fovFrom = 55,
			fovTo = 45,
		},
		{
			from = CFrame.lookAt(close, data.position),
			to = CFrame.lookAt(eye, camAt),
			duration = duration - 1.6,
			focus = camAt,
			fovFrom = 45,
			fovTo = 52,
		},
		{
			from = CFrame.lookAt(eye, camAt),
			to = CFrame.lookAt(eye + (eye - camAt).Unit * 3 - Vector3.new(0, 0.5, 0), sky),
			duration = 1.1,
			focus = sky,
			fovFrom = 52,
			fovTo = 68,
		},
	}, Color3.fromRGB(190, 215, 255))
end

-- ------------------------------------------------------------------ statue qui cligne

local function statueOf(pedestal: BasePart): Model?
	local statue = pedestal:FindFirstChild("Statue")
	return if statue and statue:IsA("Model") then statue else nil
end

-- Une tape sur le socle : un peu de poussière (le serveur fait trembler la statue) ; rien d'autre ne trahit le secret
local function onLocalTap(pedestal: BasePart)
	local top = pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2, 0)
	burst(anchorAt(top, 1.5), SMOKE, Color3.fromRGB(210, 200, 180), 4, 0.6, 2)
end

local function watchPedestal(pedestal: Instance)
	if not pedestal:IsA("BasePart") then
		return
	end
	local function hook(child: Instance)
		if child.Name == "SecretTap" and child:IsA("ClickDetector") then
			child.MouseClick:Connect(function()
				onLocalTap(pedestal)
			end)
		end
	end
	for _, child in pedestal:GetChildren() do
		hook(child)
	end
	pedestal.ChildAdded:Connect(hook)
end

-- Le serveur anime la statue (elle se tourne, double biceps) ; ici : les yeux dorés, le clin d'œil, l'onde dorée
local function statueFx(data)
	local pedestal = data.pedestal
	if typeof(pedestal) ~= "Instance" or not pedestal:IsA("BasePart") or not near(pedestal.Position) then
		return
	end
	local duration = Secrets.StatueBeliever.Scene
	local statue = statueOf(pedestal)
	local top = pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2, 0)
	shockwave(top + Vector3.new(0, 0.1, 0), GOLD, 12, 0.9)
	sfx("SceneImpact", 0.8)
	if not statue then
		burst(anchorAt(top + Vector3.new(0, 5, 0), 2.5), SPARKLE, GOLD, 30, 0.8, 8)
		return
	end
	local _, size = statue:GetBoundingBox()
	local head = statue:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	-- Deux éclats dorés à la place des yeux ; le droit se ferme (le clin d'œil)
	local eyes: { { part: Part, mesh: SpecialMesh, side: number } } = {}
	for _, sx in { -1, 1 } do
		local eye, mesh = ellipsoid(Vector3.new(0.28, 0.28, 0.1) * (head.Size.Y / 1.2), GOLD, Enum.Material.Neon, 1)
		table.insert(eyes, { part = eye, mesh = mesh, side = sx })
	end
	light(head, GOLD, 3, 12, duration)
	local winked, flexed = false, false
	animate(duration, function(t)
		if not head.Parent then
			return
		end
		local wink = math.clamp(1 - math.abs(t - 0.95) / 0.18, 0, 1) -- le droit se ferme vers 0,95 s
		local shown = ease((t - 0.45) / 0.2) * (1 - ease((t - (duration - 0.5)) / 0.4))
		for _, eye in eyes do
			eye.part.CFrame = head.CFrame
				* CFrame.new(eye.side * head.Size.X * 0.18, head.Size.Y * 0.06, -head.Size.Z * 0.5)
			eye.part.Transparency = 1 - shown
			eye.mesh.Scale = Vector3.new(1, if eye.side > 0 then 1 - wink * 0.9 else 1, 1)
		end
		if wink > 0.95 and not winked then
			winked = true
			pop(head, "😉", head.Size.Y * 1.2, nil)
		end
		if t > 1.65 and not flexed then
			flexed = true
			shockwave(top + Vector3.new(0, 0.1, 0), GOLD, 16, 1)
			burst(anchorAt(top + Vector3.new(0, size.Y * 0.8, 0), 2.5), SPARKLE, GOLD, 40, 0.8, 9)
			sfx("SceneImpact", 1.1)
			shake(data, 0.6, 0.45)
		end
	end, function()
		for _, eye in eyes do
			eye.part:Destroy()
		end
	end)
	-- Le joueur se tient juste devant la statue : on filme de trois quarts (jamais depuis sa place), zoom sur le clin
	-- d'œil, puis contre-plongée large pour le double biceps
	local face = head.Position
	local look = if typeof(data.facing) == "Vector3" then data.facing else head.CFrame.LookVector
	local right = look:Cross(Vector3.yAxis)
	local ignore: { Instance } = { statue, pedestal }
	local chest = face - Vector3.new(0, size.Y * 0.3, 0)
	local near3q = eyeOn(face, face + look * 5 + right * 3.5 + Vector3.new(0, 0.3, 0), ignore)
	local wide = eyeOn(chest, chest + look * 10 - right * 5 - Vector3.new(0, size.Y * 0.25, 0), ignore)
	film(data, {
		{
			from = CFrame.lookAt(near3q + (near3q - face).Unit * 3, face),
			to = CFrame.lookAt(near3q, face),
			duration = 1.3,
			focus = face,
			fovFrom = 55,
			fovTo = 34,
		},
		{
			from = CFrame.lookAt(near3q, face),
			to = CFrame.lookAt(wide, chest),
			duration = duration - 1.3,
			focus = chest,
			fovFrom = 34,
			fovTo = 62,
		},
	}, Color3.fromRGB(255, 235, 190))
end

-- ------------------------------------------------------------------ rat coach

local function ratFx(data)
	local rat = data.rat
	if typeof(rat) ~= "Instance" or not rat:IsA("BasePart") or not near(rat.Position) then
		return
	end
	local duration = if typeof(data.duration) == "number" then data.duration else 5
	local base = rat.CFrame
	local hole = anchorAt(base.Position - Vector3.new(0, rat.Size.Y * 0.5, 0), duration + 2)
	-- Bouffée de vapeur à l'ouverture, puis de fines volutes (elles ne doivent pas cacher le rat)
	burst(hole, SMOKE, Color3.fromRGB(220, 240, 220), 12, 1.1, 6)
	local wisps = stream(hole, SMOKE, Color3.fromRGB(200, 230, 200), 3, 0.5, 3, duration - 0.5)
	wisps.Transparency = NumberSequence.new(0.7, 1)
	light(hole, SEWER_GREEN, 2.5, 12, duration - 0.3)
	sfx("EventLand", 1.3)
	local count = 0
	local pushups = Secrets.SewerGains.Pushups
	local flexAt = 0.5 + pushups * 0.7
	local flexed = false
	animate(duration, function(t)
		if not rat.Parent then
			return
		end
		local frame = base
		if t < flexAt then
			-- Pompes : le corps descend et remonte, le nez vers le sol ; on compte à chaque remontée
			local phase = math.max(t - 0.5, 0) / 0.7
			local push = (1 - math.cos(phase * math.pi * 2)) / 2
			frame = base * CFrame.new(0, -push * 0.3, 0) * CFrame.Angles(math.rad(-push * 10), 0, 0)
			local done = math.floor(phase + 0.5)
			if t > 0.5 and done > count and count < pushups then
				count = done
				pop(rat, tostring(count), rat.Size.Y + 0.8, GOLD)
			end
		else
			-- Il se dresse sur ses pattes arrière et gonfle les bras, en sautillant
			local stand = ease((t - flexAt) / 0.3)
			local hop = math.abs(math.sin((t - flexAt) * 9)) * 0.25 * stand
			frame = base * CFrame.new(0, hop + stand * rat.Size.Z * 0.3, 0) * CFrame.Angles(math.rad(70 * stand), 0, 0)
			if not flexed and stand > 0.9 then
				flexed = true
				pop(rat, "💪", rat.Size.Y + 1.4, nil)
				burst(anchorAt(rat.Position + Vector3.new(0, 1, 0), 2), SPARKLE, GOLD, 18, 0.5, 5)
				bubble(rat, Texts.Get("Secret.SewerGains.Line"), rat.Size.Y + 2.2, duration - t - 0.2)
				sfx("SceneImpact", 1.6)
				shake(data, 0.3, 0.35)
			end
		end
		rat.CFrame = frame
	end, function()
		if rat.Parent then
			rat.CFrame = base
		end
	end)
	-- Caméra au ras du sol, à hauteur de rat (point de vue dégagé : le joueur est souvent juste au-dessus de la plaque)
	local look = base.LookVector
	local at = base.Position + Vector3.new(0, 0.5, 0)
	local up = at + Vector3.new(0, 1, 0)
	local ignore: { Instance } = { rat }
	local low = eyeOn(at, at + look * 5 + base.RightVector * 1.8 + Vector3.new(0, 0.8, 0), ignore)
	local front = eyeOn(up, at + look * 4.2 + Vector3.new(0, 0.3, 0), ignore)
	film(data, {
		{
			from = CFrame.lookAt(at + look * 7 + Vector3.new(0, 3, 0), at),
			to = CFrame.lookAt(low, at),
			duration = flexAt,
			focus = at,
			fovFrom = 60,
			fovTo = 42,
		},
		{
			from = CFrame.lookAt(low, at),
			to = CFrame.lookAt(front, up),
			duration = duration - flexAt,
			focus = up,
			fovFrom = 42,
			fovTo = 55,
		},
	}, Color3.fromRGB(205, 255, 205))
end

-- ------------------------------------------------------------------ miroir du passé

local function mirrorFx(data)
	local mirror = data.mirror
	if
		typeof(mirror) ~= "Instance"
		or not mirror:IsA("BasePart")
		or typeof(data.stage) ~= "string"
		or not near(mirror.Position)
		or not Outfit.Available()
	then
		return
	end
	local look = if typeof(data.look) == "table" then data.look else nil
	local model = Outfit.Build(data.stage, {}, { look = look })
	if not model then
		return
	end
	local duration = if typeof(data.duration) == "number" then data.duration else 5
	local front = mirror.CFrame.LookVector
	-- La glace scintille : une nappe de lumière qui ondule devant le miroir
	local sheen = fxPart({
		Size = Vector3.new(mirror.Size.X * 0.9, mirror.Size.Y * 0.9, 0.05),
		CFrame = mirror.CFrame * CFrame.new(0, 0, -mirror.Size.Z / 2 - 0.06),
		Color = Color3.fromRGB(150, 205, 255),
		Material = Enum.Material.Neon,
		Transparency = 1,
	})
	burst(sheen, SPARKLE, Color3.new(1, 1, 1), 30, 0.5, 3)
	light(sheen, GHOST_BLUE, 2, 12, duration)
	sfx("SnackPower", 0.8)
	-- Debout au pied du miroir, juste devant la glace, tourné vers la salle
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { mirror, sheen }
	local probe = mirror.Position + front * 0.8
	local hit = workspace:Raycast(probe, Vector3.new(0, -20, 0), params)
	local floor = if hit then hit.Position.Y else mirror.Position.Y - mirror.Size.Y
	local feet = Vector3.new(probe.X, floor, probe.Z)
	local base = CFrame.lookAt(feet, feet + front)
	model:PivotTo(base)
	local parts: { [BasePart]: number } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			parts[item] = math.max(item.Transparency, 0.3)
			item.Transparency = 1
			item.CastShadow = false
		end
	end
	model.Parent = workspace
	local _, size = model:GetBoundingBox()
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if root then
		task.delay(0.6, function()
			bubble(root, Texts.Get("Secret.NeverForget.Line"), size.Y * 0.5 + 1.2, duration - 1.2)
		end)
	end
	local waved = 0
	animate(duration, function(t)
		-- La glace s'allume puis pulse ; le reflet apparaît, se balance (coucou), sautille et se dissout
		local appear = ease((t - 0.3) / 0.6)
		local vanish = ease((t - (duration - 0.6)) / 0.6)
		sheen.Transparency = 1 - (0.25 + math.sin(t * 5) * 0.1) * (1 - vanish) * ease(t / 0.3)
		for part, target in parts do
			part.Transparency = 1 - (1 - target) * appear * (1 - vanish)
		end
		local hop = math.abs(math.sin(t * 4)) * 0.2 * appear
		model:PivotTo(base * CFrame.new(0, hop, 0) * CFrame.Angles(0, 0, math.sin(t * 6) * math.rad(7) * appear))
		local wave = math.floor(t / 0.9)
		if root and appear > 0.9 and wave > waved and t < duration - 0.8 then
			waved = wave
			pop(root, "👋", size.Y * 0.2, nil)
		end
	end, function()
		burst(anchorAt(feet + Vector3.new(0, size.Y * 0.5, 0), 2), SPARKLE, GHOST_BLUE, 40, 0.6, 6)
		model:Destroy()
		sheen:Destroy()
	end)
	-- De biais (35°) devant la glace, jamais dans le dos du joueur : il se tient juste devant le miroir et le
	-- cacherait ; s'il passe quand même dans le champ, il s'efface
	local target = feet + Vector3.new(0, size.Y * 0.55, 0)
	local ignore: { Instance } = { mirror, sheen, model }
	local angled = CFrame.Angles(0, math.rad(35), 0):VectorToWorldSpace(front)
	local start = eyeOn(target, target + angled * 7 + Vector3.new(0, 1.2, 0), ignore)
	local finish = eyeOn(target, target + angled * 4.5 + Vector3.new(0, 0.4, 0), ignore)
	local mine = rootPosition()
	local opening = if mine then mine + Vector3.new(0, 4, 0) + front * 2 else start
	film(data, {
		{
			from = CFrame.lookAt(opening, target),
			to = CFrame.lookAt(start, target),
			duration = 0.8,
			focus = target,
		},
		{
			from = CFrame.lookAt(start, target),
			to = CFrame.lookAt(finish, target),
			duration = duration - 0.8,
			focus = target,
			fovFrom = 60,
			fovTo = 44,
		},
	}, Color3.fromRGB(200, 225, 255))
end

-- ------------------------------------------------------------------ annonce

local function announce(secretId: string, found: number?, total: number?)
	bannerToken += 1
	local token = bannerToken
	bannerIcon.Text = ICONS[secretId] or "❔"
	bannerTitle.Text = Texts.Get("Secret.Found")
	bannerSub.Text = Texts.Get("Secret.FoundTitle", { title = Texts.Get(`Nick.Title.{secretId}`) })
	bannerCount.Text = if found and total then Texts.Get("Secret.Progress", { found = found, total = total }) else ""
	sfx("StageUp", 1.15)
	-- Fond assombri, rayons qui tournent, titre tamponné, icône qui rebondit
	bannerBack.Visible = true
	bannerBack.BackgroundTransparency = 1
	TweenService:Create(bannerBack, TweenInfo.new(0.3), { BackgroundTransparency = 0.55 }):Play()
	banner.Visible = true
	local scale = banner:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 2.2
	banner.Rotation = -10
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 })
		:Play()
	bannerIcon.Rotation = -30
	TweenService:Create(bannerIcon, TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
		Rotation = 0,
	}):Play()
	bannerRays.Visible = true
	local spin = TweenService:Create(bannerRays, TweenInfo.new(6, Enum.EasingStyle.Linear), {
		Rotation = bannerRays.Rotation + 180,
	})
	spin:Play()
	-- Confettis dorés
	for _ = 1, 26 do
		local bit = Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.32),
			Size = UDim2.fromOffset(math.random(6, 12), math.random(10, 18)),
			BackgroundColor3 = if math.random() < 0.5 then GOLD else Color3.fromRGB(255, 255, 255),
			Rotation = math.random(0, 360),
			Parent = bannerBack,
		})
		TweenService:Create(bit, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.9, 0.32 + math.random() * 0.6),
			Rotation = bit.Rotation + math.random(-360, 360),
			BackgroundTransparency = 1,
		}):Play()
		task.delay(1.7, function()
			bit:Destroy()
		end)
	end
	task.delay(4.2, function()
		if token ~= bannerToken then
			return
		end
		spin:Cancel()
		TweenService:Create(scale, TweenInfo.new(0.25), { Scale = 0 }):Play()
		TweenService:Create(bannerBack, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		task.wait(0.3)
		if token == bannerToken then
			banner.Visible = false
			bannerBack.Visible = false
			bannerRays.Visible = false
		end
	end)
end

local function buildGui()
	local gui =
		Ui.create("ScreenGui", { Name = "Secrets", ResetOnSpawn = false, DisplayOrder = 25, IgnoreGuiInset = true })
	bannerBack = Ui.create("Frame", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	-- Rayons : de longues bandes dorées qui tournent derrière la bannière
	bannerRays = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(700, 700),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	for index = 0, 5 do
		Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 46, 1, 0),
			Rotation = index * 30,
			BackgroundColor3 = GOLD,
			BackgroundTransparency = 0.78,
			BorderSizePixel = 0,
			Parent = bannerRays,
		}, {
			Ui.create("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Rotation = 90,
			}),
		})
	end
	banner = Ui.create("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.new(0.86, 0, 0, 150),
		BackgroundColor3 = Color3.fromRGB(28, 22, 44),
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(UDim.new(0, 20)),
		Ui.stroke(GOLD, 4, 0),
		Ui.create("UISizeConstraint", { MaxSize = Vector2.new(560, 150) }),
		Ui.create("UIScale", { Scale = 1 }),
	})
	bannerIcon = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 62, 0.5, 0),
		Size = UDim2.fromOffset(96, 96),
		TextStrokeTransparency = 1,
		Parent = banner,
	})
	bannerTitle = Ui.label({
		Position = UDim2.fromOffset(124, 12),
		Size = UDim2.new(1, -140, 0, 56),
		TextColor3 = GOLD,
		Parent = banner,
	})
	bannerSub = Ui.label({
		Position = UDim2.fromOffset(124, 70),
		Size = UDim2.new(1, -140, 0, 38),
		Parent = banner,
	})
	bannerCount = Ui.label({
		Position = UDim2.fromOffset(124, 110),
		Size = UDim2.new(1, -140, 0, 26),
		TextColor3 = Color3.fromRGB(200, 190, 230),
		Parent = banner,
	})
	gui.Parent = player:WaitForChild("PlayerGui")
end

function SecretController.Init(controllers)
	MinigameController = controllers.MinigameController
	CutsceneController = controllers.CutsceneController
	SoundController = controllers.SoundController
end

function SecretController.Start()
	buildGui()
	for _, part in CollectionService:GetTagged("GhostDumbbell") do
		watchGhost(part)
	end
	CollectionService:GetInstanceAddedSignal("GhostDumbbell"):Connect(watchGhost)
	for _, pedestal in CollectionService:GetTagged("MogStatue") do
		watchPedestal(pedestal)
	end
	CollectionService:GetInstanceAddedSignal("MogStatue"):Connect(watchPedestal)
	RunService.RenderStepped:Connect(floatGhosts)
	Remotes.SecretFound.OnClientEvent:Connect(function(secretId, found, total)
		if typeof(secretId) ~= "string" then
			return
		end
		-- Après le plan de caméra du secret (la cinématique cache l'interface)
		task.spawn(function()
			task.wait(0.15)
			local waited = 0
			while CutsceneController.IsPlaying() and waited < 12 do
				waited += task.wait(0.1)
			end
			announce(
				secretId,
				if typeof(found) == "number" then found else nil,
				if typeof(total) == "number" then total else nil
			)
		end)
	end)
	Remotes.SecretFx.OnClientEvent:Connect(function(secretId, data)
		if typeof(secretId) ~= "string" or typeof(data) ~= "table" then
			return
		end
		SecretController.Shown += 1
		if secretId == "GhostLifter" then
			ghostFx(data)
		elseif secretId == "StatueBeliever" then
			statueFx(data)
		elseif secretId == "SewerGains" then
			ratFx(data)
		elseif secretId == "NeverForget" then
			mirrorFx(data)
		end
	end)
end

return SecretController
