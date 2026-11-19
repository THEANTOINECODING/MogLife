-- Mouvements et effets du personnage hors activité (D84), pour tous les personnages proches, calculés chez chaque joueur.
-- Réglages dans Config/Motion.luau. Le « gabarit » (0 au premier stade, 1 au dernier) vient de l'attribut StageIndex.
-- - Démarche : torse bombé, épaules qui roulent, bras écartés, bassin qui se dandine, menton relevé (s'ajoute à
--   l'animation de marche de Roblox, plus marqué avec le gabarit).
-- - Attente : respiration lente et profonde ; son propre personnage immobile prend de temps en temps une pose (émote).
-- - Poussière à chaque pas (couleur du sol), anneau de poussière à l'atterrissage (et petite secousse de sa propre
--   caméra pour les gros gabarits), traînée de vitesse en courant.
-- - Pareur : il applaudit en rythme pendant la série de celui qu'il pare (attribut SpottingFor).
-- - D134 : transitions lissées (plus d'à-coups entre attente, marche et saut), inertie (penché au démarrage, au
--   freinage et dans les virages), pas qui tombent lourdement, bras qui s'ouvrent en l'air, atterrissage encaissé
--   par le buste, regard vers le joueur le plus proche (ou là où regarde sa caméra).
-- Un personnage déjà animé ailleurs (activité, combat, duel, émote : ActivityController.IsBusy) n'est pas touché.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Motion = require(ReplicatedStorage.Shared.Config.Motion)
local StyleSets = require(ReplicatedStorage.Shared.Config.StyleSets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rig = require(script.Parent.Parent.Activities.Rig)

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local localPlayer = Players.LocalPlayer
local ActivityController
local SettingsController

type State = {
	character: Model,
	humanoid: Humanoid,
	rig: Rig.Rig?,
	measures: any,
	-- Couche ajoutée à l'animation de Roblox : dernière valeur écrite et valeur de Roblox sous-jacente
	written: { [string]: CFrame },
	under: { [string]: CFrame },
	phase: number, -- balancement de la marche
	stepDistance: number, -- distance parcourue depuis le dernier pas
	leftFoot: boolean,
	dust: ParticleEmitter,
	dustPoint: Attachment,
	trail: Trail?,
	spotting: boolean,
	connections: { RBXScriptConnection },
	-- D134 : facteurs lissés et inertie
	walk: number, -- 0 à l'arrêt, 1 en marche (lissé)
	air: number, -- 0 au sol, 1 en l'air (lissé)
	velocity: Vector3, -- vitesse horizontale lissée
	accelLean: number, -- degrés (lissés)
	bank: number, -- degrés (lissés)
	yaw: number?, -- orientation de la racine à l'image précédente
	recoilAt: number, -- début du dernier atterrissage encaissé
	recoil: number, -- force de cet atterrissage (0 à 1)
	lookYaw: number,
	lookPitch: number,
	lookTarget: BasePart?,
	nextPick: number,
}

local states: { [Player]: State } = {}
local idleSince = os.clock()
local nextFlexAt = 0

local MotionController = {}
MotionController.PuffCount = 0 -- bouffées de poussière émises (tests dans Studio)

local function bulk(who: Player): number
	local stage = tonumber(who:GetAttribute("StageIndex")) or 1
	return math.clamp((stage - 1) / (Motion.LastStage - 1), 0, 1)
end

local function dustColor(material: Enum.Material): Color3
	return Motion.Dust.Colors[material.Name] or Motion.Dust.Colors.Default
end

local function newDust(): (Attachment, ParticleEmitter)
	local point = Instance.new("Attachment")
	point.Name = "MotionDust"
	point.Parent = workspace.Terrain
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = SMOKE
	dust.Rate = 0
	dust.Lifetime = NumberRange.new(Motion.Dust.Lifetime * 0.7, Motion.Dust.Lifetime)
	dust.Speed = NumberRange.new(1.5, 3.5)
	dust.SpreadAngle = Vector2.new(70, 70)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Acceleration = Vector3.new(0, -2, 0)
	dust.Drag = 3
	dust.RotSpeed = NumberRange.new(-60, 60)
	dust.Rotation = NumberRange.new(0, 360)
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.LightInfluence = 1
	dust.Parent = point
	return point, dust
end

local function puff(state: State, position: Vector3, count: number, size: number, ring: boolean)
	state.dustPoint.WorldPosition = position
	state.dust.Color = ColorSequence.new(dustColor(state.humanoid.FloorMaterial))
	state.dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.6),
		NumberSequenceKeypoint.new(1, size * 1.4),
	})
	-- Anneau d'atterrissage : la poussière part à l'horizontale tout autour
	state.dust.SpreadAngle = if ring then Vector2.new(90, 90) else Vector2.new(70, 70)
	state.dust.Speed = if ring then NumberRange.new(6, 10) else NumberRange.new(1.5, 3.5)
	state.dust:Emit(count)
	MotionController.PuffCount += count
end

local function release(state: State)
	if state.rig then
		state.rig:Release()
	end
end

local function cleanup(who: Player)
	local state = states[who]
	if not state then
		return
	end
	states[who] = nil
	for _, connection in state.connections do
		connection:Disconnect()
	end
	state.dustPoint:Destroy()
	if state.trail then
		state.trail:Destroy()
	end
end

local function setup(who: Player, character: Model)
	cleanup(who)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid or not character:WaitForChild("UpperTorso", 10) then
		return
	end
	local point, dust = newDust()
	local state: State = {
		character = character,
		humanoid = humanoid,
		rig = nil,
		written = {},
		under = {},
		phase = math.random() * 6,
		stepDistance = 0,
		leftFoot = true,
		dust = dust,
		dustPoint = point,
		spotting = false,
		connections = {},
		walk = 0,
		air = 0,
		velocity = Vector3.zero,
		accelLean = 0,
		bank = 0,
		yaw = nil,
		recoilAt = -math.huge,
		recoil = 0,
		lookYaw = 0,
		lookPitch = 0,
		lookTarget = nil,
		nextPick = 0,
	}
	-- Traînée de vitesse en courant : un ruban pâle entre les deux épaules
	local torso = character:FindFirstChild("UpperTorso") :: BasePart?
	if torso then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(-torso.Size.X * 0.5, torso.Size.Y * 0.2, 0.2)
		a0.Parent = torso
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(torso.Size.X * 0.5, torso.Size.Y * 0.2, 0.2)
		a1.Parent = torso
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.22
		trail.Color = ColorSequence.new(Color3.new(1, 1, 1))
		trail.Transparency = NumberSequence.new(0.75, 1)
		trail.LightEmission = 0.3
		trail.FaceCamera = true
		trail.Enabled = false
		trail.Parent = torso
		state.trail = trail
	end
	-- Atterrissage : anneau de poussière selon la vitesse de chute
	local falling = 0
	table.insert(
		state.connections,
		humanoid.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Freefall then
				falling = 0
			elseif new == Enum.HumanoidStateType.Landed then
				local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not root then
					return
				end
				-- D134 : le buste encaisse (même un petit saut, plus fort avec la vitesse de chute)
				local strength = math.clamp(falling / Motion.Air.FallFull, 0, 1)
				if strength >= 0.1 then
					state.recoilAt = os.clock()
					state.recoil = math.max(strength, Motion.Recoil.Min)
				end
				if falling < Motion.Landing.MinFall then
					return
				end
				local b = bulk(who)
				local feet = root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
				puff(
					state,
					feet,
					math.floor(Motion.Landing.Puffs + Motion.Landing.PuffsPerStage * b * 5),
					1.2 + b,
					true
				)
				local stage = tonumber(who:GetAttribute("StageIndex")) or 1
				if
					who == localPlayer
					and stage >= Motion.Landing.ShakeFromStage
					and SettingsController.Get("ScreenFx")
				then
					task.spawn(function()
						local t0 = os.clock()
						while os.clock() - t0 < Motion.Landing.ShakeTime do
							local k = 1 - (os.clock() - t0) / Motion.Landing.ShakeTime
							humanoid.CameraOffset =
								Vector3.new(0, (math.random() - 0.5) * 2 * Motion.Landing.Shake * k, 0)
							task.wait()
						end
						humanoid.CameraOffset = Vector3.zero
					end)
				end
			end
		end)
	)
	table.insert(
		state.connections,
		RunService.Heartbeat:Connect(function()
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and humanoid:GetState() == Enum.HumanoidStateType.Freefall then
				falling = math.max(falling, -root.AssemblyLinearVelocity.Y)
			end
		end)
	)
	states[who] = state
end

-- Couche ajoutée à l'animation de Roblox. Si Roblox n'a pas réécrit l'articulation cette image (animation en pause),
-- on repart de sa dernière valeur : la couche ne s'accumule jamais.
local function layer(state: State, joint: string, extra: CFrame)
	local rig = state.rig
	local instance = rig and rig.joints[joint] and rig.joints[joint].instance
	if not instance then
		return
	end
	local current = instance.Transform
	local under = if state.written[joint] == current then state.under[joint] else current
	state.under[joint] = under
	local value = under * extra
	instance.Transform = value
	state.written[joint] = value
end

local function deg(x: number): number
	return math.rad(x)
end

-- Rapproche `current` de `target` (vitesse en 1/s, indépendant du nombre d'images par seconde)
local function approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

-- Encaissement d'un atterrissage : monte vite au plus bas puis se relâche en douceur (0 à 1)
local function recoilCurve(state: State, now: number): number
	local t = now - state.recoilAt
	local cfg = Motion.Recoil
	if t < 0 or t > cfg.Time then
		return 0
	end
	if t < cfg.Attack then
		return state.recoil * (t / cfg.Attack)
	end
	local k = 1 - (t - cfg.Attack) / (cfg.Time - cfg.Attack)
	return state.recoil * k * k
end

-- Cible du regard : la tête du joueur le plus proche devant soi (choisie quelques fois par seconde)
local function pickLookTarget(state: State, who: Player, root: BasePart, now: number)
	if now < state.nextPick then
		return
	end
	state.nextPick = now + Motion.Look.PickEvery * (0.8 + math.random() * 0.4)
	local best, bestDistance = nil, Motion.Look.Distance
	local cosCone = math.cos(math.rad(Motion.Look.Cone / 2))
	for other, otherState in states do
		if other ~= who then
			local head = otherState.character:FindFirstChild("Head") :: BasePart?
			if head then
				local offset = head.Position - root.Position
				local distance = offset.Magnitude
				if distance < bestDistance and distance > 0.5 then
					local flat = Vector3.new(offset.X, 0, offset.Z)
					if flat.Magnitude > 0.1 and root.CFrame.LookVector:Dot(flat.Unit) >= cosCone then
						best, bestDistance = head, distance
					end
				end
			end
		end
	end
	state.lookTarget = best
end

-- Angles (radians) pour regarder vers `point` depuis la tête, dans le repère de la racine
local function lookAngles(root: BasePart, head: BasePart, point: Vector3): (number, number)
	local dir = root.CFrame:VectorToObjectSpace(point - head.Position)
	local flat = math.sqrt(dir.X * dir.X + dir.Z * dir.Z)
	if flat < 0.05 then
		return 0, 0
	end
	return math.atan2(-dir.X, -dir.Z), math.atan2(dir.Y, flat)
end

-- Attitude au repos d'une tenue haut de gamme (D122) : angles en degrés, nil sans tenue
type Stance =
	{ waistP: number, waistY: number, neckP: number, neckY: number, arms: number, hip: number, breath: number }
local function stanceOf(who: Player, now: number): Stance?
	local premium = who:GetAttribute("PremiumSet")
	local signature = typeof(premium) == "string" and StyleSets.Signature[premium]
	local cfg = signature and Motion.Stances[signature.style]
	if not cfg then
		return nil
	end
	local neckY = cfg.neck[2]
	if cfg.sway and cfg.sway > 0 then
		neckY += cfg.sway * math.sin(2 * math.pi * cfg.swayRate * now)
	end
	if cfg.scan then
		-- Balayage par à-coups : gauche, centre, droite, centre ; 0,15 s pour passer d'une position à l'autre
		local positions = { -1, 0, 1, 0 }
		local slot = math.floor(now / cfg.scanEvery)
		local t = math.clamp((now - slot * cfg.scanEvery) / 0.15, 0, 1)
		local from = positions[(slot - 1) % 4 + 1]
		local to = positions[slot % 4 + 1]
		neckY += cfg.scan * (from + (to - from) * t)
	end
	return {
		waistP = cfg.waist[1],
		waistY = cfg.waist[2],
		neckP = cfg.neck[1],
		neckY = neckY,
		arms = cfg.arms,
		hip = cfg.hip,
		breath = cfg.breath,
	}
end

-- Pareur : il applaudit devant lui, mains à hauteur de poitrine (toute la pose, pas une couche)
local function spotterPose(state: State, now: number)
	local rig = state.rig :: Rig.Rig
	if not state.measures then
		state.measures = rig:Measure(state.humanoid)
	end
	local m = state.measures
	rig:Clear()
	local root = rig.root.CFrame
	local chest = (root * CFrame.new(0, m.shoulderHeight - m.hipHeight - 0.2, -m.armLength * 0.55)).Position
	local clap = math.abs(math.sin(math.pi * Motion.Spotter.ClapRate * now))
	local spread = 0.08 + clap * m.shoulderWidth * 0.45
	for _, sx in { -1, 1 } do
		rig:Reach(
			if sx < 0 then "LeftArm" else "RightArm",
			chest + root.RightVector * sx * spread,
			-root.UpVector + root.RightVector * sx * 0.6
		)
	end
	rig:Set("Neck", CFrame.Angles(deg(6), 0, 0))
	rig:Apply()
	state.spotting = true
end

local function step(dt: number)
	local now = os.clock()
	-- Distance mesurée depuis son propre personnage (la caméra peut être loin : cinématique, Studio réduit)
	local camera = workspace.CurrentCamera
	local myCharacter = localPlayer.Character
	local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
	local viewer = if myRoot then myRoot.Position elseif camera then camera.CFrame.Position else nil
	for who, state in states do
		local character = state.character
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not character.Parent or not root then
			cleanup(who)
			continue
		end
		if viewer and (root.Position - viewer).Magnitude > Motion.MaxDistance then
			continue
		end
		-- Déjà animé ailleurs (activité, combat, émote) : on ne touche à rien
		if ActivityController.IsBusy(who) or who:GetAttribute("InRun") then
			state.written = {}
			if state.spotting then
				state.spotting = false
			end
			continue
		end
		state.rig = state.rig or Rig.new(character)
		if not state.rig then
			continue
		end
		local humanoid = state.humanoid
		local b = bulk(who)
		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air

		-- Pareur
		if who:GetAttribute("SpottingFor") then
			spotterPose(state, now)
			continue
		elseif state.spotting then
			state.spotting = false
			release(state)
			state.written = {}
		end

		-- Démarche ou respiration, lissées (D134 : plus d'à-coups au démarrage ni à l'arrêt)
		local smooth = Motion.Smooth
		state.walk = approach(state.walk, math.clamp(speed / 8, 0, 1), smooth.Walk, dt)
		state.air = approach(state.air, if grounded then 0 else 1, smooth.Air, dt)
		local walk = state.walk * (1 - state.air)
		local air = state.air
		state.phase += dt * speed * Motion.Walk.StepRate * 2 * math.pi
		local swing = math.sin(state.phase)
		-- Un pas « tombe » deux fois par cycle : pointe nette au contact du pied
		local contact = 1 - math.abs(math.cos(state.phase))
		contact = contact * contact * contact
		local breath = math.sin(2 * math.pi * Motion.Idle.BreathRate * now)
		local idle = (1 - state.walk) * (1 - air)
		local sprintCfg = Motion.Sprint
		local sprint = math.clamp((speed - sprintCfg.LeanFrom) / (sprintCfg.MinSpeed - sprintCfg.LeanFrom), 0, 1)
			* (1 - air)

		-- Inertie : accélération dans le sens de la marche, rotation de la racine
		local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
		local previous = state.velocity
		state.velocity = flatVelocity
		local accel = if dt > 0 then (flatVelocity - previous) / dt else Vector3.zero
		local forward = root.CFrame.LookVector
		local forwardAccel = accel:Dot(Vector3.new(forward.X, 0, forward.Z))
		local yaw = math.atan2(-forward.X, -forward.Z)
		local yawRate = 0
		if state.yaw and dt > 0 then
			local delta = (yaw - state.yaw + math.pi) % (2 * math.pi) - math.pi
			yawRate = delta / dt
		end
		state.yaw = yaw
		local inertia = Motion.Inertia
		local targetLean = if grounded
			then math.clamp(forwardAccel * inertia.Accel, -inertia.MaxAccel, inertia.MaxAccel)
			else 0
		local targetBank = if grounded
			then math.clamp(yawRate * inertia.Bank * state.walk, -inertia.MaxBank, inertia.MaxBank)
			else 0
		state.accelLean = approach(state.accelLean, targetLean, smooth.Lean, dt)
		state.bank = approach(state.bank, targetBank, smooth.Lean, dt)

		-- Saut et chute : bras ouverts, buste qui suit la vitesse verticale ; atterrissage encaissé
		local vertical = math.clamp(velocity.Y / Motion.Air.FallFull, -1, 1)
		local falling = math.max(-vertical, 0)
		local recoil = recoilCurve(state, now)

		-- Regard : joueur le plus proche devant soi, sinon (son propre personnage) là où regarde la caméra
		local head = character:FindFirstChild("Head") :: BasePart?
		local wantYaw, wantPitch = 0, 0
		if head then
			pickLookTarget(state, who, root, now)
			local target = state.lookTarget
			if target and target.Parent then
				wantYaw, wantPitch = lookAngles(root, head, target.Position)
			elseif who == localPlayer and Motion.Look.Camera and camera then
				local point = head.Position + camera.CFrame.LookVector * 20
				wantYaw, wantPitch = lookAngles(root, head, point)
				wantYaw *= Motion.Look.CameraShare
				wantPitch *= Motion.Look.CameraShare
			end
			-- Derrière soi : on ne se tord pas le cou, on revient de face
			if math.abs(wantYaw) > math.rad(Motion.Look.Cone) then
				wantYaw, wantPitch = 0, 0
			end
		end
		local look = Motion.Look
		wantYaw = math.clamp(wantYaw, -math.rad(look.MaxYaw), math.rad(look.MaxYaw)) * (1 - air)
		wantPitch = math.clamp(wantPitch, -math.rad(look.MaxPitch), math.rad(look.MaxPitch)) * (1 - air)
		state.lookYaw = approach(state.lookYaw, wantYaw, smooth.Look, dt)
		state.lookPitch = approach(state.lookPitch, wantPitch, smooth.Look, dt)

		-- Tenue haut de gamme : son attitude au repos (D122), qui s'efface en marchant
		local stance = stanceOf(who, now)
		local st = idle * idle
		local breathAmp = Motion.Idle.Breath * (0.5 + b) * (if stance then 1 + (stance.breath - 1) * st else 1)
		local stomp = (Motion.Stomp.Chest + Motion.Stomp.ChestPerBulk * b) * contact * walk
		layer(
			state,
			"Waist",
			CFrame.Angles(
				deg(
					Motion.Walk.ChestOut * b * walk * (1 - sprint)
						- Motion.Sprint.Lean * sprint
						+ breathAmp * breath * idle * 0.5
						+ (if stance then stance.waistP * st else 0)
						+ state.accelLean
						- stomp
						+ Motion.Air.Chest * vertical * air
						- Motion.Recoil.Chest * recoil
				),
				deg(Motion.Walk.Twist * b * walk * swing + (if stance then stance.waistY * st else 0))
					+ state.lookYaw * look.WaistShare,
				deg(state.bank)
			)
		)
		layer(
			state,
			"Neck",
			CFrame.Angles(
				deg(
					Motion.Walk.ChinUp * b * walk
						- breathAmp * breath * idle * 0.3
						+ (if stance then stance.neckP * st else 0)
						+ Motion.Sprint.Lean * sprint * 0.6
						+ stomp * 0.5
						- Motion.Recoil.Neck * recoil
				) + state.lookPitch,
				deg(if stance then stance.neckY * st else 0) + state.lookYaw * (1 - look.WaistShare),
				0
			)
		)
		local armsOut = (Motion.Walk.ArmsOut * walk + Motion.Idle.ArmsOut * idle) * b
			+ (if stance then stance.arms * st else 0)
			+ (Motion.Air.Arms + Motion.Air.ArmsFall * falling) * air
			+ Motion.Recoil.Arms * recoil
			+ Motion.Stomp.Shoulders * b * contact * walk
		local lift = Motion.Idle.ShoulderLift * (0.5 + b) * breath * idle
		layer(state, "LeftShoulder", CFrame.Angles(0, 0, deg(-armsOut - lift)))
		layer(state, "RightShoulder", CFrame.Angles(0, 0, deg(armsOut + lift)))
		layer(
			state,
			"Root",
			CFrame.Angles(0, 0, deg(Motion.Walk.Sway * b * walk * swing + (if stance then stance.hip * st else 0)))
		)
		-- Genoux remontés en l'air (hanches pliées vers l'avant)
		local tuck = deg(Motion.Air.Legs * air * (0.4 + 0.6 * math.max(vertical, 0) + 0.3 * falling))
		layer(state, "LeftHip", CFrame.Angles(tuck, 0, 0))
		layer(state, "RightHip", CFrame.Angles(tuck * 0.7, 0, 0))

		-- Poussière des pas
		if grounded and speed >= Motion.Dust.MinSpeed then
			state.stepDistance += speed * dt
			if state.stepDistance >= Motion.Dust.StepDistance then
				state.stepDistance -= Motion.Dust.StepDistance
				state.leftFoot = not state.leftFoot
				local foot = character:FindFirstChild(if state.leftFoot then "LeftFoot" else "RightFoot") :: BasePart?
				if foot then
					local sprinting = speed >= Motion.Sprint.MinSpeed
					local count = Motion.Dust.Puffs
						+ math.floor(Motion.Dust.PuffsPerStage * b * 5 + 0.5)
						+ (if sprinting then Motion.Dust.SprintBonus else 0)
					local ground = foot.Position - Vector3.new(0, foot.Size.Y / 2, 0)
					puff(state, ground, count, Motion.Dust.Size + Motion.Dust.SizePerStage * b * 5, false)
				end
			end
		else
			state.stepDistance = 0
		end
		if state.trail then
			state.trail.Enabled = grounded and speed >= Motion.Sprint.MinSpeed
		end
	end
end

-- Son propre personnage immobile depuis un moment : il prend une pose (vue par tous, validée par le serveur)
local function idleFlex()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return
	end
	local now = os.clock()
	local moving = humanoid.MoveDirection.Magnitude > 0.05 or root.AssemblyLinearVelocity.Magnitude > 1
	local busy = localPlayer:GetAttribute("InRun")
		or localPlayer:GetAttribute("SpottingFor")
		or ActivityController.IsBusy(localPlayer)
		or humanoid.Sit
	if moving or busy then
		idleSince = now
		nextFlexAt = now + Motion.Idle.FlexAfter
		return
	end
	if now >= nextFlexAt and now - idleSince >= Motion.Idle.FlexAfter then
		nextFlexAt = now + Motion.Idle.FlexAgain
		Remotes.Emote:FireServer(math.random(1, Balance.Emotes.Count))
	end
end

function MotionController.Init(controllers)
	ActivityController = controllers.ActivityController
	SettingsController = controllers.SettingsController
end

function MotionController.Start()
	local function watch(who: Player)
		if who.Character then
			task.spawn(setup, who, who.Character)
		end
		who.CharacterAdded:Connect(function(character)
			task.spawn(setup, who, character)
		end)
	end
	for _, who in Players:GetPlayers() do
		watch(who)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(cleanup)
	-- Toute action du joueur (toucher, clic, touche) remet le compteur d'attente à zéro : pas de pose en plein menu
	UserInputService.InputBegan:Connect(function()
		idleSince = os.clock()
		nextFlexAt = idleSince + Motion.Idle.FlexAfter
	end)
	-- Avant la physique, après l'Animator de Roblox (comme ActivityController)
	RunService.PreSimulation:Connect(step)
	RunService.Heartbeat:Connect(idleFlex)
end

-- Une image (tests dans Studio réduit)
MotionController.Step = step

return MotionController
