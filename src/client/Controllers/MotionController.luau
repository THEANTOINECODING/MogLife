-- Mouvements et effets du personnage hors activité (D84), pour tous les personnages proches, calculés chez chaque joueur.
-- Réglages dans Config/Motion.luau. Le « gabarit » (0 au premier stade, 1 au dernier) vient de l'attribut StageIndex.
-- - Démarche : torse bombé, épaules qui roulent, bras écartés, bassin qui se dandine, menton relevé (s'ajoute à
--   l'animation de marche de Roblox, plus marqué avec le gabarit).
-- - Attente : respiration lente et profonde ; son propre personnage immobile prend de temps en temps une pose (émote).
-- - Poussière à chaque pas (couleur du sol), anneau de poussière à l'atterrissage (et petite secousse de sa propre
--   caméra pour les gros gabarits), traînée de vitesse en courant.
-- - Pareur : il applaudit en rythme pendant la série de celui qu'il pare (attribut SpottingFor).
-- Un personnage déjà animé ailleurs (activité, combat, duel, émote : ActivityController.IsBusy) n'est pas touché.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Motion = require(ReplicatedStorage.Shared.Config.Motion)
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
				if not root or falling < Motion.Landing.MinFall then
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

		-- Démarche ou respiration
		local walk = math.clamp(speed / 8, 0, 1)
		state.phase += dt * speed * Motion.Walk.StepRate * 2 * math.pi
		local swing = math.sin(state.phase)
		local breath = math.sin(2 * math.pi * Motion.Idle.BreathRate * now)
		local idle = 1 - walk
		local breathAmp = Motion.Idle.Breath * (0.5 + b)
		layer(
			state,
			"Waist",
			CFrame.Angles(
				deg(Motion.Walk.ChestOut * b * walk + breathAmp * breath * idle * 0.5),
				deg(Motion.Walk.Twist * b * walk * swing),
				0
			)
		)
		layer(state, "Neck", CFrame.Angles(deg(Motion.Walk.ChinUp * b * walk - breathAmp * breath * idle * 0.3), 0, 0))
		local armsOut = (Motion.Walk.ArmsOut * walk + Motion.Idle.ArmsOut * idle) * b
		local lift = Motion.Idle.ShoulderLift * (0.5 + b) * breath * idle
		layer(state, "LeftShoulder", CFrame.Angles(0, 0, deg(-armsOut - lift)))
		layer(state, "RightShoulder", CFrame.Angles(0, 0, deg(armsOut + lift)))
		layer(state, "Root", CFrame.Angles(0, 0, deg(Motion.Walk.Sway * b * walk * swing)))

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
