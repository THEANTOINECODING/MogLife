-- Exercices : stations dans le monde (tag "Station" + attribut ExerciseId), séries de Mog.
-- Une machine = un joueur (D110) : prise, son invite disparaît pour les autres. Un autre joueur peut payer en Robux
-- pour prendre la place (Balance.StealSpot) : l'occupant est éjecté (il garde son Mog) puis protégé un moment.

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Exercises = require(ReplicatedStorage.Shared.Config.Exercises)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Throttle = require(script.Parent.Parent.Throttle)
local Analytics = require(script.Parent.Parent.Analytics)

local STATION_TAG = "Station"
local STEAL = Balance.StealSpot

-- Machine -> joueur qui s'y entraîne ; invites de chaque machine
local occupants: { [BasePart]: Player } = {}
local prompts: { [BasePart]: { train: ProximityPrompt, steal: ProximityPrompt } } = {}
-- Joueurs qu'on ne peut pas déloger avant cette heure (os.clock) : l'acheteur et le joueur délogé
local protectedUntil: { [Player]: number } = {}
-- Machine visée par chaque acheteur pendant l'achat ; reçus déjà traités (Roblox peut renvoyer le même)
local pendingSteal: { [Player]: BasePart } = {}
local processedReceipts: { [string]: boolean } = {}

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

-- Machine libre la plus proche pour cet exercice (demande sans machine précise : remote StartSeries)
local function findStation(player: Player, exerciseId: string): BasePart?
	for _, station in CollectionService:GetTagged(STATION_TAG) do
		if
			station:IsA("BasePart")
			and station:GetAttribute("ExerciseId") == exerciseId
			and not occupants[station]
			and MinigameService.IsNear(player, station)
		then
			return station
		end
	end
	return nil
end

local function setOccupant(station: BasePart, player: Player?)
	occupants[station] = player
	local pair = prompts[station]
	if pair then
		pair.train.Enabled = player == nil
		pair.steal.Enabled = player ~= nil and STEAL.ProductId > 0
	end
end

local function startSeries(player: Player, exerciseId: unknown, wanted: BasePart?)
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

	local station = if wanted and MinigameService.IsNear(player, wanted)
		then wanted
		else findStation(player, exerciseId)
	if not station or occupants[station] then
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
			Analytics.Step(p, DataService.Get(p), "FirstRep")
			SocialService.OnLifterRep(p, gain, quality)
			-- Les muscles travaillés gonflent (D40)
			BodyService.Pump(p, exerciseId, quality)
			if quality == "Perfect" then
				WeeklyService.Track(p, "PerfectReps")
			end
			return gain
		end,
		onEnd = function(p, reason, _reps, score)
			if occupants[station] == p then
				setOccupant(station, nil)
			end
			SocialService.EndSeries(p)
			if reason ~= "Completed" then
				return nil
			end
			TutorialService.OnEvent(p, "SeriesCompleted", exerciseId)
			WeeklyService.Track(p, "SeriesDone")
			Analytics.Event(p, "SeriesCompleted", score or 0, exerciseId)
			if score and MinigameService.Grade(score) == "S" then
				WeeklyService.Track(p, "GradeS")
				SocialService.Celebrate(p)
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
		setOccupant(station, player)
		SocialService.OfferSpot(player)
	end
end

-- Invite « Prendre la place » d'une machine prise : vérifications, puis fenêtre d'achat Roblox
local function onStealPrompt(buyer: Player, station: BasePart, exerciseId: string)
	local occupant = occupants[station]
	local data = DataService.Get(buyer)
	if not occupant or occupant == buyer or not data or MinigameService.IsBusy(buyer) then
		return
	end
	if data.Stage < Exercises[exerciseId].requiredStage then
		return
	end
	local left = (protectedUntil[occupant] or 0) - os.clock()
	if left > 0 then
		Remotes.Notify:FireClient(buyer, { key = "Station.Protected", args = { seconds = math.ceil(left) } })
		return
	end
	pendingSteal[buyer] = station
	MarketplaceService:PromptProductPurchase(buyer, STEAL.ProductId)
end

-- Scène drôle : l'occupant est projeté en arrière en tournoyant, loin de la machine
local function ejectFrom(occupant: Player, station: BasePart)
	local root = occupant.Character and occupant.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local away = root.Position - station.Position
	away = Vector3.new(away.X, 0, away.Z)
	local direction = if away.Magnitude > 0.1 then away.Unit else -station.CFrame.LookVector
	root.AssemblyLinearVelocity = direction * STEAL.EjectSpeed + Vector3.new(0, STEAL.EjectLift, 0)
	root.AssemblyAngularVelocity = Vector3.new(0, STEAL.EjectSpin, 0)
end

-- Achat confirmé : l'occupant est délogé (il garde le Mog déjà gagné), l'acheteur commence sa série
local function deliverSteal(buyer: Player): boolean
	local station = pendingSteal[buyer]
	if not station then
		return false
	end
	pendingSteal[buyer] = nil
	local occupant = occupants[station]
	if occupant and occupant ~= buyer then
		MinigameService.EndRun(occupant, "Stopped")
		protectedUntil[occupant] = os.clock() + STEAL.ProtectSeconds
		ejectFrom(occupant, station)
		Remotes.Notify:FireClient(occupant, { key = "Station.Stolen", args = { name = buyer.DisplayName } })
	end
	-- La machine est libérée même si la série de l'occupant s'était déjà arrêtée autrement
	setOccupant(station, nil)
	protectedUntil[buyer] = os.clock() + STEAL.ProtectSeconds
	Analytics.Event(buyer, "SpotStolen", STEAL.PriceRobux, station:GetAttribute("ExerciseId"))
	startSeries(buyer, station:GetAttribute("ExerciseId"), station)
	return true
end

local function processReceipt(receipt): Enum.ProductPurchaseDecision
	if receipt.ProductId ~= STEAL.ProductId then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if processedReceipts[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local buyer = Players:GetPlayerByUserId(receipt.PlayerId)
	if not buyer then
		-- Roblox réessaiera à sa prochaine connexion
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Machine plus visée (acheteur reconnecté) : l'achat est accordé avec la protection, le reçu ne reste pas bloqué
	if not deliverSteal(buyer) then
		protectedUntil[buyer] = os.clock() + STEAL.ProtectSeconds
	end
	processedReceipts[receipt.PurchaseId] = true
	return Enum.ProductPurchaseDecision.PurchaseGranted
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
		startSeries(player, exerciseId, station)
	end)

	-- Machine prise : « Take spot (15 R$) », vue seulement par les autres (le client de l'occupant cache toutes les
	-- invites pendant son mini-jeu)
	local steal = Instance.new("ProximityPrompt")
	steal.Name = "StealPrompt"
	steal.ActionText = Texts.Get("Station.Steal", { price = STEAL.PriceRobux })
	steal.ObjectText = Texts.Get(`Exercise.{exerciseId}`)
	steal.MaxActivationDistance = Balance.MaxStationDistance - 2
	steal.RequiresLineOfSight = false
	steal.HoldDuration = STEAL.HoldSeconds -- évite un achat par erreur
	steal.Enabled = false
	steal.Parent = station
	steal.Triggered:Connect(function(player)
		onStealPrompt(player, station, exerciseId)
	end)
	prompts[station] = { train = prompt, steal = steal }
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
	Remotes.StartSeries.OnServerEvent:Connect(function(player, exerciseId)
		startSeries(player, exerciseId)
	end)
	-- Seul produit Robux du jeu pour l'instant : ce service reçoit les reçus (à déplacer dans un service d'achats
	-- quand il y en aura d'autres)
	MarketplaceService.ProcessReceipt = processReceipt
	Players.PlayerRemoving:Connect(function(player)
		protectedUntil[player] = nil
		pendingSteal[player] = nil
	end)
	-- Records envoyés au client (objectif du HUD : exercices déjà essayés)
	local function sendRecords(player: Player)
		local data = DataService.Get(player)
		if data then
			Remotes.Records:FireClient(player, data.Records)
		end
	end
	DataService.PlayerLoaded:Connect(sendRecords)
	Remotes.RequestStats.OnServerEvent:Connect(Throttle.Wrap(Balance.RemoteThrottle.RequestStats, sendRecords))
end

return ExerciseService
