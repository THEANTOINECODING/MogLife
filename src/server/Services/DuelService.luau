-- Duels entre joueurs : bras de fer (D68, design/02_MECANIQUES/DUELS.md, Config/Duels.luau).
-- - Invitation : un joueur en invite un autre tout proche, n'importe où (prompt local sur son personnage) ; l'invité
--   accepte ou refuse (refus automatique au bout de quelques secondes, sans pénalité). Invitations désactivables.
-- - Une table de bras de fer apparaît entre les deux joueurs, là où ils sont (sol plat et assez de place, sinon on
--   cherche un autre sens) ; ils se placent de chaque côté, puis la table disparaît à la fin.
-- - 3 manches sur le mini-jeu Gauge : les deux joueurs jouent EXACTEMENT le même motif (même graine), avec les mêmes
--   fenêtres. Chaque répétition pousse le bras (Duels.Push) ; bras plaqué sur la table = manche gagnée tout de suite.
-- - Récompenses en Cash, jamais de perte ; plafonnées par paire de joueurs et par jour (compteur sauvegardé chez
--   chacun des deux). Abandon : rien pour celui qui part ; si au moins une manche a été jouée, l'autre gagne.
-- Le serveur décide de tout ; l'inclinaison des bras est publiée sur les emplacements (attribut Lean) pour que tout le
-- monde la voie.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Duels = require(ReplicatedStorage.Shared.Config.Duels)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Npc = require(script.Parent.Parent.Npc)

local DAY = 86_400
local TABLE = Duels.Table

type Side = {
	player: Player?, -- nil pour le mannequin d'entraînement (Studio)
	bot: Model?,
	botSkill: { perfect: number, good: number }?,
	name: string,
	spot: BasePart,
	sign: number, -- +1 côté A, -1 côté B : sens dans lequel ce joueur pousse le bras
	wins: number,
	hits: number, -- répétitions réussies pendant tout le duel (participation valide)
	pushed: number, -- poussée de la manche en cours
	done: boolean, -- a fini sa manche
}

type Duel = {
	id: string,
	model: Model, -- la table et les deux emplacements
	sides: { Side },
	round: number,
	lean: number, -- de -LeanLimit (B a plaqué le bras de A) à +LeanLimit (A a plaqué le bras de B)
	token: number, -- change à chaque manche : ignore les minuteurs et les fins de run périmés
	completed: number, -- manches menées à leur terme
	over: boolean,
}

local DataService
local StatsService
local MinigameService
local BossService
local WeeklyService
local LookService

local folder: Folder
local nextId = 0
local duelOf: { [Player]: Duel } = {}
-- Invitation en attente, rangée par invité
local invites: { [Player]: { from: Player } } = {}
local lastInvite: { [Player]: number } = {}
-- Après un refus : invité -> inviteur -> heure de fin du blocage
local blocked: { [Player]: { [Player]: number } } = {}

local DuelService = {}

local function notify(player: Player, key: string, args: { [string]: any }?)
	Remotes.Notify:FireClient(player, { key = key, args = args })
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function byStage(list: { number }, player: Player): number
	local data = DataService.Get(player)
	return list[math.clamp(if data then data.Stage else 1, 1, #list)]
end

-- Tutoriel fini et personnage créé : on peut se mesurer aux autres
local function canDuel(player: Player): boolean
	local data = DataService.Get(player)
	return data ~= nil and data.Look.Created == true and data.Tutorial.Done == true
end

local function isBusy(player: Player): boolean
	return duelOf[player] ~= nil or MinigameService.IsBusy(player) or BossService.IsFighting(player)
end

local function otherSide(duel: Duel, side: Side): Side
	return if duel.sides[1] == side then duel.sides[2] else duel.sides[1]
end

local function sendTo(side: Side, message: { [string]: any })
	if side.player and side.player.Parent then
		Remotes.DuelUpdate:FireClient(side.player, message)
	end
end

-- Inclinaison visible par tout le monde (Activities/ArmWrestle lit l'attribut des deux emplacements)
local function publishLean(duel: Duel)
	for _, side in duel.sides do
		side.spot:SetAttribute("Lean", duel.lean)
	end
end

local function sendLive(duel: Duel)
	for _, side in duel.sides do
		local other = otherSide(duel, side)
		sendTo(side, {
			state = "Live",
			lean = duel.lean * side.sign, -- > 0 : le bras penche en sa faveur
			limit = Duels.LeanLimit,
			pushed = side.pushed,
			theirPushed = other.pushed,
		})
	end
end

-- ------------------------------------------------------------------ table de bras de fer, n'importe où

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.05 then f.Unit else Vector3.xAxis
end

-- Repère de la table (au sol, -Z vers le côté B) entre deux positions, ou nil s'il n'y a pas la place : sol plat
-- sous la table et sous les deux joueurs, rien de solide autour. Essaie plusieurs sens autour de l'axe A -> B.
local function findPlacement(posA: Vector3, posB: Vector3, ignore: { Instance }): CFrame?
	local center = (posA + posB) / 2
	local axis = flat(posB - posA)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignore
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = ignore
	overlap.RespectCanCollide = true
	local function groundAt(position: Vector3): RaycastResult?
		local hit = workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -14, 0), rayParams)
		if hit and hit.Normal.Y > 0.85 and hit.Material ~= Enum.Material.Water then
			return hit
		end
		return nil
	end
	local hit = groundAt(center)
	if not hit then
		return nil
	end
	for _, degrees in TABLE.TryAngles do
		local direction = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), math.rad(degrees)):VectorToWorldSpace(axis)
		local base = CFrame.lookAt(hit.Position, hit.Position + direction)
		-- Les deux joueurs debout sur le même sol que la table
		local ok = true
		for _, z in { -TABLE.Spacing, TABLE.Spacing } do
			local foot = groundAt(base * Vector3.new(0, 0, z))
			if not foot or math.abs(foot.Position.Y - hit.Position.Y) > TABLE.MaxStep then
				ok = false
			end
		end
		-- Rien de solide là où se tiennent les joueurs et la table (au-dessus du sol)
		if ok then
			local box = Vector3.new(TABLE.Room.X, TABLE.Room.Y, TABLE.Spacing * 2 + TABLE.Room.Z)
			local blocking = workspace:GetPartBoundsInBox(base * CFrame.new(0, TABLE.Room.Y / 2 + 0.6, 0), box, overlap)
			if #blocking == 0 then
				return base
			end
		end
	end
	return nil
end

local function newPart(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

-- Table haute de bras de fer (on se tient debout), coussins pour les coudes et les deux emplacements des joueurs
local function buildTable(id: string, base: CFrame): (Model, BasePart, BasePart)
	local model = Instance.new("Model")
	model.Name = `ArmWrestle{id}`
	local wood = Color3.fromRGB(150, 98, 58)
	local height = TABLE.Height
	newPart(
		"Base",
		Vector3.new(1.8, 0.2, 1.8),
		base * CFrame.new(0, 0.1, 0),
		Color3.fromRGB(60, 60, 66),
		Enum.Material.Metal
	).Parent =
		model
	newPart(
		"Leg",
		Vector3.new(0.5, height - 0.3, 0.5),
		base * CFrame.new(0, (height - 0.3) / 2 + 0.2, 0),
		Color3.fromRGB(80, 80, 88),
		Enum.Material.Metal
	).Parent =
		model
	newPart("Top", Vector3.new(2.4, 0.3, 2), base * CFrame.new(0, height - 0.15, 0), wood, Enum.Material.WoodPlanks).Parent =
		model
	newPart(
		"Pad",
		Vector3.new(0.7, 0.12, 1.2),
		base * CFrame.new(0, height + 0.06, 0),
		Color3.fromRGB(200, 50, 50),
		Enum.Material.Fabric
	).Parent =
		model
	-- Coussins où l'on plaque le bras de l'adversaire, de chaque côté
	for index, x in { -0.95, 0.95 } do
		newPart(
			`PinPad{index}`,
			Vector3.new(0.35, 0.16, 0.6),
			base * CFrame.new(x, height + 0.08, 0),
			Color3.fromRGB(250, 200, 40),
			Enum.Material.SmoothPlastic
		).Parent =
			model
	end
	local spots = {}
	for _, entry in { { "A", TABLE.Spacing }, { "B", -TABLE.Spacing } } do
		local side, z = entry[1], entry[2]
		local position = base * Vector3.new(0, 0.1, z)
		local spot = newPart(
			`Spot{side}`,
			Vector3.new(1.6, 0.2, 1.6),
			CFrame.lookAt(position, base * Vector3.new(0, 0.1, 0)),
			Color3.new(1, 1, 1),
			Enum.Material.SmoothPlastic
		)
		spot.Transparency = 1
		spot:SetAttribute("Arena", id)
		spot:SetAttribute("Side", side)
		spot:SetAttribute("Lean", 0)
		-- Pour l'animation (Activities/ArmWrestle) : centre du plateau et sens des coussins de plaquage
		spot:SetAttribute("TableTop", base * Vector3.new(0, height, 0))
		spot:SetAttribute("PinAxis", base.RightVector)
		spot.Parent = model
		spots[side] = spot
	end
	model.Parent = folder
	return model, spots.A, spots.B
end

-- ------------------------------------------------------------------ fin du duel

local finish

-- Récompense d'un joueur selon son résultat : (cash, compté dans le bilan, participation valide)
local function reward(side: Side, other: Side, result: string): (number, boolean, boolean)
	local player = side.player
	local data = player and DataService.Get(player)
	if not player or not data or result == "Cancelled" or result == "Forfeit" then
		return 0, false, false
	end
	local valid = side.hits >= Duels.MinHits
	local record = data.Duels
	local today = os.time() // DAY
	if record.Day ~= today then
		record.Day = today
		record.Pairs = {}
	end
	local key = if other.player then tostring(other.player.UserId) else "Bot"
	local count = record.Pairs[key] or 0
	if not valid or count >= Duels.RewardsPerPairPerDay then
		return 0, false, valid
	end
	record.Pairs[key] = count + 1
	local cash
	if result == "Won" then
		record.Wins += 1
		cash = byStage(Duels.WinCash, player)
	elseif result == "Lost" then
		record.Losses += 1
		cash = byStage(Duels.LossCash, player)
	else
		record.Draws += 1
		cash = byStage(Duels.DrawCash, player)
	end
	StatsService.Add(player, "Cash", cash)
	WeeklyService.Track(player, "DuelsPlayed")
	if result == "Won" then
		WeeklyService.Track(player, "DuelsWon")
		-- Le compteur de victoires est affiché à côté du surnom ; il débloque des titres
		LookService.RefreshNickname(player)
		LookService.CheckTitles(player)
	end
	WeeklyService.Refresh(player)
	return cash, true, true
end

local function release(duel: Duel)
	duel.model:Destroy()
	for _, side in duel.sides do
		if side.bot then
			side.bot:Destroy()
		end
		local player = side.player
		if player and duelOf[player] == duel then
			duelOf[player] = nil
			player:SetAttribute("InDuel", nil)
			sendTo(side, { state = "Finished" })
		end
	end
end

-- forfeiter : le côté qui abandonne (quitte le jeu, arrête, s'éloigne), nil pour une fin normale
function finish(duel: Duel, forfeiter: Side?)
	if duel.over then
		return
	end
	duel.over = true
	duel.token += 1
	-- Arrête les runs encore en cours (abandon de l'autre pendant une manche)
	for _, side in duel.sides do
		if side.player and MinigameService.IsBusy(side.player) then
			MinigameService.EndRun(side.player, "Stopped")
		end
	end
	local a, b = duel.sides[1], duel.sides[2]
	for _, side in duel.sides do
		local other = otherSide(duel, side)
		local result
		if forfeiter then
			if duel.completed == 0 then
				result = "Cancelled"
			else
				result = if side == forfeiter then "Forfeit" else "Won"
			end
		elseif a.wins == b.wins then
			result = "Draw"
		else
			result = if side.wins > other.wins then "Won" else "Lost"
		end
		local cash, counted, valid = reward(side, other, result)
		local data = side.player and DataService.Get(side.player)
		sendTo(side, {
			state = "Result",
			result = result,
			cash = cash,
			counted = counted,
			valid = valid,
			-- Participation valide mais plus de récompense avec ce joueur aujourd'hui
			capped = valid and not counted,
			wins = side.wins,
			theirWins = other.wins,
			totalWins = if data then data.Duels.Wins else 0,
			opponent = other.name,
			minHits = Duels.MinHits,
			resultTime = Duels.ResultTime,
		})
	end
	task.delay(Duels.ResultTime, function()
		release(duel)
	end)
end

-- ------------------------------------------------------------------ manches

local startRound

local function resolveRound(duel: Duel)
	if duel.over then
		return
	end
	for _, side in duel.sides do
		if not side.done then
			return
		end
	end
	local token = duel.token
	local pinned = math.abs(duel.lean) >= Duels.LeanLimit
	local winner: Side? = nil
	if duel.lean > 0 then
		winner = duel.sides[1]
	elseif duel.lean < 0 then
		winner = duel.sides[2]
	end
	if winner then
		winner.wins += 1
	end
	duel.completed += 1
	for _, side in duel.sides do
		local other = otherSide(duel, side)
		sendTo(side, {
			state = "RoundResult",
			round = duel.round,
			result = if winner == nil then "Draw" elseif winner == side then "Won" else "Lost",
			knockout = pinned,
			wins = side.wins,
			theirWins = other.wins,
		})
	end
	local a, b = duel.sides[1], duel.sides[2]
	local over = a.wins >= Duels.RoundsToWin or b.wins >= Duels.RoundsToWin or duel.round >= Duels.Rounds
	task.delay(Duels.PauseBetweenRounds, function()
		if duel.over or duel.token ~= token then
			return
		end
		if over then
			finish(duel, nil)
		else
			startRound(duel)
		end
	end)
end

local function onSideEnd(duel: Duel, side: Side, reason: string, token: number)
	if duel.over or duel.token ~= token or side.done then
		return
	end
	if reason ~= "Completed" then
		finish(duel, side)
		return
	end
	side.done = true
	resolveRound(duel)
end

-- Bras plaqué sur la table : la manche s'arrête tout de suite pour les deux
local function pin(duel: Duel)
	local token = duel.token
	for _, side in duel.sides do
		if side.player and MinigameService.IsBusy(side.player) then
			MinigameService.EndRun(side.player, "Completed")
		elseif not side.player then
			onSideEnd(duel, side, "Completed", token)
		end
	end
end

local function push(duel: Duel, side: Side, quality: string, token: number)
	if duel.over or duel.token ~= token or side.done then
		return
	end
	local amount = Duels.Push[quality] or 0
	if quality == "Perfect" or quality == "Good" then
		side.hits += 1
	end
	side.pushed += amount
	duel.lean = math.clamp(duel.lean + side.sign * amount, -Duels.LeanLimit, Duels.LeanLimit)
	publishLean(duel)
	sendLive(duel)
	if math.abs(duel.lean) >= Duels.LeanLimit then
		pin(duel)
	end
end

-- Mannequin d'entraînement (Studio) : pousse au même rythme que le motif du joueur
local function playBot(duel: Duel, side: Side, interval: number, token: number)
	-- Premier passage de l'aiguille dans la zone : au milieu du premier balayage, après le temps d'arrivée
	task.wait(interval * (Duels.Lead + 0.5))
	for _ = 1, Duels.RepsPerRound do
		if duel.over or duel.token ~= token or side.done then
			return
		end
		local skill = side.botSkill or Duels.Bot
		local roll = math.random()
		local quality = "Miss"
		if roll < skill.perfect then
			quality = "Perfect"
		elseif roll < skill.perfect + skill.good then
			quality = "Good"
		end
		push(duel, side, quality, token)
		task.wait(interval)
	end
	onSideEnd(duel, side, "Completed", token)
end

function startRound(duel: Duel)
	duel.round += 1
	duel.token += 1
	duel.lean = 0
	publishLean(duel)
	local token = duel.token
	local round = duel.round
	local interval = Duels.Interval * (Duels.SpeedByRound[round] or 1)
	-- Même graine pour les deux : mêmes zones de force, au même moment
	local seed = math.random(1, 2 ^ 30)
	for _, side in duel.sides do
		side.done = false
		side.pushed = 0
	end
	for _, side in duel.sides do
		local other = otherSide(duel, side)
		sendTo(side, {
			state = "RoundStart",
			round = round,
			rounds = Duels.Rounds,
			wins = side.wins,
			theirWins = other.wins,
		})
	end
	for _, side in duel.sides do
		local player = side.player
		if not player then
			task.spawn(playBot, duel, side, interval, token)
			continue
		end
		local other = otherSide(duel, side)
		local started = MinigameService.StartRun(player, {
			kind = "Duel",
			id = Duels.Activity,
			minigame = Duels.Minigame,
			interval = interval,
			total = Duels.RepsPerRound,
			anchor = side.spot,
			timingScale = Duels.TimingScaleByRound[round] or 1,
			seed = seed,
			level = round - 1,
			titleKey = "Duel.RoundTitle",
			titleArgs = { round = round, rounds = Duels.Rounds, name = other.name },
			onRep = function(_, quality)
				push(duel, side, quality, token)
				return nil
			end,
			onEnd = function(_, reason)
				onSideEnd(duel, side, reason, token)
			end,
		})
		if not started then
			finish(duel, side)
			return
		end
	end
	-- Un joueur qui ne joue plus : sa manche se termine quand même (le mini-jeu envoie les passages ratés)
	task.delay(interval * (Duels.RepsPerRound + Duels.Lead + 1) * 2 + 3, function()
		if duel.over or duel.token ~= token then
			return
		end
		for _, side in duel.sides do
			if side.player and not side.done then
				MinigameService.EndRun(side.player, "Completed")
			end
		end
	end)
end

local function newSide(player: Player?, spot: BasePart, sign: number): Side
	return {
		player = player,
		bot = nil,
		botSkill = nil,
		name = if player then player.DisplayName else Texts.Get("Duel.BotName"),
		spot = spot,
		sign = sign,
		wins = 0,
		hits = 0,
		pushed = 0,
		done = false,
	}
end

-- Pose la table entre les deux joueurs et lance la présentation. b = nil : mannequin d'entraînement, placé devant
-- le joueur (botSkill : sa précision, Duels.Bot par défaut). Renvoie false s'il n'y a pas la place.
local function startDuel(a: Player, b: Player?, botSkill: { perfect: number, good: number }?): boolean
	local rootA = rootOf(a)
	local rootB = if b then rootOf(b) else nil
	if not rootA or (b and not rootB) then
		return false
	end
	local posA = rootA.Position
	local posB = if rootB then rootB.Position else posA + flat(rootA.CFrame.LookVector) * TABLE.Spacing * 2
	local ignore: { Instance } = { folder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local base = findPlacement(posA, posB, ignore)
	if not base then
		return false
	end
	nextId += 1
	local id = tostring(nextId)
	local model, spotA, spotB = buildTable(id, base)
	local duel: Duel = {
		id = id,
		model = model,
		sides = { newSide(a, spotA, 1), newSide(b, spotB, -1) },
		round = 0,
		lean = 0,
		token = 0,
		completed = 0,
		over = false,
	}
	publishLean(duel)
	local botSide = duel.sides[2]
	if not b then
		botSide.bot = Npc.Spawn("Kevin", botSide.name, spotB, spotA.Position)
		botSide.botSkill = botSkill
	end
	for _, side in duel.sides do
		local player = side.player
		if not player then
			continue
		end
		duelOf[player] = duel
		player:SetAttribute("InDuel", true)
		local character = player.Character
		if character then
			-- De son côté de la table, face à l'adversaire (l'activité le placera exactement)
			character:PivotTo(side.spot.CFrame * CFrame.new(0, 3.5, 0))
		end
	end
	for _, side in duel.sides do
		local other = otherSide(duel, side)
		sendTo(side, {
			state = "Started",
			opponent = other.player,
			opponentModel = other.bot,
			opponentName = other.name,
			spot = side.spot,
			theirSpot = other.spot,
			intro = Duels.IntroTime,
			rounds = Duels.Rounds,
			limit = Duels.LeanLimit,
		})
	end
	task.delay(Duels.IntroTime, function()
		if not duel.over and duel.round == 0 then
			startRound(duel)
		end
	end)
	return true
end

-- ------------------------------------------------------------------ invitations

local function onInvite(player: Player, target: unknown)
	if typeof(target) ~= "Instance" or not target:IsA("Player") or target == player or target.Parent ~= Players then
		return
	end
	local invited = target :: Player
	local now = os.clock()
	if not canDuel(player) or isBusy(player) or invites[player] then
		return
	end
	if now - (lastInvite[player] or -math.huge) < Duels.InviteCooldown then
		notify(player, "Duel.Cooldown")
		return
	end
	local name = invited.DisplayName
	if not canDuel(invited) then
		notify(player, "Duel.NotReady", { name = name })
		return
	end
	local data = DataService.Get(invited)
	if data and data.Settings.Duels == false then
		notify(player, "Duel.InvitesOff", { name = name })
		return
	end
	if isBusy(invited) or invites[invited] then
		notify(player, "Duel.Busy", { name = name })
		return
	end
	local until_ = blocked[invited] and blocked[invited][player]
	if until_ and until_ > now then
		notify(player, "Duel.Blocked", { name = name })
		return
	end
	local a, b = rootOf(player), rootOf(invited)
	if not a or not b or (a.Position - b.Position).Magnitude > Duels.InviteDistance then
		notify(player, "Duel.TooFar", { name = name })
		return
	end
	lastInvite[player] = now
	local invite = { from = player }
	invites[invited] = invite
	Remotes.DuelUpdate:FireClient(invited, { state = "Invited", from = player, timeout = Duels.InviteTimeout })
	notify(player, "Duel.InviteSent", { name = name })
	task.delay(Duels.InviteTimeout, function()
		if invites[invited] == invite then
			invites[invited] = nil
			Remotes.DuelUpdate:FireClient(invited, { state = "InviteClosed" })
			if player.Parent then
				notify(player, "Duel.NoAnswer", { name = name })
			end
		end
	end)
end

local function onAnswer(player: Player, accept: unknown)
	local invite = invites[player]
	if not invite or typeof(accept) ~= "boolean" then
		return
	end
	invites[player] = nil
	local from = invite.from
	if from.Parent ~= Players then
		return
	end
	if not accept then
		blocked[player] = blocked[player] or {}
		blocked[player][from] = os.clock() + Duels.DeclineBlock
		notify(from, "Duel.Declined", { name = player.DisplayName })
		return
	end
	if isBusy(from) or isBusy(player) then
		notify(player, "Duel.Busy", { name = from.DisplayName })
		notify(from, "Duel.Busy", { name = player.DisplayName })
		return
	end
	-- Ils ont pu s'éloigner pendant l'invitation
	local a, b = rootOf(from), rootOf(player)
	if not a or not b or (a.Position - b.Position).Magnitude > Duels.InviteDistance * 1.5 then
		notify(player, "Duel.TooFar", { name = from.DisplayName })
		notify(from, "Duel.TooFar", { name = player.DisplayName })
		return
	end
	if not startDuel(from, player, nil) then
		notify(player, "Duel.NoRoom")
		notify(from, "Duel.NoRoom")
	end
end

-- Le joueur est-il dans un duel (y compris entre deux manches) ?
function DuelService.IsDueling(player: Player): boolean
	return duelOf[player] ~= nil
end

-- Duel d'entraînement contre un mannequin (Studio uniquement, via DevService) : teste tout le déroulement seul
function DuelService.StartBotDuel(player: Player, skill: { perfect: number, good: number }?): boolean
	if isBusy(player) then
		return false
	end
	return startDuel(player, nil, skill)
end

function DuelService.Init(services)
	DataService = services.DataService
	StatsService = services.StatsService
	MinigameService = services.MinigameService
	BossService = services.BossService
	WeeklyService = services.WeeklyService
	LookService = services.LookService
end

function DuelService.Start()
	folder = Instance.new("Folder")
	folder.Name = "DuelTables"
	-- Accessoire d'activité : la caméra ne le prend jamais pour un obstacle (CameraFraming)
	folder:SetAttribute("ActivityProps", true)
	folder.Parent = workspace
	Remotes.DuelInvite.OnServerEvent:Connect(onInvite)
	Remotes.DuelAnswer.OnServerEvent:Connect(onAnswer)
	Players.PlayerRemoving:Connect(function(player)
		local duel = duelOf[player]
		if duel then
			for _, side in duel.sides do
				if side.player == player then
					finish(duel, side)
				end
			end
		end
		invites[player] = nil
		lastInvite[player] = nil
		blocked[player] = nil
		for target, invite in invites do
			if invite.from == player then
				invites[target] = nil
				Remotes.DuelUpdate:FireClient(target, { state = "InviteClosed" })
			end
		end
	end)
end

return DuelService
