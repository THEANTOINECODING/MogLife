-- Combat du Dieu du Pump au Colisée (D89, D90, D91 — manche 1 complète).
-- Le serveur décide de tout : il tire les attaques, fixe l'heure exacte de chaque impact (heure du serveur,
-- workspace:GetServerTimeNow), juge si le joueur est touché d'après sa position, son saut et sa roulade, tient la vie
-- du joueur et celle du dieu, et décide ce que fait le bouton FLEX. Les clients (PumpGodController) dessinent tout à
-- partir des messages Remotes.PumpGodUpdate (envoyés à tous : les spectateurs voient le combat).
-- Attaques (Config/PumpGod.luau) : Bolts (cercles), Dumbbell (bande traversée par un haltère), Wave (anneau à sauter),
-- Slam (cône devant lui, puis il est essoufflé), Javelin (javelot d'éclair, à renvoyer).
-- FLEX (Remotes.PumpGodFlex, appuyé / relâché), par ordre de priorité : renvoyer le javelot qui arrive, frapper le dieu
-- essoufflé (combo de 3), lancer le disque porté ou en ramasser un, charger la pose sacrée dans le cercle doré.
-- Pour l'instant le combat se lance seulement dans Studio (DevCommands « PumpGod »).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local PumpGod = require(ReplicatedStorage.Shared.Config.PumpGod)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local SPOT_TAG = "ColosseumSpot"
local ATTACKS = PumpGod.Attacks
local PIT = Balance.Colosseum.PitRadius

local ColosseumService
local DataService
local MinigameService
local StatsService

type Javelin = { from: Vector3, dir: Vector3, start: number, length: number, parried: boolean }
type Disc = { at: Vector3, born: number }

type Fight = {
	player: Player,
	hp: number,
	bossHp: number,
	token: number,
	startedAt: number,
	boss: Model?,
	center: Vector3,
	floor: number,
	invulnUntil: number,
	rollReadyAt: number,
	rollAt: number, -- dernière roulade reçue (os.clock)
	airAt: number, -- dernier instant où ses pieds étaient assez haut pour passer une onde (os.clock)
	nextId: number,
	ended: boolean,
	-- Position du dieu (au sol, sous lui) : il glisse de `bossFrom` à `bossTo` entre `moveStart` et `moveEnd`
	bossFrom: Vector3,
	bossTo: Vector3,
	moveStart: number,
	moveEnd: number,
	windedUntil: number,
	combo: number,
	comboAt: number,
	javelins: { [number]: Javelin },
	discs: { [number]: Disc },
	carrying: number?,
	sacred: { id: number, at: Vector3, ends: number }?,
	chargeEnds: number?,
}

local fights: { [Player]: Fight } = {}
local tokens = 0

local PumpGodService = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function findSpot(role: string): BasePart?
	for _, spot in CollectionService:GetTagged(SPOT_TAG) do
		if spot:IsA("BasePart") and spot:GetAttribute("Role") == role then
			return spot
		end
	end
	return nil
end

local function broadcast(message)
	Remotes.PumpGodUpdate:FireAllClients(message)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Pieds du joueur au-dessus de la piste (pour savoir s'il saute)
local function feetHeight(fight: Fight, root: BasePart): number
	local humanoid = (root.Parent :: Model):FindFirstChildOfClass("Humanoid")
	local hip = if humanoid then humanoid.HipHeight else 2
	return root.Position.Y - root.Size.Y / 2 - hip - fight.floor
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function onFloor(fight: Fight, v: Vector3): Vector3
	return Vector3.new(v.X, fight.floor, v.Z)
end

local function alive(fight: Fight, token: number): boolean
	return not fight.ended and fight.token == token and fights[fight.player] == fight
end

local function newId(fight: Fight): number
	fight.nextId += 1
	return fight.nextId
end

-- Position du dieu (au sol) à un instant donné
local function bossAt(fight: Fight, t: number): Vector3
	if t >= fight.moveEnd then
		return fight.bossTo
	elseif t <= fight.moveStart then
		return fight.bossFrom
	end
	local k = (t - fight.moveStart) / (fight.moveEnd - fight.moveStart)
	k = k * k * (3 - 2 * k)
	return fight.bossFrom:Lerp(fight.bossTo, k)
end

-- Garde un point dans la piste, à au plus `radius` du centre
local function inPit(fight: Fight, point: Vector3, radius: number): Vector3
	local offset = flat(point - fight.center)
	if offset.Magnitude > radius then
		offset = offset.Unit * radius
	end
	return fight.center + offset
end

local finish

local function hit(fight: Fight, kind: string, damage: number)
	local t = os.clock()
	if fight.ended or t < fight.invulnUntil then
		return
	end
	fight.hp = math.max(fight.hp - damage, 0)
	fight.invulnUntil = t + PumpGod.HitInvuln
	broadcast({ state = "Hit", player = fight.player, kind = kind, hp = fight.hp, damage = damage })
	if fight.hp <= 0 then
		finish(fight, "Defeat")
	end
end

local function hurtBoss(fight: Fight, kind: string, damage: number)
	if fight.ended then
		return
	end
	fight.bossHp = math.max(fight.bossHp - damage, 0)
	broadcast({
		state = "BossHit",
		player = fight.player,
		kind = kind,
		hp = fight.bossHp,
		maxHp = PumpGod.BossHealth,
		damage = damage,
	})
	if fight.bossHp <= 0 then
		finish(fight, "Victory")
	end
end

-- Le joueur est-il dans la zone d'un instant donné ? (vérifié par `test`, à chaque image, de `from` à `to`).
-- Un coup détecté attend PumpGod.Grace : une roulade, ou un saut si `jumpable`, partis à temps chez le joueur mais
-- arrivés un peu après sur le serveur, l'annulent ; `cancelled` (facultatif) aussi (javelot renvoyé).
local function watch(
	fight: Fight,
	token: number,
	from: number,
	to: number,
	kind: string,
	damage: number,
	jumpable: boolean,
	test: (number, BasePart) -> boolean,
	cancelled: (() -> boolean)?
)
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local t = now() - PumpGod.Latency
		if not alive(fight, token) or t > to or (cancelled and cancelled()) then
			connection:Disconnect()
			return
		end
		if t < from then
			return
		end
		local root = rootOf(fight.player)
		if root and test(t, root) then
			connection:Disconnect()
			local seen = os.clock()
			task.delay(PumpGod.Grace, function()
				local dodged = fight.rollAt >= seen
					or (jumpable and fight.airAt >= seen)
					or (cancelled ~= nil and cancelled())
				if alive(fight, token) and not dodged then
					hit(fight, kind, damage)
				end
			end)
		end
	end)
end

-- Le dieu glisse vers un point de la piste
local function moveBoss(fight: Fight, token: number, to: Vector3, time: number): boolean
	local t = now()
	fight.bossFrom = bossAt(fight, t)
	fight.bossTo = onFloor(fight, to)
	fight.moveStart = t
	fight.moveEnd = t + time
	broadcast({
		state = "Move",
		player = fight.player,
		from = fight.bossFrom,
		to = fight.bossTo,
		start = t,
		arrive = t + time,
	})
	task.wait(time)
	return alive(fight, token)
end

-- ------------------------------------------------------------------ disques d'haltère
local function dropDisc(fight: Fight, at: Vector3)
	local count = 0
	for _ in fight.discs do
		count += 1
	end
	if count >= PumpGod.Disc.Max then
		return
	end
	local id = newId(fight)
	local spot = inPit(fight, at, PIT - 4)
	fight.discs[id] = { at = spot, born = os.clock() }
	broadcast({ state = "Disc", player = fight.player, id = id, at = spot })
	task.delay(PumpGod.Disc.Life, function()
		if fight.discs[id] and fight.carrying ~= id then
			fight.discs[id] = nil
			broadcast({ state = "DiscGone", player = fight.player, id = id })
		end
	end)
end

-- ------------------------------------------------------------------ attaques
local function bolts(fight: Fight, token: number)
	local spec = ATTACKS.Bolts
	local last = 0
	local lastTarget = nil
	for _ = 1, spec.Count do
		local root = rootOf(fight.player)
		if not root or not alive(fight, token) then
			return
		end
		local target = onFloor(fight, root.Position)
		local start = now()
		local impact = start + spec.Warn
		broadcast({
			state = "Attack",
			player = fight.player,
			kind = "Bolt",
			id = newId(fight),
			at = target,
			radius = spec.Radius,
			start = start,
			impact = impact,
		})
		watch(fight, token, impact, impact + 0.05, "Bolt", spec.Damage, false, function(_, r: BasePart)
			return flat(r.Position - target).Magnitude < spec.Radius
		end)
		last = impact
		lastTarget = target
		task.wait(spec.Gap)
	end
	task.wait(math.max(last - now(), 0) + 0.4)
	-- Le dernier éclair laisse un disque doré
	if lastTarget and alive(fight, token) then
		dropDisc(fight, lastTarget)
	end
end

local function dumbbell(fight: Fight, token: number)
	local spec = ATTACKS.Dumbbell
	local root = rootOf(fight.player)
	if not root then
		return
	end
	-- Une droite qui passe par le joueur, dans une direction tirée au sort, d'un bord de la piste à l'autre
	local through = flat(root.Position - fight.center)
	local angle = math.random() * math.pi
	local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local along = through:Dot(dir)
	local perp = through - dir * along
	local reach = math.sqrt(math.max((PIT - 1) ^ 2 - perp.Magnitude ^ 2, 25))
	local a = onFloor(fight, fight.center + perp - dir * reach)
	local b = onFloor(fight, fight.center + perp + dir * reach)
	local length = (b - a).Magnitude
	local start = now()
	local roll = start + spec.Warn
	local done = roll + length / spec.Speed
	broadcast({
		state = "Attack",
		player = fight.player,
		kind = "Dumbbell",
		id = newId(fight),
		a = a,
		b = b,
		width = spec.Width,
		height = spec.Height,
		start = start,
		impact = roll,
		speed = spec.Speed,
	})
	local unit = (b - a).Unit
	watch(fight, token, roll, done, "Dumbbell", spec.Damage, true, function(t, r: BasePart)
		local offset = flat(r.Position - a)
		local s = (t - roll) * spec.Speed
		local d = offset:Dot(unit)
		local lateral = (offset - unit * d).Magnitude
		return math.abs(d - s) < spec.Height * 0.6
			and lateral < spec.Width / 2
			and feetHeight(fight, r) < PumpGod.JumpClear + spec.Height * 0.4
	end)
	task.wait(done - now() + 0.3)
	-- En cognant le mur, l'haltère perd un disque
	if alive(fight, token) then
		dropDisc(fight, b - unit * 4)
	end
end

local function wave(fight: Fight, token: number)
	local spec = ATTACKS.Wave
	local origin = bossAt(fight, now())
	local start = now()
	local go = start + spec.Warn
	local maxRadius = PIT + flat(origin - fight.center).Magnitude
	local done = go + maxRadius / spec.Speed
	broadcast({
		state = "Attack",
		player = fight.player,
		kind = "Wave",
		id = newId(fight),
		at = origin,
		speed = spec.Speed,
		thickness = spec.Thickness,
		maxRadius = maxRadius,
		start = start,
		impact = go,
	})
	watch(fight, token, go, done, "Wave", spec.Damage, true, function(t, r: BasePart)
		local radius = (t - go) * spec.Speed
		local d = flat(r.Position - origin).Magnitude
		return math.abs(d - radius) < spec.Thickness / 2 and feetHeight(fight, r) < PumpGod.JumpClear
	end)
	task.wait(done - now() + 0.2)
end

-- Coup de poing au sol : il fonce près du joueur, frappe en cône, puis reste essoufflé (le moment de le punir)
local function slam(fight: Fight, token: number)
	local spec = ATTACKS.Slam
	local root = rootOf(fight.player)
	if not root then
		return
	end
	local here = bossAt(fight, now())
	local away = flat(here - root.Position)
	away = if away.Magnitude > 1 then away.Unit else flat(fight.center - root.Position).Unit
	local spot = inPit(fight, root.Position + away * spec.Approach, PumpGod.Orbit.MaxRadius)
	if not moveBoss(fight, token, spot, PumpGod.Orbit.MoveTime * 0.7) then
		return
	end
	root = rootOf(fight.player)
	if not root then
		return
	end
	local origin = bossAt(fight, now())
	local dir = flat(root.Position - origin)
	dir = if dir.Magnitude > 0.5 then dir.Unit else flat(fight.center - origin).Unit
	local start = now()
	local impact = start + spec.Warn
	broadcast({
		state = "Attack",
		player = fight.player,
		kind = "Slam",
		id = newId(fight),
		at = origin,
		dir = dir,
		length = spec.Length,
		angle = spec.Angle,
		start = start,
		impact = impact,
	})
	local half = math.rad(spec.Angle / 2)
	watch(fight, token, impact, impact + 0.05, "Slam", spec.Damage, false, function(_, r: BasePart)
		local offset = flat(r.Position - origin)
		if offset.Magnitude > spec.Length then
			return false
		end
		if offset.Magnitude < 3 then
			return true
		end
		return math.acos(math.clamp(offset.Unit:Dot(dir), -1, 1)) < half
	end)
	task.wait(math.max(impact - now(), 0) + 0.15)
	if not alive(fight, token) then
		return
	end
	-- Essoufflé : il tombe à genoux, le joueur peut le frapper
	local winded = PumpGod.Winded.Time
	fight.windedUntil = now() + winded
	fight.combo = 0
	broadcast({ state = "Winded", player = fight.player, start = now(), ends = fight.windedUntil })
	task.wait(winded)
end

-- Javelot d'éclair : lancé vers le joueur ; FLEX quand il arrive près de lui pour le renvoyer
local function javelin(fight: Fight, token: number)
	local spec = ATTACKS.Javelin
	local root = rootOf(fight.player)
	if not root then
		return
	end
	local from = bossAt(fight, now())
	local dir = flat(root.Position - from)
	dir = if dir.Magnitude > 0.5 then dir.Unit else flat(fight.center - from).Unit
	-- Il vole jusqu'au mur de la piste
	local offset = flat(from - fight.center)
	local b = offset:Dot(dir)
	local length = -b + math.sqrt(math.max(b * b - (offset.Magnitude ^ 2 - PIT ^ 2), 0))
	local start = now()
	local throw = start + spec.Warn
	local id = newId(fight)
	local shot: Javelin = { from = from, dir = dir, start = throw, length = length, parried = false }
	fight.javelins[id] = shot
	broadcast({
		state = "Attack",
		player = fight.player,
		kind = "Javelin",
		id = id,
		at = from,
		dir = dir,
		length = length,
		radius = spec.Radius,
		height = spec.Height,
		speed = spec.Speed,
		start = start,
		impact = throw,
	})
	local done = throw + length / spec.Speed
	watch(fight, token, throw, done, "Javelin", spec.Damage, false, function(t, r: BasePart)
		local tip = from + dir * (t - throw) * spec.Speed
		return flat(r.Position - tip).Magnitude < spec.Radius
	end, function()
		return shot.parried
	end)
	task.wait(math.max(done - now(), 0) + 0.2)
	if not shot.parried then
		fight.javelins[id] = nil
	end
end

local RUN = { Bolts = bolts, Dumbbell = dumbbell, Wave = wave, Slam = slam, Javelin = javelin }

local function pick(previous: string?): string
	local total = 0
	for name, spec in ATTACKS do
		if name ~= previous then
			total += spec.Weight
		end
	end
	local roll = math.random() * total
	for name, spec in ATTACKS do
		if name ~= previous then
			roll -= spec.Weight
			if roll <= 0 then
				return name
			end
		end
	end
	return "Bolts"
end

-- Un nouvel endroit sur le cercle autour du centre, plutôt en face du joueur
local function orbitSpot(fight: Fight): Vector3
	local root = rootOf(fight.player)
	local from = if root then flat(root.Position - fight.center) else Vector3.new(1, 0, 0)
	local base = math.atan2(-from.Z, -from.X) -- à l'opposé du joueur
	local angle = base + (math.random() - 0.5) * math.rad(140)
	return fight.center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * PumpGod.Orbit.Radius
end

local function sacredLoop(fight: Fight, token: number)
	local spec = PumpGod.Sacred
	task.wait(spec.First)
	while alive(fight, token) do
		local boss = bossAt(fight, now())
		local spot = fight.center
		for _ = 1, 8 do
			local angle = math.random() * 2 * math.pi
			local radius = 8 + math.random() * (PIT - 16)
			spot = fight.center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
			if flat(spot - boss).Magnitude > 14 then
				break
			end
		end
		local id = newId(fight)
		local ends = now() + spec.Life
		local at = onFloor(fight, spot)
		fight.sacred = { id = id, at = at, ends = ends }
		broadcast({ state = "Sacred", player = fight.player, id = id, at = at, radius = spec.Radius, ends = ends })
		task.wait(spec.Life)
		if fight.sacred and fight.sacred.id == id then
			fight.sacred = nil
			fight.chargeEnds = nil
			broadcast({ state = "SacredGone", player = fight.player, id = id })
		end
		task.wait(spec.Every - spec.Life)
	end
end

local function loop(fight: Fight, token: number)
	task.wait(2.5) -- le dieu se présente
	local previous = nil
	local opening = table.clone(PumpGod.Opening)
	while alive(fight, token) do
		local name = table.remove(opening, 1) or pick(previous)
		previous = name
		RUN[name](fight, token)
		if not alive(fight, token) then
			return
		end
		local p = PumpGod.Pause
		local k = math.clamp((os.clock() - fight.startedAt) / p.Over, 0, 1)
		local pause = p.From + (p.To - p.From) * k
		-- Il change de place pendant la pause
		if not moveBoss(fight, token, orbitSpot(fight), math.min(PumpGod.Orbit.MoveTime, pause)) then
			return
		end
		task.wait(math.max(pause - PumpGod.Orbit.MoveTime, 0.2))
	end
end

-- ------------------------------------------------------------------ bouton FLEX
local function inSacred(fight: Fight, root: BasePart): boolean
	local sacred = fight.sacred
	return sacred ~= nil and flat(root.Position - sacred.at).Magnitude <= PumpGod.Sacred.Radius + 0.5
end

local function flexDown(fight: Fight, root: BasePart)
	local t = now()
	local token = fight.token
	-- 1. Renvoyer le javelot qui arrive
	for id, shot in fight.javelins do
		if not shot.parried and t > shot.start then
			local s = (t - shot.start) * ATTACKS.Javelin.Speed
			local tip = shot.from + shot.dir * s
			local ahead = flat(root.Position - shot.from):Dot(shot.dir) - s -- distance qui reste au javelot
			if s < shot.length and ahead > -2 and flat(root.Position - tip).Magnitude < PumpGod.Parry.Range then
				shot.parried = true
				fight.javelins[id] = nil
				local target = bossAt(fight, t + PumpGod.Parry.Flight)
				broadcast({
					state = "Parry",
					player = fight.player,
					id = id,
					from = onFloor(fight, tip),
					to = target,
					start = t,
					arrive = t + PumpGod.Parry.Flight,
				})
				task.delay(PumpGod.Parry.Flight, function()
					if alive(fight, token) then
						hurtBoss(fight, "Parry", PumpGod.Parry.Damage)
					end
				end)
				return
			end
		end
	end
	-- 2. Frapper le dieu essoufflé (combo de 3, le 3e en rythme = coup de Mog)
	local punch = PumpGod.Punch
	if t < fight.windedUntil and flat(root.Position - bossAt(fight, t)).Magnitude < PumpGod.Winded.Range then
		local gap = t - fight.comboAt
		if gap < punch.MinGap then
			return
		end
		if gap > punch.Reset then
			fight.combo = 0
		end
		fight.combo += 1
		fight.comboAt = t
		local power = fight.combo == 3 and gap >= punch.BeatFrom and gap <= punch.BeatTo
		local damage = if power then punch.PowerDamage else punch.Damage
		broadcast({ state = "Punch", player = fight.player, combo = fight.combo, power = power, at = t })
		if fight.combo >= 3 then
			fight.combo = 0
		end
		hurtBoss(fight, if power then "PowerPunch" else "Punch", damage)
		return
	end
	-- 3. Lancer le disque porté, ou en ramasser un
	if fight.carrying then
		local id = fight.carrying
		fight.carrying = nil
		fight.discs[id] = nil
		local flight = PumpGod.Disc.Flight
		broadcast({
			state = "DiscThrow",
			player = fight.player,
			id = id,
			from = root.Position,
			to = bossAt(fight, t + flight),
			start = t,
			arrive = t + flight,
		})
		task.delay(flight, function()
			if alive(fight, token) then
				hurtBoss(fight, "Disc", PumpGod.Disc.Damage)
			end
		end)
		return
	end
	for id, disc in fight.discs do
		if flat(root.Position - disc.at).Magnitude < PumpGod.Disc.PickRange then
			fight.carrying = id
			broadcast({ state = "DiscPick", player = fight.player, id = id })
			return
		end
	end
	-- 4. Pose sacrée : charger dans le cercle doré
	if inSacred(fight, root) and not fight.chargeEnds then
		fight.chargeEnds = t + PumpGod.Sacred.Charge
		broadcast({ state = "Charge", player = fight.player, start = t, ends = fight.chargeEnds })
	end
end

local function stopCharge(fight: Fight)
	if fight.chargeEnds then
		fight.chargeEnds = nil
		broadcast({ state = "Charge", player = fight.player, cancel = true })
	end
end

local function onFlex(player: Player, down: unknown)
	local fight = fights[player]
	local root = rootOf(player)
	if not fight or fight.ended or not root or typeof(down) ~= "boolean" then
		return
	end
	if down then
		flexDown(fight, root)
	else
		stopCharge(fight)
	end
end

-- Pose sacrée : la charge tient tant qu'il reste dans le cercle ; au bout, le rayon de Mog part
local function stepCharge(fight: Fight)
	local ends = fight.chargeEnds
	local sacred = fight.sacred
	if not ends then
		return
	end
	local root = rootOf(fight.player)
	if not root or not sacred or not inSacred(fight, root) then
		stopCharge(fight)
		return
	end
	if now() >= ends then
		fight.chargeEnds = nil
		fight.sacred = nil
		broadcast({
			state = "Beam",
			player = fight.player,
			id = sacred.id,
			from = root.Position,
			to = bossAt(fight, now()),
		})
		hurtBoss(fight, "Beam", PumpGod.Sacred.Damage)
	end
end

-- ------------------------------------------------------------------ début et fin
local function spawnBoss(spot: BasePart, center: Vector3): Model?
	local folder = ServerStorage:FindFirstChild("NpcModels")
	local template = folder and folder:FindFirstChild("PumpGod")
	if not template or not template:IsA("Model") or not template.PrimaryPart then
		return nil
	end
	local model = template:Clone()
	model.Name = "ColosseumPumpGod"
	model:SetAttribute("NpcStill", true) -- NpcController ne l'anime pas : c'est PumpGodController
	model:SetAttribute("ColosseumBoss", true)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
		end
	end
	if PumpGod.BossScale ~= 1 then
		model:ScaleTo(model:GetScale() * PumpGod.BossScale)
	end
	local body = model.PrimaryPart :: BasePart
	local base = Vector3.new(spot.Position.X, spot.Position.Y - spot.Size.Y / 2, spot.Position.Z)
	local look = Vector3.new(center.X, base.Y, center.Z)
	local pivotFromBody = body.CFrame:ToObjectSpace(model:GetPivot())
	model:PivotTo(CFrame.lookAt(base, look) * pivotFromBody)
	local lift = base.Y + body.Size.Y / 2 + PumpGod.BossHover - body.Position.Y
	model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
	model.Parent = workspace
	return model
end

function finish(fight: Fight, reason: string)
	if fight.ended then
		return
	end
	fight.ended = true
	fights[fight.player] = nil
	ColosseumService.SetFighter(fight.player, false)
	-- Défaite (ou départ en plein combat) : il perd une part de son Mog (D89) ; il devra refaire tout le combat
	local mogLost = 0
	if reason == "Defeat" or reason == "Left" then
		local data = DataService.Get(fight.player)
		if data and typeof(data.Mog) == "number" and data.Mog > 0 then
			mogLost = math.floor(data.Mog * PumpGod.DefeatMogShare)
			if mogLost > 0 then
				StatsService.Add(fight.player, "Mog", -mogLost)
			end
		end
	end
	broadcast({ state = "End", player = fight.player, reason = reason, mogLost = mogLost })
	task.delay(PumpGod.EndDelay, function()
		if fight.boss then
			fight.boss:Destroy()
		end
		if not fight.player.Parent or fights[fight.player] then
			return
		end
		if reason == "Defeat" then
			-- Renvoyé au temple
			ColosseumService.SendToTemple(fight.player)
			return
		end
		-- Victoire ou arrêt : il remonte dans les gradins
		local stands = findSpot("Stands")
		local root = rootOf(fight.player)
		if stands and root then
			local character = root.Parent :: Model
			local look = Vector3.new(fight.center.X, stands.Position.Y + 3, fight.center.Z)
			character:PivotTo(CFrame.lookAt(stands.Position + Vector3.new(0, 3, 0), look))
		end
	end)
end

-- Lance le combat (pour l'instant seulement depuis Studio)
function PumpGodService.Begin(player: Player): boolean
	if fights[player] or MinigameService.IsBusy(player) then
		return false
	end
	local center, fighterSpot, bossSpot = findSpot("Center"), findSpot("Fighter"), findSpot("Boss")
	local root = rootOf(player)
	if not center or not fighterSpot or not bossSpot or not root then
		return false
	end
	tokens += 1
	local floor = center.Position.Y - center.Size.Y / 2
	local middle = Vector3.new(center.Position.X, floor, center.Position.Z)
	local bossStart = Vector3.new(bossSpot.Position.X, floor, bossSpot.Position.Z)
	local fight: Fight = {
		player = player,
		hp = PumpGod.Health,
		bossHp = PumpGod.BossHealth,
		token = tokens,
		startedAt = os.clock(),
		boss = nil,
		center = middle,
		floor = floor,
		invulnUntil = 0,
		rollReadyAt = 0,
		rollAt = -math.huge,
		airAt = -math.huge,
		nextId = 0,
		ended = false,
		bossFrom = bossStart,
		bossTo = bossStart,
		moveStart = 0,
		moveEnd = 0,
		windedUntil = 0,
		combo = 0,
		comboAt = -math.huge,
		javelins = {},
		discs = {},
		carrying = nil,
		sacred = nil,
		chargeEnds = nil,
	}
	fights[player] = fight
	ColosseumService.SetFighter(player, true)
	local character = root.Parent :: Model
	local look = Vector3.new(center.Position.X, fighterSpot.Position.Y + 3, center.Position.Z)
	local inward = flat(center.Position - fighterSpot.Position).Unit * PumpGod.FighterInset
	character:PivotTo(CFrame.lookAt(fighterSpot.Position + inward + Vector3.new(0, 3, 0), look))
	fight.boss = spawnBoss(bossSpot, middle)
	broadcast({
		state = "Start",
		player = player,
		boss = fight.boss,
		hp = fight.hp,
		maxHp = PumpGod.Health,
		bossHp = fight.bossHp,
		bossMaxHp = PumpGod.BossHealth,
		center = middle,
		bossAt = bossStart,
	})
	task.spawn(loop, fight, fight.token)
	task.spawn(sacredLoop, fight, fight.token)
	-- Mort (chute, reset) : le combat est perdu
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Once(function()
			finish(fight, "Defeat")
		end)
	end
	return true
end

function PumpGodService.Stop(player: Player)
	local fight = fights[player]
	if fight then
		finish(fight, "Stopped")
	end
end

function PumpGodService.IsFighting(player: Player): boolean
	return fights[player] ~= nil
end

local function onRoll(player: Player)
	local fight = fights[player]
	local t = os.clock()
	if not fight or fight.ended or t < fight.rollReadyAt then
		return
	end
	fight.rollReadyAt = t + PumpGod.Roll.Cooldown
	fight.rollAt = t
	fight.invulnUntil = math.max(fight.invulnUntil, t + PumpGod.Roll.Invuln + PumpGod.Latency)
	stopCharge(fight)
	broadcast({ state = "Roll", player = player })
end

function PumpGodService.Init(services)
	ColosseumService = services.ColosseumService
	DataService = services.DataService
	MinigameService = services.MinigameService
	StatsService = services.StatsService
end

function PumpGodService.Start()
	Remotes.PumpGodRoll.OnServerEvent:Connect(onRoll)
	Remotes.PumpGodFlex.OnServerEvent:Connect(onFlex)
	-- Sauts (dernier instant où les pieds étaient assez haut) et charge de la pose sacrée
	RunService.Heartbeat:Connect(function()
		for _, fight in fights do
			local root = rootOf(fight.player)
			if root and feetHeight(fight, root) >= PumpGod.JumpClear then
				fight.airAt = os.clock()
			end
			stepCharge(fight)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local fight = fights[player]
		if fight then
			finish(fight, "Left")
		end
	end)
end

return PumpGodService
