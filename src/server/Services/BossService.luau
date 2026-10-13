-- Boss de stade : PNJ dans le monde (tag "BossSpot" + attribut BossId), défi, Mog-off en manches,
-- défaite automatique si le Mog est insuffisant, montée de stade à la victoire.
-- Voir design/02_MECANIQUES/BOSS.md.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Exercises = require(ReplicatedStorage.Shared.Config.Exercises)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Npc = require(script.Parent.Parent.Npc)

local SPOT_TAG = "BossSpot"
local BOSS = Balance.Boss

type Fight = {
	bossId: string,
	spot: BasePart,
	round: number,
	wins: number,
	losses: number,
	score: number, -- somme des scores de la manche en cours
	token: number, -- change à chaque manche, pour ignorer les minuteurs périmés
}

local DataService
local StatsService
local MinigameService

local spots: { [string]: BasePart } = {}
local models: { [string]: Model } = {}
local fights: { [Player]: Fight } = {}

local BossService = {}

-- État du joueur face à un boss : prêt, déjà battu (revanche), et perte annoncée en cas d'échec
local function assess(player: Player, bossId: string)
	local data = DataService.Get(player)
	local boss, stageIndex = Stages.FindBoss(bossId)
	if not data or not boss or not stageIndex then
		return nil
	end
	local beaten = data.BossesBeaten[bossId] == true
	local isCurrent = stageIndex == data.Stage
	local ready = beaten or (isCurrent and data.Mog >= boss.mogRequired)
	local cap = BOSS.DefeatCashLossCap[data.Stage] or BOSS.DefeatCashLossCap[#BOSS.DefeatCashLossCap]
	local cashLoss = if ready then 0 else math.min(math.floor(data.Cash * BOSS.DefeatCashLossPercent), cap)
	-- Boss à affronter avant celui-ci (si le joueur saute des stades)
	local currentStage = Stages.List[data.Stage]
	local blockingBossId = if not isCurrent and not beaten and currentStage.boss then currentStage.boss.id else nil
	return {
		boss = boss,
		ready = ready,
		beaten = beaten,
		isCurrent = isCurrent,
		cashLoss = cashLoss,
		blockingBossId = blockingBossId,
		mog = data.Mog,
	}
end

-- Exercices débloqués dont le mini-jeu peut servir de manche
local function roundPool(player: Player): { string }
	local data = DataService.Get(player)
	local pool = {}
	for id, exercise in Exercises do
		if data and data.Stage >= exercise.requiredStage then
			table.insert(pool, id)
		end
	end
	table.sort(pool)
	return pool
end

local function endFight(player: Player)
	fights[player] = nil
end

local function finishFight(player: Player, fight: Fight)
	endFight(player)
	local data = DataService.Get(player)
	local boss, stageIndex = Stages.FindBoss(fight.bossId)
	if not data or not boss or not stageIndex then
		return
	end

	if fight.wins < BOSS.RoundsToWin then
		Remotes.BossUpdate:FireClient(player, { state = "Defeat", bossId = fight.bossId })
		return
	end

	local model = models[fight.bossId]
	if model then
		Npc.LaunchAndReturn(model, 80, 5)
	end

	local firstWin = data.BossesBeaten[fight.bossId] ~= true and stageIndex == data.Stage
	if not firstWin then
		Remotes.BossUpdate:FireClient(player, { state = "Victory", bossId = fight.bossId, firstWin = false })
		return
	end

	-- Première victoire : récompenses idempotentes (BossesBeaten est vérifié juste au-dessus)
	data.BossesBeaten[fight.bossId] = true
	data.Stage = stageIndex + 1
	data.Cash += boss.firstWinCash
	if boss.styleReward then
		data.StyleOwned[boss.styleReward] = true
	end
	StatsService.Refresh(player)

	Remotes.BossUpdate:FireClient(player, {
		state = "Victory",
		bossId = fight.bossId,
		firstWin = true,
		stageId = Stages.List[data.Stage].id,
		cash = boss.firstWinCash,
		styleItem = boss.styleReward,
	})
end

local startRound

local function onRoundEnd(player: Player, fight: Fight, reason: string)
	if fights[player] ~= fight then
		return
	end
	if reason ~= "Completed" then
		endFight(player)
		Remotes.BossUpdate:FireClient(player, { state = "Aborted", bossId = fight.bossId })
		return
	end

	local boss = Stages.FindBoss(fight.bossId)
	local score = math.floor(fight.score / BOSS.RepsPerRound + 0.5)
	local won = boss ~= nil and score >= boss.targetScore
	if won then
		fight.wins += 1
	else
		fight.losses += 1
	end
	Remotes.BossUpdate:FireClient(player, {
		state = "RoundResult",
		bossId = fight.bossId,
		round = fight.round,
		score = score,
		target = boss and boss.targetScore or 0,
		won = won,
	})

	if fight.wins >= BOSS.RoundsToWin or fight.losses > BOSS.Rounds - BOSS.RoundsToWin then
		task.delay(BOSS.PauseBetweenRounds, function()
			if fights[player] == fight then
				finishFight(player, fight)
			end
		end)
	else
		task.delay(BOSS.PauseBetweenRounds, function()
			if fights[player] == fight then
				startRound(player, fight)
			end
		end)
	end
end

function startRound(player: Player, fight: Fight)
	local boss = Stages.FindBoss(fight.bossId)
	local pool = roundPool(player)
	if not boss or #pool == 0 then
		endFight(player)
		return
	end
	fight.round += 1
	fight.score = 0
	fight.token += 1
	local token = fight.token

	local exerciseId = pool[math.random(1, #pool)]
	local exercise = Exercises[exerciseId]
	local interval = exercise.repInterval * BOSS.SpeedFactor

	local started = MinigameService.StartRun(player, {
		kind = "Boss",
		id = fight.bossId,
		minigame = exercise.minigame,
		interval = interval,
		total = BOSS.RepsPerRound,
		anchor = fight.spot,
		autoAllowed = false,
		titleKey = "Boss.RoundTitle",
		titleArgs = { round = fight.round, rounds = BOSS.Rounds, target = boss.targetScore },
		onRep = function(_, quality)
			fight.score += BOSS.QualityScore[quality] or 0
			return nil
		end,
		onEnd = function(p, reason)
			onRoundEnd(p, fight, reason)
		end,
	})
	if not started then
		endFight(player)
		return
	end

	-- Un joueur qui ne joue pas : la manche se termine quand même (répétitions manquantes = 0)
	task.delay(interval * BOSS.RepsPerRound * 2 + 3, function()
		if fights[player] == fight and fight.token == token then
			MinigameService.EndRun(player, "Completed")
		end
	end)
end

local function onChallenge(player: Player, bossId: unknown)
	if typeof(bossId) ~= "string" or fights[player] or MinigameService.IsBusy(player) then
		return
	end
	local spot = spots[bossId]
	if not spot or not MinigameService.IsNear(player, spot) then
		return
	end
	local state = assess(player, bossId)
	if not state then
		return
	end

	if not state.ready then
		-- Défaite automatique et comique, avec la perte annoncée dans la fenêtre de défi
		StatsService.Add(player, "Cash", -state.cashLoss)
		local model = models[bossId]
		if model then
			Npc.Pose(model)
		end
		Remotes.BossUpdate:FireClient(player, { state = "Mogged", bossId = bossId, cash = state.cashLoss })
		return
	end

	local fight: Fight = {
		bossId = bossId,
		spot = spot,
		round = 0,
		wins = 0,
		losses = 0,
		score = 0,
		token = 0,
	}
	fights[player] = fight
	startRound(player, fight)
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
	spots[bossId] = spot

	local model, root = Npc.Spawn(bossId, Texts.Get(`Boss.{bossId}`), spot, Vector3.new(spot.Position.X, 0, 0))
	model:SetAttribute("BossId", bossId)
	models[bossId] = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Texts.Get("Boss.Challenge")
	prompt.ObjectText = Texts.Get(`Boss.{bossId}`)
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	prompt.Triggered:Connect(function(player)
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
			cashLoss = state.cashLoss,
			blockingBossId = state.blockingBossId,
		})
	end)
end

function BossService.Init(services)
	DataService = services.DataService
	StatsService = services.StatsService
	MinigameService = services.MinigameService
end

function BossService.Start()
	for _, spot in CollectionService:GetTagged(SPOT_TAG) do
		setupSpot(spot)
	end
	CollectionService:GetInstanceAddedSignal(SPOT_TAG):Connect(setupSpot)
	Remotes.ChallengeBoss.OnServerEvent:Connect(onChallenge)
	Players.PlayerRemoving:Connect(endFight)
end

return BossService
