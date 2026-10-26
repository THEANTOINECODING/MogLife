-- Moteur générique des « runs » de mini-jeu : une série d'exercice, une aide en ville, une manche de boss.
-- Le client envoie seulement la qualité de chaque répétition ; ce moteur vérifie la cadence, la distance,
-- puis délègue la récompense au service qui a lancé le run (onRep / onEnd).

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

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
	level: number?, -- difficulté du mini-jeu (0, 1, 2… : débloque ses surprises, Balance.Minigames, D81)
	titleKey: string?, -- texte affiché en haut du run (clé Texts)
	titleArgs: { [string]: any }?,
	-- Appelé pour chaque répétition validée ; renvoie le gain à afficher (ou nil).
	-- combo : multiplicateur du combo en cours (Balance.Combo), à appliquer au gain si le run en profite
	onRep: ((player: Player, quality: string, combo: number) -> number?)?,
	-- Appelé à la fin du run, quelle qu'en soit la raison. score : précision (0-100) des répétitions jouées à la
	-- main, nil si la série n'est pas notée. Peut renvoyer des infos à ajouter au message de fin (ex. record).
	onEnd: ((player: Player, reason: EndReason, reps: number, score: number?) -> { [string]: any }?)?,
}

type Run = {
	spec: RunSpec,
	reps: number,
	streak: number, -- répétitions réussies d'affilée (combo)
	points: number, -- points de précision des répétitions jouées à la main (Balance.Grade)
	manual: number, -- répétitions jouées à la main
	startedAt: number,
	lastRepAt: number,
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

-- Niveau du mini-jeu. Dans Studio seulement, l'attribut DevMinigameLevel (sur ServerStorage, ou sur le joueur) force
-- un niveau minimum pour tester toutes les surprises sans changer de stade ; aucun effet dans le jeu publié.
local function levelFor(player: Player, spec: RunSpec): number
	local level = spec.level or 0
	local forced = player:GetAttribute("DevMinigameLevel") or ServerStorage:GetAttribute("DevMinigameLevel")
	if RunService:IsStudio() and typeof(forced) == "number" then
		level = math.max(level, forced)
	end
	return level
end

-- Lance un run. Renvoie false si le joueur est déjà occupé.
function MinigameService.StartRun(player: Player, spec: RunSpec): boolean
	if runs[player] then
		return false
	end
	-- Assis sur un banc ou un canapé : il se relève pour l'activité
	SeatService.StandUp(player)
	runs[player] = { spec = spec, reps = 0, streak = 0, points = 0, manual = 0, startedAt = os.clock(), lastRepAt = 0 }
	-- Visible de tous : les autres clients ne proposent pas de duel à un joueur occupé
	player:SetAttribute("InRun", true)
	Remotes.SeriesUpdate:FireClient(player, {
		state = "Started",
		kind = spec.kind,
		id = spec.id,
		minigame = spec.minigame,
		interval = spec.interval,
		total = spec.total,
		timingScale = spec.timingScale,
		seed = spec.seed,
		level = levelFor(player, spec),
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
	local extra = if run.spec.onEnd then run.spec.onEnd(player, reason, run.reps, score) else nil
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

local function onRep(player: Player, quality: unknown)
	local run = runs[player]
	if not run then
		return
	end
	if typeof(quality) ~= "string" or Balance.Quality[quality] == nil then
		return
	end
	local spec = run.spec

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
	local gain = if spec.onRep then spec.onRep(player, quality, combo) else nil

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

function MinigameService.Init(services)
	SeatService = services.SeatService
end

function MinigameService.Start()
	-- Corps du joueur pendant une activité (ActivityController) : allongé sur un banc ou suspendu à une barre,
	-- il traverse le décor au lieu de pousser le personnage
	PhysicsService:RegisterCollisionGroup("ActivityBody")
	PhysicsService:CollisionGroupSetCollidable("ActivityBody", "Default", false)
	PhysicsService:CollisionGroupSetCollidable("ActivityBody", "ActivityBody", false)
	Remotes.Rep.OnServerEvent:Connect(onRep)
	Remotes.StopSeries.OnServerEvent:Connect(function(player)
		MinigameService.EndRun(player, "Stopped")
	end)
	Players.PlayerRemoving:Connect(function(player)
		MinigameService.EndRun(player, "Left")
	end)
end

return MinigameService
