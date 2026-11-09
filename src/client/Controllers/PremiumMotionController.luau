-- Derniers détails des tenues Robux (D126, design/REVIEW_2026-11-10.md), vus par tous les joueurs :
-- - pièces souples : la cape ondule et s'envole en courant, la queue remue, les ailes battent et se replient,
--   l'auréole et la couronne d'étoiles tournent (pièces dont la teinte contient Cape, Tail, WingA/WingB ou Spin) ;
--   chaque pièce suit le mouvement avec un ressort (retard puis léger dépassement : « follow-through ») ;
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
	base: CFrame,
	written: CFrame?,
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
	stepDistance: number,
	foot: number,
	steps: BasePart?,
	stepsSet: string?,
}

local states: { [Model]: State } = {}
local folder: Folder? = nil

local function kindOf(name: string): string?
	-- Nom de la pièce : <Corps>__<Objet>__<Partie>_<Teinte>
	local key = string.match(name, "__[^_]+__(.+)$")
	local tint = key and string.match(key, "_(%w+)$")
	if not tint then
		return nil
	end
	if string.find(tint, "Cape", 1, true) then
		return "Cape"
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
			local kind = kindOf(part.Name)
			local weld = kind and part:FindFirstChildOfClass("Weld")
			if kind and weld then
				table.insert(list, known[part] or { part = part, weld = weld, kind = kind, base = weld.C0 })
			end
		end
	end
	state.pieces = list
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
	local fall = math.clamp(-localVelocity.Y / 10, 0, 1.5)
	local cape, tail, wing = SWAY.Cape, SWAY.Tail, SWAY.Wing
	local capeLift = spring(
		state,
		"capeLift",
		math.clamp(
			cape.Lift * (run + fall * cape.Fall)
				- cape.Idle * math.sin(now * cape.IdleSpeed)
				- run * cape.Flutter * math.sin(now * cape.FlutterSpeed),
			-cape.Max,
			cape.Max
		),
		dt
	)
	local capeSide = spring(state, "capeSide", math.clamp(-state.turn * cape.Turn, -cape.Max, cape.Max), dt)
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
		end
		local base, size = piece.base, piece.part.Size
		local offset = base.Position
		local c0
		if piece.kind == "Cape" then
			local pivot = Vector3.new(0, size.Y / 2, -sign(offset.Z) * size.Z / 2)
			c0 = around(base, pivot, CFrame.Angles(capeLift * sign(offset.Z), 0, capeSide))
		elseif piece.kind == "Tail" then
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
end

-- Effets coupés : les pièces reprennent la position donnée par le serveur
local function restore(state: State)
	for _, piece in state.pieces do
		if piece.weld.Parent and piece.written and piece.weld.C0 == piece.written then
			piece.weld.C0 = piece.base
		end
		piece.written = nil
	end
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
