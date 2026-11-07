-- Secrets de la ville (D121, Config/Secrets.luau) : le serveur valide chaque découverte (distance, moment, ordre),
-- enregistre le secret (sauvegarde Secrets), débloque son titre secret et l'annonce au joueur (Remotes.SecretFound).
-- Les scènes (fantôme qui s'évapore, statue qui cligne, rat coach, reflet du Normie) sont jouées par tous les
-- clients proches (Remotes.SecretFx, SecretController). Aucun Mog, aucun avantage.
-- - GhostLifter : la nuit, un haltère fantôme flotte à l'un des emplacements GhostSpot ; appui long pour le soulever.
-- - StatueBeliever : taper vite sur le socle de la plus haute statue de la place (tag MogStatue, Rank 1).
-- - SewerGains : frapper sur la plaque d'égout de la ruelle (tag RatManhole).
-- - NeverForget : au dernier stade, une pose immobile devant un miroir du coiffeur (appelé par SocialService).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Look = require(ReplicatedStorage.Shared.Look)
local Secrets = require(ReplicatedStorage.Shared.Config.Secrets)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local GHOST_TAG = "GhostSpot"
local STATUE_TAG = "MogStatue"
local MANHOLE_TAG = "RatManhole"
local MIRROR_TAG = "Mirror"
local FOLDER_NAME = "Secrets"

local DataService
local PropService

local SecretService = {}

local function folder(): Folder
	local existing = workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		return existing :: Folder
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = workspace
	return created
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Débloque un secret ; renvoie true la première fois
function SecretService.Award(player: Player, secretId: string): boolean
	local data = DataService.Get(player)
	if not data or not Secrets[secretId] then
		return false
	end
	if typeof(data.Secrets) ~= "table" then
		data.Secrets = {}
	end
	if data.Secrets[secretId] then
		return false
	end
	data.Secrets[secretId] = true
	-- Le titre est annoncé par SECRET FOUND (pas une seconde fois par LookService.CheckTitles)
	data.Tips[`Title.{secretId}`] = true
	local found, total = 0, 0
	for id in Secrets do
		total += 1
		if data.Secrets[id] then
			found += 1
		end
	end
	Remotes.SecretFound:FireClient(player, secretId, found, total)
	return true
end

-- Modèle 3D importé (Blender, D121) ou nil ; la copie est ancrée, sans collision
local function propCopy(name: string): BasePart?
	local template = PropService.GetTemplate(name)
	if not template then
		return nil
	end
	local copy = template:Clone()
	for _, child in copy:GetChildren() do
		child:Destroy()
	end
	copy.Anchored = true
	copy.CanCollide = false
	copy.CanTouch = false
	copy.CanQuery = false
	return copy
end

local function simplePart(size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Size = size
	part.Color = color
	part.Shape = shape or Enum.PartType.Block
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- ------------------------------------------------------------------ haltère fantôme

local ghost: BasePart? = nil
local ghostSpot: BasePart? = nil
local nextGhostAt = 0

local function isNight(): boolean
	local cfg = Secrets.GhostLifter
	local clock = Lighting.ClockTime
	return clock >= cfg.NightStart or clock < cfg.NightEnd
end

local function removeGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
end

local function onGhostLifted(player: Player)
	local current, spot = ghost, ghostSpot
	local root = rootOf(player)
	if not current or not spot or not root then
		return
	end
	if (root.Position - current.Position).Magnitude > Secrets.GhostLifter.PromptDistance + 4 then
		return
	end
	-- D122 : l'haltère reste le temps de la scène (le fantôme le soulève), puis disparaît
	local prompt = current:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end
	ghost = nil
	Remotes.SecretFx:FireAllClients("GhostLifter", { position = current.Position, player = player, dumbbell = current })
	task.delay(Secrets.GhostLifter.Scene + 0.3, function()
		current:Destroy()
	end)
	nextGhostAt = os.clock() + Secrets.GhostLifter.Respawn
	SecretService.Award(player, "GhostLifter")
end

local function spawnGhost()
	local spots = {}
	for _, spot in CollectionService:GetTagged(GHOST_TAG) do
		if spot:IsA("BasePart") and spot ~= ghostSpot then
			table.insert(spots, spot)
		end
	end
	if #spots == 0 then
		return
	end
	local spot = spots[math.random(1, #spots)]
	local part = propCopy("Secret_GhostDumbbell")
	if not part then
		part = simplePart(Vector3.new(3, 0.4, 0.4), Color3.new(1, 1, 1), Enum.PartType.Cylinder)
	end
	local cfg = Secrets.GhostLifter
	part.Name = "GhostDumbbell"
	part.Transparency = 0.45
	part.CFrame = CFrame.new(spot.Position + Vector3.new(0, cfg.FloatHeight, 0))
	CollectionService:AddTag(part, "GhostDumbbell") -- le client le fait flotter et luire
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Texts.Get("Secret.GhostLifter.Action")
	prompt.ObjectText = Texts.Get("Secret.Unknown")
	prompt.HoldDuration = cfg.HoldDuration
	prompt.MaxActivationDistance = cfg.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(onGhostLifted)
	part.Parent = folder()
	ghost, ghostSpot = part, spot
end

local function ghostLoop()
	while true do
		task.wait(2)
		if isNight() then
			if not ghost and os.clock() >= nextGhostAt then
				spawnGhost()
			end
		elseif ghost then
			removeGhost()
		end
	end
end

-- ------------------------------------------------------------------ statue qui cligne

local taps: { [Player]: { number } } = {}
local lastStatueFx = -math.huge
local statueBusy: { [Model]: boolean } = {}

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- La statue est un avatar Roblox (articulations AnimationConstraint, pièces simulées par le serveur) : seul le
-- serveur peut l'animer, et tout le monde voit le même mouvement.
local function statueJoints(statue: Model): { [string]: AnimationConstraint }
	local found = {}
	for _, item in statue:GetDescendants() do
		if item:IsA("AnimationConstraint") then
			found[item.Name] = item
		end
	end
	return found
end

-- Une tape sur le socle : la statue tremble à peine (plus fort à chaque tape) ; rien d'autre ne trahit le secret
local function shakeStatue(statue: Model, strength: number)
	local root = statue:FindFirstChild("HumanoidRootPart")
	if statueBusy[statue] or not root or not root:IsA("BasePart") then
		return
	end
	statueBusy[statue] = true
	local base = root.CFrame
	task.spawn(function()
		for k = 1, 4 do
			if not root.Parent then
				break
			end
			root.CFrame = base * CFrame.new((if k % 2 == 0 then -1 else 1) * strength, 0, 0)
			task.wait(0.04)
		end
		if root.Parent then
			root.CFrame = base
		end
		statueBusy[statue] = nil
	end)
end

-- Elle se tourne vers le joueur, cligne de l'œil (côté client), fait un double biceps qui pompe, puis revient
local function performStatue(statue: Model, toward: Vector3, duration: number): CFrame?
	local root = statue:FindFirstChild("HumanoidRootPart")
	if statueBusy[statue] or not root or not root:IsA("BasePart") then
		return nil
	end
	statueBusy[statue] = true
	local base = root.CFrame
	local flat = Vector3.new(toward.X - base.X, 0, toward.Z - base.Z)
	local turned = if flat.Magnitude > 0.1 then CFrame.lookAt(base.Position, base.Position + flat.Unit) else base
	local rig = statueJoints(statue)
	local pose = Secrets.StatueBeliever.Pose
	local function set(name: string, angles: CFrame)
		local joint = rig[name]
		if joint and joint.Parent then
			joint.Transform = angles
		end
	end
	local start = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - start
		if not root.Parent or t >= duration then
			connection:Disconnect()
			for _, joint in rig do
				if joint.Parent then
					joint.Transform = CFrame.new()
				end
			end
			if root.Parent then
				root.CFrame = base
			end
			statueBusy[statue] = nil
			return
		end
		local turn = smooth(t / 0.6) * (1 - smooth((t - (duration - 0.6)) / 0.6))
		root.CFrame = base:Lerp(turned, turn)
		local flex = smooth((t - 1.3) / 0.35) * (1 - smooth((t - (duration - 0.7)) / 0.5))
		local pump = math.abs(math.sin((t - 1.3) * 6)) * math.rad(pose.Pump) * flex
		local shoulder = math.rad(pose.Shoulder) * flex
		local elbow = math.rad(pose.Elbow) * flex + pump
		set("RightShoulder", CFrame.Angles(0, 0, shoulder))
		set("LeftShoulder", CFrame.Angles(0, 0, -shoulder))
		set("RightElbow", CFrame.Angles(elbow, 0, 0))
		set("LeftElbow", CFrame.Angles(elbow, 0, 0))
		set("Neck", CFrame.Angles(math.rad(-8) * flex, 0, math.rad(6) * flex))
	end)
	return turned
end

local function onStatueClicked(player: Player, pedestal: BasePart)
	local cfg = Secrets.StatueBeliever
	local root = rootOf(player)
	if not root or (root.Position - pedestal.Position).Magnitude > cfg.ClickDistance then
		return
	end
	local now = os.clock()
	local list = taps[player] or {}
	taps[player] = list
	table.insert(list, now)
	while #list > 0 and now - list[1] > cfg.Window do
		table.remove(list, 1)
	end
	local statue = pedestal:FindFirstChild("Statue")
	if #list < cfg.Taps then
		if statue and statue:IsA("Model") then
			shakeStatue(statue, cfg.ShakePerTap * #list)
		end
		return
	end
	table.clear(list)
	if now - lastStatueFx >= cfg.Cooldown then
		lastStatueFx = now
		local turned = if statue and statue:IsA("Model") then performStatue(statue, root.Position, cfg.Scene) else nil
		Remotes.SecretFx:FireAllClients("StatueBeliever", {
			pedestal = pedestal,
			player = player,
			facing = if turned then turned.LookVector else nil,
		})
	end
	SecretService.Award(player, "StatueBeliever")
end

local function setupPedestal(pedestal: Instance)
	if not pedestal:IsA("BasePart") or pedestal:GetAttribute("Rank") ~= 1 or pedestal:FindFirstChild("SecretTap") then
		return
	end
	local detector = Instance.new("ClickDetector")
	detector.Name = "SecretTap"
	detector.MaxActivationDistance = Secrets.StatueBeliever.ClickDistance
	detector.CursorIcon = "" -- curseur normal : rien ne trahit le secret
	detector.Parent = pedestal
	detector.MouseClick:Connect(function(player)
		onStatueClicked(player, pedestal)
	end)
end

-- ------------------------------------------------------------------ rat coach

local ratBusy = false
local lastRat = -math.huge

local function lidOf(marker: BasePart): BasePart
	local existing = marker:FindFirstChild("Lid")
	if existing and existing:IsA("BasePart") then
		return existing
	end
	local lid = propCopy("Secret_ManholeLid")
	if not lid then
		lid = simplePart(Vector3.new(0.2, 3, 3), Color3.fromRGB(70, 70, 76), Enum.PartType.Cylinder)
		lid.CFrame = CFrame.Angles(0, 0, math.rad(90))
	end
	lid.Name = "Lid"
	-- Le couvercle de secours est un cylindre couché (son épaisseur est sur X)
	local mesh = lid:IsA("MeshPart")
	local lying = if mesh then CFrame.new() else CFrame.Angles(0, 0, math.rad(90))
	local half = (if mesh then lid.Size.Y else lid.Size.X) / 2
	lid.CFrame = marker.CFrame * CFrame.new(0, -marker.Size.Y / 2 + half + 0.02, 0) * lying
	lid.CanCollide = false
	lid.Parent = marker
	return lid
end

local function onKnock(player: Player, marker: BasePart)
	local cfg = Secrets.SewerGains
	local root = rootOf(player)
	if not root or (root.Position - marker.Position).Magnitude > cfg.PromptDistance + 4 then
		return
	end
	if ratBusy or os.clock() - lastRat < cfg.Cooldown then
		SecretService.Award(player, "SewerGains")
		return
	end
	ratBusy = true
	local lid = lidOf(marker)
	local closed = lid.CFrame
	local floor = marker.Position.Y - marker.Size.Y / 2
	local rat = propCopy("Secret_RatCoach") or simplePart(Vector3.new(1.2, 1, 2), Color3.fromRGB(150, 150, 150))
	rat.Name = "RatCoach"
	-- Le rat regarde le joueur qui a frappé
	local toward = Vector3.new(root.Position.X - marker.Position.X, 0, root.Position.Z - marker.Position.Z)
	local turn = if toward.Magnitude > 0.1 then CFrame.lookAt(Vector3.zero, toward).Rotation else marker.CFrame.Rotation
	local face = CFrame.new(marker.Position.X, 0, marker.Position.Z) * turn
	local up = face + Vector3.new(0, floor + rat.Size.Y / 2 + 0.25, 0)
	local down = up - Vector3.new(0, rat.Size.Y + 0.6, 0)
	rat.CFrame = down
	rat.Parent = folder()
	local info = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(lid, info, {
		CFrame = closed * CFrame.new(1.2, cfg.LidLift, 0) * CFrame.Angles(0, 0, math.rad(-35)),
	}):Play()
	task.wait(0.3)
	TweenService:Create(rat, info, { CFrame = up }):Play()
	task.wait(0.5)
	Remotes.SecretFx:FireAllClients("SewerGains", { rat = rat, player = player, duration = cfg.Show })
	SecretService.Award(player, "SewerGains")
	task.wait(cfg.Show)
	TweenService:Create(rat, TweenInfo.new(0.4), { CFrame = down }):Play()
	task.wait(0.4)
	rat:Destroy()
	TweenService:Create(lid, TweenInfo.new(0.35, Enum.EasingStyle.Bounce), { CFrame = closed }):Play()
	lastRat = os.clock()
	ratBusy = false
end

local function setupManhole(marker: Instance)
	if not marker:IsA("BasePart") or marker:FindFirstChildOfClass("ProximityPrompt") then
		return
	end
	lidOf(marker)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Texts.Get("Secret.SewerGains.Action")
	prompt.ObjectText = Texts.Get("Secret.Unknown")
	prompt.MaxActivationDistance = Secrets.SewerGains.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = marker
	prompt.Triggered:Connect(function(player)
		task.spawn(onKnock, player, marker)
	end)
end

-- ------------------------------------------------------------------ miroir du passé

local posing: { [Player]: boolean } = {}

local function barberMirrorNear(position: Vector3): BasePart?
	local cfg = Secrets.NeverForget
	local npcs = workspace:FindFirstChild("Npcs")
	local best, bestDistance = nil, cfg.MirrorDistance
	for _, mirror in CollectionService:GetTagged(MIRROR_TAG) do
		if
			mirror:IsA("BasePart")
			and mirror:GetAttribute("Store") == cfg.Store
			and not (npcs and mirror:IsDescendantOf(npcs))
		then
			local distance = (mirror.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = mirror, distance
			end
		end
	end
	return best
end

-- Appelé par SocialService quand un joueur fait une pose (émote validée)
function SecretService.OnEmote(player: Player)
	local data = DataService.Get(player)
	local root = rootOf(player)
	if not data or not root or posing[player] or data.Stage < #Stages.List then
		return
	end
	local mirror = barberMirrorNear(root.Position)
	if not mirror then
		return
	end
	local cfg = Secrets.NeverForget
	posing[player] = true
	local start = root.Position
	local elapsed = 0
	while elapsed < cfg.Hold do
		task.wait(0.25)
		elapsed += 0.25
		local now = rootOf(player)
		if not now or not player.Parent or (now.Position - start).Magnitude > cfg.StillDistance then
			posing[player] = nil
			return
		end
	end
	posing[player] = nil
	local fresh = DataService.Get(player)
	if not fresh then
		return
	end
	Remotes.SecretFx:FireAllClients("NeverForget", {
		mirror = mirror,
		player = player,
		look = Look.Sanitize(fresh.Look, nil),
		stage = Stages.List[1].id,
		duration = cfg.Show,
	})
	SecretService.Award(player, "NeverForget")
end

-- ------------------------------------------------------------------ démarrage

function SecretService.Init(services)
	DataService = services.DataService
	PropService = services.PropService
end

function SecretService.Start()
	for _, pedestal in CollectionService:GetTagged(STATUE_TAG) do
		setupPedestal(pedestal)
	end
	CollectionService:GetInstanceAddedSignal(STATUE_TAG):Connect(setupPedestal)
	for _, marker in CollectionService:GetTagged(MANHOLE_TAG) do
		setupManhole(marker)
	end
	CollectionService:GetInstanceAddedSignal(MANHOLE_TAG):Connect(setupManhole)
	Players.PlayerRemoving:Connect(function(player)
		taps[player] = nil
		posing[player] = nil
	end)
	task.spawn(ghostLoop)
end

-- Pour les tests dans Studio
SecretService.SpawnGhost = spawnGhost
SecretService.Ghost = function(): BasePart?
	return ghost
end

return SecretService
