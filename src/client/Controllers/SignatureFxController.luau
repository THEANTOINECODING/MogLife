-- Mise en scène des tenues haut de gamme (D122, StyleSets.Signature), vue par tous les joueurs proches :
-- - traînée aux couleurs de la tenue quand le joueur se déplace vite ;
-- - entrée en scène quand il enfile la tenue, réapparaît, ou entre en combat (Remotes.OutfitShow « Entrance ») ;
-- - effet de victoire pendant sa pose de célébration (Remotes.EmotePlay, célébration) : le Dragon crache du feu, le
--   Soleil éclate en rayons, le Mecha allume ses réacteurs, la Statue se change en marbre couronné de laurier ;
-- - de temps en temps à l'arrêt, un petit effet (fumée, pulsation, balayage, reflet). Son attitude au repos est dans
--   MotionController ; l'aura (particules et lumière) dans OutfitFxController.
-- Purement visuel, calculé chez chaque joueur ; le réglage « effets de tenue » (OutfitFx) masque tout.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local StyleSets = require(ReplicatedStorage.Shared.Config.StyleSets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local FX = StyleSets.SignatureFx
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SPARKS = "rbxasset://textures/particles/fire_sparks_main.dds"
local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local GOLD = Color3.fromRGB(255, 205, 80)

local SettingsController

type Signature = typeof(StyleSets.Signature.GymDragon)
type State = {
	id: string,
	signature: Signature,
	character: Model,
	trail: Trail?,
	points: { Attachment },
	stillSince: number,
	nextIdle: number,
}

local states: { [Player]: State } = {}
local folder: Folder

local SignatureFxController = {}
SignatureFxController.Played = { Entrance = 0, Victory = 0, Idle = 0 } -- effets joués (tests dans Studio)

-- ------------------------------------------------------------------ outils

local function enabled(): boolean
	return SettingsController.Get("OutfitFx") ~= false
end

local function signatureOf(owner: Player): (string?, Signature?)
	local id = owner:GetAttribute("PremiumSet")
	if typeof(id) == "string" and StyleSets.Signature[id] then
		return id, StyleSets.Signature[id]
	end
	return nil, nil
end

local function partOf(character: Model, name: string): BasePart?
	local part = character:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part else nil
end

-- Repères du personnage : pieds, centre du torse, tête, hauteur, orientation
type Frame = { feet: Vector3, chest: Vector3, head: Vector3, height: number, cf: CFrame }
local function frameOf(character: Model): Frame?
	local root = partOf(character, "HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return nil
	end
	local feet = root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	local head = partOf(character, "Head")
	local torso = partOf(character, "UpperTorso")
	local headPos = if head then head.Position else root.Position + Vector3.new(0, 3, 0)
	return {
		feet = feet,
		chest = if torso then torso.Position else root.Position,
		head = headPos,
		height = math.max(headPos.Y - feet.Y, 2),
		cf = CFrame.new(root.Position) * root.CFrame.Rotation,
	}
end

local function near(character: Model): boolean
	local root = partOf(character, "HumanoidRootPart")
	local camera = workspace.CurrentCamera
	return root ~= nil and camera ~= nil and (root.Position - camera.CFrame.Position).Magnitude <= FX.MaxDistance
end

local function fxPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = folder
	return part
end

local function fade(instance: Instance, duration: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local tween = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad), goal)
	tween:Play()
	return tween
end

-- Disque horizontal (onde au sol, anneau de balayage) : cylindre couché
local function disc(center: Vector3, diameter: number, color: Color3, transparency: number): Part
	return fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, diameter, diameter),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = transparency,
	})
end

-- Onde qui s'élargit et s'efface
local function shockwave(center: Vector3, color: Color3, from: number, to: number, duration: number)
	local wave = disc(center, from, color, 0.25)
	fade(wave, duration, { Size = Vector3.new(0.06, to, to), Transparency = 1 }, Enum.EasingStyle.Quart)
	task.delay(duration, function()
		wave:Destroy()
	end)
end

-- Lumière qui s'allume puis s'éteint
local function flash(parent: Instance, color: Color3, brightness: number, range: number, duration: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = parent
	fade(light, duration, { Brightness = 0 })
	task.delay(duration, function()
		light:Destroy()
	end)
end

-- Émetteur de particules posé sur une attache ; émet `burst` d'un coup, ou en continu pendant `duration`
type Emit = {
	texture: string,
	colors: { Color3 },
	size: { number },
	lifetime: { number },
	speed: { number },
	spread: number?,
	rate: number?,
	direction: Enum.NormalId?,
	accel: Vector3?,
	light: number?,
	drag: number?,
	transparency: { number }?,
}
local function emitter(point: Attachment, spec: Emit): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = spec.texture
	local keys = {}
	for index, color in spec.colors do
		table.insert(keys, ColorSequenceKeypoint.new((index - 1) / math.max(#spec.colors - 1, 1), color))
	end
	particles.Color = ColorSequence.new(keys)
	particles.Size = NumberSequence.new(spec.size[1], spec.size[2])
	particles.Lifetime = NumberRange.new(spec.lifetime[1], spec.lifetime[2])
	particles.Speed = NumberRange.new(spec.speed[1], spec.speed[2])
	local spread = spec.spread or 180
	particles.SpreadAngle = Vector2.new(spread, spread)
	particles.EmissionDirection = spec.direction or Enum.NormalId.Top
	particles.Acceleration = spec.accel or Vector3.zero
	particles.LightEmission = spec.light or 0.6
	particles.Drag = spec.drag or 0
	local t = spec.transparency or { 0.1, 1 }
	particles.Transparency = NumberSequence.new(t[1], t[2])
	particles.Rate = spec.rate or 0
	particles.Enabled = (spec.rate or 0) > 0
	particles.Parent = point
	return particles
end

-- Attache temporaire sur une partie du personnage (suit ses mouvements), détruite après `life` secondes
local function attach(part: BasePart, offset: CFrame, life: number): Attachment
	local point = Instance.new("Attachment")
	point.Name = "SignatureFx"
	point.CFrame = offset
	point.Parent = part
	task.delay(life, function()
		point:Destroy()
	end)
	return point
end

-- Attache temporaire fixe dans le monde
local function anchorAt(position: Vector3, life: number): Attachment
	local base = fxPart({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Position = position })
	local point = Instance.new("Attachment")
	point.Parent = base
	task.delay(life, function()
		base:Destroy()
	end)
	return point
end

local function burst(point: Attachment, spec: Emit, count: number)
	local particles = emitter(point, spec)
	particles:Emit(count)
	return particles
end

-- Surbrillance qui recouvre tout le personnage (statue de marbre, reflet)
local function glaze(character: Model, fill: Color3, outline: Color3, fillFrom: number, hold: number, out: number)
	local light = Instance.new("Highlight")
	light.Name = "SignatureGlaze"
	light.FillColor = fill
	light.OutlineColor = outline
	light.FillTransparency = 1
	light.OutlineTransparency = 1
	light.DepthMode = Enum.HighlightDepthMode.Occluded
	light.Adornee = character
	light.Parent = character
	fade(light, 0.25, { FillTransparency = fillFrom, OutlineTransparency = 0 })
	task.delay(0.25 + hold, function()
		fade(light, out, { FillTransparency = 1, OutlineTransparency = 1 })
		task.wait(out)
		light:Destroy()
	end)
end

-- ------------------------------------------------------------------ entrée en scène

local entrances = {}

function entrances.Dragon(_character: Model, f: Frame, sig: Signature, time: number)
	-- Anneau de feu qui jaillit du sol autour des pieds, flammes vers le ciel
	shockwave(f.feet + Vector3.new(0, 0.1, 0), sig.color, 1, 14, time * 0.6)
	local ground = anchorAt(f.feet, time + 1.5)
	local flames = emitter(ground, {
		texture = FIRE,
		colors = { Color3.fromRGB(255, 230, 120), sig.color, Color3.fromRGB(120, 20, 10) },
		size = { 1.6, 0.2 },
		lifetime = { 0.5, 0.9 },
		speed = { 10, 18 },
		spread = 25,
		rate = 90,
		light = 0.9,
	})
	burst(ground, {
		texture = SPARKS,
		colors = { Color3.fromRGB(255, 220, 90), sig.color },
		size = { 0.4, 0 },
		lifetime = { 0.8, 1.4 },
		speed = { 8, 16 },
		spread = 70,
		accel = Vector3.new(0, -12, 0),
	}, 60)
	flash(ground, sig.glow, 6, 22, time)
	task.delay(time * 0.5, function()
		flames.Enabled = false
	end)
end

function entrances.Sun(_character: Model, f: Frame, sig: Signature, time: number)
	-- Colonne de lumière qui tombe du ciel sur le joueur, puis s'ouvre et s'efface
	local pillar = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(80, 0.4, 0.4),
		CFrame = CFrame.new(f.feet + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = sig.glow,
		Transparency = 0.15,
	})
	fade(pillar, time * 0.35, { Size = Vector3.new(80, f.height * 1.4, f.height * 1.4), Transparency = 0.45 })
	task.delay(time * 0.35, function()
		fade(pillar, time * 0.65, { Size = Vector3.new(80, 0.2, 0.2), Transparency = 1 })
	end)
	task.delay(time, function()
		pillar:Destroy()
	end)
	shockwave(f.feet + Vector3.new(0, 0.1, 0), sig.color, 2, 16, time * 0.7)
	local point = anchorAt(f.chest, time + 2)
	burst(point, {
		texture = SPARKLES,
		colors = { Color3.new(1, 1, 1), sig.color },
		size = { 0.7, 0 },
		lifetime = { 1, 1.8 },
		speed = { 6, 12 },
		drag = 2,
	}, 70)
	flash(point, sig.glow, 8, 26, time)
end

function entrances.Mecha(_character: Model, f: Frame, sig: Signature, time: number)
	-- Téléportation : trois anneaux de balayage descendent de la tête aux pieds, étincelles, lumière qui grésille
	for index = 0, 2 do
		task.delay(index * time * 0.18, function()
			local ring = disc(f.head + Vector3.new(0, 0.8, 0), f.height * 0.9, sig.color, 0.3)
			fade(ring, time * 0.45, { Position = f.feet + Vector3.new(0, 0.1, 0) }, Enum.EasingStyle.Sine)
			task.delay(time * 0.45, function()
				fade(ring, 0.25, { Transparency = 1, Size = Vector3.new(0.06, f.height * 1.6, f.height * 1.6) })
				task.wait(0.25)
				ring:Destroy()
			end)
		end)
	end
	local point = anchorAt(f.chest, time + 1.5)
	burst(point, {
		texture = SPARKLES,
		colors = { sig.glow, sig.color },
		size = { 0.35, 0 },
		lifetime = { 0.4, 0.8 },
		speed = { 10, 20 },
		drag = 3,
		light = 1,
	}, 50)
	-- Grésillement : la lumière s'allume par à-coups
	task.spawn(function()
		for _ = 1, 4 do
			flash(point, sig.color, 5, 18, 0.12)
			task.wait(0.18)
		end
	end)
	shockwave(f.feet + Vector3.new(0, 0.1, 0), sig.color, 1, 10, time * 0.5)
end

function entrances.Marble(character: Model, f: Frame, sig: Signature, time: number)
	-- Nuage de poussière de marbre, couronne dorée qui monte des pieds à la tête, le joueur luit comme une statue
	local ground = anchorAt(f.feet + Vector3.new(0, 0.5, 0), time + 2.5)
	burst(ground, {
		texture = SMOKE,
		colors = { Color3.fromRGB(250, 248, 240), Color3.fromRGB(200, 196, 188) },
		size = { 2.2, 4 },
		lifetime = { 1.2, 2 },
		speed = { 4, 9 },
		spread = 80,
		drag = 2.5,
		light = 0,
		transparency = { 0.35, 1 },
	}, 30)
	local ring = disc(f.feet + Vector3.new(0, 0.2, 0), f.height * 0.8, sig.glow, 0.2)
	fade(
		ring,
		time * 0.7,
		{ Position = f.head + Vector3.new(0, 0.6, 0), Size = Vector3.new(0.12, 2, 2) },
		Enum.EasingStyle.Sine
	)
	task.delay(time * 0.7, function()
		fade(ring, 0.3, { Transparency = 1 })
		task.wait(0.3)
		ring:Destroy()
	end)
	glaze(character, Color3.fromRGB(250, 248, 242), sig.glow, 0.35, time * 0.5, 0.6)
	flash(ground, sig.glow, 4, 16, time)
end

local function playEntrance(owner: Player)
	local state = states[owner]
	if not state or not enabled() or not near(state.character) then
		return
	end
	local f = frameOf(state.character)
	local play = entrances[state.signature.style]
	if f and play then
		SignatureFxController.Played.Entrance += 1
		play(state.character, f, state.signature, state.signature.entrance)
	end
end

-- ------------------------------------------------------------------ victoire

local victories = {}

function victories.Dragon(character: Model, f: Frame, sig: Signature, time: number)
	-- Il crache un long jet de feu devant lui, puis des braises retombent
	local head = partOf(character, "Head")
	if head then
		local mouth = attach(head, CFrame.new(0, -head.Size.Y * 0.15, -head.Size.Z * 0.55), time + 1.2)
		local breath = emitter(mouth, {
			texture = FIRE,
			colors = { Color3.fromRGB(255, 245, 170), sig.color, Color3.fromRGB(90, 20, 10) },
			size = { 0.5, 3.2 },
			lifetime = { 0.55, 0.85 },
			speed = { 20, 28 },
			spread = 10,
			rate = 140,
			direction = Enum.NormalId.Front,
			light = 0.9,
		})
		local light = Instance.new("PointLight")
		light.Color = sig.glow
		light.Brightness = 5
		light.Range = 20
		light.Shadows = false
		light.Parent = mouth
		task.delay(time * 0.75, function()
			breath.Enabled = false
			fade(light, 0.4, { Brightness = 0 })
		end)
	end
	local point = anchorAt(f.head + Vector3.new(0, 1, 0), time + 2)
	burst(point, {
		texture = SPARKS,
		colors = { Color3.fromRGB(255, 220, 90), sig.color },
		size = { 0.35, 0 },
		lifetime = { 1.2, 2 },
		speed = { 4, 10 },
		accel = Vector3.new(0, -8, 0),
	}, 40)
end

function victories.Sun(_character: Model, f: Frame, sig: Signature, time: number)
	-- Éruption solaire : un soleil grossit derrière lui, douze rayons tournent et s'allongent
	local center = f.chest + Vector3.new(0, f.height * 0.15, 0)
	local core = fxPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1,
		Position = center,
		Color = sig.glow,
		Transparency = 0.2,
	})
	fade(core, time * 0.4, { Size = Vector3.one * f.height * 1.3, Transparency = 0.75 }, Enum.EasingStyle.Back)
	local rays: { Part } = {}
	for index = 1, 12 do
		table.insert(
			rays,
			fxPart({
				Size = Vector3.new(0.25, 0.25, 0.1),
				Color = if index % 2 == 0 then sig.color else sig.glow,
				Transparency = 0.15,
				CFrame = CFrame.new(center),
			})
		)
	end
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t > time then
			connection:Disconnect()
			for _, ray in rays do
				ray:Destroy()
			end
			fade(core, 0.4, { Transparency = 1 })
			task.delay(0.4, function()
				core:Destroy()
			end)
			return
		end
		local grow = math.min(t / (time * 0.35), 1)
		local fadeOut = math.clamp((time - t) / 0.5, 0, 1)
		for index, ray in rays do
			local angle = index / #rays * math.pi * 2 + t * 0.9
			local length = f.height * (if index % 2 == 0 then 1.4 else 0.9) * grow
			local dir = Vector3.new(math.cos(angle), math.sin(angle), 0)
			local facing = f.cf.Rotation
			local mid = center
				+ facing:VectorToWorldSpace(dir * (f.height * 0.45 + length / 2))
				+ facing.LookVector * -0.6
			ray.Size = Vector3.new(0.3, length, 0.12)
			ray.CFrame = CFrame.new(mid) * facing * CFrame.Angles(0, 0, angle - math.pi / 2)
			ray.Transparency = 1 - 0.85 * fadeOut
		end
	end)
	local point = anchorAt(center, time + 2)
	flash(point, sig.glow, 9, 30, time)
	burst(point, {
		texture = SPARKLES,
		colors = { Color3.new(1, 1, 1), sig.color },
		size = { 0.6, 0 },
		lifetime = { 1.2, 2 },
		speed = { 8, 14 },
		drag = 2,
	}, 60)
end

function victories.Mecha(character: Model, f: Frame, sig: Signature, time: number)
	-- Réacteurs allumés : deux jets bleus sous le dos, onde au sol, anneaux de visée qui s'ouvrent autour de lui
	local torso = partOf(character, "UpperTorso")
	if torso then
		for _, sx in { -1, 1 } do
			local nozzle =
				attach(torso, CFrame.new(sx * torso.Size.X * 0.18, -torso.Size.Y * 0.45, torso.Size.Z * 0.6), time + 1)
			local jet = emitter(nozzle, {
				texture = FIRE,
				colors = { Color3.new(1, 1, 1), sig.glow, sig.color },
				size = { 0.8, 0.1 },
				lifetime = { 0.25, 0.4 },
				speed = { 14, 20 },
				spread = 6,
				rate = 110,
				direction = Enum.NormalId.Bottom,
				light = 1,
			})
			task.delay(time * 0.85, function()
				jet.Enabled = false
			end)
		end
		flash(torso, sig.color, 5, 18, time)
	end
	shockwave(f.feet + Vector3.new(0, 0.1, 0), sig.color, 1, 12, time * 0.5)
	for index = 0, 2 do
		task.delay(index * 0.35, function()
			local ring = disc(f.chest, 1, sig.glow, 0.35)
			ring.CFrame = CFrame.new(f.chest) * f.cf.Rotation * CFrame.Angles(0, math.rad(90), 0)
			fade(ring, 0.7, { Size = Vector3.new(0.06, f.height * 1.5, f.height * 1.5), Transparency = 1 })
			task.delay(0.7, function()
				ring:Destroy()
			end)
		end)
	end
end

function victories.Marble(character: Model, f: Frame, sig: Signature, time: number)
	-- Il se fige en statue de marbre ; une couronne de laurier dorée tourne au-dessus de sa tête
	glaze(character, Color3.fromRGB(248, 246, 238), sig.glow, 0.15, time * 0.8, 0.5)
	local crown: { Part } = {}
	for _ = 1, 10 do
		table.insert(
			crown,
			fxPart({
				Size = Vector3.new(0.18, 0.12, 0.42),
				Color = GOLD,
				Transparency = 1,
				Material = Enum.Material.Neon,
			})
		)
	end
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local head = partOf(character, "Head")
		if t > time or not head then
			connection:Disconnect()
			for _, leaf in crown do
				leaf:Destroy()
			end
			return
		end
		local appear = math.clamp(t / 0.3, 0, 1) * math.clamp((time - t) / 0.4, 0, 1)
		local top = head.Position + Vector3.new(0, head.Size.Y * 0.75 + 0.3 * (1 - appear), 0)
		local radius = head.Size.X * 0.62
		for index, leaf in crown do
			local angle = index / #crown * math.pi * 2 + t * 0.8
			local at = top + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			leaf.CFrame = CFrame.lookAt(at, at + Vector3.new(-math.sin(angle), 0.35, math.cos(angle)))
			leaf.Transparency = 1 - appear
		end
	end)
	local point = anchorAt(f.head + Vector3.new(0, 1.2, 0), time + 2)
	burst(point, {
		texture = SPARKLES,
		colors = { Color3.new(1, 1, 1), sig.glow },
		size = { 0.5, 0 },
		lifetime = { 1, 1.6 },
		speed = { 3, 7 },
		drag = 1.5,
	}, 40)
	flash(point, sig.glow, 4, 16, time)
end

local function playVictory(owner: Player)
	local state = states[owner]
	if not state or not enabled() or not near(state.character) then
		return
	end
	local f = frameOf(state.character)
	local play = victories[state.signature.style]
	if f and play then
		SignatureFxController.Played.Victory += 1
		-- Laisser au personnage le temps de prendre la pose
		task.delay(0.25, play, state.character, f, state.signature, FX.VictoryTime)
	end
end

-- ------------------------------------------------------------------ au repos

local idles = {}

function idles.Dragon(character: Model, _f: Frame, sig: Signature)
	-- Deux bouffées de fumée par les naseaux, quelques braises
	local head = partOf(character, "Head")
	if not head then
		return
	end
	local nose = attach(head, CFrame.new(0, -head.Size.Y * 0.05, -head.Size.Z * 0.55), 3)
	burst(nose, {
		texture = SMOKE,
		colors = { Color3.fromRGB(120, 115, 110), Color3.fromRGB(60, 58, 56) },
		size = { 0.4, 1.4 },
		lifetime = { 1, 1.6 },
		speed = { 1.5, 3 },
		spread = 20,
		direction = Enum.NormalId.Front,
		accel = Vector3.new(0, 2, 0),
		light = 0,
		transparency = { 0.4, 1 },
	}, 6)
	burst(nose, {
		texture = SPARKS,
		colors = { Color3.fromRGB(255, 220, 90), sig.color },
		size = { 0.15, 0 },
		lifetime = { 0.6, 1 },
		speed = { 2, 4 },
		spread = 40,
		direction = Enum.NormalId.Front,
	}, 5)
end

function idles.Sun(character: Model, f: Frame, sig: Signature)
	-- L'auréole pulse : un anneau de lumière s'ouvre dans son dos
	local torso = partOf(character, "UpperTorso")
	if not torso then
		return
	end
	local back = torso.CFrame * CFrame.new(0, torso.Size.Y * 0.35, torso.Size.Z * 0.9)
	local ring = disc(back.Position, f.height * 0.35, sig.glow, 0.4)
	ring.CFrame = back * CFrame.Angles(0, math.rad(90), 0)
	fade(ring, 1, { Size = Vector3.new(0.05, f.height * 0.9, f.height * 0.9), Transparency = 1 })
	task.delay(1, function()
		ring:Destroy()
	end)
	flash(torso, sig.glow, 3, 14, 1.2)
end

function idles.Mecha(_character: Model, f: Frame, sig: Signature)
	-- Auto-diagnostic : un plan de balayage descend de la tête aux pieds
	local ring = disc(f.head + Vector3.new(0, 0.5, 0), f.height * 0.75, sig.color, 0.55)
	fade(ring, 0.8, { Position = f.feet + Vector3.new(0, 0.1, 0) }, Enum.EasingStyle.Linear)
	task.delay(0.8, function()
		fade(ring, 0.15, { Transparency = 1 })
		task.wait(0.15)
		ring:Destroy()
	end)
end

function idles.Marble(character: Model, f: Frame, sig: Signature)
	-- Un reflet passe sur le marbre ; quelques grains de poussière tombent
	glaze(character, Color3.new(1, 1, 1), sig.glow, 0.7, 0.1, 0.45)
	local point = anchorAt(f.chest + Vector3.new(0, f.height * 0.2, 0), 3)
	burst(point, {
		texture = SPARKLES,
		colors = { Color3.new(1, 1, 1), sig.glow },
		size = { 0.25, 0 },
		lifetime = { 1, 1.5 },
		speed = { 0.5, 1.5 },
		accel = Vector3.new(0, -3, 0),
	}, 6)
end

-- ------------------------------------------------------------------ suivi des joueurs

local function clear(owner: Player)
	local state = states[owner]
	if state then
		states[owner] = nil
		for _, point in state.points do
			point:Destroy()
		end
		if state.trail then
			state.trail:Destroy()
		end
	end
end

-- Traînée entre les deux omoplates (sous l'aura) : visible dès qu'il se déplace vite
local function buildTrail(torso: BasePart, sig: Signature): (Trail, { Attachment })
	local points = {}
	for _, sx in { -1, 1 } do
		local point = Instance.new("Attachment")
		point.Name = "SignatureTrail"
		point.Position = Vector3.new(sx * torso.Size.X * 0.45, -torso.Size.Y * 0.1, torso.Size.Z * 0.3)
		point.Parent = torso
		table.insert(points, point)
	end
	local trail = Instance.new("Trail")
	trail.Name = "SignatureTrail"
	trail.Attachment0 = points[1]
	trail.Attachment1 = points[2]
	trail.Color = ColorSequence.new(sig.trail[1], sig.trail[2])
	trail.Transparency = NumberSequence.new(0.25, 1)
	trail.Lifetime = FX.TrailLifetime
	trail.LightEmission = 0.8
	trail.FaceCamera = true
	trail.WidthScale = NumberSequence.new(1, 0.3)
	trail.Enabled = false
	trail.Parent = torso
	return trail, points
end

local function refresh(owner: Player, entrance: boolean)
	local id, sig = signatureOf(owner)
	local character = owner.Character
	local torso = character and partOf(character, "UpperTorso")
	local state = states[owner]
	if not id or not sig or not character or not torso or not enabled() then
		clear(owner)
		return
	end
	if state and state.id == id and state.character == character and state.trail and state.trail.Parent == torso then
		return
	end
	clear(owner)
	local trail, points = buildTrail(torso, sig)
	states[owner] = {
		id = id,
		signature = sig,
		character = character,
		trail = trail,
		points = points,
		stillSince = os.clock(),
		nextIdle = os.clock() + FX.IdleAfter + sig.idleEvery,
	}
	if entrance then
		task.delay(0.3, playEntrance, owner)
	end
end

local function watch(owner: Player)
	owner:GetAttributeChangedSignal("PremiumSet"):Connect(function()
		refresh(owner, true)
	end)
	owner.CharacterAdded:Connect(function(character)
		character:WaitForChild("UpperTorso", 10)
		-- L'apparence (corps, tenue) se construit d'abord côté serveur
		task.wait(0.5)
		refresh(owner, true)
	end)
	refresh(owner, false)
end

local function step()
	local now = os.clock()
	for owner, state in states do
		local character = state.character
		local root = partOf(character, "HumanoidRootPart")
		if not character.Parent or not root then
			clear(owner)
			continue
		end
		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		if state.trail then
			state.trail.Enabled = speed >= FX.TrailMinSpeed
		end
		if speed > 1 or owner:GetAttribute("InRun") then
			state.stillSince = now
			state.nextIdle = math.max(state.nextIdle, now + FX.IdleAfter)
			continue
		end
		if now - state.stillSince >= FX.IdleAfter and now >= state.nextIdle then
			state.nextIdle = now + state.signature.idleEvery
			local play = idles[state.signature.style]
			local f = near(character) and frameOf(character)
			if play and f then
				SignatureFxController.Played.Idle += 1
				play(character, f, state.signature)
			end
		end
	end
end

-- Tests dans Studio (et réglage changé) : tout reconstruire
function SignatureFxController.RefreshAll()
	for _, owner in Players:GetPlayers() do
		refresh(owner, false)
	end
end

SignatureFxController.PlayEntrance = playEntrance
SignatureFxController.PlayVictory = playVictory
SignatureFxController.Step = step

function SignatureFxController.Init(controllers)
	SettingsController = controllers.SettingsController
end

function SignatureFxController.Start()
	folder = Instance.new("Folder")
	folder.Name = "SignatureFx"
	folder.Parent = workspace
	for _, owner in Players:GetPlayers() do
		watch(owner)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
	Remotes.OutfitShow.OnClientEvent:Connect(function(owner, kind)
		if typeof(owner) == "Instance" and owner:IsA("Player") and kind == "Entrance" then
			playEntrance(owner)
		end
	end)
	Remotes.EmotePlay.OnClientEvent:Connect(function(owner, _index, celebrate)
		if celebrate == true and typeof(owner) == "Instance" and owner:IsA("Player") then
			playVictory(owner)
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return SignatureFxController
