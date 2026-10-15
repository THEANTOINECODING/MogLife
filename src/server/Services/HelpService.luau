-- Aides en ville : habitants (tag "HelperSpot" + attribut HelpId), run de mini-jeu, Cash à la réussite,
-- délai avant de refaire la même aide. Voir design/02_MECANIQUES/AIDES.md.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Helps = require(ReplicatedStorage.Shared.Config.Helps)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Npc = require(script.Parent.Parent.Npc)

local SPOT_TAG = "HelperSpot"
local HELPER_TAG = "Helper"

local DataService
local StatsService
local MinigameService
local ExerciseService
local TutorialService

-- Heure serveur (workspace:GetServerTimeNow) où chaque aide redevient disponible, par joueur
local readyAt: { [Player]: { [string]: number } } = {}
-- Une même aide peut avoir plusieurs habitants (la maman de chaque maison)
local anchors: { [string]: { BasePart } } = {}

local HelpService = {}

local function sendState(player: Player)
	Remotes.HelpState:FireClient(player, readyAt[player] or {})
end

local function complete(player: Player, helpId: string)
	local help = Helps[helpId]
	local data = DataService.Get(player)
	if not data then
		return
	end

	local firstTime = data.HelpsDone[helpId] ~= true
	data.HelpsDone[helpId] = true
	StatsService.Add(player, "Cash", help.cash)

	readyAt[player] = readyAt[player] or {}
	readyAt[player][helpId] = workspace:GetServerTimeNow() + Balance.Helps.Cooldown
	sendState(player)

	Remotes.Notify:FireClient(player, {
		key = if firstTime then "Help.Done" else "Help.Thanks",
		args = {
			npc = { key = `Npc.{help.npc}` },
			line = { key = `HelpLine.{helpId}` },
			cash = help.cash,
		},
	})
	TutorialService.OnEvent(player, "HelpCompleted", helpId)
end

local function startHelp(player: Player, helpId: string)
	if not Helps[helpId] then
		return
	end
	local help = Helps[helpId]
	local data = DataService.Get(player)
	if not help or not data or MinigameService.IsBusy(player) then
		return
	end
	local anchor: BasePart? = nil
	for _, spot in anchors[helpId] or {} do
		if MinigameService.IsNear(player, spot) then
			anchor = spot
			break
		end
	end
	if not anchor then
		return
	end

	if data.Stage < help.requiredStage then
		Remotes.Notify:FireClient(player, {
			key = "Series.Locked",
			args = { boss = { key = `Boss.{ExerciseService.UnlockingBossId(help.requiredStage)}` } },
		})
		return
	end

	local remaining = ((readyAt[player] or {})[helpId] or 0) - workspace:GetServerTimeNow()
	if remaining > 0 then
		Remotes.Notify:FireClient(player, {
			key = "Help.Cooldown",
			args = { npc = { key = `Npc.{help.npc}` }, seconds = math.ceil(remaining) },
		})
		return
	end

	MinigameService.StartRun(player, {
		kind = "Help",
		id = helpId,
		minigame = help.minigame,
		interval = help.interval,
		total = help.reps or Balance.Helps.Reps,
		anchor = anchor,
		autoAllowed = true,
		titleKey = `Help.{helpId}`,
		onEnd = function(p, reason)
			if reason == "Completed" then
				complete(p, helpId)
			end
		end,
	})
end

local function setupSpot(spot: Instance)
	if not spot:IsA("BasePart") then
		return
	end
	local helpId = spot:GetAttribute("HelpId")
	local help = if typeof(helpId) == "string" then Helps[helpId] else nil
	if not help then
		warn(`[HelpService] HelperSpot {spot:GetFullName()} has an invalid HelpId`)
		return
	end
	anchors[helpId] = anchors[helpId] or {}
	table.insert(anchors[helpId], spot)

	local model, root = Npc.Spawn(help.npc, Texts.Get(`Npc.{help.npc}`), spot, spot.Position + spot.CFrame.LookVector)
	model:SetAttribute("HelpId", helpId)
	CollectionService:AddTag(model, HELPER_TAG)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Texts.Get("Help.Action")
	prompt.ObjectText = Texts.Get(`Help.{helpId}`)
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	prompt.Triggered:Connect(function(player)
		startHelp(player, helpId)
	end)
end

-- Même chemin que le prompt de l'habitant (utilisé aussi par les commandes de test de DevService)
HelpService.StartHelp = startHelp

function HelpService.Init(services)
	DataService = services.DataService
	StatsService = services.StatsService
	MinigameService = services.MinigameService
	ExerciseService = services.ExerciseService
	TutorialService = services.TutorialService
end

function HelpService.Start()
	for _, spot in CollectionService:GetTagged(SPOT_TAG) do
		setupSpot(spot)
	end
	CollectionService:GetInstanceAddedSignal(SPOT_TAG):Connect(setupSpot)

	DataService.PlayerLoaded:Connect(sendState)
	Remotes.RequestStats.OnServerEvent:Connect(sendState)
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
	end)
end

return HelpService
