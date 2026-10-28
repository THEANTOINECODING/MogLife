-- Combat du Dieu du Pump au Colisée (D89, D90 — tranche 2 : manche 1 en esquive, le dieu ne se frappe pas encore).
-- Le serveur décide de tout : il tire les attaques, fixe l'heure exacte de chaque impact (heure du serveur,
-- workspace:GetServerTimeNow), juge si le joueur est touché d'après sa position, son saut et sa roulade, et tient sa
-- vie. Les clients (PumpGodController) dessinent les zones et animent le dieu à partir des messages
-- Remotes.PumpGodUpdate (envoyés à tous : les spectateurs voient le combat).
-- Attaques (Config/PumpGod.luau) : Bolts (cercles), Dumbbell (bande traversée par un haltère), Wave (anneau qui
-- s'élargit : sauter). Pour l'instant le combat se lance seulement dans Studio (DevCommands « PumpGod »).

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
local MinigameService

type Fight = {
	player: Player,
	hp: number,
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

local function alive(fight: Fight, token: number): boolean
	return not fight.ended and fight.token == token and fights[fight.player] == fight
end

local function newId(fight: Fight): number
	fight.nextId += 1
	return fight.nextId
end

-- Le joueur est-il dans la zone d'un instant donné ? (vérifié par `test`, à chaque image, de `from` à `to`).
-- Un coup détecté attend PumpGod.Grace : une roulade, ou un saut si `jumpable`, partis à temps chez le joueur mais
-- arrivés un peu après sur le serveur, l'annulent.
local function watch(
	fight: Fight,
	token: number,
	from: number,
	to: number,
	kind: string,
	damage: number,
	jumpable: boolean,
	test
)
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local t = now() - PumpGod.Latency
		if not alive(fight, token) or t > to then
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
				local dodged = fight.rollAt >= seen or (jumpable and fight.airAt >= seen)
				if alive(fight, token) and not dodged then
					hit(fight, kind, damage)
				end
			end)
		end
	end)
end

-- ------------------------------------------------------------------ attaques
local function bolts(fight: Fight, token: number)
	local spec = ATTACKS.Bolts
	local last = 0
	for _ = 1, spec.Count do
		local root = rootOf(fight.player)
		if not root or not alive(fight, token) then
			return
		end
		local target = Vector3.new(root.Position.X, fight.floor, root.Position.Z)
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
		task.wait(spec.Gap)
	end
	task.wait(math.max(last - now(), 0) + 0.4)
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
	local a = fight.center + perp - dir * reach
	local b = fight.center + perp + dir * reach
	a = Vector3.new(a.X, fight.floor, a.Z)
	b = Vector3.new(b.X, fight.floor, b.Z)
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
end

local function wave(fight: Fight, token: number)
	local spec = ATTACKS.Wave
	local origin = if fight.boss and fight.boss.PrimaryPart then fight.boss.PrimaryPart.Position else fight.center
	origin = Vector3.new(origin.X, fight.floor, origin.Z)
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

local RUN = { Bolts = bolts, Dumbbell = dumbbell, Wave = wave }

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

local function loop(fight: Fight, token: number)
	task.wait(2.5) -- le dieu se présente
	local previous = nil
	while alive(fight, token) do
		local name = pick(previous)
		previous = name
		RUN[name](fight, token)
		local p = PumpGod.Pause
		local k = math.clamp((os.clock() - fight.startedAt) / p.Over, 0, 1)
		task.wait(p.From + (p.To - p.From) * k)
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
	broadcast({ state = "End", player = fight.player, reason = reason })
	task.delay(2.5, function()
		if fight.boss then
			fight.boss:Destroy()
		end
		-- Le joueur remonte dans les gradins
		local stands = findSpot("Stands")
		local root = rootOf(fight.player)
		if stands and root and fight.player.Parent and not fights[fight.player] then
			local character = root.Parent :: Model
			local look = Vector3.new(fight.center.X, stands.Position.Y + 3, fight.center.Z)
			character:PivotTo(CFrame.lookAt(stands.Position + Vector3.new(0, 3, 0), look))
		end
	end)
end

-- Lance le combat (tranche 2 : seulement depuis Studio)
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
	local fight: Fight = {
		player = player,
		hp = PumpGod.Health,
		token = tokens,
		startedAt = os.clock(),
		boss = nil,
		center = Vector3.new(center.Position.X, floor, center.Position.Z),
		floor = floor,
		invulnUntil = 0,
		rollReadyAt = 0,
		rollAt = -math.huge,
		airAt = -math.huge,
		nextId = 0,
		ended = false,
	}
	fights[player] = fight
	ColosseumService.SetFighter(player, true)
	local character = root.Parent :: Model
	local look = Vector3.new(center.Position.X, fighterSpot.Position.Y + 3, center.Position.Z)
	character:PivotTo(CFrame.lookAt(fighterSpot.Position + Vector3.new(0, 3, 0), look))
	fight.boss = spawnBoss(bossSpot, fight.center)
	broadcast({
		state = "Start",
		player = player,
		boss = fight.boss,
		hp = fight.hp,
		maxHp = PumpGod.Health,
		center = fight.center,
	})
	task.spawn(loop, fight, fight.token)
	-- Mort (chute, reset) : le combat s'arrête
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
	broadcast({ state = "Roll", player = player })
end

function PumpGodService.Init(services)
	ColosseumService = services.ColosseumService
	MinigameService = services.MinigameService
end

function PumpGodService.Start()
	Remotes.PumpGodRoll.OnServerEvent:Connect(onRoll)
	-- Sauts : on note le dernier instant où les pieds du combattant étaient assez haut
	RunService.Heartbeat:Connect(function()
		for _, fight in fights do
			local root = rootOf(fight.player)
			if root and feetHeight(fight, root) >= PumpGod.JumpClear then
				fight.airAt = os.clock()
			end
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
