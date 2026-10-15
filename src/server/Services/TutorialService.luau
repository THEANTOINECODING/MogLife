-- Tutoriel et conseils du mentor (étape 5, D29).
-- - Tutoriel des 5 premières minutes (Config/Tutorial.luau) : une étape à la fois, validée par un événement du jeu
--   (série terminée, aide réussie, boutique ouverte, boss battu). Quittable (bouton « Passer »), rejouable (le
--   mentor le relance). Les joueurs qui ont déjà progressé ne le voient pas d'office.
-- - Conseils : la première fois qu'on ouvre chaque boutique, et à chaque nouveau stade (ce qui se débloque,
--   le prochain boss). Le mentor parle via le remote MentorSay ; on ne répète jamais un conseil déjà donné.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Exercises = require(ReplicatedStorage.Shared.Config.Exercises)
local Helps = require(ReplicatedStorage.Shared.Config.Helps)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DataService

local TutorialService = {}

local function say(player: Player, key: string, args: { [string]: any }?)
	Remotes.MentorSay:FireClient(player, { key = key, args = args })
end

local function send(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	Remotes.Tutorial:FireClient(player, {
		step = data.Tutorial.Step,
		total = #Tutorial.Steps,
		done = data.Tutorial.Done,
	})
end

-- Le mentor annonce l'étape en cours
local function announce(player: Player)
	local data = DataService.Get(player)
	local step = data and not data.Tutorial.Done and Tutorial.Steps[data.Tutorial.Step]
	if step then
		say(player, `Tutorial.{step.id}.Say`)
	end
	send(player)
end

-- Conseil donné une seule fois (mémorisé dans la sauvegarde)
local function tip(player: Player, key: string, args: { [string]: any }?)
	local data = DataService.Get(player)
	if not data or data.Tips[key] then
		return
	end
	data.Tips[key] = true
	say(player, `Mentor.Tip.{key}`, args)
end

-- Nouveau stade : ce qui vient de se débloquer, et le prochain boss
local function stageUp(player: Player, stageIndex: number)
	local stage = Stages.List[stageIndex]
	if not stage then
		return
	end
	say(player, "Mentor.StageUp", { stage = { key = `Stage.{stage.id}` } })
	local exerciseIds = {}
	for id, exercise in Exercises do
		if exercise.requiredStage == stageIndex then
			table.insert(exerciseIds, id)
		end
	end
	table.sort(exerciseIds)
	for _, id in exerciseIds do
		say(player, "Mentor.UnlockExercise", { exercise = { key = `Exercise.{id}` } })
	end
	local helpIds = {}
	for id, help in Helps do
		if help.requiredStage == stageIndex then
			table.insert(helpIds, id)
		end
	end
	table.sort(helpIds)
	for _, id in helpIds do
		say(player, "Mentor.UnlockHelp", { npc = { key = `Npc.{Helps[id].npc}` } })
	end
	local boss = stage.boss
	if boss and not boss.comingSoon then
		say(player, "Mentor.NextBoss", { boss = { key = `Boss.{boss.id}` }, mog = boss.mogRequired })
	end
end

-- Un événement du jeu : fait avancer le tutoriel, et déclenche les conseils
function TutorialService.OnEvent(player: Player, event: string, arg: any)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if not data.Tutorial.Done then
		local step = Tutorial.Steps[data.Tutorial.Step]
		if step and step.event == event and (step.arg == nil or step.arg == arg) then
			data.Tutorial.Step += 1
			if data.Tutorial.Step > #Tutorial.Steps then
				data.Tutorial.Done = true
				say(player, "Tutorial.Done")
				send(player)
			else
				announce(player)
			end
		end
	end
	if event == "ShopOpened" and typeof(arg) == "string" then
		tip(player, `Shop.{arg}`)
	elseif event == "StageUp" and typeof(arg) == "number" then
		stageUp(player, arg)
	end
end

-- Relance le tutoriel depuis le début (le mentor le propose)
function TutorialService.Restart(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.Tutorial.Step = 1
	data.Tutorial.Done = false
	announce(player)
end

local function onAction(player: Player, action: unknown)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if action == "Skip" and not data.Tutorial.Done then
		data.Tutorial.Done = true
		send(player)
	end
end

local function onPlayerLoaded(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	-- Joueur qui a déjà progressé (avant l'arrivée du tutoriel) : il n'en a pas besoin
	if not data.Tutorial.Done and data.Tutorial.Step == 1 and (data.Stage > 1 or data.Mog > 0) then
		data.Tutorial.Done = true
	end
	if data.Tutorial.Done then
		send(player)
	else
		-- Laisse le temps au client d'afficher le jeu avant la première réplique
		task.delay(3, function()
			if player.Parent then
				announce(player)
			end
		end)
	end
end

function TutorialService.Init(services)
	DataService = services.DataService
end

function TutorialService.Start()
	DataService.PlayerLoaded:Connect(onPlayerLoaded)
	Remotes.TutorialAction.OnServerEvent:Connect(onAction)
	Remotes.RequestStats.OnServerEvent:Connect(send)
	for _, player in Players:GetPlayers() do
		if DataService.Get(player) then
			task.spawn(onPlayerLoaded, player)
		end
	end
end

return TutorialService
