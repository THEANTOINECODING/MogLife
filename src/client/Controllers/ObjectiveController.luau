-- Objectif toujours visible (D52) : une petite carte à gauche dit au joueur quoi faire ensuite, une fois le
-- tutoriel fini (pendant le tutoriel, c'est sa carte qui occupe cette place). Par ordre de priorité :
-- 1. assez de Mog pour le boss : aller le défier (le trait doré du guide y mène) ;
-- 2. un exercice débloqué jamais essayé : l'essayer ;
-- 3. sinon : s'entraîner sur l'exercice qui rapporte le plus, jusqu'au Mog du boss.
-- Tout est calculé ici à partir des stats et des records envoyés par le serveur (rien n'est décidé côté client).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Exercises = require(ReplicatedStorage.Shared.Config.Exercises)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local player = Players.LocalPlayer

local card: Frame
local goalLabel: TextLabel
local stats: { Mog: number, Stage: number }? = nil
local records: { [string]: number } = {}
local tutorialActive = false

local ObjectiveController = {}

local function exerciseName(id: string): string
	return Texts.Get(`Exercise.{id}`)
end

local function render()
	card.Visible = stats ~= nil and not tutorialActive
	if not stats then
		return
	end
	local stage = Stages.List[stats.Stage]
	local boss = stage and stage.boss
	if not boss or boss.comingSoon then
		goalLabel.Text = Texts.Get("Objective.Top")
		return
	end
	local bossName = Texts.Get(`Boss.{boss.id}`)
	if stats.Mog >= boss.mogRequired then
		goalLabel.Text = Texts.Get("Objective.Boss", { boss = bossName })
		return
	end
	-- Exercice débloqué jamais essayé, puis meilleur exercice disponible
	local untried, best = nil, nil
	for id, exercise in Exercises do
		if exercise.requiredStage <= stats.Stage then
			if records[id] == nil and (untried == nil or exercise.requiredStage > Exercises[untried].requiredStage) then
				untried = id
			end
			if best == nil or exercise.mogPerRep > Exercises[best].mogPerRep then
				best = id
			end
		end
	end
	if untried then
		goalLabel.Text = Texts.Get("Objective.TryExercise", { exercise = exerciseName(untried) })
	elseif best then
		goalLabel.Text = Texts.Get("Objective.Train", {
			exercise = exerciseName(best),
			mog = Format.Short(boss.mogRequired),
			boss = bossName,
		})
	end
end

local function buildGui()
	local gui = Ui.create("ScreenGui", { Name = "Objective", ResetOnSpawn = false, DisplayOrder = 2 })
	card = Ui.panel({
		Name = "Card",
		Position = UDim2.fromOffset(12, 64),
		Size = UDim2.fromOffset(250, 84),
		Visible = false,
		Parent = gui,
	})
	Ui.label({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 220, 120),
		Text = Texts.Get("Objective.Title"),
		Parent = card,
	})
	goalLabel = Ui.label({
		Position = UDim2.fromOffset(12, 28),
		Size = UDim2.new(1, -24, 1, -36),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Parent = card,
	})
	gui.Parent = player:WaitForChild("PlayerGui")
end

function ObjectiveController.Start()
	buildGui()
	Remotes.StatsChanged.OnClientEvent:Connect(function(newStats)
		stats = newStats
		render()
	end)
	Remotes.Records.OnClientEvent:Connect(function(newRecords)
		records = newRecords or {}
		render()
	end)
	Remotes.Tutorial.OnClientEvent:Connect(function(state)
		tutorialActive = state ~= nil and not state.done
		render()
	end)
end

return ObjectiveController
