-- Boss de stade : PNJ dans le monde (tag "BossSpot" + attribut BossId), défi, Mog-off en manches
-- sur le mini-jeu PROPRE au boss, boss qui joue en direct, manches de plus en plus dures,
-- défaite automatique si le Mog est insuffisant, montée de stade à la victoire.
-- Voir design/02_MECANIQUES/BOSS.md.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local PumpGod = require(ReplicatedStorage.Shared.Config.PumpGod)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Npc = require(script.Parent.Parent.Npc)
local Analytics = require(script.Parent.Parent.Analytics)

local SPOT_TAG = "BossSpot"
local BOSS = Balance.Boss

type Fight = {
	bossId: string,
	spot: BasePart,
	round: number,
	wins: number,
	losses: number,
	score: number, -- somme des points du joueur dans la manche en cours
	bossScore: number, -- somme des points du boss dans la manche en cours
	bossReps: number,
	playerDone: boolean,
	bossDone: boolean,
	token: number, -- change à chaque manche, pour ignorer les minuteurs périmés
	stakes: number, -- Cash perdu en cas de défaite (annoncé avant le combat)
	mogStakes: number, -- part de Mog perdue en cas de défaite (0 en revanche, D110)
}

local DataService
local StatsService
local MinigameService
local StyleService
local TutorialService
local WeeklyService
local PumpGodService

-- Un même boss peut avoir plusieurs emplacements (Kevin dans le garage de chaque maison)
local spots: { [string]: { BasePart } } = {}
local models: { [BasePart]: Model } = {}
local fights: { [Player]: Fight } = {}
local lastChallenge: { [Player]: number } = {}

local BossService = {}

local function cashLoss(cash: number, stage: number, percent: number, caps: { number }): number
	local cap = caps[stage] or caps[#caps]
	return math.min(math.floor(cash * percent), cap)
end

-- État du joueur face à un boss : prêt, déjà battu (revanche), et pertes annoncées
local function assess(player: Player, bossId: string)
	local data = DataService.Get(player)
	local boss, stageIndex = Stages.FindBoss(bossId)
	if not data or not boss or not stageIndex then
		return nil
	end
	local beaten = data.BossesBeaten[bossId] == true
	local isCurrent = stageIndex == data.Stage
	local ready = beaten or (isCurrent and data.Mog >= boss.mogRequired)
	local currentStage = Stages.List[data.Stage]
	return {
		boss = boss,
		ready = ready,
		beaten = beaten,
		-- Perte si le joueur n'est pas prêt (défaite automatique)
		autoLoss = cashLoss(data.Cash, data.Stage, BOSS.DefeatCashLossPercent, BOSS.DefeatCashLossCap),
		-- Perte si le joueur perd le Mog-off (aucune en revanche) ; au Colisée, c'est du Mog, même en revanche (D89)
		fightLoss = if beaten or boss.arena
			then 0
			else cashLoss(data.Cash, data.Stage, BOSS.MogOffLossPercent, BOSS.MogOffLossCap),
		-- Mog perdu (D110 : 15 %, jamais sous le Mog du stade atteint) ; aucun en revanche. Au Colisée : PumpGod.
		mogLoss = if boss.arena
			then math.floor(data.Mog * PumpGod.DefeatMogShare)
			elseif beaten then 0
			else StatsService.MogLoss(data, BOSS.DefeatMogShare),
		autoMogLoss = StatsService.MogLoss(data, BOSS.DefeatMogShare),
		blockingBossId = if not isCurrent and not beaten and currentStage.boss then currentStage.boss.id else nil,
		mog = data.Mog,
	}
end

local function endFight(player: Player)
	fights[player] = nil
	player:SetAttribute("InFight", nil)
end

local function finishFight(player: Player, fight: Fight)
	endFight(player)
	local data = DataService.Get(player)
	local boss, stageIndex = Stages.FindBoss(fight.bossId)
	if not data or not boss or not stageIndex then
		return
	end

	-- Tout le monde voit la fin du duel (BossFights/Scene, D85) : le perdant tombe, le vainqueur exulte
	local won = fight.wins >= BOSS.RoundsToWin
	Remotes.Activity:FireAllClients({
		player = player,
		state = "FightEnd",
		kind = "Boss",
		id = fight.bossId,
		won = won,
	})

	Analytics.Event(player, if won then "BossWon" else "BossLost", fight.wins, fight.bossId)
	if not won then
		if fight.stakes > 0 then
			StatsService.Add(player, "Cash", -fight.stakes)
		end
		-- Recalculée à la fin (le Mog a pu changer), avec le plancher du stade
		local mogLost = if fight.mogStakes > 0 then StatsService.LoseMog(player, fight.mogStakes) else 0
		local model = models[fight.spot]
		if model then
			Npc.Pose(model)
		end
		Remotes.BossUpdate:FireClient(
			player,
			{ state = "Defeat", bossId = fight.bossId, cash = fight.stakes, mog = mogLost }
		)
		return
	end

	-- Vaincu, le boss s'envole... une fois la fin du duel jouée (la pose de victoire est jouée par le duel)
	local model = models[fight.spot]
	if model then
		task.delay(BOSS.VictoryLaunchDelay, function()
			if model.Parent then
				Npc.LaunchAndReturn(model, 80, 5)
			end
		end)
	end
	WeeklyService.Track(player, "MogOffsWon")

	local firstWin = data.BossesBeaten[fight.bossId] ~= true and stageIndex == data.Stage
	if not firstWin then
		Remotes.BossUpdate:FireClient(player, { state = "Victory", bossId = fight.bossId, firstWin = false })
		return
	end

	-- Première victoire : récompenses idempotentes (BossesBeaten est vérifié juste au-dessus)
	data.BossesBeaten[fight.bossId] = true
	data.Stage = stageIndex + 1
	Analytics.Step(player, data, "FirstBossWin")
	if data.Stage >= 3 then
		Analytics.Step(player, data, "SecondStage")
	end
	Analytics.Event(player, "StageReached", data.Stage, Stages.List[data.Stage].id)
	data.Cash += boss.firstWinCash
	if boss.styleReward then
		data.StyleOwned[boss.styleReward] = true
	end
	StatsService.Refresh(player)
	StyleService.Refresh(player)

	Remotes.BossUpdate:FireClient(player, {
		state = "Victory",
		bossId = fight.bossId,
		firstWin = true,
		stageId = Stages.List[data.Stage].id,
		cash = boss.firstWinCash,
		styleItem = boss.styleReward,
	})
	-- Le mentor annonce ce qui se débloque ; le tutoriel se termine sur Kevin
	TutorialService.OnEvent(player, "BossBeaten", fight.bossId)
	TutorialService.OnEvent(player, "StageUp", data.Stage)
end

local function averageScore(total: number, reps: number): number
	return math.floor(total / math.max(reps, 1) + 0.5)
end

-- Scores officiels de la manche, envoyés à tous (D88) : la couronne et la position du duel (BossFights/Scene) sont les
-- mêmes chez le combattant et chez les spectateurs. won : résultat de la manche, une fois finie.
local function broadcastScores(player: Player, fight: Fight, won: boolean?)
	Remotes.Activity:FireAllClients({
		player = player,
		state = "Score",
		kind = "Boss",
		id = fight.bossId,
		score = averageScore(fight.score, BOSS.RepsPerRound),
		opponent = averageScore(fight.bossScore, BOSS.RepsPerRound),
		won = won,
	})
end

local startRound

-- Résultat de la manche, une fois que le joueur ET le boss ont fini
local function resolveRound(player: Player, fight: Fight)
	if fights[player] ~= fight or not fight.playerDone or not fight.bossDone then
		return
	end
	fight.playerDone = false
	fight.bossDone = false

	-- Répétitions manquantes du joueur = 0 point ; le boss a toujours joué toutes les siennes
	local score = averageScore(fight.score, BOSS.RepsPerRound)
	local opponent = averageScore(fight.bossScore, BOSS.RepsPerRound)
	-- Les vrais totaux décident (les scores affichés sont arrondis) ; à égalité parfaite, le joueur l'emporte (D88 :
	-- des scores affichés égaux donnaient la manche au boss, Antoine trouvait la victoire « refusée »)
	local won = fight.score >= fight.bossScore
	if won then
		fight.wins += 1
	else
		fight.losses += 1
	end
	broadcastScores(player, fight, won)
	Remotes.BossUpdate:FireClient(player, {
		state = "RoundResult",
		bossId = fight.bossId,
		round = fight.round,
		score = score,
		opponent = opponent,
		won = won,
		wins = fight.wins,
		losses = fight.losses,
	})

	local over = fight.wins >= BOSS.RoundsToWin or fight.losses > BOSS.Rounds - BOSS.RoundsToWin
	task.delay(BOSS.PauseBetweenRounds, function()
		if fights[player] == fight then
			if over then
				finishFight(player, fight)
			else
				startRound(player, fight)
			end
		end
	end)
end

local function onPlayerRoundEnd(player: Player, fight: Fight, reason: string)
	if fights[player] ~= fight then
		return
	end
	if reason ~= "Completed" then
		endFight(player)
		Remotes.BossUpdate:FireClient(player, { state = "Aborted", bossId = fight.bossId })
		return
	end
	fight.playerDone = true
	resolveRound(player, fight)
end

-- Le boss joue sa manche en direct : une répétition par intervalle, tirée selon son niveau
local function playBoss(player: Player, fight: Fight, interval: number, token: number)
	local boss = Stages.FindBoss(fight.bossId)
	if not boss then
		return
	end
	-- Le boss devient aussi plus précis à chaque manche
	local bonus = (fight.round - 1) * BOSS.BossSkillBonusPerRound
	local skill = boss.skill :: { perfect: number, good: number } -- Mog-off : jamais un boss d'arène
	for rep = 1, BOSS.RepsPerRound do
		task.wait(interval)
		if fights[player] ~= fight or fight.token ~= token then
			return
		end
		local roll = math.random()
		local quality = "Miss"
		if roll < skill.perfect + bonus then
			quality = "Perfect"
		elseif roll < skill.perfect + skill.good + bonus then
			quality = "Good"
		end
		fight.bossScore += BOSS.QualityScore[quality]
		fight.bossReps = rep
		-- Tout le monde voit le boss répliquer en direct (ActivityController : MogOff.OpponentRep)
		Remotes.Activity:FireAllClients({
			player = player,
			state = "OpponentRep",
			kind = "Boss",
			id = fight.bossId,
			quality = quality,
		})
		Remotes.BossUpdate:FireClient(player, {
			state = "Live",
			bossId = fight.bossId,
			score = averageScore(fight.score, BOSS.RepsPerRound),
			opponent = averageScore(fight.bossScore, BOSS.RepsPerRound),
		})
		broadcastScores(player, fight)
	end
	fight.bossDone = true
	resolveRound(player, fight)
end

function startRound(player: Player, fight: Fight)
	local boss = Stages.FindBoss(fight.bossId)
	if not boss then
		endFight(player)
		return
	end
	fight.round += 1
	fight.score = 0
	fight.bossScore = 0
	fight.bossReps = 0
	fight.playerDone = false
	fight.bossDone = false
	fight.token += 1
	local token = fight.token
	local interval = (boss.interval :: number) * (BOSS.SpeedByRound[fight.round] or 1)
	Remotes.BossUpdate:FireClient(player, {
		state = "RoundStart",
		bossId = fight.bossId,
		round = fight.round,
		rounds = BOSS.Rounds,
		wins = fight.wins,
		losses = fight.losses,
	})

	local started = MinigameService.StartRun(player, {
		kind = "Boss",
		id = fight.bossId,
		minigame = boss.minigame :: string,
		interval = interval,
		total = BOSS.RepsPerRound,
		anchor = fight.spot,
		timingScale = BOSS.TimingScaleByRound[fight.round] or 1,
		level = fight.round - 1, -- chaque manche débloque les surprises du mini-jeu du boss (D81)
		titleKey = "Boss.RoundTitle",
		titleArgs = { round = fight.round, rounds = BOSS.Rounds, boss = { key = `Boss.{fight.bossId}` } },
		onRep = function(p, quality)
			fight.score += BOSS.QualityScore[quality] or 0
			Remotes.BossUpdate:FireClient(p, {
				state = "Live",
				bossId = fight.bossId,
				score = averageScore(fight.score, BOSS.RepsPerRound),
				opponent = averageScore(fight.bossScore, BOSS.RepsPerRound),
			})
			broadcastScores(p, fight)
			return nil
		end,
		onEnd = function(p, reason)
			onPlayerRoundEnd(p, fight, reason)
		end,
	})
	if not started then
		endFight(player)
		return
	end
	task.spawn(playBoss, player, fight, interval, token)

	-- Un joueur qui ne joue pas : sa manche se termine quand même (répétitions manquantes = 0)
	task.delay(interval * BOSS.RepsPerRound * 2 + 3, function()
		if fights[player] == fight and fight.token == token and not fight.playerDone then
			MinigameService.EndRun(player, "Completed")
		end
	end)
end

-- Emplacement de ce boss à portée du joueur (nil s'il est trop loin de tous)
local function nearestSpot(player: Player, bossId: string): BasePart?
	for _, spot in spots[bossId] or {} do
		if MinigameService.IsNear(player, spot) then
			return spot
		end
	end
	return nil
end

local function onChallenge(player: Player, bossId: unknown)
	if typeof(bossId) ~= "string" or fights[player] or MinigameService.IsBusy(player) then
		return
	end
	local now = os.clock()
	if now - (lastChallenge[player] or -math.huge) < BOSS.ChallengeCooldown then
		return
	end
	lastChallenge[player] = now
	local spot = nearestSpot(player, bossId)
	if not spot then
		return
	end
	local state = assess(player, bossId)
	if not state then
		return
	end

	if not state.ready then
		-- Défaite automatique et comique, avec la perte annoncée dans la fenêtre de défi
		StatsService.Add(player, "Cash", -state.autoLoss)
		local mogLost = StatsService.LoseMog(player, BOSS.DefeatMogShare)
		local model = models[spot]
		if model then
			Npc.Pose(model)
		end
		Remotes.BossUpdate:FireClient(
			player,
			{ state = "Mogged", bossId = bossId, cash = state.autoLoss, mog = mogLost }
		)
		return
	end

	-- Dernier boss : pas de Mog-off, le combat a lieu au Colisée du Pump (D94)
	if state.boss.arena then
		local started = PumpGodService.Challenge(player)
		Remotes.BossUpdate:FireClient(player, { state = if started then "Arena" else "ArenaBusy", bossId = bossId })
		return
	end

	local fight: Fight = {
		bossId = bossId,
		spot = spot,
		round = 0,
		wins = 0,
		losses = 0,
		score = 0,
		bossScore = 0,
		bossReps = 0,
		playerDone = false,
		bossDone = false,
		token = 0,
		stakes = state.fightLoss,
		mogStakes = if state.beaten then 0 else BOSS.DefeatMogShare,
	}
	fights[player] = fight
	player:SetAttribute("InFight", true) -- tout le combat, manches et entractes compris (le client range les événements)
	-- Présentation (écran VS, compte à rebours) avant la première manche
	Remotes.BossUpdate:FireClient(player, {
		state = "FightStarted",
		bossId = bossId,
		intro = BOSS.IntroTime,
		rounds = BOSS.Rounds,
	})
	task.delay(BOSS.IntroTime, function()
		if fights[player] == fight then
			startRound(player, fight)
		end
	end)
end

local function setupSpot(spot: Instance)
	if not spot:IsA("BasePart") then
		return
	end
	local bossId = spot:GetAttribute("BossId")
	if typeof(bossId) ~= "string" or not Stages.FindBoss(bossId) then
		warn(`[BossService] BossSpot {spot:GetFullName()} has an invalid BossId`)
		return
	end
	spots[bossId] = spots[bossId] or {}
	table.insert(spots[bossId], spot)

	local model, root = Npc.Spawn(bossId, Texts.Get(`Boss.{bossId}`), spot, spot.Position + spot.CFrame.LookVector)
	model:SetAttribute("BossId", bossId)
	models[spot] = model

	-- Boss annoncé mais pas encore jouable : une statue qui nargue le joueur, sans défi
	local boss = Stages.FindBoss(bossId)
	if boss and boss.comingSoon then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Texts.Get("Boss.Challenge")
	prompt.ObjectText = Texts.Get(`Boss.{bossId}`)
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	prompt.Triggered:Connect(function(player)
		BossService.ShowChallenge(player, bossId)
	end)
end

-- Le joueur est-il en plein Mog-off (y compris entre deux manches), ou au combat du Dieu du Pump au Colisée ?
-- (bus, maison, portails, duels et bancs le refusent : sinon on fuirait un combat perdu sans perdre de Mog)
function BossService.IsFighting(player: Player): boolean
	return fights[player] ~= nil or PumpGodService.IsFighting(player)
end

-- Envoie la fenêtre de défi au joueur (prompt du boss ; aussi utilisé par les tests de DevService)
function BossService.ShowChallenge(player: Player, bossId: string)
	if fights[player] or MinigameService.IsBusy(player) then
		return
	end
	local state = assess(player, bossId)
	if not state then
		return
	end
	Remotes.BossPrompt:FireClient(player, {
		bossId = bossId,
		mogRequired = state.boss.mogRequired,
		mog = state.mog,
		ready = state.ready,
		beaten = state.beaten,
		cashLoss = if state.ready then state.fightLoss else state.autoLoss,
		arena = state.boss.arena == true,
		mogLoss = if state.ready or state.boss.arena then state.mogLoss else state.autoMogLoss,
		blockingBossId = state.blockingBossId,
	})
end

function BossService.Init(services)
	DataService = services.DataService
	StatsService = services.StatsService
	MinigameService = services.MinigameService
	StyleService = services.StyleService
	TutorialService = services.TutorialService
	WeeklyService = services.WeeklyService
	PumpGodService = services.PumpGodService
end

-- Première rencontre avec chaque boss : présentation en cinématique (D53), une seule fois par joueur
local function checkMeetings()
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		if not data or fights[player] or MinigameService.IsBusy(player) then
			continue
		end
		for bossId, list in spots do
			local key = `Meet.{bossId}`
			if data.Tips[key] then
				continue
			end
			-- Un boss déjà battu n'a pas besoin d'être présenté
			if data.BossesBeaten[bossId] then
				data.Tips[key] = true
				continue
			end
			for _, spot in list do
				if MinigameService.IsNear(player, spot, BOSS.MeetDistance) then
					data.Tips[key] = true
					Remotes.Cutscene:FireClient(player, { kind = "Boss", bossId = bossId, spot = spot })
					break
				end
			end
		end
	end
end

function BossService.Start()
	for _, spot in CollectionService:GetTagged(SPOT_TAG) do
		setupSpot(spot)
	end
	task.spawn(function()
		while true do
			task.wait(0.5)
			checkMeetings()
		end
	end)
	CollectionService:GetInstanceAddedSignal(SPOT_TAG):Connect(setupSpot)
	Remotes.ChallengeBoss.OnServerEvent:Connect(onChallenge)
	Players.PlayerRemoving:Connect(function(player)
		lastChallenge[player] = nil
		endFight(player)
	end)
end

return BossService
