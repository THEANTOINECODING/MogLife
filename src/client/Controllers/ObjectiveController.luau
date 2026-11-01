-- Objectif toujours visible (D52, D96) : une pastille d'une ligne à côté du rond du menu dit au joueur quoi faire
-- ensuite, une fois le tutoriel fini (pendant le tutoriel, c'est sa carte qui parle). Un toucher sur la pastille
-- affiche la phrase complète. Par ordre de priorité :
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

local pill: TextButton
local goalLabel: TextLabel
local fullText = ""
local stats: { Mog: number, Stage: number }? = nil
local records: { [string]: number } = {}
local tutorialActive = false
local hiddenForFight = false
local menuOpen = false

local UIController

local ObjectiveController = {}

local function refreshVisible()
	-- En portrait, le tiroir du menu s'ouvre par-dessus la pastille : elle s'efface le temps qu'il soit ouvert
	pill.Visible = stats ~= nil
		and not tutorialActive
		and not hiddenForFight
		and not (menuOpen and Ui.isPhonePortrait())
end

local function layoutPill()
	local slots = Ui.menuSlots()
	pill.Position = slots.pillPosition
	pill.Size = slots.pillSize
	refreshVisible()
end

-- Phrase courte (pastille) et phrase complète (au toucher)
local function setGoal(short: string, full: string)
	goalLabel.Text = short
	fullText = full
end

local function exerciseName(id: string): string
	return Texts.Get(`Exercise.{id}`)
end

local function render()
	refreshVisible()
	if not stats then
		return
	end
	local stage = Stages.List[stats.Stage]
	local boss = stage and stage.boss
	if not boss or boss.comingSoon then
		setGoal(Texts.Get("Objective.Short.Top"), Texts.Get("Objective.Top"))
		return
	end
	local bossName = Texts.Get(`Boss.{boss.id}`)
	if stats.Mog >= boss.mogRequired then
		setGoal(
			Texts.Get("Objective.Short.Boss", { boss = bossName }),
			Texts.Get("Objective.Boss", { boss = bossName })
		)
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
		local exercise = exerciseName(untried)
		setGoal(
			Texts.Get("Objective.Short.TryExercise", { exercise = exercise }),
			Texts.Get("Objective.TryExercise", { exercise = exercise })
		)
	elseif best then
		local mog = Format.Short(boss.mogRequired)
		setGoal(
			Texts.Get("Objective.Short.Train", { exercise = exerciseName(best), mog = mog }),
			Texts.Get("Objective.Train", { exercise = exerciseName(best), mog = mog, boss = bossName })
		)
	end
end

-- Caché pendant un combat de boss (BossController)
function ObjectiveController.SetHidden(hidden: boolean)
	hiddenForFight = hidden
	render()
end

-- Le tiroir du menu (SettingsController) est ouvert ou fermé
function ObjectiveController.SetMenuOpen(open: boolean)
	menuOpen = open
	refreshVisible()
end

local function buildGui()
	local gui = Ui.create("ScreenGui", { Name = "Objective", ResetOnSpawn = false, DisplayOrder = 2 })
	pill = Ui.create("TextButton", {
		Name = "Goal",
		BackgroundColor3 = Color3.fromRGB(40, 35, 55),
		BackgroundTransparency = 0.25,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		Parent = gui,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.fromRGB(255, 220, 120), 1.5, 0.5) })
	Ui.label({
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.new(0, 24, 0.7, 0),
		Text = Texts.Get("Objective.Icon"),
		TextStrokeTransparency = 1,
		Parent = pill,
	})
	goalLabel = Ui.label({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 38, 0.5, 0),
		Size = UDim2.new(1, -50, 0.66, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = pill,
	})
	pill.Activated:Connect(function()
		if fullText ~= "" then
			UIController.Toast(fullText, 3.5)
		end
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	Ui.watchViewport(layoutPill)
end

function ObjectiveController.Init(controllers)
	UIController = controllers.UIController
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
