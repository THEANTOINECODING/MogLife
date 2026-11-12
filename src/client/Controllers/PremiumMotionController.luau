-- Derniers détails des tenues Robux (D126, design/REVIEW_2026-11-10.md), vus par tous les joueurs :
-- - pièces souples : la queue remue, les ailes battent et se replient, l'auréole et la couronne d'étoiles tournent
--   (pièces dont la teinte contient Tail, WingA/WingB ou Spin) ; chaque pièce suit le mouvement avec un ressort
--   (retard puis léger dépassement : « follow-through ») ;
-- - cape (D128) : elle est découpée en bandes horizontales (teinte Cape<n>, 1 = en haut). Chaque bande a une
--   direction simulée (pesanteur, vent de la course et de la chute, battement, retard sur la bande du dessus) et la
--   chaîne se plie : la cape se courbe, ondule de haut en bas et retombe, sans jamais traverser le dos ;
-- - traces de pas : une petite gerbe de particules sous chaque pas (StyleSets.Footsteps).
-- Réglages : Config/Feel.luau (Sway, Footsteps). Le réglage « effets de tenue » du joueur coupe tout.
-- Les soudures (Weld) appartiennent au serveur (BodyService) : on garde la valeur du serveur comme base et on n'y
-- ajoute qu'une rotation autour de l'attache de la pièce ; si le serveur la change (croissance, pump), la base suit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Feel = require(ReplicatedStorage.Shared.Config.Feel)
local StyleSets = require(ReplicatedStorage.Shared.Config.StyleSets)

local SWAY = Feel.Sway
local STEPS = Feel.Footsteps
local RESCAN = 1 -- secondes entre deux recherches des pièces souples d'un personnage

local PremiumMotionController = {}

local SettingsController

type Piece = {
	part: BasePart,
	weld: Weld,
	kind: string, -- "Cape", "Tail", "Wing", "Spin"
	index: number?, -- cape : numéro de la bande (1 = en haut)
	base: CFrame,
	written: CFrame?,
}

-- Une bande de cape : ses pièces (tissu, étoiles, liseré), sa charnière au repos (repère du torse), le vecteur
-- vers la charnière suivante, et sa direction simulée (repère du torse, repos = vers le bas)
type CapeSegment = {
	pieces: { Piece },
	hinge: Vector3,
	length: Vector3,
	dir: Vector3,
	vel: Vector3,
}

type Cape = {
	segments: { CapeSegment },
	back: number, -- signe de Z du côté du dos
	torso: BasePart,
}

type Spring = { x: number, v: number }

type State = {
	character: Model,
	pieces: { Piece },
	rescanAt: number,
	lastPos: Vector3?,
	lastLook: Vector3?,
	velocity: Vector3,
	turn: number,
	springs: { [string]: Spring },
	cape: Cape?,
	capeDirty: boolean,
	stepDistance: number,
	foot: number,
	steps: BasePart?,
	stepsSet: string?,
}

local states: { [Model]: State } = {}
local folder: Folder? = nil

local function kindOf(name: string): (string?, number?)
	-- Nom de la pièce : <Corps>__<Objet>__<Partie>_<Teinte>
	local key = string.match(name, "__[^_]+__(.+)$")
	local tint = key and string.match(key, "_(%w+)$")
	if not tint then
		return nil
	end
	if string.find(tint, "Cape", 1, true) then
		return "Cape", tonumber(string.match(tint, "Cape(%d+)")) or 1
	elseif string.find(tint, "Tail", 1, true) then
		return "Tail"
	elseif string.find(tint, "Wing", 1, true) then
		return "Wing"
	elseif string.find(tint, "Spin", 1, true) then
		return "Spin"
	end
	return nil
end

local function scan(state: State)
	local known: { [BasePart]: Piece } = {}
	for _, piece in state.pieces do
		known[piece.part] = piece
	end
	local list: { Piece } = {}
	for _, part in state.character:GetDescendants() do
		if part:IsA("BasePart") then
			local kind, index = kindOf(part.Name)
			local weld = kind and part:FindFirstChildOfClass("Weld")
			if kind and weld then
				table.insert(
					list,
					known[part] or { part = part, weld = weld, kind = kind, index = index, base = weld.C0 }
				)
			end
		end
	end
	state.pieces = list
	state.capeDirty = true
end

-- ------------------------------------------------------------------ cape en bandes (D128)

local DOWN = Vector3.new(0, -1, 0)

-- Rotation la plus courte qui amène `from` sur `to` (vecteurs unitaires)
local function arc(from: Vector3, to: Vector3): CFrame
	local axis = from:Cross(to)
	if axis.Magnitude < 1e-5 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(from:Dot(to), -1, 1)))
end

-- Range les pièces de cape par bande et mesure les charnières au repos ; garde le mouvement en cours
local function buildCape(state: State)
	state.capeDirty = false
	local groups: { [number]: { Piece } } = {}
	local indices: { number } = {}
	for _, piece in state.pieces do
		if piece.kind == "Cape" and piece.weld.Parent and piece.part.Parent then
			local index = piece.index or 1
			if not groups[index] then
				groups[index] = {}
				table.insert(indices, index)
			end
			table.insert(groups[index], piece)
		end
	end
	if #indices == 0 then
		state.cape = nil
		return
	end
	table.sort(indices)
	-- Pièce principale d'une bande : la plus grande (le tissu), les autres (étoiles, liseré) la suivent
	local centers: { Vector3 } = {}
	local sizes: { Vector3 } = {}
	local torso: BasePart? = nil
	for order, index in indices do
		local main = groups[index][1]
		for _, piece in groups[index] do
			if piece.part.Size.X * piece.part.Size.Y > main.part.Size.X * main.part.Size.Y then
				main = piece
			end
		end
		centers[order] = main.base.Position
		sizes[order] = main.part.Size
		torso = torso or main.weld.Part0
	end
	if not torso then
		state.cape = nil
		return
	end
	local old = state.cape
	local keep = old ~= nil and #old.segments == #indices
	local segments: { CapeSegment } = {}
	local count = #indices
	local hinges: { Vector3 } = {}
	for order = 1, count do
		local c = centers[order]
		if order == 1 then
			hinges[order] = Vector3.new(c.X, c.Y + sizes[order].Y / 2, c.Z)
		else
			local above = centers[order - 1]
			hinges[order] = Vector3.new(c.X, above.Y - sizes[order - 1].Y / 2, (above.Z + c.Z) / 2)
		end
	end
	local last = centers[count]
	hinges[count + 1] = Vector3.new(last.X, last.Y - sizes[count].Y / 2, last.Z)
	for order, index in indices do
		segments[order] = {
			pieces = groups[index],
			hinge = hinges[order],
			length = hinges[order + 1] - hinges[order],
			dir = if keep and old then old.segments[order].dir else DOWN,
			vel = if keep and old then old.segments[order].vel else Vector3.zero,
		}
	end
	state.cape = { segments = segments, back = if centers[1].Z < 0 then -1 else 1, torso = torso }
end

local function stepCape(state: State, cape: Cape, dt: number, now: number)
	local config = SWAY.Cape
	local torso = cape.torso
	if not torso.Parent then
		state.capeDirty = true
		return
	end
	local frame = torso.CFrame
	local down = frame:VectorToObjectSpace(DOWN)
	-- Vent relatif : l'air vient à la rencontre du personnage (course, chute)
	local air = frame:VectorToObjectSpace(-state.velocity) / SWAY.RunSpeed
	local speed = math.clamp(air.Magnitude, 0, 1.5)
	local worldUp = frame:VectorToObjectSpace(-DOWN)
	local lift = air:Dot(worldUp)
	if lift > config.MaxUp then
		air -= worldUp * (lift - config.MaxUp) -- en chute, la cape se soulève sans passer par-dessus la tête
	end
	local wind = air * config.Wind
	local back = cape.back
	local count = #cape.segments
	local damping = math.exp(-config.Damping * dt)
	local previous: CapeSegment? = nil
	for order, segment in cape.segments do
		local depth = order / count
		local weight = depth ^ config.WindCurve
		local phase = now * config.FlutterSpeed - order * config.FlutterPhase
		local flutter = speed * config.Flutter * weight
		local idle = config.Idle * weight
		local target = down
			+ wind * weight
			+ Vector3.new(
				math.sin(phase * 0.73 + 1.3) * flutter * 0.6
					+ math.sin(now * config.IdleSpeed + order * 0.5) * idle
					+ state.turn * config.Turn * weight,
				0,
				back * (math.sin(phase) * flutter + math.sin(now * config.IdleSpeed * 0.7 + order * 0.4) * idle)
			)
		target = if target.Magnitude > 1e-3 then target.Unit else down
		-- Les bandes du bas sont plus souples : elles suivent en retard (l'onde descend le long de la cape)
		local stiffness = config.Stiffness * (1 + (config.TipSoftness - 1) * (order - 1) / math.max(count - 1, 1))
		local accel = (target - segment.dir) * stiffness
		if previous then
			accel += (previous.dir - segment.dir) * config.Coupling
		end
		local velocity = (segment.vel + accel * dt) * damping
		local dir = segment.dir + velocity * dt
		-- Le dos arrête la cape
		if dir.Z * back < config.MinBack then
			dir = Vector3.new(dir.X, dir.Y, config.MinBack * back)
			if velocity.Z * back < 0 then
				velocity = Vector3.new(velocity.X, velocity.Y, 0)
			end
		end
		dir = dir.Unit
		-- Pli limité entre deux bandes (le tissu ne se casse pas, les bandes ne s'ouvrent pas)
		local parent = if previous then previous.dir else DOWN
		local limit = if previous then config.MaxBend else config.MaxRootBend
		if math.acos(math.clamp(dir:Dot(parent), -1, 1)) > limit then
			local axis = parent:Cross(dir)
			if axis.Magnitude > 1e-5 then
				dir = CFrame.fromAxisAngle(axis.Unit, limit) * parent
				velocity *= 0.5
			end
		end
		segment.vel = velocity - dir * velocity:Dot(dir)
		segment.dir = dir
		previous = segment
	end
	-- Pose : chaque bande tourne autour de sa charnière, portée par la bande du dessus
	local position = cape.segments[1].hinge
	for _, segment in cape.segments do
		local rotation = arc(DOWN, segment.dir)
		local transform = CFrame.new(position) * rotation * CFrame.new(-segment.hinge)
		for _, piece in segment.pieces do
			local weld = piece.weld
			if weld.Parent and piece.part.Parent then
				local c0 = transform * piece.base
				weld.C0 = c0
				piece.written = c0
			end
		end
		position += rotation * segment.length
	end
end

local function spring(state: State, name: string, target: number, dt: number): number
	local s = state.springs[name]
	if not s then
		s = { x = target, v = 0 }
		state.springs[name] = s
	end
	local accel = SWAY.Stiffness * (target - s.x) - SWAY.Damping * s.v
	s.v += accel * dt
	s.x += s.v * dt
	return s.x
end

local function sign(value: number): number
	return if value < 0 then -1 else 1
end

-- Rotation autour d'un point de la pièce (repère de la pièce)
local function around(base: CFrame, pivot: Vector3, rotation: CFrame): CFrame
	return base * CFrame.new(pivot) * rotation * CFrame.new(-pivot)
end

local function emitterFor(state: State, setId: string, config): BasePart
	if state.steps and state.stepsSet == setId and state.steps.Parent then
		return state.steps
	end
	if state.steps then
		state.steps:Destroy()
	end
	if not folder or not folder.Parent then
		local created = Instance.new("Folder")
		created.Name = "PremiumFootsteps"
		created.Parent = workspace
		folder = created
	end
	local holder = Instance.new("Part")
	holder.Name = "Steps"
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/" .. config.texture
	emitter.Color = ColorSequence.new(config.colors[1], config.colors[2])
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, config.size[1]),
		NumberSequenceKeypoint.new(0.5, config.size[2]),
		NumberSequenceKeypoint.new(1, config.size[3]),
	})
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Lifetime = NumberRange.new(config.life[1], config.life[2])
	emitter.Speed = NumberRange.new(config.speed[1], config.speed[2])
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.LightEmission = config.emission
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = 0
	emitter.Parent = holder
	holder.Parent = folder
	state.steps, state.stepsSet = holder, setId
	return holder
end

local function footsteps(state: State, owner: Player?, root: BasePart, humanoid: Humanoid, moved: number)
	local setId = owner and owner:GetAttribute("PremiumSet")
	local config = typeof(setId) == "string" and StyleSets.Footsteps[setId]
	if not config or humanoid.FloorMaterial == Enum.Material.Air then
		return
	end
	state.stepDistance += moved
	if state.stepDistance < STEPS.StepDistance then
		return
	end
	state.stepDistance = 0
	state.foot = -state.foot
	local holder = emitterFor(state, setId :: string, config)
	local ground = root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight + 0.1
	local side = root.CFrame.RightVector * STEPS.FootSpread * state.foot
	holder.Position = Vector3.new(root.Position.X, ground, root.Position.Z) + side
	local emitter = holder:FindFirstChildOfClass("ParticleEmitter")
	if emitter then
		emitter:Emit(config.count)
	end
end

local function step(state: State, dt: number, now: number, near: boolean)
	local character = state.character
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	-- Mouvement du personnage (déduit de sa position : marche aussi pour les autres joueurs)
	local position, look = root.Position, root.CFrame.LookVector
	local moved = 0
	if state.lastPos and dt > 0 then
		local delta = position - state.lastPos
		moved = Vector3.new(delta.X, 0, delta.Z).Magnitude
		local velocity = delta / dt
		if velocity.Magnitude > 200 then
			velocity = Vector3.zero -- téléportation : pas de cape qui s'envole
			moved = 0
		end
		state.velocity = state.velocity:Lerp(velocity, math.min(dt * 10, 1))
		local yaw = math.atan2(look.X * state.lastLook.Z - look.Z * state.lastLook.X, look:Dot(state.lastLook))
		state.turn += (yaw / dt - state.turn) * math.min(dt * 8, 1)
	end
	state.lastPos, state.lastLook = position, look
	footsteps(state, Players:GetPlayerFromCharacter(character), root, humanoid, moved)
	if not near then
		return
	end
	if now >= state.rescanAt then
		state.rescanAt = now + RESCAN
		scan(state)
	end
	if #state.pieces == 0 then
		return
	end
	local localVelocity = root.CFrame:VectorToObjectSpace(state.velocity)
	local run = math.clamp(Vector3.new(localVelocity.X, 0, localVelocity.Z).Magnitude / SWAY.RunSpeed, 0, 1)
	local tail, wing = SWAY.Tail, SWAY.Wing
	local wagSpeed = tail.WagSpeed * (1 + run)
	local tailWag = spring(
		state,
		"tailWag",
		math.clamp(
			(tail.Wag + tail.RunWag * run) * math.sin(now * wagSpeed) - state.turn * tail.Turn,
			-tail.Max,
			tail.Max
		),
		dt
	)
	local tailLift = spring(state, "tailLift", tail.Lift * run, dt)
	local flapSpeed = wing.FlapSpeed + (wing.RunFlapSpeed - wing.FlapSpeed) * run
	local flap = (wing.Flap + (wing.RunFlap - wing.Flap) * run) * math.sin(now * flapSpeed)
	local fold = spring(state, "wingFold", math.clamp(wing.Fold * run, -wing.Max, wing.Max), dt)
	for _, piece in state.pieces do
		local weld = piece.weld
		if not weld.Parent or not piece.part.Parent then
			continue
		end
		-- La soudure a changé ailleurs que chez nous (croissance, pump, nouvelle tenue) : nouvelle base
		if piece.written == nil or weld.C0 ~= piece.written then
			piece.base = weld.C0
			if piece.kind == "Cape" then
				state.capeDirty = true
			end
		end
		if piece.kind == "Cape" then
			continue -- posée par stepCape
		end
		local base, size = piece.base, piece.part.Size
		local offset = base.Position
		local c0
		if piece.kind == "Tail" then
			local pivot = Vector3.new(0, size.Y / 2, -sign(offset.Z) * size.Z / 2)
			c0 = around(base, pivot, CFrame.Angles(tailLift * sign(offset.Z), tailWag, 0))
		elseif piece.kind == "Wing" then
			local side = sign(offset.X)
			local pivot = Vector3.new(-side * size.X / 2, wing.PivotY * size.Y, -sign(offset.Z) * size.Z / 2)
			c0 = around(base, pivot, CFrame.Angles(0, -side * fold, side * flap))
		else
			-- Spin : autour de l'axe le plus fin de la pièce (auréole debout, couronne à plat)
			local axis = if size.X <= size.Y and size.X <= size.Z
				then Vector3.xAxis
				elseif size.Y <= size.Z then Vector3.yAxis
				else Vector3.zAxis
			c0 = base * CFrame.fromAxisAngle(axis, (now * SWAY.SpinSpeed) % (2 * math.pi))
		end
		weld.C0 = c0
		piece.written = c0
	end
	if state.capeDirty then
		buildCape(state)
	end
	if state.cape then
		stepCape(state, state.cape, dt, now)
	end
end

-- Effets coupés : les pièces reprennent la position donnée par le serveur
local function restore(state: State)
	for _, piece in state.pieces do
		if piece.weld.Parent and piece.written and piece.weld.C0 == piece.written then
			piece.weld.C0 = piece.base
		end
		piece.written = nil
	end
	state.cape = nil
	state.capeDirty = true
end

local function drop(character: Model)
	local state = states[character]
	if state then
		restore(state)
		if state.steps then
			state.steps:Destroy()
		end
		states[character] = nil
	end
end

function PremiumMotionController.Init(controllers)
	SettingsController = controllers.SettingsController
end

function PremiumMotionController.Start()
	local enabled = true
	RunService.RenderStepped:Connect(function(dt)
		local on = SettingsController == nil or SettingsController.Get("OutfitFx")
		if not on then
			if enabled then
				enabled = false
				for character in states do
					drop(character)
				end
			end
			return
		end
		enabled = true
		local camera = workspace.CurrentCamera
		local eye = camera and camera.CFrame.Position or Vector3.zero
		local now = os.clock()
		local alive: { [Model]: boolean } = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if character and root then
				alive[character] = true
				local state = states[character]
				if not state then
					state = {
						character = character,
						pieces = {},
						rescanAt = 0,
						velocity = Vector3.zero,
						turn = 0,
						springs = {},
						capeDirty = true,
						stepDistance = 0,
						foot = 1,
					}
					states[character] = state
				end
				local near = (root.Position - eye).Magnitude <= SWAY.MaxDistance
				step(state :: State, math.min(dt, 0.1), now, near)
			end
		end
		for character in states do
			if not alive[character] then
				drop(character)
			end
		end
	end)
end

return PremiumMotionController
