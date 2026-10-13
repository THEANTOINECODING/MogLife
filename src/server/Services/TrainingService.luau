-- Entraînement : le client demande une répétition, le serveur vérifie tout et attribue les gains.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Exercises = require(ReplicatedStorage.Shared.Config.Exercises)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local EQUIPMENT_TAG = "Equipment"

local DataService
local StatsService

local lastRepAt: { [Player]: number } = {}

local TrainingService = {}

local function isNearEquipment(player: Player, exerciseId: string): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end

	for _, equipment in CollectionService:GetTagged(EQUIPMENT_TAG) do
		if equipment:IsA("BasePart") and equipment:GetAttribute("ExerciseId") == exerciseId then
			if (equipment.Position - root.Position).Magnitude <= Balance.MaxEquipmentDistance then
				return true
			end
		end
	end
	return false
end

local function onTrain(player: Player, exerciseId: unknown)
	if typeof(exerciseId) ~= "string" then
		return
	end

	local exercise = Exercises[exerciseId]
	local data = DataService.Get(player)
	if not exercise or not data then
		return
	end

	local now = os.clock()
	if now - (lastRepAt[player] or 0) < Balance.TrainCooldown then
		return
	end

	if data.Strength < exercise.requiredStrength then
		return
	end

	if exercise.requiresEquipment and not isNearEquipment(player, exerciseId) then
		return
	end

	lastRepAt[player] = now
	StatsService.Add(player, "Strength", exercise.strengthPerRep)
	StatsService.Add(player, "Cash", exercise.cashPerRep)
end

function TrainingService.Init(services)
	DataService = services.DataService
	StatsService = services.StatsService
end

function TrainingService.Start()
	Remotes.Train.OnServerEvent:Connect(onTrain)
	Players.PlayerRemoving:Connect(function(player)
		lastRepAt[player] = nil
	end)
end

return TrainingService
