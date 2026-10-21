-- Moteur générique des « runs » de mini-jeu : une série d'exercice, une aide en ville, une manche de boss.
-- Le client envoie seulement la qualité de chaque répétition ; ce moteur vérifie la cadence, la distance,
-- puis délègue la récompense au service qui a lancé le run (onRep / onEnd).

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Playground = require(ReplicatedStorage.Shared.Playground)
local PlaygroundConfig = require(ReplicatedStorage.Shared.Config.Playground)

export type EndReason = "Completed" | "Stopped" | "TooFar" | "Left"

export type RunSpec = {
	kind: "Exercise" | "Help" | "Boss" | "Duel",
	id: string, -- exerciseId, helpId ou bossId
	minigame: string, -- module dans src/client/Minigames/
	interval: number, -- durée d'une répétition (secondes)
	total: number, -- nombre de répétitions du run
	anchor: BasePart, -- le joueur doit rester près de cette pièce
	timingScale: number?, -- < 1 = fenêtres de timing plus serrées (combats de boss)
	seed: number?, -- graine du motif du mini-jeu (duels : les deux joueurs jouent exactement le même)
	titleKey: string?, -- texte affiché en haut du run (clé Texts)
	titleArgs: { [string]: any }?,
	-- Appelé pour chaque répétition validée ; renvoie le gain à afficher (ou nil).
	-- combo : multiplicateur du combo en cours (Balance.Combo), à appliquer au gain si le run en profite
	onRep: ((player: Player, quality: string, combo: number, payoutScale: number?, playground: any?) -> number?)?,
	-- Appelé à la fin du run, quelle qu'en soit la raison. score : précision (0-100) des répétitions jouées à la
	-- main, nil si la série n'est pas notée. Peut renvoyer des infos à ajouter au message de fin (ex. record).
	onEnd: ((player: Player, reason: EndReason, reps: number, score: number?, outcome: any?) -> { [string]: any }?)?,
}

type Run = {
	spec: RunSpec,
	reps: number,
	streak: number, -- répétitions réussies d'affilée (combo)
	points: number, -- points de précision des répétitions jouées à la main (Balance.Grade)
	manual: number, -- répétitions jouées à la main
	startedAt: number,
	lastRepAt: number,
	playground: any?,
	token: string?,
	sequence: number?,
	budget: number?,
	lastInput: number?,
	duelHeld: boolean?,
	lastBudget: number?,
	nextSnapshot: number?,
	finishAt: number?,
	payoutScale: number?,
}

-- Écart minimum absolu entre deux répétitions (évite les doublons d'un même geste)
local MIN_GAP = 0.15

local runs: { [Player]: Run } = {}

local SeatService

local MinigameService = {}

-- Lettre de la note (S, A, B, C) pour une précision de 0 à 100
function MinigameService.Grade(score: number): string
	for _, entry in Balance.Grade.Letters do
		if score >= entry.min then
			return entry.letter
		end
	end
	return "C"
end

-- Multiplicateur du combo pour une série de `streak` répétitions réussies d'affilée
function MinigameService.ComboMultiplier(streak: number): number
	local multiplier = 1
	for _, step in Balance.Combo.Steps do
		if streak >= step.at then
			multiplier = step.multiplier
		end
	end
	return multiplier
end

-- Tout le monde voit l'activité se réaliser : le personnage fait la répétition que le serveur a validée
local function broadcast(player: Player, spec: RunSpec, state: string, quality: string?, streak: number?)
	Remotes.Activity:FireAllClients({
		player = player,
		state = state,
		kind = spec.kind,
		id = spec.id,
		anchor = spec.anchor,
		interval = spec.interval,
		minigame = spec.minigame,
		quality = quality,
		streak = streak,
	})
end

function MinigameService.IsNear(player: Player, part: BasePart, maxDistance: number?): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	return (part.Position - root.Position).Magnitude <= (maxDistance or Balance.MaxStationDistance)
end

function MinigameService.IsBusy(player: Player): boolean
	return runs[player] ~= nil
end

-- Lance un run. Renvoie false si le joueur est déjà occupé.
function MinigameService.StartRun(player: Player, spec: RunSpec): boolean
	if runs[player] then
		return false
	end
	-- Assis sur un banc ou un canapé : il se relève pour l'activité
	SeatService.StandUp(player)
	local gameConfig = PlaygroundConfig.Games[spec.minigame]
	local isPlayground = gameConfig and spec.kind ~= "Duel"
	if isPlayground then
		spec.interval = gameConfig.duration
		spec.total = 1
		spec.seed = math.random(1, 1000000)
	end
	runs[player] = {
		spec = spec,
		reps = 0,
		streak = 0,
		points = 0,
		manual = 0,
		startedAt = os.clock(),
		lastRepAt = 0,
		playground = if isPlayground
			then Playground.New(spec.minigame, spec.seed, math.max(0, 1 / (spec.timingScale or 1) - 1))
			else nil,
		token = if gameConfig then HttpService:GenerateGUID(false) else nil,
		sequence = 0,
		budget = PlaygroundConfig.InputBurst,
		lastInput = os.clock(),
		lastBudget = os.clock(),
		nextSnapshot = 0,
		payoutScale = 1,
	}
	-- Visible de tous : les autres clients ne proposent pas de duel à un joueur occupé
	player:SetAttribute("InRun", true)
	Remotes.SeriesUpdate:FireClient(player, {
		state = "Started",
		token = runs[player].token,
		playground = if runs[player].playground then Playground.Snapshot(runs[player].playground) else nil,
		anchor = spec.anchor,
		kind = spec.kind,
		id = spec.id,
		minigame = spec.minigame,
		interval = spec.interval,
		total = spec.total,
		timingScale = spec.timingScale,
		seed = spec.seed,
		titleKey = spec.titleKey,
		titleArgs = spec.titleArgs,
	})
	broadcast(player, spec, "Started")
	return true
end

function MinigameService.EndRun(player: Player, reason: EndReason)
	local run = runs[player]
	if not run then
		return
	end
	runs[player] = nil
	player:SetAttribute("InRun", nil)
	broadcast(player, run.spec, "Ended")
	-- Note : seulement si la série est finie et surtout jouée à la main
	local score: number? = nil
	if reason == "Completed" and run.manual > 0 and run.manual >= run.reps * Balance.Grade.MinManualShare then
		score = math.floor(run.points / run.manual + 0.5)
	end
	local outcome = if run.playground
		then {
			won = run.playground.won,
			score = Playground.Score(run.playground),
			misses = run.playground.misses,
		}
		else nil
	if outcome then
		score = outcome.score
	end
	local extra = if run.spec.onEnd then run.spec.onEnd(player, reason, run.reps, score, outcome) else nil
	if reason ~= "Left" then
		local message = {
			state = "Ended",
			kind = run.spec.kind,
			id = run.spec.id,
			reason = reason,
			reps = run.reps,
			score = score,
			grade = if score then MinigameService.Grade(score) else nil,
		}
		for key, value in extra or {} do
			message[key] = value
		end
		Remotes.SeriesUpdate:FireClient(player, message)
	end
end

local function onRep(player: Player, quality: unknown, trusted: boolean?)
	local run = runs[player]
	if not run then
		return
	end
	if typeof(quality) ~= "string" or Balance.Quality[quality] == nil then
		return
	end
	local spec = run.spec
	if PlaygroundConfig.Games[spec.minigame] and not trusted then
		return
	end

	-- Quota : jamais plus de répétitions que le temps écoulé ne le permet (+1 d'avance).
	-- Les jeux de réaction peuvent ainsi envoyer deux répétitions rapprochées, sans dépasser le rythme moyen.
	local now = os.clock()
	local allowed = math.floor((now - run.startedAt) / (spec.interval * Balance.RepIntervalTolerance)) + 1
	if run.reps >= allowed or now - run.lastRepAt < MIN_GAP then
		return
	end
	if not MinigameService.IsNear(player, spec.anchor) then
		MinigameService.EndRun(player, "TooFar")
		return
	end

	run.lastRepAt = now
	run.reps += 1
	run.manual += 1
	run.points += Balance.Grade.Points[quality] or 0
	-- Combo : un raté le remet à zéro
	if quality == "Miss" then
		run.streak = 0
	else
		run.streak += 1
	end
	local combo = MinigameService.ComboMultiplier(run.streak)
	if run.playground then
		run.streak = run.playground.streak or 0
		combo = Playground.Combo(run.playground)
	end
	local gain = if spec.onRep then spec.onRep(player, quality, combo, run.payoutScale or 1, run.playground) else nil

	-- Le run a pu être terminé par onRep
	if runs[player] ~= run then
		return
	end
	Remotes.SeriesUpdate:FireClient(player, {
		state = "Rep",
		kind = spec.kind,
		reps = run.reps,
		quality = quality,
		gain = gain,
		streak = run.streak,
		combo = combo,
	})
	broadcast(player, spec, "Rep", quality, run.streak)
	if run.reps >= spec.total then
		MinigameService.EndRun(player, "Completed")
	end
end

-- Input is an intent, never a score. A per-run token prevents stale/replayed actions.
function MinigameService.GetPlaygroundInput(player)
	local run = runs[player]
	return run and MinigameService.IsNear(player, run.spec.anchor) and run.duelHeld == true
end

function MinigameService.SetDuelState(player, state)
	local run = runs[player]
	if run and run.spec.kind == "Duel" then
		Remotes.PlaygroundState:FireClient(player, { token = run.token, duel = state })
	end
end

local function onPlaygroundInput(player, token, sequence, kind, x, y, sentAt)
	local run = runs[player]
	if not run or not run.token or token ~= run.token then
		return
	end
	if
		typeof(sequence) ~= "number"
		or sequence ~= sequence
		or sequence % 1 ~= 0
		or sequence <= run.sequence
		or sequence > run.sequence + 1000
	then
		return
	end
	if
		typeof(x) ~= "number"
		or typeof(y) ~= "number"
		or x ~= x
		or y ~= y
		or math.abs(x) == math.huge
		or math.abs(y) == math.huge
	then
		return
	end
	if kind ~= "down" and kind ~= "up" and kind ~= "move" and kind ~= "undo" then
		return
	end
	local now = os.clock()
	run.budget = math.min(PlaygroundConfig.InputBurst, run.budget + (now - run.lastBudget) * PlaygroundConfig.InputRate)
	run.lastBudget = now
	if run.budget < 1 then
		return
	end
	run.budget -= 1
	run.sequence = sequence
	run.lastInput = now
	if run.spec.kind == "Duel" then
		if kind == "down" then
			run.duelHeld = true
		elseif kind == "up" then
			run.duelHeld = false
		end
		return
	end
	if not run.playground then
		return
	end
	-- Bounded latency allowance for rhythm only; never accept a client grade or unrestricted rewind.
	local lag = if typeof(sentAt) == "number" and sentAt == sentAt
		then math.clamp(workspace:GetServerTimeNow() - sentAt, 0, PlaygroundConfig.TimingGrace)
		else 0
	run.playground.inputTime = run.playground.t - lag
	Playground.Input(run.playground, kind, x, y)
	run.playground.inputTime = nil
end

local function stepPlaygrounds(dt)
	local now = os.clock()
	for player, run in runs do
		if run.token and now - run.lastInput > PlaygroundConfig.InputTimeout then
			run.duelHeld = false
			if run.playground then
				run.playground.held = false
			end
		end
		if run.token and (not player.Character or not MinigameService.IsNear(player, run.spec.anchor)) then
			MinigameService.EndRun(player, "TooFar")
			continue
		end
		local state = run.playground
		if not state then
			continue
		end
		if not player.Character or not MinigameService.IsNear(player, run.spec.anchor) then
			MinigameService.EndRun(player, "TooFar")
			continue
		end
		Playground.Step(state, dt)
		if now >= run.nextSnapshot then
			run.nextSnapshot = now + PlaygroundConfig.SnapshotInterval
			Remotes.PlaygroundState:FireClient(
				player,
				{ token = run.token, state = Playground.Snapshot(state), sequence = run.sequence }
			)
			for _, viewer in Players:GetPlayers() do
				if MinigameService.IsNear(viewer, run.spec.anchor, PlaygroundConfig.SpectatorDistance) then
					Remotes.Activity:FireClient(
						viewer,
						{ player = player, state = "Playground", gameState = Playground.Snapshot(state) }
					)
				end
			end
		end
		if state.finished then
			if not run.finishAt then
				run.finishAt = now + PlaygroundConfig.ResultPause
				run.payoutScale = Playground.Payout(state)
			elseif now >= run.finishAt then
				onRep(player, Playground.Quality(state), true)
			end
		end
	end
end

function MinigameService.Init(services)
	SeatService = services.SeatService
end

function MinigameService.Start()
	Remotes.PlaygroundInput.OnServerEvent:Connect(onPlaygroundInput)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += math.min(dt, 0.25)
		while accumulator >= PlaygroundConfig.Step do
			accumulator -= PlaygroundConfig.Step
			stepPlaygrounds(PlaygroundConfig.Step)
		end
	end)
	-- Corps du joueur pendant une activité (ActivityController) : allongé sur un banc ou suspendu à une barre,
	-- il traverse le décor au lieu de pousser le personnage
	PhysicsService:RegisterCollisionGroup("ActivityBody")
	PhysicsService:CollisionGroupSetCollidable("ActivityBody", "Default", false)
	PhysicsService:CollisionGroupSetCollidable("ActivityBody", "ActivityBody", false)
	Remotes.Rep.OnServerEvent:Connect(function(player, quality)
		onRep(player, quality, false)
	end)
	Remotes.StopSeries.OnServerEvent:Connect(function(player)
		MinigameService.EndRun(player, "Stopped")
	end)
	Players.PlayerRemoving:Connect(function(player)
		MinigameService.EndRun(player, "Left")
	end)
end

return MinigameService
