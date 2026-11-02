-- Événements de ville (Config/Events.luau) : toutes les 9 à 12 minutes, un événement pour tout le serveur.
-- Le serveur place les objets, décide qui gagne quoi et annonce le début, les étapes et la fin à tous
-- (Remotes.CityEvent). Le spectacle (rotation, parachutes, jambes du piano, effets) est joué par chaque client
-- (EventFxController) à partir des objets et de leurs attributs.
-- - GoldenDumbbells : haltères dorés posés au sol en plein air, le premier joueur qui en touche un le ramasse ;
--   l'un d'eux est un MÉGA haltère (attribut Mega).
-- - FreeShakes : des shakes atterrissent en parachute sur la place (attribut LandsAt = heure serveur d'arrivée),
--   un shake gratuit (boost) par joueur, en le touchant une fois posé.
-- - RunawayPiano : un piano fuit les joueurs autour de la fontaine (attributs Mood et Hits) ; le plaquer (prompt)
--   le sonne ; au dernier plaquage il s'arrête. Le dernier plaqueur gagne, les autres reçoivent une part.

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
local WeeklyService

type Event = {
	kind: string,
	endsAt: number,
	cleanup: { () -> () },
	joined: { [Player]: boolean },
	over: boolean, -- objectif atteint : l'événement se clôt bientôt
}

local folder: Folder
local active: Event? = nil
local tackle: ((Player) -> ())? = nil -- plaquage du piano en cours (bouton « Tackle! », commandes de test)
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
	local exclude: { Instance } = { folder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	return workspace:Raycast(Vector3.new(position.X, 150, position.Z), Vector3.new(0, -300, 0), params)
end

-- Sol dégagé, en plein air : pas sur un toit, pas dans l'eau de la fontaine
local function openGround(position: Vector3): Vector3?
	local hit = groundAt(position)
	if hit and hit.Normal.Y > 0.9 and hit.Position.Y < 4 and hit.Material ~= Enum.Material.Water then
		return hit.Position
	end
	return nil
end

-- Copie d'un décor (ServerStorage.Props), ancrée, sans collision, posée par sa base sur `cframe`
local function spawnProp(name: string, cframe: CFrame, rename: string, scale: number?): BasePart?
	local props = ServerStorage:FindFirstChild("Props")
	local template = props and props:FindFirstChild(name)
	if not template or not template:IsA("BasePart") then
		warn(`[EventService] Missing prop {name}`)
		return nil
	end
	local part = template:Clone()
	part.Name = rename
	part.Size *= scale or 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CFrame = cframe * CFrame.new(0, part.Size.Y / 2, 0)
	CollectionService:AddTag(part, EVENT_TAG)
	part.Parent = folder
	return part
end

-- Défi de la semaine « participer à des événements » : compté une fois par événement et par joueur
local function joined(player: Player)
	if active and not active.joined[player] then
		active.joined[player] = true
		WeeklyService.Track(player, "CityEvents")
	end
end

local function announce(kind: string, state: string, extra: { [string]: any }?)
	local message = { kind = kind, state = state }
	for key, value in extra or {} do
		message[key] = value
	end
	Remotes.CityEvent:FireAllClients(message)
end

-- Joueur vivant qui touche `prop`. Le contact est signalé par le client du joueur : on vérifie aussi que son corps
-- est vraiment à côté (un tricheur ne ramasse pas tout depuis l'autre bout de la ville)
local function playerFromHit(hit: BasePart, prop: BasePart): Player?
	local character = hit.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not player or not humanoid or humanoid.Health <= 0 or not root then
		return nil
	end
	if (root.Position - prop.Position).Magnitude > prop.Size.Magnitude / 2 + Events.TouchReach then
		return nil
	end
	return player
end

local finish: () -> ()

-- Objectif atteint : on laisse quelques secondes pour la fête, puis l'événement se clôt
local function endSoon(event: Event)
	if event.over then
		return
	end
	event.over = true
	task.delay(Events.EndDelay, function()
		if active == event then
			finish()
		end
	end)
end

-- ------------------------------------------------------------------ haltères dorés

local function goldenDumbbells(event: Event)
	local cfg = Events.GoldenDumbbells
	local placed, left, tries = 0, 0, 0
	while placed < cfg.Count and tries < cfg.Count * 30 do
		tries += 1
		local angle = rng:NextNumber() * math.pi * 2
		local distance = 20 + rng:NextNumber() * (cfg.Radius - 20)
		local ground =
			openGround(Events.Center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance))
		if ground then
			local mega = placed < cfg.Mega.Count
			local part = spawnProp(
				cfg.Model,
				CFrame.new(ground + Vector3.new(0, cfg.Hover, 0)) * CFrame.Angles(0, rng:NextNumber() * 6.28, 0),
				"GoldenDumbbell",
				if mega then cfg.Mega.Scale else 1
			)
			if part then
				placed += 1
				left += 1
				part:SetAttribute("Mega", mega)
				CollectionService:AddTag(part, "EventDumbbell")
				local taken = false
				part.CanTouch = true
				part.Touched:Connect(function(hit)
					local player = playerFromHit(hit, part)
					if taken or not player then
						return
					end
					taken = true
					left -= 1
					local cash = cashFor(player, cfg.CashByStage) * (if mega then cfg.Mega.CashMultiplier else 1)
					StatsService.Add(player, "Cash", cash)
					Remotes.Notify:FireClient(player, {
						key = if mega then "Event.GoldenDumbbells.GotMega" else "Event.GoldenDumbbells.Got",
						args = { cash = cash },
					})
					joined(player)
					announce("GoldenDumbbells", "Taken", {
						position = part.Position,
						mega = mega,
						name = player.DisplayName,
						left = left,
						userId = player.UserId,
					})
					part:Destroy()
					if left == 0 then
						endSoon(event)
					end
				end)
			end
		end
	end
	event.cleanup[#event.cleanup + 1] = function()
		for _, child in folder:GetChildren() do
			child:Destroy()
		end
	end
	return { left = left }
end

-- ------------------------------------------------------------------ shakes en parachute

local function freeShakes(event: Event)
	local cfg = Events.FreeShakes
	local served: { [Player]: boolean } = {}
	local warned: { [Player]: number } = {}
	local now = workspace:GetServerTimeNow()
	local dropped, tries = 0, 0
	while dropped < cfg.Count and tries < cfg.Count * 30 do
		tries += 1
		local angle = rng:NextNumber() * math.pi * 2
		local distance = cfg.Ring[1] + rng:NextNumber() * (cfg.Ring[2] - cfg.Ring[1])
		local ground =
			openGround(Events.Center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance))
		if ground then
			local part = spawnProp(
				cfg.Model,
				CFrame.new(ground) * CFrame.Angles(0, rng:NextNumber() * 6.28, 0),
				"FallingShake",
				cfg.Scale
			)
			if part then
				-- Atterrissages étalés : le premier tombe tout de suite, le dernier après DropOver secondes
				local landsAt = now + cfg.FallTime + cfg.DropOver * dropped / math.max(cfg.Count - 1, 1)
				dropped += 1
				part:SetAttribute("LandsAt", landsAt)
				CollectionService:AddTag(part, "EventShake")
				task.delay(landsAt - now, function()
					if not part.Parent then
						return
					end
					part.CanTouch = true
					announce("FreeShakes", "Landed", { position = part.Position })
				end)
				part.Touched:Connect(function(hit)
					local player = playerFromHit(hit, part)
					if not player or not part.Parent then
						return
					end
					if served[player] then
						-- Message au plus une fois toutes les 4 s (Touched se répète en marchant dessus)
						if os.clock() - (warned[player] or -math.huge) > 4 then
							warned[player] = os.clock()
							Remotes.Notify:FireClient(player, { key = "Event.FreeShakes.Already" })
						end
						return
					end
					if BoostService.Grant(player, cfg.Boost) then
						served[player] = true
						joined(player)
						Remotes.Notify:FireClient(
							player,
							{ key = "Event.FreeShakes.Got", args = { boost = { key = `Boost.{cfg.Boost}` } } }
						)
						announce("FreeShakes", "Drank", { position = part.Position, userId = player.UserId })
						part:Destroy()
					elseif os.clock() - (warned[player] or -math.huge) > 4 then
						warned[player] = os.clock()
						Remotes.Notify:FireClient(player, { key = "Event.FreeShakes.Stronger" })
					end
				end)
			end
		end
	end
	event.cleanup[#event.cleanup + 1] = function()
		for _, child in folder:GetChildren() do
			child:Destroy()
		end
	end
	return nil
end

-- ------------------------------------------------------------------ piano fugueur

-- Joueur vivant le plus proche (à plat) et sa distance
local function nearestPlayer(position: Vector3): (Vector3?, number)
	local best, bestDistance = nil, math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local offset = (root.Position - position) * Vector3.new(1, 0, 1)
			if offset.Magnitude < bestDistance then
				best, bestDistance = root.Position, offset.Magnitude
			end
		end
	end
	return best, bestDistance
end

local function flat(v: Vector3): Vector3
	local f = v * Vector3.new(1, 0, 1)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, -1)
end

local function runawayPiano(event: Event)
	local cfg = Events.RunawayPiano
	local center = Events.Center
	local arena = cfg.Arena
	local startAngle = rng:NextNumber() * math.pi * 2
	local radius = (arena.Inner + arena.Outer) / 2
	local position = center + Vector3.new(math.cos(startAngle), 0, math.sin(startAngle)) * radius
	local spin = if rng:NextNumber() < 0.5 then 1 else -1 -- sens dans lequel il tourne autour de la fontaine
	local heading = flat(Vector3.new(0, 1, 0):Cross(position - center) * spin)
	local piano = spawnProp(cfg.Model, CFrame.lookAt(position, position + heading), "EventPiano")
	if not piano then
		return nil
	end
	CollectionService:AddTag(piano, "EventPiano")
	local halfHeight = piano.Size.Y / 2
	local hits = cfg.Tackles
	local mood = "Trot"
	local stamina = cfg.Stamina
	local moodUntil = 0
	local tacklers: { [Player]: number } = {} -- dernier plaquage de chaque joueur (os.clock)
	piano:SetAttribute("Hits", hits)
	piano:SetAttribute("Mood", mood)

	local function setMood(newMood: string, duration: number?)
		mood = newMood
		moodUntil = os.clock() + (duration or 0)
		piano:SetAttribute("Mood", newMood)
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Texts.Get("Event.RunawayPiano.Prompt")
	prompt.ObjectText = Texts.Get("Event.RunawayPiano.Title")
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = cfg.TackleDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = piano
	local function onTackle(player: Player)
		if hits <= 0 or mood == "Stunned" then
			return
		end
		local last = tacklers[player]
		if last and os.clock() - last < cfg.TackleCooldown then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or ((root.Position - piano.Position) * Vector3.new(1, 0, 1)).Magnitude > cfg.TackleDistance + 2 then
			return
		end
		tacklers[player] = os.clock()
		joined(player)
		hits -= 1
		piano:SetAttribute("Hits", hits)
		if hits > 0 then
			setMood("Stunned", cfg.StunTime)
			stamina = cfg.Stamina -- il repart de plus belle
			announce("RunawayPiano", "Tackled", { name = player.DisplayName, left = hits, userId = player.UserId })
			return
		end
		-- Dernier plaquage : il s'effondre, le plaqueur gagne, les autres reçoivent leur part
		prompt.Enabled = false
		setMood("Down")
		local cash = cashFor(player, cfg.CashByStage)
		StatsService.Add(player, "Cash", cash)
		Remotes.Notify:FireClient(player, { key = "Event.RunawayPiano.Got", args = { cash = cash } })
		for helper in tacklers do
			if helper ~= player and helper.Parent then
				local share = math.max(1, math.floor(cashFor(helper, cfg.CashByStage) * cfg.HelperShare))
				StatsService.Add(helper, "Cash", share)
				Remotes.Notify:FireClient(helper, { key = "Event.RunawayPiano.Helped", args = { cash = share } })
			end
		end
		announce("RunawayPiano", "Stopped", { name = player.DisplayName, userId = player.UserId })
		endSoon(event)
	end
	prompt.Triggered:Connect(onTackle)
	tackle = onTackle

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true -- les volumes invisibles (eau, zones) ne sont pas des obstacles
	local lastTurnBack = 0
	local connection = RunService.Heartbeat:Connect(function(dt)
		if not piano.Parent or mood == "Down" then
			return
		end
		local now = os.clock()
		if (mood == "Stunned" or mood == "Tired") and now < moodUntil then
			if mood == "Stunned" then
				return -- sonné : il ne bouge plus
			end
		elseif mood == "Stunned" or mood == "Tired" then
			setMood("Trot")
		end

		local fromCenter = (position - center) * Vector3.new(1, 0, 1)
		local r = fromCenter.Magnitude
		local radial = flat(fromCenter)
		local tangent = flat(Vector3.new(0, 1, 0):Cross(radial) * spin)
		local threat, distance = nearestPlayer(position)

		-- Envie : tourner autour de la fontaine ; fuir le joueur le plus proche ; rester dans l'anneau
		local wish = tangent + Vector3.new(math.noise(now * 0.4, 1) * 0.6, 0, math.noise(now * 0.4, 2) * 0.6)
		local panicking = threat ~= nil and distance < cfg.PanicDistance
		if panicking and threat then
			local away = flat(position - threat)
			-- Il garde son sens de rotation tant que le joueur n'est pas devant lui ; sinon il fait demi-tour
			if away:Dot(tangent) < -0.3 then
				spin = -spin
				tangent = -tangent
			end
			wish = tangent * 1.2 + away * 1.6
		end
		local margin = 3
		if r > arena.Outer - margin then
			wish -= radial * (r - (arena.Outer - margin)) * 0.8
		elseif r < arena.Inner + margin then
			wish += radial * ((arena.Inner + margin) - r) * 0.8
		end

		-- Obstacle devant (banc, statue, lampadaire) : il fait demi-tour (pas plus d'une fois par seconde)
		local exclude: { Instance } = { folder }
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(exclude, player.Character)
			end
		end
		params.FilterDescendantsInstances = exclude
		if now - lastTurnBack > 1 and workspace:Raycast(position + Vector3.new(0, 1.5, 0), heading * 5, params) then
			lastTurnBack = now
			spin = -spin
			heading = flat(-heading + radial * 0.3)
		end
		wish = flat(wish)

		-- Vitesse : trot, sprint de panique (qui l'essouffle), essoufflé
		local speed = cfg.Speed.Trot
		if mood == "Tired" then
			speed = cfg.Speed.Tired
		elseif panicking then
			speed = cfg.Speed.Panic
			stamina -= dt
			if stamina <= 0 then
				stamina = cfg.Stamina
				setMood("Tired", cfg.TiredTime)
			elseif mood ~= "Panic" then
				setMood("Panic")
			end
		else
			stamina = math.min(cfg.Stamina, stamina + dt * 0.5)
			if mood ~= "Trot" then
				setMood("Trot")
			end
		end

		-- Virage limité, puis déplacement collé au sol et retenu dans l'anneau
		local angle = math.acos(math.clamp(heading:Dot(wish), -1, 1))
		local turn = math.min(angle, cfg.TurnRate * dt)
		if angle > 1e-3 then
			local side = if heading:Cross(wish).Y > 0 then 1 else -1
			heading = flat(CFrame.Angles(0, side * turn, 0):VectorToWorldSpace(heading))
		end
		position += heading * speed * dt
		local offset = (position - center) * Vector3.new(1, 0, 1)
		position = center + offset.Unit * math.clamp(offset.Magnitude, arena.Inner, arena.Outer)
		local hit = groundAt(position)
		local y = if hit then hit.Position.Y else center.Y
		position = Vector3.new(position.X, y, position.Z)
		piano.CFrame =
			CFrame.lookAt(position + Vector3.new(0, halfHeight, 0), position + Vector3.new(0, halfHeight, 0) + heading)
	end)
	event.cleanup[#event.cleanup + 1] = function()
		connection:Disconnect()
		piano:Destroy()
		tackle = nil
	end
	return { hits = hits }
end

local STARTERS = {
	GoldenDumbbells = goldenDumbbells,
	FreeShakes = freeShakes,
	RunawayPiano = runawayPiano,
}

-- ------------------------------------------------------------------ déroulement

function finish()
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

-- Plaque le piano fugueur comme le bouton « Tackle! » (mêmes vérifications ; commandes de test)
function EventService.Tackle(player: Player)
	if tackle then
		tackle(player)
	end
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
	local event: Event = {
		kind = chosen,
		endsAt = workspace:GetServerTimeNow() + duration,
		cleanup = {},
		joined = {},
		over = false,
	}
	active = event
	local extra = starter(event) or {}
	extra.endsAt = event.endsAt
	announce(chosen, "Started", extra)
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
	WeeklyService = services.WeeklyService
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
