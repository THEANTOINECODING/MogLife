-- Séries d'exercices : démarrage aux stations, validation de chaque répétition, gain de Mog.
-- Le client envoie seulement la qualité de sa répétition ; le serveur vérifie la cadence,
-- la station, le déblocage, et calcule lui-même le Mog.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Exercises = require(ReplicatedStorage.Shared.Config.Exercises)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local STATION_TAG = "Station"

type Session = {
	exerciseId: string,
	station: BasePart,
	reps: number,
	mogGained: number,
	lastRepAt: number,
}

local DataService
local StatsService

local sessions: { [Player]: Session } = {}

local MinigameService = {}

local function isNear(player: Player, station: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	return (station.Position - root.Position).Magnitude <= Balance.MaxStationDistance
end

local function findStation(player: Player, exerciseId: string): BasePart?
	for _, station in CollectionService:GetTagged(STATION_TAG) do
		if station:IsA("BasePart") and station:GetAttribute("ExerciseId") == exerciseId and isNear(player, station) then
			return station
		end
	end
	return nil
end

local function endSeries(player: Player, reason: "Completed" | "Stopped" | "TooFar")
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	Remotes.SeriesUpdate:FireClient(player, {
		state = "Ended",
		reason = reason,
		exerciseId = session.exerciseId,
		reps = session.reps,
		mogGained = session.mogGained,
	})
end

local function startSeries(player: Player, exerciseId: unknown)
	if typeof(exerciseId) ~= "string" then
		return
	end
	local exercise = Exercises[exerciseId]
	local data = DataService.Get(player)
	if not exercise or not data or sessions[player] then
		return
	end

	if data.Stage < exercise.requiredStage then
		local unlockingStage = Stages.List[exercise.requiredStage - 1]
		Remotes.SeriesUpdate:FireClient(player, {
			state = "Locked",
			exerciseId = exerciseId,
			bossId = unlockingStage.boss and unlockingStage.boss.id,
		})
		return
	end

	local station = findStation(player, exerciseId)
	if not station then
		return
	end

	sessions[player] = {
		exerciseId = exerciseId,
		station = station,
		reps = 0,
		mogGained = 0,
		lastRepAt = 0,
	}
	Remotes.SeriesUpdate:FireClient(player, {
		state = "Started",
		exerciseId = exerciseId,
		total = Balance.SeriesLength,
	})
end

local function onRep(player: Player, quality: unknown)
	local session = sessions[player]
	if not session then
		return
	end
	if typeof(quality) ~= "string" or Balance.Quality[quality] == nil then
		return
	end

	local exercise = Exercises[session.exerciseId]
	local now = os.clock()
	if now - session.lastRepAt < exercise.repInterval * Balance.RepIntervalTolerance then
		return
	end
	if not isNear(player, session.station) then
		endSeries(player, "TooFar")
		return
	end

	session.lastRepAt = now
	local gain = exercise.mogPerRep * Balance.Quality[quality]
	StatsService.Add(player, "Mog", gain)
	session.reps += 1
	session.mogGained += gain

	Remotes.SeriesUpdate:FireClient(player, {
		state = "Rep",
		reps = session.reps,
		quality = quality,
		gain = gain,
	})

	if session.reps >= Balance.SeriesLength then
		endSeries(player, "Completed")
	end
end

local function setupStation(station: Instance)
	if not station:IsA("BasePart") then
		return
	end
	local exerciseId = station:GetAttribute("ExerciseId")
	if typeof(exerciseId) ~= "string" or not Exercises[exerciseId] then
		warn(`[MinigameService] Station {station:GetFullName()} has an invalid ExerciseId`)
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

function MinigameService.Init(services)
	DataService = services.DataService
	StatsService = services.StatsService
end

function MinigameService.Start()
	for _, station in CollectionService:GetTagged(STATION_TAG) do
		setupStation(station)
	end
	CollectionService:GetInstanceAddedSignal(STATION_TAG):Connect(setupStation)

	Remotes.StartSeries.OnServerEvent:Connect(startSeries)
	Remotes.Rep.OnServerEvent:Connect(onRep)
	Remotes.StopSeries.OnServerEvent:Connect(function(player)
		endSeries(player, "Stopped")
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

return MinigameService
