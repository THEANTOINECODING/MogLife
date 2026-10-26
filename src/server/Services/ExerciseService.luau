-- Exercices : stations dans le monde (tag "Station" + attribut ExerciseId), séries de Mog.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Exercises = require(ReplicatedStorage.Shared.Config.Exercises)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local STATION_TAG = "Station"

local DataService
local StatsService
local MinigameService
local BodyService
local TutorialService
local BoostService
local SocialService
local WeeklyService

local ExerciseService = {}

-- Nom du boss à battre pour débloquer un stade donné (pour les messages « verrouillé »)
function ExerciseService.UnlockingBossId(requiredStage: number): string?
	local stage = Stages.List[requiredStage - 1]
	return stage and stage.boss and stage.boss.id
end

local function findStation(player: Player, exerciseId: string): BasePart?
	for _, station in CollectionService:GetTagged(STATION_TAG) do
		if
			station:IsA("BasePart")
			and station:GetAttribute("ExerciseId") == exerciseId
			and MinigameService.IsNear(player, station)
		then
			return station
		end
	end
	return nil
end

local function startSeries(player: Player, exerciseId: unknown)
	if typeof(exerciseId) ~= "string" then
		return
	end
	local exercise = Exercises[exerciseId]
	local data = DataService.Get(player)
	if not exercise or not data or MinigameService.IsBusy(player) then
		return
	end

	if data.Stage < exercise.requiredStage then
		local bossId = ExerciseService.UnlockingBossId(exercise.requiredStage)
		Remotes.Notify:FireClient(player, {
			key = "Series.Locked",
			args = { boss = { key = `Boss.{bossId}` } },
		})
		return
	end

	local station = findStation(player, exerciseId)
	if not station then
		return
	end

	local started = MinigameService.StartRun(player, {
		kind = "Exercise",
		id = exerciseId,
		minigame = exercise.minigame,
		interval = exercise.repInterval,
		total = Balance.SeriesLength,
		anchor = station,
		-- Plus le joueur a dépassé le stade de déblocage, plus le mini-jeu a de surprises (D81)
		level = data.Stage - exercise.requiredStage,
		titleKey = `Exercise.{exerciseId}`,
		onRep = function(p, quality, combo)
			-- Gain = base × qualité × combo × boost en cours × pareur (+20 % si un autre joueur le pare)
			local gain = exercise.mogPerRep
				* Balance.Quality[quality]
				* combo
				* BoostService.Multiplier(p)
				* SocialService.LifterMultiplier(p)
			StatsService.Add(p, "Mog", gain)
			SocialService.OnLifterRep(p, gain, quality)
			-- Les muscles travaillés gonflent (D40)
			BodyService.Pump(p, exerciseId, quality)
			if quality == "Perfect" then
				WeeklyService.Track(p, "PerfectReps")
			end
			return gain
		end,
		onEnd = function(p, reason, _reps, score)
			SocialService.EndSeries(p)
			if reason ~= "Completed" then
				return nil
			end
			TutorialService.OnEvent(p, "SeriesCompleted", exerciseId)
			WeeklyService.Track(p, "SeriesDone")
			if score and MinigameService.Grade(score) == "S" then
				WeeklyService.Track(p, "GradeS")
			end
			-- Record personnel de l'exercice (D51)
			local playerData = DataService.Get(p)
			if not score or not playerData then
				return nil
			end
			local best = playerData.Records[exerciseId]
			local newRecord = best == nil or score > best
			if newRecord then
				playerData.Records[exerciseId] = score
				Remotes.Records:FireClient(p, playerData.Records)
			end
			return { record = if newRecord then score else best, newRecord = newRecord }
		end,
	})
	-- Les autres joueurs peuvent le parer pendant la série
	if started then
		SocialService.OfferSpot(player)
	end
end

local function setupStation(station: Instance)
	if not station:IsA("BasePart") then
		return
	end
	local exerciseId = station:GetAttribute("ExerciseId")
	if typeof(exerciseId) ~= "string" or not Exercises[exerciseId] then
		warn(`[ExerciseService] Station {station:GetFullName()} has an invalid ExerciseId`)
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Texts.Get("Station.Train")
	prompt.ObjectText = Texts.Get(`Exercise.{exerciseId}`)
	prompt.MaxActivationDistance = Balance.MaxStationDistance - 2
	prompt.RequiresLineOfSight = false
	prompt.Parent = station

	prompt.Triggered:Connect(function(player)
		startSeries(player, exerciseId)
	end)
end

function ExerciseService.Init(services)
	DataService = services.DataService
	StatsService = services.StatsService
	MinigameService = services.MinigameService
	BodyService = services.BodyService
	TutorialService = services.TutorialService
	BoostService = services.BoostService
	SocialService = services.SocialService
	WeeklyService = services.WeeklyService
end

function ExerciseService.Start()
	for _, station in CollectionService:GetTagged(STATION_TAG) do
		setupStation(station)
	end
	CollectionService:GetInstanceAddedSignal(STATION_TAG):Connect(setupStation)
	Remotes.StartSeries.OnServerEvent:Connect(startSeries)
	-- Records envoyés au client (objectif du HUD : exercices déjà essayés)
	local function sendRecords(player: Player)
		local data = DataService.Get(player)
		if data then
			Remotes.Records:FireClient(player, data.Records)
		end
	end
	DataService.PlayerLoaded:Connect(sendRecords)
	Remotes.RequestStats.OnServerEvent:Connect(sendRecords)
end

return ExerciseService
