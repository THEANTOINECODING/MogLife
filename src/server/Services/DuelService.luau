-- Duels entre joueurs : « Tug of Mog » (D67, design/02_MECANIQUES/DUELS.md, Config/Duels.luau).
-- - Invitation : un joueur en invite un autre tout proche (prompt local sur son personnage) ; l'invité accepte ou
--   refuse (refus automatique au bout de quelques secondes, sans pénalité). Invitations désactivables (Settings).
-- - Le duel se joue sur une estrade de la salle (tag DuelSpot, attributs Arena et Side "A" / "B") : les deux
--   joueurs y sont placés face à face, puis ramenés à leur place à la fin.
-- - 3 manches sur le mini-jeu Tug : les deux joueurs jouent EXACTEMENT le même motif (même graine), avec les mêmes
--   fenêtres. Chaque répétition tire la corde (Duels.Pull) ; au bout de la corde, K.-O. et manche gagnée.
-- - Récompenses en Cash, jamais de perte ; plafonnées par paire de joueurs et par jour (compteur sauvegardé chez
--   chacun des deux). Abandon : rien pour celui qui part ; si au moins une manche a été jouée, l'autre gagne.
-- Le serveur décide de tout ; la corde est publiée sur les estrades (attribut Rope) pour que tout le monde la voie.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Duels = require(ReplicatedStorage.Shared.Config.Duels)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Npc = require(script.Parent.Parent.Npc)

local SPOT_TAG = "DuelSpot"
local DAY = 86_400

type Side = {
	player: Player?, -- nil pour le mannequin d'entraînement (Studio)
	bot: Model?,
	botSkill: { perfect: number, good: number }?,
	name: string,
	spot: BasePart,
	sign: number, -- +1 côté A, -1 côté B : sens dans lequel ce joueur tire la corde
	returnTo: CFrame?,
	wins: number,
	hits: number, -- répétitions réussies pendant tout le duel (participation valide)
	pulled: number, -- traction de la manche en cours
	done: boolean, -- a fini sa manche
}

type Duel = {
	arena: string,
	sides: { Side },
	round: number,
	rope: number, -- de -RopeLimit (côté B) à +RopeLimit (côté A)
	token: number, -- change à chaque manche : ignore les minuteurs et les fins de run périmés
	completed: number, -- manches menées à leur terme
	over: boolean,
}

type Arena = { A: BasePart?, B: BasePart?, busy: boolean }

local DataService
local StatsService
local MinigameService
local BossService
local WeeklyService
local LookService

local arenas: { [string]: Arena } = {}
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

local function freeArena(): string?
	local ids = {}
	for id, arena in arenas do
		if not arena.busy and arena.A and arena.B then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids[1]
end

local function otherSide(duel: Duel, side: Side): Side
	return if duel.sides[1] == side then duel.sides[2] else duel.sides[1]
end

local function sendTo(side: Side, message: { [string]: any })
	if side.player and side.player.Parent then
		Remotes.DuelUpdate:FireClient(side.player, message)
	end
end

-- La corde est visible par tout le monde (Activities/Tug lit l'attribut des deux emplacements)
local function publishRope(duel: Duel)
	local arena = arenas[duel.arena]
	for _, spot in { arena.A, arena.B } do
		if spot then
			spot:SetAttribute("Rope", duel.rope)
		end
	end
end

local function sendLive(duel: Duel)
	for _, side in duel.sides do
		local other = otherSide(duel, side)
		sendTo(side, {
			state = "Live",
			rope = duel.rope * side.sign, -- > 0 : la corde penche de son côté
			limit = Duels.RopeLimit,
			pulled = side.pulled,
			theirPulled = other.pulled,
		})
	end
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
	local arena = arenas[duel.arena]
	arena.busy = false
	duel.rope = 0
	publishRope(duel)
	for _, side in duel.sides do
		if side.bot then
			side.bot:Destroy()
		end
		local player = side.player
		if player and duelOf[player] == duel then
			duelOf[player] = nil
			player:SetAttribute("InDuel", nil)
			local character = player.Character
			if character and side.returnTo and character.Parent then
				character:PivotTo(side.returnTo)
			end
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
	local knockout = math.abs(duel.rope) >= Duels.RopeLimit
	local winner: Side? = nil
	if duel.rope > 0 then
		winner = duel.sides[1]
	elseif duel.rope < 0 then
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
			knockout = knockout,
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

-- Corde au bout : la manche s'arrête tout de suite pour les deux
local function knockout(duel: Duel)
	local token = duel.token
	for _, side in duel.sides do
		if side.player and MinigameService.IsBusy(side.player) then
			MinigameService.EndRun(side.player, "Completed")
		elseif not side.player then
			onSideEnd(duel, side, "Completed", token)
		end
	end
end

local function pull(duel: Duel, side: Side, quality: string, token: number)
	if duel.over or duel.token ~= token or side.done then
		return
	end
	local amount = Duels.Pull[quality] or 0
	if quality == "Perfect" or quality == "Good" then
		side.hits += 1
	end
	side.pulled += amount
	duel.rope = math.clamp(duel.rope + side.sign * amount, -Duels.RopeLimit, Duels.RopeLimit)
	publishRope(duel)
	sendLive(duel)
	if math.abs(duel.rope) >= Duels.RopeLimit then
		knockout(duel)
	end
end

-- Mannequin d'entraînement (Studio) : joue ses nœuds au même rythme que le motif du joueur
local function playBot(duel: Duel, side: Side, interval: number, token: number)
	-- Premier nœud : il arrive après le temps de traversée du mini-jeu
	task.wait(interval * Duels.Lead)
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
		pull(duel, side, quality, token)
		task.wait(interval)
	end
	onSideEnd(duel, side, "Completed", token)
end

function startRound(duel: Duel)
	duel.round += 1
	duel.token += 1
	duel.rope = 0
	publishRope(duel)
	local token = duel.token
	local round = duel.round
	local interval = Duels.Interval * (Duels.SpeedByRound[round] or 1)
	-- Même graine pour les deux : même suite de nœuds courts et longs
	local seed = math.random(1, 2 ^ 30)
	for _, side in duel.sides do
		side.done = false
		side.pulled = 0
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
			autoAllowed = false,
			timingScale = Duels.TimingScaleByRound[round] or 1,
			seed = seed,
			titleKey = "Duel.RoundTitle",
			titleArgs = { round = round, rounds = Duels.Rounds, name = other.name },
			onRep = function(_, quality)
				pull(duel, side, quality, token)
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
	-- Un joueur qui ne joue plus : sa manche se termine quand même (le mini-jeu envoie les nœuds ratés)
	task.delay(interval * (Duels.RepsPerRound + 1.5) * 2 + 3, function()
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
		returnTo = nil,
		wins = 0,
		hits = 0,
		pulled = 0,
		done = false,
	}
end

-- Place les deux joueurs sur l'estrade et lance la présentation. b = nil : mannequin d'entraînement (botSkill :
-- sa précision, Duels.Bot par défaut).
local function startDuel(arenaId: string, a: Player, b: Player?, botSkill: { perfect: number, good: number }?)
	local arena = arenas[arenaId]
	local spotA, spotB = arena.A :: BasePart, arena.B :: BasePart
	arena.busy = true
	local duel: Duel = {
		arena = arenaId,
		sides = { newSide(a, spotA, 1), newSide(b, spotB, -1) },
		round = 0,
		rope = 0,
		token = 0,
		completed = 0,
		over = false,
	}
	publishRope(duel)
	local botSide = duel.sides[2]
	if not b then
		local model = Npc.Spawn("Kevin", botSide.name, spotB, spotA.Position)
		botSide.bot = model
		botSide.botSkill = botSkill
	end
	for _, side in duel.sides do
		local player = side.player
		if not player then
			continue
		end
		duelOf[player] = duel
		player:SetAttribute("InDuel", true)
		local root = rootOf(player)
		local character = player.Character
		if root and character then
			side.returnTo = root.CFrame
			-- Face à l'adversaire, au-dessus de l'emplacement (l'activité le placera exactement)
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
			limit = Duels.RopeLimit,
		})
	end
	task.delay(Duels.IntroTime, function()
		if not duel.over and duel.round == 0 then
			startRound(duel)
		end
	end)
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
	if not freeArena() then
		notify(player, "Duel.ArenaBusy")
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
	local arenaId = freeArena()
	if not arenaId then
		notify(player, "Duel.ArenaBusy")
		notify(from, "Duel.ArenaBusy")
		return
	end
	startDuel(arenaId, from, player)
end

-- ------------------------------------------------------------------ estrades

local function setupSpot(spot: Instance)
	if not spot:IsA("BasePart") then
		return
	end
	local arenaId, side = spot:GetAttribute("Arena"), spot:GetAttribute("Side")
	if typeof(arenaId) ~= "string" or (side ~= "A" and side ~= "B") then
		warn(`[DuelService] DuelSpot {spot:GetFullName()} needs Arena and Side (A or B) attributes`)
		return
	end
	arenas[arenaId] = arenas[arenaId] or { busy = false }
	arenas[arenaId][side] = spot
	spot:SetAttribute("Rope", 0)
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
	local arenaId = freeArena()
	if not arenaId then
		return false
	end
	startDuel(arenaId, player, nil, skill)
	return true
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
	for _, spot in CollectionService:GetTagged(SPOT_TAG) do
		setupSpot(spot)
	end
	CollectionService:GetInstanceAddedSignal(SPOT_TAG):Connect(setupSpot)
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
