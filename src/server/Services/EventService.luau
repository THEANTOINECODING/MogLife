-- Événements de ville (Config/Events.luau) : toutes les 9 à 12 minutes, un événement pour tout le serveur.
-- Le serveur place les objets, décide qui gagne quoi et annonce le début et la fin à tous (Remotes.CityEvent).
-- - GoldenDumbbells : haltères dorés posés au sol en plein air, le premier joueur qui en touche un le ramasse.
-- - FreeShakes : distributeur sur la place, un shake gratuit (boost) par joueur.
-- - RunawayPiano : un piano dévale la place en suivant le sol ; le premier qui l'arrête (prompt) est récompensé.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Events = require(ReplicatedStorage.Shared.Config.Events)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local EVENT_TAG = "CityEventObject"
local KINDS = { "GoldenDumbbells", "FreeShakes", "RunawayPiano" }

local DataService
local StatsService
local BoostService

local folder: Folder
local active: { kind: string, endsAt: number, cleanup: { () -> () } }? = nil
local rng = Random.new()

local EventService = {}

local function cashFor(player: Player, list: { number }): number
	local data = DataService.Get(player)
	local stage = if data then data.Stage else 1
	return list[math.clamp(stage, 1, #list)]
end

local function groundAt(position: Vector3): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	return workspace:Raycast(Vector3.new(position.X, 150, position.Z), Vector3.new(0, -300, 0), params)
end

-- Copie d'un décor (ServerStorage.Props), posée au sol, ancrée, sans collision
local function spawnProp(name: string, cframe: CFrame): BasePart?
	local props = ServerStorage:FindFirstChild("Props")
	local template = props and props:FindFirstChild(name)
	if not template or not template:IsA("BasePart") then
		warn(`[EventService] Missing prop {name}`)
		return nil
	end
	local part = template:Clone()
	part.Anchored = true
	part.CanCollide = false
	part.CFrame = cframe * CFrame.new(0, part.Size.Y / 2, 0)
	CollectionService:AddTag(part, EVENT_TAG)
	part.Parent = folder
	return part
end

local function announce(kind: string, state: string, extra: { [string]: any }?)
	local message = { kind = kind, state = state }
	for key, value in extra or {} do
		message[key] = value
	end
	Remotes.CityEvent:FireAllClients(message)
end

-- ------------------------------------------------------------------ haltères dorés

local function goldenDumbbells(cleanup: { () -> () })
	local cfg = Events.GoldenDumbbells
	local placed = 0
	local tries = 0
	while placed < cfg.Count and tries < cfg.Count * 30 do
		tries += 1
		local angle = rng:NextNumber() * math.pi * 2
		local distance = 20 + rng:NextNumber() * (cfg.Radius - 20)
		local guess = Events.Center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local hit = groundAt(guess)
		-- Au sol et en plein air : pas sur un toit, pas dans l'eau de la fontaine
		if hit and hit.Normal.Y > 0.9 and hit.Position.Y < 4 and hit.Material ~= Enum.Material.Water then
			local part = spawnProp(cfg.Model, CFrame.new(hit.Position) * CFrame.Angles(0, rng:NextNumber() * 6.28, 0))
			if part then
				placed += 1
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 210, 80)
				light.Range = 14
				light.Brightness = 2
				light.Parent = part
				local taken = false
				part.CanTouch = true
				part.Touched:Connect(function(other)
					local player = Players:GetPlayerFromCharacter(other.Parent)
					if taken or not player then
						return
					end
					taken = true
					local cash = cashFor(player, cfg.CashByStage)
					StatsService.Add(player, "Cash", cash)
					Remotes.Notify:FireClient(player, { key = "Event.GoldenDumbbells.Got", args = { cash = cash } })
					announce("GoldenDumbbells", "Taken", { position = part.Position })
					part:Destroy()
				end)
			end
		end
	end
	table.insert(cleanup, function()
		for _, child in folder:GetChildren() do
			child:Destroy()
		end
	end)
end

-- ------------------------------------------------------------------ shakes gratuits

local function freeShakes(cleanup: { () -> () })
	local cfg = Events.FreeShakes
	local spot = Events.Center + cfg.Offset
	local hit = groundAt(spot)
	local base = if hit then hit.Position else spot
	local machine =
		spawnProp(cfg.Model, CFrame.lookAt(base, Events.Center * Vector3.new(1, 0, 1) + Vector3.new(0, base.Y, 0)))
	if not machine then
		return
	end
	local served: { [Player]: boolean } = {}
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Texts.Get("Event.FreeShakes.Prompt")
	prompt.ObjectText = Texts.Get("Event.FreeShakes.Title")
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = machine
	prompt.Triggered:Connect(function(player)
		if served[player] then
			Remotes.Notify:FireClient(player, { key = "Event.FreeShakes.Already" })
			return
		end
		if BoostService.Grant(player, cfg.Boost) then
			served[player] = true
			Remotes.Notify:FireClient(
				player,
				{ key = "Event.FreeShakes.Got", args = { boost = { key = `Boost.{cfg.Boost}` } } }
			)
		else
			Remotes.Notify:FireClient(player, { key = "Event.FreeShakes.Stronger" })
		end
	end)
	table.insert(cleanup, function()
		machine:Destroy()
	end)
end

-- ------------------------------------------------------------------ piano fou

local function runawayPiano(cleanup: { () -> () })
	local cfg = Events.RunawayPiano
	local from, to = Events.Center + cfg.From, Events.Center + cfg.To
	if rng:NextNumber() < 0.5 then
		from, to = to, from
	end
	local direction = (to - from) * Vector3.new(1, 0, 1)
	local piano = spawnProp(cfg.Model, CFrame.lookAt(from, from + direction))
	if not piano then
		return
	end
	local halfHeight = piano.Size.Y / 2
	local stopped = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Texts.Get("Event.RunawayPiano.Prompt")
	prompt.ObjectText = Texts.Get("Event.RunawayPiano.Title")
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = piano
	prompt.Triggered:Connect(function(player)
		if stopped then
			return
		end
		stopped = true
		prompt:Destroy()
		local cash = cashFor(player, cfg.CashByStage)
		StatsService.Add(player, "Cash", cash)
		Remotes.Notify:FireClient(player, { key = "Event.RunawayPiano.Got", args = { cash = cash } })
		announce("RunawayPiano", "Stopped", { name = player.DisplayName })
	end)
	-- Il roule d'un bout à l'autre de la place pendant la durée de l'événement, en tanguant
	local t0 = os.clock()
	local connection = RunService.Heartbeat:Connect(function()
		if stopped or not piano.Parent then
			return
		end
		local t = math.min((os.clock() - t0) / cfg.Duration, 1)
		-- Aller-retour : il traverse la place deux fois
		local u = if t < 0.5 then t * 2 else 2 - t * 2
		local position = from:Lerp(to, u)
		local hit = groundAt(position)
		local y = if hit then hit.Position.Y else position.Y
		local heading = if t < 0.5 then direction else -direction
		local wobble = math.sin(os.clock() * 9) * 0.08
		piano.CFrame = CFrame.lookAt(
			Vector3.new(position.X, y + halfHeight, position.Z),
			Vector3.new(position.X, y + halfHeight, position.Z) + heading
		) * CFrame.Angles(0, 0, wobble)
	end)
	table.insert(cleanup, function()
		connection:Disconnect()
		piano:Destroy()
	end)
end

local STARTERS = {
	GoldenDumbbells = goldenDumbbells,
	FreeShakes = freeShakes,
	RunawayPiano = runawayPiano,
}

-- ------------------------------------------------------------------ déroulement

local function finish()
	if not active then
		return
	end
	local event = active
	active = nil
	for _, fn in event.cleanup do
		fn()
	end
	announce(event.kind, "Ended")
end

-- Termine l'événement en cours tout de suite (commandes de test)
function EventService.Stop()
	finish()
end

-- Lance un événement (au hasard si kind est nil). Renvoie false si un événement est déjà en cours.
function EventService.Run(kind: string?): boolean
	if active then
		return false
	end
	local chosen = kind or KINDS[rng:NextInteger(1, #KINDS)]
	local starter = STARTERS[chosen]
	if not starter then
		return false
	end
	local duration = (Events :: any)[chosen].Duration
	local event = { kind = chosen, endsAt = workspace:GetServerTimeNow() + duration, cleanup = {} }
	active = event
	starter(event.cleanup)
	announce(chosen, "Started", { endsAt = event.endsAt })
	task.delay(duration, function()
		if active == event then
			finish()
		end
	end)
	return true
end

function EventService.Init(services)
	DataService = services.DataService
	StatsService = services.StatsService
	BoostService = services.BoostService
end

function EventService.Start()
	folder = Instance.new("Folder")
	folder.Name = "CityEvents"
	folder.Parent = workspace
	-- Un joueur qui arrive pendant un événement le voit aussi
	DataService.PlayerLoaded:Connect(function(player)
		if active then
			Remotes.CityEvent:FireClient(player, { kind = active.kind, state = "Started", endsAt = active.endsAt })
		end
	end)
	task.spawn(function()
		task.wait(Events.FirstDelay)
		while true do
			if #Players:GetPlayers() > 0 then
				EventService.Run(nil)
			end
			task.wait(rng:NextNumber(Events.Interval[1], Events.Interval[2]))
		end
	end)
end

return EventService
