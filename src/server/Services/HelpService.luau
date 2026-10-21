-- Aides en ville : habitants (tag "HelperSpot" + attribut HelpId), run de mini-jeu, délai avant de refaire la
-- même aide. Voir design/02_MECANIQUES/AIDES.md.
-- Le Cash dépend de la réussite (D57, Balance.Helps.Reward) : chaque répétition rapporte selon sa qualité, le combo
-- et la chaîne de Perfect ; bonus « sans faute » ; tout raté = rien. Le total est versé à la fin (même si le joueur
-- arrête en cours de route : il garde ce qu'il a gagné).

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
local WeeklyService

-- Heure serveur (workspace:GetServerTimeNow) où chaque aide redevient disponible, par joueur
local readyAt: { [Player]: { [string]: number } } = {}
-- Une même aide peut avoir plusieurs habitants (la maman de chaque maison)
local anchors: { [string]: { BasePart } } = {}
-- Aide en cours de chaque joueur : Cash gagné jusqu'ici, Perfect d'affilée, ratés
type Progress = { earned: number, chain: number, misses: number, auto: number }
local progress: { [Player]: Progress } = {}

local HelpService = {}

local function sendState(player: Player)
	Remotes.HelpState:FireClient(player, readyAt[player] or {})
end

local REWARD = Balance.Helps.Reward

-- Cash d'une répétition (le client l'affiche ; le total est versé à la fin)
local function repCash(player: Player, helpId: string, quality: string, combo: number, playground: any?): number
	local state = progress[player]
	if not state then
		return 0
	end
	local help = Helps[helpId]
	if quality == "Perfect" then
		state.chain = if playground then playground.perfectStreak or 0 else state.chain + 1
	else
		state.chain = 0
	end
	if quality == "Miss" then
		state.misses += 1
	elseif quality == "Auto" then
		state.auto += 1
	end
	local base = help.cash / (help.reps or Balance.Helps.Reps) * REWARD.Scale
	local chainBonus = 1 + math.min(math.max(state.chain - 1, 0) * REWARD.PerfectChainStep, REWARD.PerfectChainMax)
	local gain = base * (REWARD.Quality[quality] or 0) * combo * chainBonus
	state.earned += gain
	return math.floor(gain * 10 + 0.5) / 10
end

-- Fin de l'aide : verse ce qui a été gagné, remercie (ou pas) l'habitant
local function finish(player: Player, helpId: string, reason: string, outcome: any?): { [string]: any }?
	local state = progress[player]
	progress[player] = nil
	local help = Helps[helpId]
	local data = DataService.Get(player)
	if not state or not data or reason == "Left" then
		return nil
	end
	local completed = reason == "Completed" and (not outcome or outcome.won)
	if outcome then
		state.misses = outcome.misses
	end
	local flawless = completed and state.misses == 0 and state.auto == 0
	-- Playground jobs pay for a completed objective. Failed jobs remain freely retryable.
	local total = (if outcome and not completed then 0 else state.earned) * (if flawless then REWARD.Flawless else 1)
	local cash = math.floor(total + 0.5)
	local firstTime = completed and cash > 0 and data.HelpsDone[helpId] ~= true
	-- Toute première réussite : au moins la récompense de découverte (le bocal de Maman, D48)
	if firstTime and help.firstCash then
		cash = math.max(cash, help.firstCash)
	end
	if cash > 0 then
		StatsService.Add(player, "Cash", cash)
	end

	if completed then
		if cash > 0 then
			data.HelpsDone[helpId] = true
			WeeklyService.Track(player, "HelpsDone")
			if flawless then
				WeeklyService.Track(player, "FlawlessHelps")
			end
			readyAt[player] = readyAt[player] or {}
			readyAt[player][helpId] = workspace:GetServerTimeNow() + Balance.Helps.Cooldown
			sendState(player)
		end
		Remotes.Notify:FireClient(player, {
			key = if cash == 0 then "Help.Failed" elseif firstTime then "Help.Done" else "Help.Thanks",
			args = {
				npc = { key = `Npc.{help.npc}` },
				line = { key = `HelpLine.{helpId}` },
				cash = cash,
			},
		})
		TutorialService.OnEvent(player, "HelpCompleted", helpId)
	end
	return { cash = cash, flawless = flawless }
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

	progress[player] = { earned = 0, chain = 0, misses = 0, auto = 0 }
	local started = MinigameService.StartRun(player, {
		kind = "Help",
		id = helpId,
		minigame = help.minigame,
		interval = help.interval,
		total = help.reps or Balance.Helps.Reps,
		anchor = anchor,
		autoAllowed = true,
		titleKey = `Help.{helpId}`,
		onRep = function(p, quality, combo, _payoutScale, playground)
			return repCash(p, helpId, quality, combo, playground)
		end,
		onEnd = function(p, reason, _reps, _score, outcome)
			return finish(p, helpId, reason, outcome)
		end,
	})
	if not started then
		progress[player] = nil
	end
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
	WeeklyService = services.WeeklyService
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
		progress[player] = nil
	end)
end

return HelpService
