-- Spectacle des événements de ville (D100), joué chez chaque joueur à partir des objets posés par EventService :
-- - haltères dorés : ils tournent et flottent sous une colonne de lumière dorée, gerbe d'étincelles quand on en
--   ramasse un (le MÉGA haltère a une colonne rouge et or plus large) ;
-- - shakes : ils descendent du ciel sous un parachute rayé, une cible lumineuse montre où ils vont tomber ; posés,
--   ils tournent en brillant ;
-- - piano fugueur : une copie locale du piano, lissée, qui court sur deux jambes en baskets, avec des yeux qui
--   suivent le joueur le plus proche, des notes de musique, de la poussière, un « ! » quand il panique, de la sueur
--   quand il est essoufflé, des étoiles quand il est sonné ; il tombe à la renverse quand il est arrêté.
-- Les objets du serveur restent les vrais (contact, bouton) ; ils sont seulement cachés ici quand une copie animée
-- les remplace. Rien ici ne décide de quoi que ce soit.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Events = require(ReplicatedStorage.Shared.Config.Events)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local GOLD = Color3.fromRGB(255, 205, 60)
local MEGA_RED = Color3.fromRGB(255, 90, 60)
local SHAKE_PINK = Color3.fromRGB(240, 170, 215)
local FX_DISTANCE = 260 -- au-delà, on n'anime pas (téléphone)

local player = Players.LocalPlayer

local SoundController
local UIController

local fxFolder: Folder
local removers: { [Instance]: () -> () } = {} -- nettoyage quand le serveur retire l'objet

local EventFxController = {}

-- ------------------------------------------------------------------ outils

local function fxPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = props.Parent or fxFolder
	return part
end

-- Copie locale d'un objet du serveur, sans ses tags ni ses boutons (sinon elle serait reprise par les contrôleurs)
local function visualCopy(source: BasePart): BasePart
	local copy = source:Clone()
	for _, tag in copy:GetTags() do
		copy:RemoveTag(tag)
	end
	for _, child in copy:GetChildren() do
		child:Destroy()
	end
	copy.Anchored = true
	copy.CanCollide = false
	copy.CanQuery = false
	copy.CanTouch = false
	copy.Transparency = 0
	copy.Parent = fxFolder
	return copy
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE
	e.LightInfluence = 1
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

local function near(position: Vector3, distance: number): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude < distance
end

-- Gerbe d'étincelles + onde au sol (objet ramassé, shake bu, piano arrêté)
local function burst(position: Vector3, color: Color3, size: number)
	local anchor = fxPart({ Size = Vector3.one * 0.2, Transparency = 1, Position = position })
	local sparks = emitter(anchor, {
		Texture = SPARKLE,
		Color = ColorSequence.new(color, Color3.new(1, 1, 1)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.9), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(10 * size, 22 * size),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -25, 0),
		Drag = 2,
		LightEmission = 1,
		Rate = 0,
	})
	sparks:Emit(math.floor(30 * size))
	local ring = fxPart({
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.2,
		Size = Vector3.new(0.15, 1, 1),
		CFrame = CFrame.new(position - Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, 0, math.pi / 2),
	})
	TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.15, 14 * size, 14 * size),
		Transparency = 1,
	}):Play()
	Debris:AddItem(anchor, 1.5)
	Debris:AddItem(ring, 0.7)
end

-- Petit texte qui monte et s'efface (notes de musique, « ! »)
local function floatText(adornee: BasePart, offset: Vector3, text: string, color: Color3, rise: number, life: number)
	local gui = Ui.create("BillboardGui", {
		Size = UDim2.fromOffset(48, 48),
		StudsOffsetWorldSpace = offset,
		LightInfluence = 0,
		MaxDistance = 140,
		Adornee = adornee,
		Parent = fxFolder,
	}, {
		Ui.label({ Size = UDim2.fromScale(1, 1), Text = text, TextColor3 = color }),
	})
	local label = gui:FindFirstChildOfClass("TextLabel") :: TextLabel
	local info = TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = offset + Vector3.new(0, rise, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(gui, life)
end

-- ------------------------------------------------------------------ haltères dorés

type Dumbbell = { part: BasePart, base: CFrame, pillar: Part, ring: Part, phase: number }
local dumbbells: { [BasePart]: Dumbbell } = {}

local function addDumbbell(part: Instance)
	if not part:IsA("BasePart") or dumbbells[part] then
		return
	end
	local mega = part:GetAttribute("Mega") == true
	local color = if mega then MEGA_RED else GOLD
	local width = if mega then 4 else 2.4
	local hover = Events.GoldenDumbbells.Hover
	local groundY = part.Position.Y - part.Size.Y / 2 - hover
	local pillar = fxPart({
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.72,
		Size = Vector3.new(90, width, width),
		CFrame = CFrame.new(part.Position.X, groundY + 45, part.Position.Z) * CFrame.Angles(0, 0, math.pi / 2),
	})
	local ring = fxPart({
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.45,
		Size = Vector3.new(0.12, width * 2.2, width * 2.2),
		CFrame = CFrame.new(part.Position.X, groundY + 0.08, part.Position.Z) * CFrame.Angles(0, 0, math.pi / 2),
	})
	emitter(part, {
		Texture = SPARKLE,
		Color = ColorSequence.new(color),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, if mega then 1 else 0.6),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
		Rate = if mega then 14 else 6,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = if mega then 20 else 14
	light.Brightness = 2.5
	light.Parent = part
	dumbbells[part] = { part = part, base = part.CFrame, pillar = pillar, ring = ring, phase = math.random() * 6 }
	removers[part] = function()
		local entry = dumbbells[part]
		dumbbells[part] = nil
		if entry then
			entry.pillar:Destroy()
			entry.ring:Destroy()
		end
	end
end

local function updateDumbbells(now: number)
	for part, entry in dumbbells do
		if near(entry.base.Position, FX_DISTANCE) then
			local bob = math.sin(now * 2.2 + entry.phase) * 0.35
			part.CFrame = CFrame.new(entry.base.Position + Vector3.new(0, bob, 0))
				* CFrame.Angles(0, now * 1.6 + entry.phase, 0)
				* entry.base.Rotation
			entry.pillar.Transparency = 0.72 + math.sin(now * 3 + entry.phase) * 0.06
		end
	end
end

-- ------------------------------------------------------------------ shakes en parachute

type Shake = {
	part: BasePart,
	cup: BasePart,
	canopy: { { part: BasePart, offset: CFrame } },
	target: Part,
	ground: Vector3,
	landsAt: number,
	landed: boolean,
	spin: number,
}
local shakes: { [BasePart]: Shake } = {}

-- Fil entre deux points (repère du parachute)
local function cordOffset(a: Vector3, b: Vector3): (CFrame, Vector3)
	local mid = (a + b) / 2
	return CFrame.lookAt(mid, b), Vector3.new(0.06, 0.06, (b - a).Magnitude)
end

local function addShake(part: Instance)
	if not part:IsA("BasePart") or shakes[part] then
		return
	end
	local landsAt = part:GetAttribute("LandsAt")
	if typeof(landsAt) ~= "number" then
		return
	end
	part.Transparency = 1 -- la copie animée la remplace
	local cup = visualCopy(part)
	local half = part.Size.Y / 2
	local canopy = {}
	local stripes = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(240, 90, 150) }
	local top = half + 5.2 -- centre du parachute au-dessus du shake
	for i = 0, 7 do
		local panel =
			fxPart({ Material = Enum.Material.Fabric, Color = stripes[i % 2 + 1], Size = Vector3.new(2.3, 0.12, 2.6) })
		local offset = CFrame.new(0, top, 0)
			* CFrame.Angles(0, i * math.pi / 4, 0)
			* CFrame.new(0, -0.6, -1.65)
			* CFrame.Angles(-math.rad(32), 0, 0)
		table.insert(canopy, { part = panel, offset = offset })
	end
	local cap = fxPart({
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Fabric,
		Color = stripes[2],
		Size = Vector3.new(1.8, 1.8, 1.8),
	})
	table.insert(canopy, { part = cap, offset = CFrame.new(0, top + 0.1, 0) })
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		local rim = Vector3.new(math.sin(a) * 2.7, top - 1.4, math.cos(a) * 2.7)
		local offset, size = cordOffset(rim, Vector3.new(0, half, 0))
		local cord = fxPart({ Color = Color3.fromRGB(235, 235, 235), Size = size })
		table.insert(canopy, { part = cord, offset = offset })
	end
	local ground = part.Position - Vector3.new(0, half, 0)
	local target = fxPart({
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		Color = SHAKE_PINK,
		Transparency = 0.5,
		Size = Vector3.new(0.12, 5, 5),
		CFrame = CFrame.new(ground + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.pi / 2),
	})
	local light = Instance.new("PointLight")
	light.Color = SHAKE_PINK
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = cup
	emitter(cup, {
		Texture = SPARKLE,
		Color = ColorSequence.new(SHAKE_PINK),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(0.5, 2),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
		Rate = 4,
	})
	local entry: Shake = {
		part = part,
		cup = cup,
		canopy = canopy,
		target = target,
		ground = ground,
		landsAt = landsAt,
		landed = false,
		spin = math.random() * 6,
	}
	shakes[part] = entry
	removers[part] = function()
		shakes[part] = nil
		cup:Destroy()
		target:Destroy()
		for _, piece in entry.canopy do
			piece.part:Destroy()
		end
	end
end

-- Posé : le parachute s'affaisse et disparaît, petit nuage de poussière
local function land(entry: Shake)
	entry.landed = true
	entry.target:Destroy()
	for _, piece in entry.canopy do
		local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(piece.part, info, {
			CFrame = piece.part.CFrame * CFrame.new(math.random() * 2 - 1, -4.5, math.random() * 2 - 1),
			Transparency = 1,
		}):Play()
		Debris:AddItem(piece.part, 1)
	end
	entry.canopy = {}
	local puff =
		fxPart({ Size = Vector3.one * 0.2, Transparency = 1, Position = entry.ground + Vector3.new(0, 0.4, 0) })
	emitter(puff, {
		Color = ColorSequence.new(Color3.fromRGB(235, 225, 210)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(4, 7),
		SpreadAngle = Vector2.new(10, 180),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 4,
		Rate = 0,
	}):Emit(14)
	Debris:AddItem(puff, 1.2)
	if near(entry.ground, 40) then
		SoundController.Play("EventLand")
	end
end

local function updateShakes(now: number, serverNow: number)
	for _, entry in shakes do
		local left = entry.landsAt - serverNow
		local fall = Events.FreeShakes.FallTime
		local half = entry.part.Size.Y / 2
		if left > fall then
			-- Pas encore largué : seule la cible au sol est visible
			entry.cup.Transparency = 1
			for _, piece in entry.canopy do
				piece.part.Transparency = 1
			end
			entry.target.Transparency = 0.75
		elseif left > 0 then
			local height = Events.FreeShakes.FallHeight * (left / fall)
			local root = CFrame.new(entry.ground + Vector3.new(0, half + height, 0))
				* CFrame.Angles(
					math.sin(now * 1.7 + entry.spin) * 0.13,
					now * 0.6 + entry.spin,
					math.cos(now * 1.3) * 0.13
				)
			entry.cup.Transparency = 0
			entry.cup.CFrame = root
			local parts, cframes = {}, {}
			for _, piece in entry.canopy do
				piece.part.Transparency = 0
				table.insert(parts, piece.part)
				table.insert(cframes, root * piece.offset)
			end
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
			-- La cible pulse de plus en plus vite à l'approche
			entry.target.Transparency = 0.45 + math.sin(now * (6 + 10 * (1 - left / fall))) * 0.2
		else
			if not entry.landed then
				land(entry)
			end
			entry.cup.Transparency = 0
			entry.cup.CFrame = CFrame.new(
				entry.ground + Vector3.new(0, half + 0.4 + math.sin(now * 2.4 + entry.spin) * 0.25, 0)
			) * CFrame.Angles(0, now * 1.4 + entry.spin, 0)
		end
	end
end

-- ------------------------------------------------------------------ piano fugueur

local LEG = 1.9 -- longueur des jambes du piano (il est soulevé d'autant)

type Limb = { part: BasePart, offset: CFrame }
type Piano = {
	source: BasePart,
	body: BasePart,
	view: CFrame, -- position lissée (au sol)
	phase: number,
	speed: number,
	legs: { { thigh: BasePart, sock: BasePart, shoe: BasePart, sole: BasePart, x: number } },
	eyes: { { white: BasePart, pupil: BasePart, offset: Vector3 } },
	stars: { BasePart },
	hearts: { Frame },
	alarm: TextLabel,
	sweat: ParticleEmitter,
	dust: { ParticleEmitter },
	noteAt: number,
	mood: string,
	downAt: number,
	flashUntil: number,
	highlight: Highlight,
}
local pianos: { [BasePart]: Piano } = {}

local SKIN = Color3.fromRGB(232, 186, 146)

local function addPiano(source: Instance)
	if not source:IsA("BasePart") or pianos[source] then
		return
	end
	source.Transparency = 1 -- la copie animée la remplace (le bouton « Tackle! » reste sur le vrai piano)
	local body = visualCopy(source)
	local half = body.Size / 2

	-- Façade : on cherche la face avant du meuble à hauteur des yeux (le clavier dépasse en dessous)
	local eyeY = half.Y * 0.5
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { body }
	body.CanQuery = true
	body.CFrame = CFrame.new(0, 5000, 0)
	local hit = workspace:Raycast(
		body.CFrame:PointToWorldSpace(Vector3.new(0, eyeY, -half.Z - 2)),
		body.CFrame.LookVector * -(half.Z * 2 + 4),
		params
	)
	local frontZ = if hit then body.CFrame:PointToObjectSpace(hit.Position).Z else -half.Z
	body.CanQuery = false

	local legs = {}
	for _, x in { -half.X * 0.42, half.X * 0.42 } do
		table.insert(legs, {
			x = x,
			thigh = fxPart({ Color = SKIN, Size = Vector3.new(0.55, LEG - 0.45, 0.55) }),
			sock = fxPart({ Color = Color3.fromRGB(250, 250, 250), Size = Vector3.new(0.6, 0.5, 0.6) }),
			shoe = fxPart({ Color = Color3.fromRGB(230, 50, 50), Size = Vector3.new(0.85, 0.42, 1.3) }),
			sole = fxPart({ Color = Color3.fromRGB(250, 250, 250), Size = Vector3.new(0.9, 0.14, 1.36) }),
		})
	end
	local eyes = {}
	for _, x in { -half.X * 0.22, half.X * 0.22 } do
		table.insert(eyes, {
			offset = Vector3.new(x, eyeY, frontZ - 0.25),
			white = fxPart({ Shape = Enum.PartType.Ball, Color = Color3.new(1, 1, 1), Size = Vector3.one * 1.3 }),
			pupil = fxPart({ Shape = Enum.PartType.Ball, Color = Color3.fromRGB(20, 20, 24), Size = Vector3.one * 0.6 }),
		})
	end
	local stars = {}
	for _ = 1, 3 do
		table.insert(
			stars,
			fxPart({
				Shape = Enum.PartType.Ball,
				Material = Enum.Material.Neon,
				Color = GOLD,
				Size = Vector3.one * 0.55,
				Transparency = 1,
			})
		)
	end
	local dust = {}
	for _, leg in legs do
		table.insert(
			dust,
			emitter(leg.sole, {
				Color = ColorSequence.new(Color3.fromRGB(225, 215, 200)),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.8) }),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.5),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Lifetime = NumberRange.new(0.4, 0.7),
				Speed = NumberRange.new(1, 3),
				SpreadAngle = Vector2.new(40, 40),
				EmissionDirection = Enum.NormalId.Top,
				Rate = 0,
			})
		)
	end
	local sweat = emitter(body, {
		Color = ColorSequence.new(Color3.fromRGB(150, 210, 255)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.2) }),
		Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(4, 7),
		SpreadAngle = Vector2.new(50, 50),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -30, 0),
		Rate = 0,
	})

	-- Au-dessus : un cœur par plaquage restant et le « ! » de panique
	local hearts = {}
	local gui = Ui.create("BillboardGui", {
		Size = UDim2.fromOffset(150, 80),
		StudsOffsetWorldSpace = Vector3.new(0, half.Y + LEG + 2.6, 0),
		LightInfluence = 0,
		AlwaysOnTop = true,
		MaxDistance = 160,
		Adornee = body,
		Parent = fxFolder,
	})
	local row = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(150, 30),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
		}),
	})
	for _ = 1, Events.RunawayPiano.Tackles do
		table.insert(
			hearts,
			Ui.create("Frame", {
				Size = UDim2.fromOffset(24, 24),
				BackgroundColor3 = Color3.fromRGB(235, 60, 70),
				Parent = row,
			}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(1, 1, 1), 2) })
		)
	end
	local alarm = Ui.label({
		Size = UDim2.new(1, 0, 0, 46),
		Text = Texts.Get("Fx.Alarm"),
		TextColor3 = Color3.fromRGB(255, 70, 60),
		Visible = false,
		Parent = gui,
	})
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.Adornee = body
	highlight.Parent = body

	local entry: Piano = {
		source = source,
		body = body,
		view = source.CFrame * CFrame.new(0, -half.Y, 0),
		phase = 0,
		speed = 0,
		legs = legs,
		eyes = eyes,
		stars = stars,
		hearts = hearts,
		alarm = alarm,
		sweat = sweat,
		dust = dust,
		noteAt = 0,
		mood = "Trot",
		downAt = 0,
		flashUntil = 0,
		highlight = highlight,
	}
	pianos[source] = entry
	removers[source] = function()
		pianos[source] = nil
		burst(entry.view.Position + Vector3.new(0, 2, 0), GOLD, 0.8)
		for _, leg in legs do
			leg.thigh:Destroy()
			leg.sock:Destroy()
			leg.shoe:Destroy()
			leg.sole:Destroy()
		end
		for _, eye in eyes do
			eye.white:Destroy()
			eye.pupil:Destroy()
		end
		for _, star in stars do
			star:Destroy()
		end
		gui:Destroy()
		body:Destroy()
	end
end

local function nearestCharacter(position: Vector3): Vector3?
	local best, bestDistance = nil, 40
	for _, other in Players:GetPlayers() do
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - position).Magnitude < bestDistance then
			best, bestDistance = root.Position, (root.Position - position).Magnitude
		end
	end
	return best
end

local function updatePiano(entry: Piano, now: number, dt: number)
	local source = entry.source
	local half = entry.body.Size / 2
	local mood = source:GetAttribute("Mood") or "Trot"
	if mood ~= entry.mood then
		entry.mood = mood
		if mood == "Down" then
			entry.downAt = now
		elseif mood == "Tired" and near(source.Position, 70) then
			UIController.Toast(Texts.Get("Event.RunawayPiano.Tired"), 2)
		elseif mood == "Panic" and near(source.Position, 60) then
			SoundController.Play("EventWhoosh")
		end
	end
	local hits = source:GetAttribute("Hits") or 0
	for index, heart in entry.hearts do
		heart.BackgroundColor3 = if index <= hits then Color3.fromRGB(235, 60, 70) else Color3.fromRGB(60, 60, 70)
	end

	-- Position lissée (le serveur envoie ses positions par à-coups)
	local target = source.CFrame * CFrame.new(0, -half.Y, 0)
	local before = entry.view.Position
	entry.view = entry.view:Lerp(target, 1 - math.exp(-14 * dt))
	local speed = ((entry.view.Position - before) * Vector3.new(1, 0, 1)).Magnitude / math.max(dt, 1e-3)
	entry.speed += (speed - entry.speed) * math.min(1, dt * 8)
	local run = math.clamp(entry.speed / 19, 0, 1)
	entry.phase += dt * (4 + entry.speed * 0.75)

	-- Corps : soulevé par les jambes, rebond de course, penché en avant, roulis ; à la renverse s'il est arrêté
	local swing = math.sin(entry.phase) * (0.25 + 0.75 * run)
	local bodyCF: CFrame
	if mood == "Down" then
		local t = math.min((now - entry.downAt) / 0.5, 1)
		local fall = CFrame.new(0, half.Z * t + (half.Y + LEG) * (1 - t), 0) * CFrame.Angles(math.rad(82) * t, 0, 0)
		bodyCF = entry.view * fall
		swing = math.sin(now * 14) * 0.8 -- il pédale dans le vide
	else
		local bounce = math.abs(math.sin(entry.phase)) * 0.45 * run
		local lean = -0.14 * run
		local roll = math.sin(entry.phase) * 0.07 * run
		if mood == "Stunned" then
			lean, roll, bounce, swing = 0, math.sin(now * 9) * 0.12, 0, math.sin(now * 9) * 0.15
		elseif mood == "Tired" then
			lean, bounce = 0.1, math.abs(math.sin(now * 3)) * 0.1
		end
		bodyCF = entry.view * CFrame.new(0, LEG + half.Y + bounce, 0) * CFrame.Angles(lean, 0, roll)
	end
	if now < entry.flashUntil then
		bodyCF *= CFrame.new(math.sin(now * 60) * 0.25, 0, 0)
	end

	local parts, cframes = { entry.body }, { bodyCF }
	local function put(part: BasePart, cframe: CFrame)
		table.insert(parts, part)
		table.insert(cframes, cframe)
	end
	for index, leg in entry.legs do
		local angle = if index == 1 then swing else -swing
		local hip = bodyCF * CFrame.new(leg.x, -half.Y + 0.15, 0) * CFrame.Angles(angle, 0, 0)
		put(leg.thigh, hip * CFrame.new(0, -(LEG - 0.45) / 2, 0))
		put(leg.sock, hip * CFrame.new(0, -LEG + 0.55, 0))
		put(leg.shoe, hip * CFrame.new(0, -LEG + 0.2, -0.25))
		put(leg.sole, hip * CFrame.new(0, -LEG - 0.02, -0.25))
		entry.dust[index].Rate = if mood == "Down" or mood == "Stunned" then 0 else 18 * run
	end
	local look = nearestCharacter(bodyCF.Position)
	for _, eye in entry.eyes do
		local center = bodyCF * CFrame.new(eye.offset)
		put(eye.white, center)
		local dir = if look then center:VectorToObjectSpace(look - center.Position).Unit else Vector3.new(0, 0, -1)
		local pupil = Vector3.new(math.clamp(dir.X, -1, 1) * 0.3, math.clamp(dir.Y, -1, 1) * 0.3, -0.42)
		if mood == "Stunned" then
			pupil = Vector3.new(math.cos(now * 12) * 0.3, math.sin(now * 12) * 0.3, -0.42)
		end
		put(eye.pupil, center * CFrame.new(pupil))
	end
	for index, star in entry.stars do
		local a = now * 5 + index * math.pi * 2 / 3
		star.Transparency = if mood == "Stunned" then 0 else 1
		put(star, bodyCF * CFrame.new(math.cos(a) * 1.8, half.Y + 0.8, math.sin(a) * 1.8))
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)

	entry.alarm.Visible = mood == "Panic" and math.floor(now * 4) % 2 == 0
	entry.sweat.Rate = if mood == "Tired" or mood == "Panic" then 10 else 0
	entry.highlight.FillTransparency = if now < entry.flashUntil then 0.3 else 1

	-- Notes de musique qui s'échappent quand il court
	if mood ~= "Stunned" and mood ~= "Down" and now >= entry.noteAt and near(bodyCF.Position, 120) then
		entry.noteAt = now + 0.45 - 0.25 * run
		local hue = math.random()
		floatText(
			entry.body,
			Vector3.new(math.random() * 3 - 1.5, half.Y + 0.5, math.random() * 2 - 1),
			Texts.Get("Fx.Note"),
			Color3.fromHSV(hue, 0.55, 1),
			4,
			1.2
		)
	end
end

-- ------------------------------------------------------------------ messages du serveur

local function onEvent(message)
	if typeof(message) ~= "table" then
		return
	end
	local kind, state = message.kind, message.state
	local mine = message.userId == player.UserId
	if state == "Started" then
		SoundController.Play("EventStart")
	elseif kind == "GoldenDumbbells" and state == "Taken" and typeof(message.position) == "Vector3" then
		burst(message.position, if message.mega then MEGA_RED else GOLD, if message.mega then 1.6 else 1)
		if mine then
			SoundController.Play(if message.mega then "EventMega" else "EventPickup")
		end
		if message.mega and typeof(message.name) == "string" then
			UIController.Toast(Texts.Get("Event.GoldenDumbbells.MegaTaken", { name = message.name }))
		end
	elseif kind == "FreeShakes" and state == "Drank" and typeof(message.position) == "Vector3" then
		burst(message.position, SHAKE_PINK, 0.8)
		if mine then
			SoundController.Play("EventDrink")
		end
	elseif kind == "RunawayPiano" and (state == "Tackled" or state == "Stopped") then
		for _, entry in pianos do
			entry.flashUntil = os.clock() + 0.3
			local position = entry.body.Position
			burst(position, Color3.new(1, 1, 1), if state == "Stopped" then 1.6 else 0.7)
			for _ = 1, 5 do
				floatText(
					entry.body,
					Vector3.new(math.random() * 4 - 2, 1, math.random() * 2 - 1),
					Texts.Get("Fx.Note"),
					Color3.fromHSV(math.random(), 0.6, 1),
					6,
					1.4
				)
			end
			if near(position, 80) then
				SoundController.Play(if state == "Stopped" then "EventCheer" else "EventTackle")
			end
		end
		if state == "Tackled" and typeof(message.name) == "string" then
			UIController.Toast(Texts.Get("Event.RunawayPiano.Tackled", { name = message.name, count = message.left }))
		end
	end
end

function EventFxController.Init(controllers)
	SoundController = controllers.SoundController
	UIController = controllers.UIController
end

function EventFxController.Start()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "EventFx"
	fxFolder.Parent = workspace
	for tag, add in
		{ EventDumbbell = addDumbbell, EventShake = addShake, EventPiano = addPiano } :: { [string]: (Instance) -> () }
	do
		for _, object in CollectionService:GetTagged(tag) do
			add(object)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(add)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(object)
			local remove = removers[object]
			removers[object] = nil
			if remove then
				remove()
			end
		end)
	end
	Remotes.CityEvent.OnClientEvent:Connect(onEvent)
	-- Heartbeat (et non RenderStepped) : les animations continuent même quand l'image n'est pas redessinée
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		updateDumbbells(now)
		if next(shakes) then
			updateShakes(now, workspace:GetServerTimeNow())
		end
		for _, entry in pianos do
			updatePiano(entry, now, dt)
		end
	end)
end

return EventFxController
