-- Combat du Dieu du Pump au Colisée (D89 à D92 : trois manches, finale, spectateurs).
-- Le serveur décide de tout : il tire les attaques, fixe l'heure exacte de chaque impact (heure du serveur,
-- workspace:GetServerTimeNow), juge si le joueur est touché d'après sa position, son saut et sa roulade, tient la vie
-- du joueur et celle du dieu, et décide ce que fait le bouton FLEX. Les clients (PumpGodController) dessinent tout à
-- partir des messages Remotes.PumpGodUpdate (envoyés à tous : les spectateurs voient le combat).
-- Attaques (Config/PumpGod.luau) : Bolts (cercles), Dumbbell (bande traversée par un haltère), Wave (anneau à sauter),
-- Slam (cône devant lui, puis il est essoufflé), Javelin (javelot d'éclair, à renvoyer) ; manche 2 : Columns (colonnes
-- qui tombent), Tiles (dalles par motifs), Chariot (char de shake), Leap (il retombe sur le joueur) ; manche 3, géant
-- au bord de la piste : Storm (toute la piste sauf des cercles sûrs), Rings (anneaux à sauter), Gaze (regard qui
-- balaie : se cacher derrière les colonnes).
-- Chaque manche a sa jauge de vie du dieu ; à zéro, transition (le jeton du combat change : les attaques en cours
-- s'arrêtent), puis manche suivante ; après la 3e, la finale « Suplex olympien » (D110, remplace le tir à la corde
-- de D104) : le dieu est à genoux devant le joueur ; FLEX le plus vite possible pour le soulever au-dessus de la tête
-- (il glisse si l'on ralentit), puis FLEX (glisser vers le haut) au sommet de la jauge de lancer pour l'envoyer au ciel,
-- où il devient une constellation. Raté : il retombe sur le joueur (dégâts), se relève, et on recommence plus vite.
-- Spectateurs (Remotes.PumpGodCheer) : leurs encouragements remplissent la jauge de la foule (envoyée à tous sauf au
-- combattant) ; à chaque palier, la foule agit (amphore de shake, pétales, chant).
-- FLEX (Remotes.PumpGodFlex, appuyé / relâché), par ordre de priorité : renvoyer le javelot qui arrive, frapper le dieu
-- essoufflé (combo de 3), lancer le disque porté ou en ramasser un, charger la pose sacrée dans le cercle doré.
-- Pour l'instant le combat se lance seulement dans Studio (DevCommands « PumpGod »).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local PumpGod = require(ReplicatedStorage.Shared.Config.PumpGod)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)

local SPOT_TAG = "ColosseumSpot"
local ATTACKS = PumpGod.Attacks
local ROUNDS = PumpGod.Rounds
local FINALE = PumpGod.Finale
local CROWD = PumpGod.Crowd
local PIT = Balance.Colosseum.PitRadius

local ColosseumService
local DataService
local MinigameService
local StatsService
local StatueService
local TutorialService

type Javelin = { from: Vector3, dir: Vector3, start: number, length: number, parried: boolean }
type Disc = { at: Vector3, born: number }
-- Finale (D110, suplex) : phase "Lift" (lift de 0 au sol à 1 au-dessus de la tête), "Aim" (jauge de lancer qui
-- oscille de aimStart à aimEnds, période period), "Fall" (raté : il retombe, jusqu'à fallUntil), "Throw" (lancé) ;
-- attempt : essais ratés (chaque essai est plus rapide)
type Finale = {
	phase: string,
	lift: number,
	beatStart: number,
	sentAt: number,
	calmUntil: number,
	taps: { number },
	base: CFrame,
	attempt: number,
	aimStart: number,
	aimEnds: number,
	period: number,
	window: number,
	fallUntil: number,
}

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
	round: number,
	phase: string, -- "Round" (on se bat), "Transition" (entre deux manches), "Finale"
	giant: number, -- taille du dieu (1, ou Rounds[3].Giant)
	pillars: { Vector3 }, -- colonnes de la manche 3 (cachettes contre le regard)
	pillarFolder: Folder?,
	finale: Finale?,
	moveSaved: { walk: number, jump: number }?,
	-- Foule
	cheers: { [Player]: { count: number, at: number } },
	gauge: number,
	actions: number,
	slow: number, -- secondes de plus avant la prochaine attaque (pétales)
	chant: boolean, -- le prochain renvoi se fait de plus loin
	amphora: { id: number, at: Vector3, ends: number }?,
}

local fights: { [Player]: Fight } = {}
local tokens = 0
-- Une seule piste : réservée pendant le voyage du challenger, libre un peu après la fin du combat précédent
local arenaHeldBy: Player? = nil
local arenaFreeAt = 0

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

local nextRound

local function hurtBoss(fight: Fight, kind: string, damage: number)
	if fight.ended or fight.phase ~= "Round" then
		return
	end
	fight.bossHp = math.max(fight.bossHp - damage, 0)
	broadcast({
		state = "BossHit",
		player = fight.player,
		kind = kind,
		hp = fight.bossHp,
		maxHp = ROUNDS[fight.round].BossHealth,
		damage = damage,
	})
	if fight.bossHp <= 0 then
		nextRound(fight, fight.round + 1)
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

-- Essoufflé : il tombe à genoux, le joueur peut le frapper
local function wind(fight: Fight, token: number)
	if not alive(fight, token) then
		return
	end
	local winded = PumpGod.Winded.Time
	fight.windedUntil = now() + winded
	fight.combo = 0
	broadcast({ state = "Winded", player = fight.player, start = now(), ends = fight.windedUntil })
	task.wait(winded)
end

-- Distance (à plat) entre un point et le segment [a, b]
local function segmentDistance(p: Vector3, a: Vector3, b: Vector3): number
	local ab = flat(b - a)
	local ap = flat(p - a)
	local k = math.clamp(ap:Dot(ab) / math.max(ab:Dot(ab), 1e-3), 0, 1)
	return (ap - ab * k).Magnitude
end

-- Une colonne cache-t-elle le joueur (en `to`) au regard qui part de `from` ?
local function hidden(fight: Fight, from: Vector3, to: Vector3): boolean
	local ab = flat(to - from)
	for _, pillar in fight.pillars do
		local ap = flat(pillar - from)
		local k = ap:Dot(ab) / math.max(ab:Dot(ab), 1e-3)
		if k > 0 and k < 1 and (ap - ab * k).Magnitude < PumpGod.Pillars.Radius + 0.3 then
			return true
		end
	end
	return false
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

-- Un objet qui traverse la piste en passant par le joueur (haltère qui roule : à sauter ; char de shake : trop haut)
local function lane(fight: Fight, token: number, kind: string, spec, jumpable: boolean, size: number)
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
		kind = kind,
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
	watch(fight, token, roll, done, kind, spec.Damage, jumpable, function(t, r: BasePart)
		local offset = flat(r.Position - a)
		local s = (t - roll) * spec.Speed
		local d = offset:Dot(unit)
		local lateral = (offset - unit * d).Magnitude
		return math.abs(d - s) < size
			and lateral < spec.Width / 2
			and (not jumpable or feetHeight(fight, r) < PumpGod.JumpClear + spec.Height * 0.4)
	end)
	task.wait(done - now() + 0.3)
	-- En cognant le mur, il perd un disque
	if alive(fight, token) then
		dropDisc(fight, b - unit * 4)
	end
end

local function dumbbell(fight: Fight, token: number)
	lane(fight, token, "Dumbbell", ATTACKS.Dumbbell, true, ATTACKS.Dumbbell.Height * 0.6)
end

local function chariot(fight: Fight, token: number)
	lane(fight, token, "Chariot", ATTACKS.Chariot, false, ATTACKS.Chariot.Height * 0.75)
end

-- Un anneau qui part du dieu à l'heure `go` ; renvoie l'heure où il atteint le mur
local function ring(fight: Fight, token: number, spec, start: number, go: number): number
	local origin = bossAt(fight, now())
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
	return done
end

local function wave(fight: Fight, token: number)
	local spec = ATTACKS.Wave
	local start = now()
	local done = ring(fight, token, spec, start, start + spec.Warn)
	task.wait(done - now() + 0.2)
end

-- Anneaux du géant : plusieurs, l'un après l'autre
local function rings(fight: Fight, token: number)
	local spec = ATTACKS.Rings
	local start = now()
	local done = start
	for k = 1, spec.Count do
		done = ring(fight, token, spec, start, start + spec.Warn + (k - 1) * spec.Gap)
	end
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
	wind(fight, token)
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

-- Colonnes qui tombent du bord de la piste vers le joueur
local function columns(fight: Fight, token: number)
	local spec = ATTACKS.Columns
	local last = now()
	local lastEnd = nil
	for k = 1, spec.Count do
		local root = rootOf(fight.player)
		if not root or not alive(fight, token) then
			return
		end
		local toward = flat(root.Position - fight.center)
		local base = if toward.Magnitude > 1 then math.atan2(toward.Z, toward.X) else math.random() * 2 * math.pi
		local angle = base + (math.random() - 0.5) * math.rad(150)
		local a = onFloor(fight, fight.center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (PIT - 1))
		local dir = flat(root.Position - a)
		dir = if dir.Magnitude > 1 then dir.Unit else flat(fight.center - a).Unit
		local b = onFloor(fight, inPit(fight, a + dir * spec.Length, PIT - 1))
		local start = now()
		local impact = start + spec.Warn
		broadcast({
			state = "Attack",
			player = fight.player,
			kind = "Column",
			id = newId(fight),
			a = a,
			b = b,
			width = spec.Width,
			start = start,
			impact = impact,
		})
		watch(fight, token, impact, impact + 0.05, "Column", spec.Damage, false, function(_, r: BasePart)
			return segmentDistance(r.Position, a, b) < spec.Width / 2
		end)
		last = impact
		lastEnd = b
		if k < spec.Count then
			task.wait(spec.Gap)
		end
	end
	task.wait(math.max(last - now(), 0) + 0.4)
	-- La dernière se brise : un disque roule de ses débris
	if lastEnd and alive(fight, token) then
		dropDisc(fight, lastEnd)
	end
end

-- Motifs des dalles de mosaïque (case i, j) : damier, bandes, bandes en travers, anneaux
local PATTERNS = {
	function(i: number, j: number): boolean
		return (i + j) % 2 == 0
	end,
	function(i: number, _j: number): boolean
		return i % 2 == 0
	end,
	function(_i: number, j: number): boolean
		return j % 2 == 0
	end,
	function(i: number, j: number): boolean
		return math.floor(math.sqrt((i + 0.5) ^ 2 + (j + 0.5) ^ 2)) % 2 == 0
	end,
}

-- Dalles : un motif s'allume puis jaillit, puis le motif inverse (il faut changer de case)
local function tiles(fight: Fight, token: number)
	local spec = ATTACKS.Tiles
	local cell = spec.Cell
	local n = math.ceil(PIT / cell)
	local pattern = PATTERNS[math.random(#PATTERNS)]
	local flip = math.random() < 0.5
	local start = now()
	for round = 1, 2 do
		if not alive(fight, token) then
			return
		end
		local danger: { [string]: boolean } = {}
		local cells = {}
		for i = -n, n - 1 do
			for j = -n, n - 1 do
				local at = fight.center + Vector3.new((i + 0.5) * cell, 0, (j + 0.5) * cell)
				local lit = pattern(i, j) ~= flip
				if flat(at - fight.center).Magnitude < PIT + cell * 0.2 and lit == (round == 1) then
					danger[i .. "," .. j] = true
					table.insert(cells, onFloor(fight, at))
				end
			end
		end
		local impact = start + spec.Warn
		broadcast({
			state = "Attack",
			player = fight.player,
			kind = "Tiles",
			id = newId(fight),
			cells = cells,
			cell = cell,
			start = start,
			impact = impact,
		})
		watch(fight, token, impact, impact + 0.05, "Tiles", spec.Damage, false, function(_, r: BasePart)
			local offset = r.Position - fight.center
			return danger[math.floor(offset.X / cell) .. "," .. math.floor(offset.Z / cell)] == true
		end)
		task.wait(math.max(impact - now(), 0) + spec.Gap)
		start = now()
	end
end

-- Il saute ; un grand cercle suit le joueur, se fige, et il retombe dessus ; puis il est essoufflé
local function leap(fight: Fight, token: number)
	local spec = ATTACKS.Leap
	local start = now()
	local lock = start + spec.Rise + spec.Follow
	local impact = lock + spec.Fall
	local id = newId(fight)
	broadcast({
		state = "Attack",
		player = fight.player,
		kind = "Leap",
		id = id,
		at = bossAt(fight, start),
		radius = spec.Radius,
		rise = start + spec.Rise,
		lock = lock,
		start = start,
		impact = impact,
	})
	task.wait(math.max(lock - now(), 0))
	local root = rootOf(fight.player)
	if not root or not alive(fight, token) then
		return
	end
	local target = onFloor(fight, inPit(fight, root.Position, PIT - 3))
	fight.bossFrom = bossAt(fight, now())
	fight.bossTo = target
	fight.moveStart = lock
	fight.moveEnd = impact
	broadcast({ state = "LeapLock", player = fight.player, id = id, at = target, lock = lock, impact = impact })
	watch(fight, token, impact, impact + 0.05, "Leap", spec.Damage, false, function(_, r: BasePart)
		return flat(r.Position - target).Magnitude < spec.Radius
	end)
	task.wait(math.max(impact - now(), 0) + 0.15)
	wind(fight, token)
end

-- Cercles sûrs de l'orage : le premier à quelques pas du joueur, les autres ailleurs, bien séparés
local function safeSpots(fight: Fight, root: BasePart, spec): { Vector3 }
	local angle = math.random() * 2 * math.pi
	local first = root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (6 + math.random() * 6)
	local safes = { onFloor(fight, inPit(fight, first, PIT - spec.SafeRadius - 1)) }
	for _ = 2, spec.Safe do
		local spot = fight.center
		for _ = 1, 12 do
			local a = math.random() * 2 * math.pi
			spot = fight.center + Vector3.new(math.cos(a), 0, math.sin(a)) * (math.random() * (PIT - 10))
			local apart = true
			for _, other in safes do
				if flat(spot - other).Magnitude < spec.SafeRadius * 3 then
					apart = false
				end
			end
			if apart then
				break
			end
		end
		table.insert(safes, onFloor(fight, spot))
	end
	return safes
end

-- Orage : toute la piste s'allume sauf quelques cercles sûrs ; un disque tombe ensuite dans l'un d'eux
local function storm(fight: Fight, token: number)
	local spec = ATTACKS.Storm
	local safes = {}
	for _ = 1, spec.Count do
		local root = rootOf(fight.player)
		if not root or not alive(fight, token) then
			return
		end
		local spots = safeSpots(fight, root, spec)
		safes = spots
		local start = now()
		local impact = start + spec.Warn
		broadcast({
			state = "Attack",
			player = fight.player,
			kind = "Storm",
			id = newId(fight),
			at = fight.center,
			radius = PIT,
			safes = spots,
			safeRadius = spec.SafeRadius,
			start = start,
			impact = impact,
		})
		watch(fight, token, impact, impact + 0.05, "Storm", spec.Damage, false, function(_, r: BasePart)
			for _, safe in spots do
				if flat(r.Position - safe).Magnitude < spec.SafeRadius then
					return false
				end
			end
			return true
		end)
		task.wait(math.max(impact - now(), 0) + spec.Gap)
	end
	if alive(fight, token) and #safes > 0 then
		dropDisc(fight, safes[math.random(#safes)])
	end
end

-- Regard brûlant : un rayon balaie la piste depuis le géant ; les colonnes cachent le joueur
local function gaze(fight: Fight, token: number)
	local spec = ATTACKS.Gaze
	local origin = bossAt(fight, now())
	local inward = flat(fight.center - origin)
	local base = math.atan2(inward.Z, inward.X)
	local half = math.rad(spec.Angle) / 2
	local sign = if math.random() < 0.5 then 1 else -1
	local from, to = base - half * sign, base + half * sign
	local start = now()
	local go = start + spec.Warn
	local ends = go + spec.Sweep
	local length = PIT * 2 + 4
	broadcast({
		state = "Attack",
		player = fight.player,
		kind = "Gaze",
		id = newId(fight),
		at = origin,
		from = from,
		to = to,
		width = spec.Width,
		length = length,
		start = start,
		impact = go,
		ends = ends,
	})
	watch(fight, token, go, ends, "Gaze", spec.Damage, false, function(t, r: BasePart)
		local a = from + (to - from) * math.clamp((t - go) / spec.Sweep, 0, 1)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local offset = flat(r.Position - origin)
		local along = offset:Dot(dir)
		return along > 0
			and along < length
			and (offset - dir * along).Magnitude < spec.Width / 2
			and not hidden(fight, origin, r.Position)
	end)
	task.wait(math.max(ends - now(), 0) + 0.2)
	-- Il se frotte les yeux : le moment de le frapper
	wind(fight, token)
end

local RUN = {
	Bolts = bolts,
	Dumbbell = dumbbell,
	Wave = wave,
	Slam = slam,
	Javelin = javelin,
	Columns = columns,
	Tiles = tiles,
	Chariot = chariot,
	Leap = leap,
	Storm = storm,
	Rings = rings,
	Gaze = gaze,
}

-- Tirage d'une attaque de la manche (nom = poids), jamais deux fois la même de suite
local function pick(weights: { [string]: number }, previous: string?): string
	local total = 0
	for name, weight in weights do
		if name ~= previous then
			total += weight
		end
	end
	local roll = math.random() * total
	local fallback = "Bolts"
	for name, weight in weights do
		if name ~= previous then
			fallback = name
			roll -= weight
			if roll <= 0 then
				return name
			end
		end
	end
	return fallback
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
		if fight.sacred and fight.sacred.id == id and not fight.ended then
			fight.sacred = nil
			fight.chargeEnds = nil
			broadcast({ state = "SacredGone", player = fight.player, id = id })
		end
		task.wait(spec.Every - spec.Life)
	end
end

local function loop(fight: Fight, token: number, intro: number)
	task.wait(intro) -- le dieu se présente
	local spec = ROUNDS[fight.round]
	local previous = nil
	local opening = table.clone(spec.Opening)
	while alive(fight, token) do
		local name = table.remove(opening, 1) or pick(spec.Attacks, previous)
		previous = name
		RUN[name](fight, token)
		if not alive(fight, token) then
			return
		end
		local p = spec.Pause
		local k = math.clamp((os.clock() - fight.startedAt) / p.Over, 0, 1)
		-- Les pétales de la foule le font attendre un peu plus
		local pause = p.From + (p.To - p.From) * k + fight.slow
		fight.slow = 0
		if fight.giant == 1 then
			-- Il change de place pendant la pause
			if not moveBoss(fight, token, orbitSpot(fight), math.min(PumpGod.Orbit.MoveTime, pause)) then
				return
			end
			task.wait(math.max(pause - PumpGod.Orbit.MoveTime, 0.2))
		else
			-- Géant : il reste au bord de la piste
			task.wait(pause)
		end
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
			-- Le chant de la foule rend le prochain renvoi plus facile
			local range = PumpGod.Parry.Range * (if fight.chant then CROWD.ChantRange else 1)
			if s < shot.length and ahead > -2 and flat(root.Position - tip).Magnitude < range then
				shot.parried = true
				if fight.chant then
					fight.chant = false
					broadcast({ state = "ChantUsed", player = fight.player })
				end
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
	local reach = if fight.giant > 1 then PumpGod.Winded.GiantRange else PumpGod.Winded.Range
	if t < fight.windedUntil and flat(root.Position - bossAt(fight, t)).Magnitude < reach then
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

-- Finale (D110) : jauge de lancer à l'instant t (0 en bas, 1 au sommet), la même que celle dessinée par les clients
local function aimMeter(finale: Finale, t: number): number
	return 0.5 - 0.5 * math.cos((t - finale.aimStart) / finale.period * 2 * math.pi)
end

local function broadcastSuplex(fight: Fight, finale: Finale)
	broadcast({
		state = "Suplex",
		player = fight.player,
		phase = finale.phase,
		lift = finale.lift,
		attempt = finale.attempt,
		aimStart = finale.aimStart,
		aimEnds = finale.aimEnds,
		period = finale.period,
		window = finale.window,
		fallUntil = finale.fallUntil,
	})
end

-- Raté (lancer hors du sommet, ou trop tard) : il retombe sur le joueur, se relève, et l'essai suivant va plus vite
local function suplexMiss(fight: Fight, finale: Finale)
	finale.phase = "Fall"
	finale.lift = 0
	finale.attempt += 1
	finale.fallUntil = now() + FINALE.FallTime
	broadcastSuplex(fight, finale)
	fight.invulnUntil = 0
	hit(fight, "Suplex", FINALE.Aim.MissDamage)
	task.delay(FINALE.FallTime, function()
		if fight.finale == finale and not fight.ended then
			finale.phase = "Lift"
			finale.taps = {}
			broadcastSuplex(fight, finale)
		end
	end)
end

-- Appui sur FLEX pendant la finale : soulever (le plus vite possible, au plus MaxRate appuis comptés par seconde,
-- contre l'autoclic), puis lancer au sommet de la jauge
local function finaleFlex(fight: Fight, finale: Finale)
	local t = now()
	if t < finale.beatStart then
		return
	end
	if finale.phase == "Lift" then
		local taps = finale.taps
		while taps[1] and t - taps[1] > 1 do
			table.remove(taps, 1)
		end
		if #taps >= FINALE.MaxRate then
			return
		end
		table.insert(taps, t)
		finale.lift = math.min(finale.lift + FINALE.Push, 1)
		broadcast({ state = "Pulse", player = fight.player, good = true, k = finale.lift })
		if finale.lift >= 1 then
			-- Au-dessus de la tête : la jauge de lancer démarre (plus rapide et plus étroite à chaque essai raté)
			local AIM = FINALE.Aim
			finale.phase = "Aim"
			finale.aimStart = t
			finale.aimEnds = t + AIM.Time
			finale.period = AIM.Period / (1 + AIM.Faster * finale.attempt)
			finale.window = math.max(AIM.Window - AIM.WindowShrink * finale.attempt, AIM.WindowMin)
			broadcastSuplex(fight, finale)
		end
	elseif finale.phase == "Aim" then
		-- Les appuis de la fin du soulevé (mitraillage) ne lancent pas par erreur
		if t - finale.aimStart < FINALE.Aim.Grace then
			return
		end
		-- Jugé un peu avant la réception : le temps que le geste du joueur arrive (même marge que les attaques)
		if aimMeter(finale, t - PumpGod.Latency) >= 1 - finale.window then
			finale.phase = "Throw"
			broadcastSuplex(fight, finale)
			task.delay(FINALE.ThrowTime, function()
				if fight.finale == finale then
					finish(fight, "Victory")
				end
			end)
		else
			suplexMiss(fight, finale)
		end
	end
end

local function onFlex(player: Player, down: unknown)
	local fight = fights[player]
	local root = rootOf(player)
	if not fight or fight.ended or not root or typeof(down) ~= "boolean" then
		return
	end
	if fight.finale then
		if down then
			finaleFlex(fight, fight.finale)
		end
	elseif fight.phase ~= "Round" then
		return
	elseif down then
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

-- Finale : le dieu glisse des mains si l'on ralentit (plus vite à chaque essai, sauf pendant les pétales de la
-- foule) ; trop tard pour lancer = raté
local function stepFinale(fight: Fight, dt: number)
	local finale = fight.finale
	local t = now()
	if not finale or fight.ended or t < finale.beatStart then
		return
	end
	if finale.phase == "Lift" and t >= finale.calmUntil and finale.lift > 0 then
		finale.lift = math.max(finale.lift - (FINALE.Drift + FINALE.DriftPerAttempt * finale.attempt) * dt, 0)
	elseif finale.phase == "Aim" and t >= finale.aimEnds then
		suplexMiss(fight, finale)
		return
	end
	if finale.phase == "Lift" and t - finale.sentAt > 0.15 then
		finale.sentAt = t
		broadcast({ state = "Clash", player = fight.player, k = finale.lift })
	end
end

-- ------------------------------------------------------------------ foule
local function sendCrowd(fight: Fight)
	for _, other in Players:GetPlayers() do
		-- Jamais au combattant : il ne voit pas la jauge
		if other ~= fight.player then
			local mine = fight.cheers[other]
			Remotes.PumpGodUpdate:FireClient(other, {
				state = "Crowd",
				player = fight.player,
				gauge = fight.gauge % CROWD.Step,
				step = CROWD.Step,
				left = CROWD.Max - (if mine then mine.count else 0),
			})
		end
	end
end

local function crowdAction(fight: Fight)
	fight.actions += 1
	local action = CROWD.Actions[(fight.actions - 1) % #CROWD.Actions + 1]
	if action == "Amphora" then
		-- Une amphore de shake lancée près du combattant (à ses pieds pendant la finale : il ne bouge plus)
		local root = rootOf(fight.player)
		if not root then
			return
		end
		local angle = math.random() * 2 * math.pi
		local distance = if fight.finale then 0 else 5 + math.random() * 5
		local spot = root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
		local id = newId(fight)
		local ends = now() + CROWD.AmphoraLife
		fight.amphora = { id = id, at = onFloor(fight, inPit(fight, spot, PIT - 3)), ends = ends }
		broadcast({ state = "Amphora", player = fight.player, id = id, at = fight.amphora.at, ends = ends })
	elseif action == "Petals" then
		fight.slow += CROWD.Slow
		if fight.finale then
			fight.finale.calmUntil = now() + CROWD.Slow
		end
		broadcast({ state = "Petals", player = fight.player, ends = now() + CROWD.Slow })
	else
		fight.chant = true
		broadcast({ state = "Chant", player = fight.player })
	end
end

local function addCheers(fight: Fight, count: number)
	for _ = 1, count do
		fight.gauge += 1
		if fight.gauge % CROWD.Step == 0 then
			crowdAction(fight)
		end
	end
	sendCrowd(fight)
end

local function onCheer(player: Player)
	local root = rootOf(player)
	if fights[player] or not root then
		return
	end
	for _, fight in fights do
		if not fight.ended and flat(root.Position - fight.center).Magnitude < CROWD.Range then
			local mine = fight.cheers[player] or { count = 0, at = -math.huge }
			fight.cheers[player] = mine
			local t = os.clock()
			if mine.count >= CROWD.Max or t - mine.at < CROWD.MinGap then
				return
			end
			mine.count += 1
			mine.at = t
			addCheers(fight, 1)
			return
		end
	end
end

-- Amphore : ramassée en marchant dessus (rend de la vie), sinon elle disparaît
local function stepAmphora(fight: Fight)
	local amphora = fight.amphora
	if not amphora then
		return
	end
	local root = rootOf(fight.player)
	if now() > amphora.ends then
		fight.amphora = nil
		broadcast({ state = "AmphoraGone", player = fight.player, id = amphora.id })
	elseif root and flat(root.Position - amphora.at).Magnitude < CROWD.AmphoraPick then
		fight.amphora = nil
		local before = fight.hp
		fight.hp = math.min(fight.hp + CROWD.Heal, PumpGod.Health)
		broadcast({
			state = "Heal",
			player = fight.player,
			id = amphora.id,
			hp = fight.hp,
			amount = fight.hp - before,
		})
	end
end

-- ------------------------------------------------------------------ début, manches et fin
-- Le dieu posé sur la piste en `ground`, tourné vers le centre ; scale : taille (géant en manche 3)
local function spawnBoss(ground: Vector3, center: Vector3, scale: number): Model?
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
	if PumpGod.BossScale * scale ~= 1 then
		model:ScaleTo(model:GetScale() * PumpGod.BossScale * scale)
	end
	local body = model.PrimaryPart :: BasePart
	local look = Vector3.new(center.X, ground.Y, center.Z)
	if flat(look - ground).Magnitude < 0.5 then
		look = ground + Vector3.new(0, 0, -1)
	end
	local pivotFromBody = body.CFrame:ToObjectSpace(model:GetPivot())
	model:PivotTo(CFrame.lookAt(ground, look) * pivotFromBody)
	local lift = ground.Y + body.Size.Y / 2 + PumpGod.BossHover * scale - body.Position.Y
	model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
	model.Parent = workspace
	return model
end

-- Colonnes de la manche 3 : elles sortent du sol de la piste (de vraies colonnes, on se cache derrière)
local function raisePillars(fight: Fight)
	local spec = PumpGod.Pillars
	local folder = Instance.new("Folder")
	folder.Name = "ColosseumPillars"
	folder.Parent = workspace
	fight.pillarFolder = folder
	local offset = math.random() * 2 * math.pi
	for k = 1, spec.Count do
		local angle = offset + 2 * math.pi * k / spec.Count
		local at = fight.center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * spec.Distance
		table.insert(fight.pillars, at)
		local pillar = Instance.new("Part")
		pillar.Name = "Pillar"
		pillar.Shape = Enum.PartType.Cylinder
		pillar.Anchored = true
		pillar.Material = Enum.Material.Marble
		pillar.Color = Color3.fromRGB(236, 230, 218)
		pillar.Size = Vector3.new(spec.Height, spec.Radius * 2, spec.Radius * 2)
		local up = CFrame.new(at + Vector3.new(0, spec.Height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		pillar.CFrame = up - Vector3.new(0, spec.Height + 0.5, 0)
		pillar.Parent = folder
		local capital = Instance.new("Part")
		capital.Name = "Capital"
		capital.Anchored = true
		capital.Material = Enum.Material.SmoothPlastic
		capital.Color = Color3.fromRGB(255, 205, 80)
		capital.Size = Vector3.new(spec.Radius * 2.6, 1.2, spec.Radius * 2.6)
		local top = CFrame.new(at + Vector3.new(0, spec.Height + 0.6, 0))
		capital.CFrame = top - Vector3.new(0, spec.Height + 2, 0)
		capital.Parent = folder
		local info = TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(pillar, info, { CFrame = up }):Play()
		TweenService:Create(capital, info, { CFrame = top }):Play()
	end
end

local function clearField(fight: Fight)
	table.clear(fight.javelins)
	table.clear(fight.discs)
	fight.carrying = nil
	fight.sacred = nil
	fight.chargeEnds = nil
	fight.windedUntil = 0
	fight.combo = 0
	fight.amphora = nil
end

-- Finale (D110) : le dieu tombe à genoux devant le joueur (taille normale, même après la manche du géant) ; le joueur
-- ne bouge plus
local function startFinale(fight: Fight)
	tokens += 1
	fight.token = tokens
	fight.phase = "Finale"
	clearField(fight)
	local t = now()
	local root = rootOf(fight.player)
	local boss = bossAt(fight, t)
	local base = if root
		then CFrame.lookAt(root.Position, Vector3.new(boss.X, root.Position.Y, boss.Z))
		else CFrame.new(fight.center)
	-- Le dieu à genoux, à quelques pas devant lui
	local ground = onFloor(fight, (base * CFrame.new(0, 0, -FINALE.Distance)).Position)
	if fight.boss then
		fight.boss:Destroy()
	end
	fight.boss = spawnBoss(ground, base.Position, 1)
	fight.giant = 1
	fight.bossFrom, fight.bossTo, fight.moveStart, fight.moveEnd = ground, ground, 0, 0
	if fight.pillarFolder then
		fight.pillarFolder:Destroy()
		fight.pillarFolder = nil
	end
	fight.finale = {
		phase = "Lift",
		lift = 0,
		beatStart = t + FINALE.Intro,
		sentAt = 0,
		calmUntil = 0,
		taps = {},
		base = base,
		attempt = 0,
		aimStart = 0,
		aimEnds = 0,
		period = FINALE.Aim.Period,
		window = FINALE.Aim.Window,
		fallUntil = 0,
	}
	if root then
		local character = root.Parent :: Model
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			fight.moveSaved = { walk = humanoid.WalkSpeed, jump = humanoid.JumpHeight }
			humanoid.WalkSpeed = 0
			humanoid.JumpHeight = 0
		end
		character:PivotTo(base)
	end
	broadcast({
		state = "Finale",
		player = fight.player,
		start = t,
		beatStart = fight.finale.beatStart,
		k = 0,
		base = base,
		boss = fight.boss,
		bossAt = ground,
	})
end

-- Manche suivante (ou la finale après la dernière) : le jeton change (les attaques en cours s'arrêtent), le terrain se
-- vide, le joueur récupère un peu de vie, le dieu se replace (géant au bord de la piste en manche 3)
function nextRound(fight: Fight, index: number)
	if fight.ended then
		return
	end
	if index > #ROUNDS then
		startFinale(fight)
		return
	end
	tokens += 1
	fight.token = tokens
	local token = tokens
	fight.phase = "Transition"
	clearField(fight)
	local spec = ROUNDS[index]
	fight.round = index
	fight.bossHp = spec.BossHealth
	fight.hp = math.min(fight.hp + spec.Heal, PumpGod.Health)
	local t = now()
	local ground = bossAt(fight, t)
	local giant = spec.Giant or 1
	if giant > 1 then
		-- Au bord de la piste, en face du joueur
		local root = rootOf(fight.player)
		local away = if root then flat(fight.center - root.Position) else Vector3.zero
		away = if away.Magnitude > 1 then away.Unit else Vector3.new(1, 0, 0)
		ground = onFloor(fight, fight.center + away * (PIT - (spec.Edge or 0)))
	end
	if giant ~= fight.giant or not fight.boss then
		if fight.boss then
			fight.boss:Destroy()
		end
		fight.boss = spawnBoss(ground, fight.center, giant)
		fight.giant = giant
	end
	fight.bossFrom, fight.bossTo, fight.moveStart, fight.moveEnd = ground, ground, 0, 0
	if giant > 1 and not fight.pillarFolder then
		raisePillars(fight)
	end
	broadcast({
		state = "Round",
		player = fight.player,
		round = index,
		title = spec.Title,
		hp = fight.hp,
		maxHp = PumpGod.Health,
		bossHp = fight.bossHp,
		bossMaxHp = spec.BossHealth,
		boss = fight.boss,
		bossAt = ground,
		start = t,
		go = t + PumpGod.Transition,
	})
	task.delay(PumpGod.Transition, function()
		if alive(fight, token) then
			fight.phase = "Round"
			fight.startedAt = os.clock()
			task.spawn(loop, fight, token, 0.3)
			task.spawn(sacredLoop, fight, token)
		end
	end)
end

-- ------------------------------------------------------------------ récompense (D93)
-- Couronne de laurier dorée des vainqueurs : des feuilles soudées autour de la tête (la coque visible du corps de
-- stade si elle existe, sinon la tête Roblox)
local function visibleHead(character: Model): BasePart?
	local best: BasePart? = nil
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part.Name == "Head" and part.Transparency < 1 then
			if not best or part.Size.Magnitude > best.Size.Magnitude then
				best = part
			end
		end
	end
	local fallback = character:FindFirstChild("Head")
	return best or (if fallback and fallback:IsA("BasePart") then fallback else nil)
end

local function crown(player: Player)
	local data = DataService.Get(player)
	local character = player.Character
	if not data or (data.PumpGodWins or 0) <= 0 or not character then
		return
	end
	-- Mesurée sur la tête visible, soudée à la tête Roblox (la coque du corps est refaite au changement de stade)
	local head = visibleHead(character)
	local anchor = character:FindFirstChild("Head")
	if not head or not anchor or not anchor:IsA("BasePart") then
		return
	end
	local old = character:FindFirstChild("GodLaurel")
	if old then
		old:Destroy()
	end
	local spec = PumpGod.Laurel
	local laurel = Instance.new("Model")
	laurel.Name = "GodLaurel"
	local size = head.Size
	local radius = math.max(size.X, size.Z) * spec.Radius
	local leaf = Vector3.new(size.X * spec.LeafWidth, size.Y * spec.LeafHeight, size.X * spec.LeafWidth * 0.35)
	local center = head.CFrame * CFrame.new(0, size.Y * spec.Height, 0)
	for k = 1, spec.Leaves do
		-- Deux branches qui partent de l'arrière et se rejoignent presque devant le front
		local side = if k % 2 == 0 then 1 else -1
		local step = math.ceil(k / 2) - 1
		local angle = math.pi - side * (math.rad(spec.Gap) + step * math.rad(360 - 2 * spec.Gap) / spec.Leaves)
		local part = Instance.new("Part")
		part.Name = "Leaf"
		part.Size = leaf
		part.Shape = Enum.PartType.Ball
		part.Material = Enum.Material.Foil
		part.Color = spec.Color
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = false
		local around = CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius)
		part.CFrame = center * around * CFrame.Angles(0, 0, side * math.rad(spec.Tilt))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = anchor
		weld.Part1 = part
		weld.Parent = part
		part.Parent = laurel
	end
	laurel.Parent = character
end

-- Victoire : chaque victoire compte (titre GOD MOGGER, laurier, statue dorée au Panthéon) ; la première, quand il
-- est bien au stade du Dieu du Pump, le fait passer au stade GOD MOGGER avec le Cash du boss (comme BossService)
local function reward(player: Player): { [string]: any }
	local data = DataService.Get(player)
	if not data then
		return {}
	end
	data.PumpGodWins = (data.PumpGodWins or 0) + 1
	local result: { [string]: any } = { wins = data.PumpGodWins }
	local stageIndex, boss = nil, nil
	for index, stage in Stages.List do
		if stage.boss and stage.boss.id == "PumpGod" then
			stageIndex, boss = index, stage.boss
		end
	end
	if boss and stageIndex and data.BossesBeaten.PumpGod ~= true and data.Stage == stageIndex then
		data.BossesBeaten.PumpGod = true
		data.Stage = stageIndex + 1
		data.Cash += boss.firstWinCash
		result.firstWin = true
		result.cash = boss.firstWinCash
		result.stageId = Stages.List[data.Stage].id
	end
	StatsService.Refresh(player)
	StatueService.Refresh()
	task.delay(PumpGod.EndDelay + 1, crown, player)
	if result.firstWin then
		TutorialService.OnEvent(player, "BossBeaten", "PumpGod")
		TutorialService.OnEvent(player, "StageUp", data.Stage)
	end
	return result
end

function finish(fight: Fight, reason: string)
	if fight.ended then
		return
	end
	fight.ended = true
	fights[fight.player] = nil
	arenaFreeAt = os.clock() + PumpGod.EndDelay + 1
	ColosseumService.SetFighter(fight.player, false)
	-- Il peut de nouveau bouger (finale)
	local root = rootOf(fight.player)
	local humanoid = root and (root.Parent :: Model):FindFirstChildOfClass("Humanoid")
	if fight.moveSaved and humanoid then
		humanoid.WalkSpeed = fight.moveSaved.walk
		humanoid.JumpHeight = fight.moveSaved.jump
	end
	if fight.pillarFolder then
		fight.pillarFolder:Destroy()
	end
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
	local prize = if reason == "Victory" then reward(fight.player) else nil
	broadcast({ state = "End", player = fight.player, reason = reason, mogLost = mogLost, reward = prize })
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
		local back = rootOf(fight.player)
		if stands and back then
			local character = back.Parent :: Model
			local look = Vector3.new(fight.center.X, stands.Position.Y + 3, fight.center.Z)
			character:PivotTo(CFrame.lookAt(stands.Position + Vector3.new(0, 3, 0), look))
		end
	end)
end

local function startMessage(fight: Fight)
	return {
		state = "Start",
		player = fight.player,
		boss = fight.boss,
		hp = fight.hp,
		maxHp = PumpGod.Health,
		bossHp = fight.bossHp,
		bossMaxHp = ROUNDS[math.min(fight.round, #ROUNDS)].BossHealth,
		center = fight.center,
		bossAt = bossAt(fight, now()),
	}
end

-- Arrivé sur le serveur pendant un combat : il le voit comme spectateur (et peut encourager)
local function syncTo(player: Player)
	for _, fight in fights do
		if not fight.ended then
			Remotes.PumpGodUpdate:FireClient(player, startMessage(fight))
			sendCrowd(fight)
		end
	end
end

-- La piste est-elle libre pour ce joueur ? (aucun combat, pas réservée par un autre, le dieu précédent est parti)
local function arenaFree(player: Player): boolean
	for _, fight in fights do
		if not fight.ended then
			return false
		end
	end
	if arenaHeldBy and arenaHeldBy ~= player and arenaHeldBy.Parent then
		return false
	end
	return os.clock() >= arenaFreeAt
end

-- Lance le combat (défi accepté au temple, ou DevCommands dans Studio)
function PumpGodService.Begin(player: Player): boolean
	if fights[player] or MinigameService.IsBusy(player) or not arenaFree(player) then
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
	local first = ROUNDS[1]
	local fight: Fight = {
		player = player,
		hp = PumpGod.Health,
		bossHp = first.BossHealth,
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
		round = 1,
		phase = "Round",
		giant = 1,
		pillars = {},
		pillarFolder = nil,
		finale = nil,
		moveSaved = nil,
		cheers = {},
		gauge = 0,
		actions = 0,
		slow = 0,
		chant = false,
		amphora = nil,
	}
	fights[player] = fight
	ColosseumService.SetFighter(player, true)
	local character = root.Parent :: Model
	local look = Vector3.new(center.Position.X, fighterSpot.Position.Y + 3, center.Position.Z)
	local inward = flat(center.Position - fighterSpot.Position).Unit * PumpGod.FighterInset
	character:PivotTo(CFrame.lookAt(fighterSpot.Position + inward + Vector3.new(0, 3, 0), look))
	fight.boss = spawnBoss(bossStart, middle, 1)
	broadcast(startMessage(fight))
	task.spawn(loop, fight, fight.token, 2.5)
	task.spawn(sacredLoop, fight, fight.token)
	sendCrowd(fight)
	-- Mort (chute, reset) : le combat est perdu
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Once(function()
			finish(fight, "Defeat")
		end)
	end
	return true
end

-- Défi accepté au temple (BossService) : colonne de lumière, puis il arrive sur la piste. false si la piste est prise.
function PumpGodService.Challenge(player: Player): boolean
	local root = rootOf(player)
	if fights[player] or MinigameService.IsBusy(player) or not root or not arenaFree(player) then
		return false
	end
	arenaHeldBy = player
	Remotes.ColosseumTravel:FireAllClients({ player = player, from = root.Position })
	task.delay(Balance.Colosseum.TravelDelay, function()
		if arenaHeldBy == player then
			arenaHeldBy = nil
		end
		if player.Parent then
			PumpGodService.Begin(player)
		end
	end)
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

-- Studio : passer à une manche (4 = la finale)
function PumpGodService.DevRound(player: Player, index: number): boolean
	local fight = fights[player]
	if not fight or fight.ended or fight.finale then
		return false
	end
	nextRound(fight, index)
	return true
end

-- Studio : simuler des encouragements de la foule (tester seul)
function PumpGodService.DevCheer(count: number): boolean
	for _, fight in fights do
		if not fight.ended then
			addCheers(fight, count)
			return true
		end
	end
	return false
end

local function onRoll(player: Player)
	local fight = fights[player]
	local t = os.clock()
	if not fight or fight.ended or fight.finale or t < fight.rollReadyAt then
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
	StatueService = services.StatueService
	TutorialService = services.TutorialService
end

function PumpGodService.Start()
	Remotes.PumpGodRoll.OnServerEvent:Connect(onRoll)
	Remotes.PumpGodFlex.OnServerEvent:Connect(onFlex)
	Remotes.PumpGodCheer.OnServerEvent:Connect(onCheer)
	-- Sauts (dernier instant où les pieds étaient assez haut), charge de la pose sacrée, finale, amphore
	RunService.Heartbeat:Connect(function(dt)
		for _, fight in fights do
			local root = rootOf(fight.player)
			if root and feetHeight(fight, root) >= PumpGod.JumpClear then
				fight.airAt = os.clock()
			end
			stepCharge(fight)
			stepFinale(fight, dt)
			stepAmphora(fight)
		end
	end)
	-- Laurier des vainqueurs, à chaque apparition (une fois le corps de stade posé)
	local function watchCharacter(player: Player)
		player.CharacterAdded:Connect(function()
			task.delay(PumpGod.Laurel.SpawnDelay, crown, player)
		end)
		if player.Character then
			task.delay(PumpGod.Laurel.SpawnDelay, crown, player)
		end
	end
	Players.PlayerAdded:Connect(function(player)
		watchCharacter(player)
		syncTo(player)
	end)
	for _, player in Players:GetPlayers() do
		watchCharacter(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local fight = fights[player]
		if fight then
			finish(fight, "Left")
		end
	end)
end

return PumpGodService
