-- Entraînement côté client : un clic (ou un tap) = une demande de répétition au serveur.
-- Le client ne calcule aucun gain, il demande seulement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local TrainingController = {}

local currentExercise = "Curl"

function TrainingController.SetExercise(exerciseId: string)
	currentExercise = exerciseId
end

function TrainingController.Start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local isClick = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		if isClick then
			Remotes.Train:FireServer(currentExercise)
		end
	end)
end

return TrainingController
