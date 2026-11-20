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
-- D135 (demande d'Antoine du 21/11 : « améliore énormément l'animation des secrets ») : les quatre scènes suivent
-- les principes de l'animation (anticipation, écrasement et étirement, dépassement, mouvements secondaires, sortie) :
-- le fantôme sort du sol en tire-bouchon, regarde l'haltère, fait trois curls avec le bras et le buste, s'accroupit
-- puis s'envole en spirale ; la statue s'effrite, ses yeux s'allument, elle cligne et chaque pompe du biceps lance un
-- anneau doré ; le rat renifle, force sur sa dernière pompe, fait un salto arrière puis gonfle les bras ; le reflet
-- se dessine de bas en haut, salue vraiment du bras et se dissout du haut vers le bas.

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

-- ------------------------------------------------------------------ principes d'animation (D135)
-- Anticipation (on se prépare avant d'agir), écrasement et étirement (volume conservé), dépassement puis retour
-- (overshoot), mouvements secondaires en retard (queue, bras), et chaque scène a une vraie sortie.

-- Arrivée avec dépassement : monte un peu au-dessus de 1 puis revient (0 à 1)
local function backOut(t: number, overshoot: number?): number
	t = math.clamp(t, 0, 1)
	local s = overshoot or 1.7
	local u = t - 1
	return 1 + (s + 1) * u * u * u + s * u * u
end

-- Ressort amorti : 0 au départ, 1 à la fin, avec quelques rebonds qui s'éteignent
local function spring(t: number, bounces: number?): number
	t = math.clamp(t, 0, 1)
	return 1 - math.exp(-6 * t) * math.cos(t * math.pi * 2 * (bounces or 2))
end

-- Fenêtre de temps : 0 avant `a`, 1 après `b`, lissé entre les deux
local function window(t: number, a: number, b: number): number
	return ease((t - a) / (b - a))
end

-- Écrasement / étirement à volume constant : `amount` > 0 étire en hauteur, < 0 écrase
local function squash(amount: number): Vector3
	local y = math.max(1 + amount, 0.2)
	local xz = 1 / math.sqrt(y)
	return Vector3.new(xz, y, xz)
end

-- Anneau lumineux dans le plan de `frame` (axe X = normale), qui s'élargit et s'efface
local function ring(frame: CFrame, color: Color3, from: number, to: number, duration: number, thickness: number?)
	local disc = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness or 0.08, from, from),
		CFrame = frame,
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
	})
	local tween = TweenService:Create(disc, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = Vector3.new(thickness or 0.08, to, to),
		Transparency = 1,
	})
	tween.Completed:Connect(function()
		disc:Destroy()
	end)
	tween:Play()
end

-- Petits éclats qui tombent en tournant (pierre de la statue, gouttes) puis disparaissent
local function debris(origin: Vector3, color: Color3, material: Enum.Material, count: number, spread: number)
	for _ = 1, count do
		local size = 0.12 + math.random() * 0.18
		local bit = fxPart({
			Size = Vector3.new(size, size, size),
			CFrame = CFrame.new(
				origin + Vector3.new((math.random() - 0.5) * spread, 0, (math.random() - 0.5) * spread)
			) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
			Color = color,
			Material = material,
		})
		local fall = 1.5 + math.random() * 2
		local info = TweenInfo.new(0.5 + math.random() * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local tween = TweenService:Create(bit, info, {
			CFrame = CFrame.new(0, -fall, 0) * bit.CFrame * CFrame.Angles(math.random() * 4, 0, math.random() * 4),
			Transparency = 1,
		})
		tween.Completed:Connect(function()
			bit:Destroy()
		end)
		tween:Play()
	end
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

-- Le fantôme : un corps ovale translucide dans un halo, une queue en deux volutes, deux bras, de grands yeux et une
-- bouche en « o ». Chaque pièce garde sa place et sa taille de repos (rôle : corps, bras, queue, œil, bouche) pour
-- être écrasée, étirée et articulée image par image.
type GhostPiece = {
	part: Part,
	offset: CFrame,
	size: Vector3,
	opacity: number,
	role: string,
	side: number,
}
type Ghost = { body: Part, pieces: { GhostPiece }, all: { Part } }

local GHOST_SHOULDER = Vector3.new(0.95, 0.45, -0.1) -- épaule droite (repère du fantôme) ; la gauche en miroir

local function buildGhost(at: CFrame): Ghost
	local pieces: { GhostPiece } = {}
	local all: { Part } = {}
	local function add(part: Part, offset: CFrame, opacity: number, role: string, side: number?)
		table.insert(pieces, {
			part = part,
			offset = offset,
			size = part.Size,
			opacity = opacity,
			role = role,
			side = side or 0,
		})
		table.insert(all, part)
	end
	local skin = Color3.fromRGB(228, 238, 255)
	local ink = Color3.fromRGB(25, 30, 55)
	local plain = Enum.Material.SmoothPlastic
	local body = ellipsoid(Vector3.new(2.2, 3.2, 2.2), skin, plain, 1)
	add(body, CFrame.new(), 0.12, "body")
	add((ellipsoid(Vector3.new(2.9, 3.9, 2.9), GHOST_BLUE, Enum.Material.ForceField, 1)), CFrame.new(), 0, "body")
	-- Queue en volute qui se perd vers le bas (elle suit le corps avec du retard)
	add((ellipsoid(Vector3.new(1.5, 1.6, 1.5), skin, plain, 1)), CFrame.new(0, -1.8, 0.25), 0.3, "tail", 1)
	add((ellipsoid(Vector3.new(0.8, 1, 0.8), skin, plain, 1)), CFrame.new(0.2, -2.6, 0.55), 0.5, "tail", 2)
	for _, sx in { -1, 1 } do
		-- Bras : pendant depuis l'épaule (pivot), légèrement écarté
		add((ellipsoid(Vector3.new(0.65, 1.3, 0.65), skin, plain, 1)), CFrame.new(0, -0.55, 0), 0.15, "arm", sx)
		add((ellipsoid(Vector3.new(0.42, 0.62, 0.22), ink, plain, 1)), CFrame.new(sx * 0.42, 0.7, -1.0), 0, "eye", sx)
		-- Reflet dans l'œil
		add(
			(ellipsoid(Vector3.new(0.14, 0.16, 0.1), Color3.new(1, 1, 1), Enum.Material.Neon, 1)),
			CFrame.new(sx * 0.42 + 0.08, 0.84, -1.1),
			0,
			"glint",
			sx
		)
	end
	add((ellipsoid(Vector3.new(0.36, 0.46, 0.2), ink, plain, 1)), CFrame.new(0, 0.05, -1.04), 0, "mouth")
	for _, piece in pieces do
		piece.part.CFrame = at * piece.offset
	end
	light(body, GHOST_BLUE, 1.6, 14, 4)
	return { body = body, pieces = pieces, all = all }
end

-- Pose du fantôme à cette image. `pose` : stretch (écrasement / étirement), lean (buste, radians), curl (0 à 1 du
-- bras droit), wave (bras gauche), blink (0 à 1), look (yeux vers le bas, 0 à 1), mouth (bouche ouverte, 0 à 1),
-- sway (balancement de la queue, radians), fade (0 visible, 1 invisible).
local function poseGhost(ghost: Ghost, frame: CFrame, pose: { [string]: number })
	local scale = squash(pose.stretch or 0)
	local body = frame * CFrame.Angles(pose.lean or 0, 0, 0)
	local fade = pose.fade or 0
	for _, piece in ghost.pieces do
		local offset = piece.offset
		local size = piece.size * scale
		local cf
		if piece.role == "arm" then
			-- Bras : rotation autour de l'épaule ; droit = curl (avant-bras qui monte), gauche = petit salut
			local shoulder = Vector3.new(GHOST_SHOULDER.X * piece.side, GHOST_SHOULDER.Y, GHOST_SHOULDER.Z) * scale
			local swing = if piece.side > 0
				then CFrame.Angles(math.rad(150) * (pose.curl or 0), 0, math.rad(25))
				else CFrame.Angles(0, 0, -math.rad(30) - math.rad(40) * (pose.wave or 0))
			cf = body * CFrame.new(shoulder) * swing * offset
		elseif piece.role == "tail" then
			-- Queue : suit le corps avec du retard (plus de balancement au bout)
			local lag = (pose.sway or 0) * piece.side
			cf = frame * CFrame.Angles(lag * 0.4, 0, lag) * CFrame.new(offset.Position * scale)
		elseif piece.role == "eye" or piece.role == "glint" then
			local look = pose.look or 0
			local blink = 1 - (pose.blink or 0) * 0.92
			cf = body * CFrame.new(offset.Position * scale + Vector3.new(0, -0.12 * look, 0))
			size = Vector3.new(size.X, size.Y * blink, size.Z)
		elseif piece.role == "mouth" then
			local open = pose.mouth or 0
			size = Vector3.new(size.X * (1 + open * 0.5), size.Y * (1 + open * 0.9), size.Z)
			cf = body * CFrame.new(offset.Position * scale)
		else
			cf = body * CFrame.new(offset.Position * scale) * offset.Rotation
		end
		piece.part.Size = size
		piece.part.CFrame = cf
		piece.part.Transparency = piece.opacity + (1 - piece.opacity) * fade
	end
end

-- Position de la main droite (bout du bras) dans le monde, pour tenir l'haltère
local function ghostHand(frame: CFrame, pose: { [string]: number }): Vector3
	local scale = squash(pose.stretch or 0)
	local body = frame * CFrame.Angles(pose.lean or 0, 0, 0)
	local swing = CFrame.Angles(math.rad(150) * (pose.curl or 0), 0, math.rad(25))
	return (body * CFrame.new(GHOST_SHOULDER * scale) * swing * CFrame.new(0, -1.2, 0)).Position
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
	-- Le sol s'ouvre : volutes en spirale et anneau froid avant qu'il sorte
	burst(at, SMOKE, GHOST_BLUE, 22, 1.4, 4)
	ring(CFrame.new(center - Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90)), GHOST_BLUE, 1, 9, 0.8)
	sfx("EventWhoosh", 0.7)
	task.delay(1.0, function()
		bubble(ghost.body, Texts.Get("Secret.GhostLifter.Line"), 2.8, duration - 1.8)
	end)

	-- Découpage (D135) : sortie du sol en tire-bouchon (0 → 0,8 s) ; il remarque l'haltère (→ 1,05) ; trois curls
	-- qui pèsent (→ curlEnd) ; anticipation, il s'accroupit (0,3 s) ; envol en spirale, étiré, qui s'efface.
	local rise = 0.8
	local curlStart = 1.05
	local launch = duration - 0.95
	local crouch = launch - 0.3
	local curlPeriod = (crouch - curlStart) / 3
	local launched = false
	local lastCurl = 0
	animate(duration, function(t)
		local pose: { [string]: number } = {}
		-- Sortie du sol : étiré en montant, écrasé en se posant, puis il se stabilise (dépassement)
		local up = backOut(t / rise, 1.2)
		local settle = window(t, rise * 0.7, rise + 0.25)
		pose.stretch = 0.45 * (1 - settle) * math.min(t / 0.2, 1)
			- 0.18 * math.sin(math.clamp((t - rise * 0.75) / 0.3, 0, 1) * math.pi)
		local spinIn = (1 - ease(t / rise)) * math.pi * 2
		local bob = math.sin(t * 3.2) * 0.18
		pose.sway = math.sin(t * 3.2 - 0.9) * 0.22
		-- Il regarde l'haltère, cligne, puis le regarde de nouveau en face
		pose.look = window(t, rise, rise + 0.15) * (1 - window(t, curlStart + 0.1, curlStart + 0.3))
		pose.blink = math.clamp(1 - math.abs(t - (rise + 0.1)) / 0.07, 0, 1)
			+ math.clamp(1 - math.abs(t - (crouch - 0.2)) / 0.07, 0, 1)
		pose.wave = 0
		-- Curls : montée rapide, descente lente ; le buste part en arrière à chaque montée, la bouche souffle
		local curl = 0
		if t >= curlStart and t < crouch then
			local u = ((t - curlStart) % curlPeriod) / curlPeriod
			curl = if u < 0.4 then ease(u / 0.4) else 1 - ease((u - 0.4) / 0.6)
			local index = math.floor((t - curlStart) / curlPeriod) + 1
			if index > lastCurl and u > 0.35 then
				lastCurl = index
				pop(ghost.body, tostring(index), 3.2, GHOST_BLUE)
			end
		end
		pose.curl = curl
		pose.lean = math.rad(12) * curl
		pose.mouth = curl
		pose.stretch += 0.06 * curl - 0.05 * (1 - curl) * window(t, curlStart, curlStart + 0.2)
		-- Anticipation puis envol : il s'écrase, puis jaillit en s'étirant, en spirale
		local squat = window(t, crouch, launch) * (1 - window(t, launch, launch + 0.12))
		local fly = window(t, launch, duration)
		pose.stretch += -0.35 * squat + 0.7 * math.sin(math.min(fly * 1.6, 1) * math.pi * 0.5) * (1 - fly * 0.5)
		pose.wave = squat
		local spiral = fly * fly
		local orbit = Vector3.new(math.cos(spiral * 9) * 1.6 * spiral, 0, math.sin(spiral * 9) * 1.6 * spiral)
		local height = -3 + 3 * up + bob * settle - 0.45 * squat + spiral * 11
		pose.fade = math.clamp((1 - math.min(t / 0.35, 1)) * 0.8 + window(t, launch + 0.35, duration), 0, 1)
		local frame = facing
			* CFrame.new(orbit + Vector3.new(0, height, 0))
			* CFrame.Angles(0, spinIn + spiral * math.pi * 6, math.sin(t * 2.1) * 0.06)
		poseGhost(ghost, frame, pose)
		if dumbbell and dumbbell.Parent and hold then
			-- Dans sa main droite : il l'attrape, l'haltère suit le curl, puis s'envole avec lui
			local grab = window(t, rise + 0.15, curlStart)
			local hand = ghostHand(frame, pose)
			dumbbell.CFrame = hold:Lerp(CFrame.new(hand) * hold.Rotation, grab)
				* CFrame.Angles(0, spiral * math.pi * 6, 0)
			dumbbell.Transparency = math.clamp(0.4 + 0.6 * window(t, launch + 0.35, duration), 0, 1)
		end
		if fly > 0 and not launched then
			launched = true
			sfx("EventWhoosh", 1.2)
			shake(data, 0.35, 0.4)
			ring(
				CFrame.new(frame.Position - Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				GHOST_BLUE,
				1,
				7,
				0.6
			)
			local trail = stream(ghost.body, SPARKLE, GHOST_BLUE, 50, 0.6, 2, 0.9)
			trail.LightEmission = 1
		end
	end, function()
		local last = anchorAt(ghost.body.Position, 2)
		burst(last, SPARKLE, Color3.new(1, 1, 1), 45, 0.7, 10)
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
	local sky = camAt + Vector3.new(0, 9, 0)
	film(data, {
		{
			from = CFrame.lookAt(close + (close - data.position).Unit * 1.5, data.position),
			to = CFrame.lookAt(close, data.position),
			duration = 0.8,
			focus = data.position,
			fovFrom = 55,
			fovTo = 45,
		},
		{
			from = CFrame.lookAt(close, data.position),
			to = CFrame.lookAt(eye, camAt),
			duration = duration - 1.9,
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
			fovTo = 70,
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

-- Le serveur anime la statue (frisson, elle se tourne, prépare puis gonfle un double biceps qui pompe, revient) ;
-- ici : la pierre qui s'effrite au réveil, les yeux qui s'allument, le clin d'œil, les ondes et anneaux dorés
-- calés sur chaque pompe, la poussière qui retombe à la fin. Les moments suivent Secrets.StatueBeliever.Beats.
local function statueFx(data)
	local pedestal = data.pedestal
	if typeof(pedestal) ~= "Instance" or not pedestal:IsA("BasePart") or not near(pedestal.Position) then
		return
	end
	local cfg = Secrets.StatueBeliever
	local beats = cfg.Beats
	local duration = cfg.Scene
	local statue = statueOf(pedestal)
	local top = pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2, 0)
	shockwave(top + Vector3.new(0, 0.1, 0), GOLD, 9, 0.7)
	sfx("SceneImpact", 0.6)
	if not statue then
		burst(anchorAt(top + Vector3.new(0, 5, 0), 2.5), SPARKLE, GOLD, 30, 0.8, 8)
		return
	end
	local center, size = statue:GetBoundingBox()
	local head = statue:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local stone = head.Color
	-- Réveil : la pierre s'effrite (éclats et poussière qui tombent des épaules)
	debris(center.Position + Vector3.new(0, size.Y * 0.3, 0), stone, Enum.Material.Slate, 10, size.X * 0.6)
	burst(
		anchorAt(center.Position + Vector3.new(0, size.Y * 0.35, 0), 2),
		SMOKE,
		Color3.fromRGB(215, 205, 185),
		14,
		1.2,
		3
	)
	-- Deux éclats dorés à la place des yeux ; le droit se ferme (le clin d'œil)
	local eyes: { { part: Part, mesh: SpecialMesh, side: number } } = {}
	for _, sx in { -1, 1 } do
		local eye, mesh = ellipsoid(Vector3.new(0.28, 0.28, 0.1) * (head.Size.Y / 1.2), GOLD, Enum.Material.Neon, 1)
		table.insert(eyes, { part = eye, mesh = mesh, side = sx })
	end
	local glow = light(head, GOLD, 0, 12, duration)
	local hands: { BasePart } = {}
	for _, name in { "RightHand", "LeftHand" } do
		local hand = statue:FindFirstChild(name, true)
		if hand and hand:IsA("BasePart") then
			table.insert(hands, hand)
		end
	end
	local ignited, winked, flexed = false, false, false
	local pumps = 0
	animate(duration, function(t)
		if not head.Parent then
			return
		end
		-- Yeux : ils s'allument d'un coup (éclat plus gros que nature puis retour), le droit cligne
		local ignite = window(t, beats.Eyes, beats.Eyes + 0.12)
		local flare = 1 + 0.9 * math.max(0, 1 - math.abs(t - beats.Eyes - 0.08) / 0.12)
		local wink = math.clamp(1 - math.abs(t - beats.Wink) / 0.16, 0, 1)
		local shown = ignite * (1 - window(t, duration - 0.5, duration - 0.1))
		glow.Brightness = 3.5 * shown * flare
		for _, eye in eyes do
			eye.part.CFrame = head.CFrame
				* CFrame.new(eye.side * head.Size.X * 0.18, head.Size.Y * 0.06, -head.Size.Z * 0.5)
			eye.part.Transparency = 1 - shown
			eye.mesh.Scale = Vector3.new(flare, flare * (if eye.side > 0 then 1 - wink * 0.92 else 1), 1)
		end
		if ignite > 0 and not ignited then
			ignited = true
			for _, eye in eyes do
				burst(anchorAt(eye.part.Position, 1.5), SPARKLE, GOLD, 8, 0.35, 4)
			end
		end
		if wink > 0.95 and not winked then
			winked = true
			pop(head, "😉", head.Size.Y * 1.3, nil)
			burst(anchorAt(eyes[2].part.Position, 1.5), SPARKLE, Color3.new(1, 1, 1), 10, 0.3, 3)
		end
		-- Double biceps : grosse onde au moment où les bras montent, puis un anneau doré qui monte à chaque pompe
		if t > beats.Flex and not flexed then
			flexed = true
			shockwave(top + Vector3.new(0, 0.1, 0), GOLD, 18, 1.1)
			ring(
				CFrame.new(top + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				GOLD,
				size.X,
				size.X * 4,
				0.9,
				0.2
			)
			burst(anchorAt(top + Vector3.new(0, size.Y * 0.8, 0), 2.5), SPARKLE, GOLD, 45, 0.8, 9)
			sfx("SceneImpact", 1.1)
			shake(data, 0.7, 0.5)
		end
		if t > beats.Flex then
			local pump = math.floor((t - beats.Flex) * cfg.PumpRate / math.pi)
			if pump > pumps and t < duration - 0.8 then
				pumps = pump
				local y = top.Y + size.Y * (0.35 + 0.12 * pump)
				ring(
					CFrame.new(Vector3.new(center.X, y, center.Z)) * CFrame.Angles(0, 0, math.rad(90)),
					GOLD,
					size.X * 0.9,
					size.X * 2.4,
					0.6,
					0.12
				)
				for _, hand in hands do
					burst(anchorAt(hand.Position, 1.2), SPARKLE, GOLD, 6, 0.4, 3)
				end
			end
		end
	end, function()
		for _, eye in eyes do
			eye.part:Destroy()
		end
		-- Retour à la pierre : un peu de poussière retombe
		burst(anchorAt(top + Vector3.new(0, size.Y * 0.5, 0), 2), SMOKE, Color3.fromRGB(215, 205, 185), 8, 1, 2)
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
			duration = beats.Wink + 0.3,
			focus = face,
			fovFrom = 55,
			fovTo = 32,
		},
		{
			from = CFrame.lookAt(near3q, face),
			to = CFrame.lookAt(wide, chest),
			duration = duration - beats.Wink - 0.3,
			focus = chest,
			fovFrom = 32,
			fovTo = 64,
		},
	}, Color3.fromRGB(255, 235, 190))
end

-- ------------------------------------------------------------------ rat coach

local function ratFx(data)
	local rat = data.rat
	if typeof(rat) ~= "Instance" or not rat:IsA("BasePart") or not near(rat.Position) then
		return
	end
	local cfg = Secrets.SewerGains
	local duration = if typeof(data.duration) == "number" then data.duration else cfg.Show
	local base = rat.CFrame
	local baseSize = rat.Size
	local hole = anchorAt(base.Position - Vector3.new(0, rat.Size.Y * 0.5, 0), duration + 2)
	-- Bouffée de vapeur à l'ouverture, puis de fines volutes (elles ne doivent pas cacher le rat)
	burst(hole, SMOKE, Color3.fromRGB(220, 240, 220), 12, 1.1, 6)
	local wisps = stream(hole, SMOKE, Color3.fromRGB(200, 230, 200), 3, 0.5, 3, duration - 0.5)
	wisps.Transparency = NumberSequence.new(0.7, 1)
	light(hole, SEWER_GREEN, 2.5, 12, duration - 0.3)
	ring(CFrame.new(hole.Position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), SEWER_GREEN, 1, 6, 0.7)
	sfx("EventLand", 1.3)

	-- Découpage (D135) : il renifle à gauche et à droite ; pompes de plus en plus dures (la dernière tremble et
	-- transpire) ; il prend son élan, salto arrière, réception écrasée ; il se dresse et gonfle les bras, chaque
	-- pompe de biceps le fait grossir un instant ; il salue d'un dernier saut avant de redescendre (serveur).
	local pushups = cfg.Pushups
	local sniffEnd = 0.75
	local pushPeriod = 0.62
	local strainExtra = 0.35 -- la dernière pompe dure plus longtemps
	local pushEnd = sniffEnd + pushups * pushPeriod + strainExtra
	local flipStart = pushEnd + 0.15 -- petite pause, il s'accroupit
	local flipEnd = flipStart + 0.5
	local count = 0
	local flipped, landed, flexed = false, false, false
	local lastPump = 0
	animate(duration, function(t)
		if not rat.Parent then
			return
		end
		local frame = base
		local stretch = 0
		if t < sniffEnd then
			-- Il renifle : la tête balaie à gauche puis à droite, petits coups de nez rapides
			local look = math.sin(t / sniffEnd * math.pi * 2) * math.rad(35)
			local sniff = math.abs(math.sin(t * 28)) * 0.04
			frame = base * CFrame.Angles(math.rad(-4) - sniff * 2, look, 0)
			stretch = sniff
		elseif t < pushEnd then
			-- Pompes : on descend lentement, on remonte vite ; la dernière force (lente, tremblante)
			local local_t = t - sniffEnd
			local index = math.min(math.floor(local_t / pushPeriod) + 1, pushups)
			local last = index == pushups
			local period = if last then pushPeriod + strainExtra else pushPeriod
			local u = math.clamp((local_t - (index - 1) * pushPeriod) / period, 0, 1)
			local push = if u < 0.55 then ease(u / 0.55) else 1 - ease((u - 0.55) / 0.45)
			local tremble = if last and u > 0.35 and u < 0.85 then math.sin(t * 70) * 0.03 else 0
			frame = base * CFrame.new(tremble, -push * 0.32, 0) * CFrame.Angles(math.rad(-push * 12), 0, 0)
			stretch = -0.22 * push
			if u > 0.8 and index > count then
				count = index
				local final = count == pushups
				pop(rat, tostring(count) .. (if final then "!" else ""), rat.Size.Y + 0.8 + count * 0.15, GOLD)
				if final then
					pop(rat, "💦", rat.Size.Y + 0.4, nil)
				end
			end
		elseif t < flipStart then
			-- Élan : il s'écrase sur ses pattes
			local crouch = window(t, pushEnd, flipStart)
			frame = base * CFrame.new(0, -0.15 * crouch, 0)
			stretch = -0.3 * crouch
		elseif t < flipEnd then
			-- Salto arrière : arc en l'air, étiré en montant
			if not flipped then
				flipped = true
				sfx("EventWhoosh", 1.5)
			end
			local u = (t - flipStart) / (flipEnd - flipStart)
			local height = 4 * u * (1 - u) * 2.2
			frame = base * CFrame.new(0, height, 0) * CFrame.Angles(ease(u) * math.pi * 2, 0, 0)
			stretch = 0.25 * (1 - math.abs(u * 2 - 1))
		else
			-- Réception écrasée, puis il se dresse sur ses pattes arrière et gonfle les bras
			if not landed then
				landed = true
				burst(
					anchorAt(base.Position - Vector3.new(0, 0.3, 0), 1.5),
					SMOKE,
					Color3.fromRGB(200, 195, 180),
					8,
					0.6,
					3
				)
				shake(data, 0.25, 0.25)
			end
			local since = t - flipEnd
			local impact = math.max(0, 1 - since / 0.18)
			local stand = spring(since / 0.6, 1.5)
			local pumpWave = math.abs(math.sin(since * 7))
			local hop = math.abs(math.sin(since * 9)) * 0.18 * math.min(stand, 1)
			-- Salut final : un dernier saut avant que le serveur le fasse redescendre
			local bye = window(t, duration - 0.45, duration - 0.15)
			frame = base
				* CFrame.new(0, hop + stand * baseSize.Z * 0.3 + bye * 0.8, 0)
				* CFrame.Angles(math.rad(70) * stand, bye * math.pi, 0)
			stretch = -0.35 * impact + 0.1 * pumpWave * math.min(stand, 1)
			if stand > 0.85 and not flexed then
				flexed = true
				pop(rat, "💪", rat.Size.Y + 1.4, nil)
				burst(anchorAt(rat.Position + Vector3.new(0, 1, 0), 2), SPARKLE, GOLD, 22, 0.5, 5)
				bubble(rat, Texts.Get("Secret.SewerGains.Line"), rat.Size.Y + 2.2, duration - t - 0.3)
				sfx("SceneImpact", 1.6)
				shake(data, 0.3, 0.35)
			end
			local pump = math.floor(since * 7 / math.pi)
			if flexed and pump > lastPump and t < duration - 0.5 then
				lastPump = pump
				burst(anchorAt(rat.Position + Vector3.new(0, 0.6, 0), 1), SPARKLE, GOLD, 4, 0.3, 2)
			end
		end
		rat.Size = baseSize * squash(stretch)
		rat.CFrame = frame
	end, function()
		if rat.Parent then
			rat.Size = baseSize
			rat.CFrame = base
		end
	end)
	-- Caméra au ras du sol, à hauteur de rat (point de vue dégagé : le joueur est souvent juste au-dessus de la plaque)
	local look = base.LookVector
	local at = base.Position + Vector3.new(0, 0.5, 0)
	local up = at + Vector3.new(0, 1.4, 0)
	local ignore: { Instance } = { rat }
	local low = eyeOn(at, at + look * 5 + base.RightVector * 1.8 + Vector3.new(0, 0.8, 0), ignore)
	local front = eyeOn(up, at + look * 4.6 + Vector3.new(0, 0.6, 0), ignore)
	film(data, {
		{
			from = CFrame.lookAt(at + look * 7 + Vector3.new(0, 3, 0), at),
			to = CFrame.lookAt(low, at),
			duration = pushEnd,
			focus = at,
			fovFrom = 60,
			fovTo = 42,
		},
		{
			from = CFrame.lookAt(low, at),
			to = CFrame.lookAt(front, up),
			duration = duration - pushEnd,
			focus = up,
			fovFrom = 42,
			fovTo = 58,
		},
	}, Color3.fromRGB(205, 255, 205))
end

-- ------------------------------------------------------------------ miroir du passé

type MirrorPiece = { part: BasePart, rest: CFrame, opacity: number, height: number, arm: string? }

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
	local duration = if typeof(data.duration) == "number" then data.duration else Secrets.NeverForget.Show
	local front = mirror.CFrame.LookVector
	local glassFrame = mirror.CFrame * CFrame.new(0, 0, -mirror.Size.Z / 2 - 0.06)
	-- La glace : une nappe de lumière devant le miroir, et des ondes comme à la surface de l'eau
	local sheen = fxPart({
		Size = Vector3.new(mirror.Size.X * 0.9, mirror.Size.Y * 0.9, 0.05),
		CFrame = glassFrame,
		Color = Color3.fromRGB(150, 205, 255),
		Material = Enum.Material.Neon,
		Transparency = 1,
	})
	local rippleFrame = CFrame.lookAt(glassFrame.Position, glassFrame.Position + front)
		* CFrame.new(0, 0, -0.05)
		* CFrame.Angles(0, math.rad(90), 0)
	local reach = math.min(mirror.Size.X, mirror.Size.Y) * 0.9
	for index = 0, 2 do
		task.delay(index * 0.18, function()
			ring(rippleFrame, Color3.fromRGB(190, 230, 255), 0.4, reach, 0.9, 0.05)
		end)
	end
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

	-- Chaque pièce : sa place au repos dans le repère du reflet, sa transparence, sa hauteur (apparition de bas en
	-- haut) et son rôle (bras droit qui salue : épaule et coude)
	local pieces: { MirrorPiece } = {}
	local _, size = model:GetBoundingBox()
	local shoulder: CFrame? = nil
	local elbow: CFrame? = nil
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local rest = base:ToObjectSpace(item.CFrame)
			local bodyPart = item:GetAttribute("BodyPart")
			local arm = if bodyPart == "RightUpperArm"
					or bodyPart == "RightLowerArm"
					or bodyPart == "RightHand"
				then bodyPart :: string
				else nil
			if bodyPart == "RightUpperArm" and not shoulder then
				shoulder = CFrame.new(rest.Position + Vector3.new(0, item.Size.Y * 0.4, 0))
			elseif bodyPart == "RightLowerArm" and not elbow then
				elbow = CFrame.new(rest.Position + Vector3.new(0, item.Size.Y * 0.45, 0))
			end
			table.insert(pieces, {
				part = item,
				rest = rest,
				opacity = math.max(item.Transparency, 0.3),
				height = math.clamp(rest.Position.Y / math.max(size.Y, 0.1), 0, 1),
				arm = arm,
			})
			item.Transparency = 1
			item.CastShadow = false
		end
	end
	model.Parent = workspace
	-- Ligne lumineuse qui balaie le reflet de bas en haut pendant qu'il apparaît
	local scan = fxPart({
		Size = Vector3.new(size.X * 1.1, 0.06, size.Z * 1.1),
		CFrame = base,
		Color = Color3.fromRGB(200, 235, 255),
		Material = Enum.Material.Neon,
		Transparency = 1,
	})
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if root then
		task.delay(1.3, function()
			bubble(root, Texts.Get("Secret.NeverForget.Line"), size.Y * 0.5 + 1.2, duration - 2.4)
		end)
	end

	-- Découpage (D135) : ondes sur la glace (0 → 0,4 s) ; le reflet se dessine de bas en haut (→ 1,3 s) ; il salue du
	-- bras droit (le bras monte, l'avant-bras balance) en sautillant ; il se dissout du haut vers le bas en paillettes.
	local appearStart, appearEnd = 0.4, 1.3
	local vanishStart = duration - 1.1
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	animate(duration, function(t)
		sheen.Transparency = 1
			- (0.25 + math.sin(t * 5) * 0.1) * ease(t / 0.3) * (1 - window(t, vanishStart + 0.4, duration))
		local sweep = window(t, appearStart, appearEnd)
		scan.CFrame = base * CFrame.new(0, size.Y * sweep, 0)
		scan.Transparency = if t > appearStart and t < appearEnd then 0.2 else 1
		-- Salut : le bras monte avec un dépassement, puis l'avant-bras balance
		local raise = backOut((t - appearEnd) / 0.45) * (1 - window(t, vanishStart - 0.3, vanishStart))
		raise = math.max(raise, 0)
		local wave = math.sin((t - appearEnd) * 9) * math.rad(28) * math.min(raise, 1)
		local hop = math.abs(math.sin(t * 4.5)) * 0.18 * sweep * (1 - window(t, vanishStart - 0.3, vanishStart))
		local sway = math.sin(t * 2.2) * math.rad(4) * sweep
		local body = base * CFrame.new(0, hop, 0) * CFrame.Angles(0, 0, sway)
		table.clear(parts)
		table.clear(cframes)
		for _, piece in pieces do
			-- Apparition de bas en haut ; dissolution du haut vers le bas, chaque pièce s'envole un peu
			local shown = window(sweep, piece.height - 0.12, piece.height + 0.02)
			local gone = window(t, vanishStart + (1 - piece.height) * 0.6, vanishStart + (1 - piece.height) * 0.6 + 0.4)
			piece.part.Transparency = 1 - (1 - piece.opacity) * shown * (1 - gone)
			local cf = piece.rest
			if piece.arm and shoulder then
				local upper = shoulder * CFrame.Angles(0, 0, math.rad(150) * raise) * shoulder:Inverse()
				if piece.arm ~= "RightUpperArm" and elbow then
					cf = upper * elbow * CFrame.Angles(0, 0, wave) * elbow:Inverse() * cf
				else
					cf = upper * cf
				end
			end
			table.insert(parts, piece.part)
			table.insert(cframes, body * CFrame.new(0, gone * 1.2, 0) * cf)
		end
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end, function()
		burst(anchorAt(feet + Vector3.new(0, size.Y * 0.5, 0), 2), SPARKLE, GHOST_BLUE, 45, 0.6, 6)
		ring(rippleFrame, Color3.fromRGB(190, 230, 255), reach, 0.3, 0.5, 0.05)
		model:Destroy()
		sheen:Destroy()
		scan:Destroy()
	end)
	-- De biais (35°) devant la glace, jamais dans le dos du joueur : il se tient juste devant le miroir et le
	-- cacherait ; s'il passe quand même dans le champ, il s'efface
	local target = feet + Vector3.new(0, size.Y * 0.55, 0)
	local ignore: { Instance } = { mirror, sheen, model, scan }
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
