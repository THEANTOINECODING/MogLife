-- Moteur générique des « runs » de mini-jeu : une série d'exercice, une aide en ville, une manche de boss.
-- Le client envoie seulement la qualité de chaque répétition ; ce moteur vérifie la cadence, la distance,
-- le mode auto, puis délègue la récompense au service qui a lancé le run (onRep / onEnd).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type EndReason = "Completed" | "Stopped" | "TooFar" | "Left"

export type RunSpec = {
	kind: "Exercise" | "Help" | "Boss",
	id: string, -- exerciseId, helpId ou bossId
	minigame: string, -- module dans src/client/Minigames/
	interval: number, -- durée d'une répétition (secondes)
	total: number, -- nombre de répétitions du run
	anchor: BasePart, -- le joueur doit rester près de cette pièce
	autoAllowed: boolean,
	timingScale: number?, -- < 1 = fenêtres de timing plus serrées (combats de boss)
	titleKey: string?, -- texte affiché en haut du run (clé Texts)
	titleArgs: { [string]: any }?,
	-- Appelé pour chaque répétition validée ; renvoie le gain à afficher (ou nil)
	onRep: ((player: Player, quality: string) -> number?)?,
	-- Appelé à la fin du run, quelle qu'en soit la raison
	onEnd: ((player: Player, reason: EndReason, reps: number) -> ())?,
}

type Run = {
	spec: RunSpec,
	reps: number,
	startedAt: number,
	lastRepAt: number,
}

-- Écart minimum absolu entre deux répétitions (évite les doublons d'un même geste)
local MIN_GAP = 0.15

local runs: { [Player]: Run } = {}

local MinigameService = {}

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
	runs[player] = { spec = spec, reps = 0, startedAt = os.clock(), lastRepAt = 0 }
	Remotes.SeriesUpdate:FireClient(player, {
		state = "Started",
		kind = spec.kind,
		id = spec.id,
		minigame = spec.minigame,
		interval = spec.interval,
		total = spec.total,
		autoAllowed = spec.autoAllowed,
		timingScale = spec.timingScale,
		titleKey = spec.titleKey,
		titleArgs = spec.titleArgs,
	})
	return true
end

function MinigameService.EndRun(player: Player, reason: EndReason)
	local run = runs[player]
	if not run then
		return
	end
	runs[player] = nil
	if reason ~= "Left" then
		Remotes.SeriesUpdate:FireClient(player, {
			state = "Ended",
			kind = run.spec.kind,
			id = run.spec.id,
			reason = reason,
			reps = run.reps,
		})
	end
	if run.spec.onEnd then
		run.spec.onEnd(player, reason, run.reps)
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
	if quality == "Auto" and not spec.autoAllowed then
		return
	end

	-- Quota : jamais plus de répétitions que le temps écoulé ne le permet (+1 d'avance).
	-- Les jeux de réaction peuvent ainsi envoyer deux répétitions rapprochées, sans dépasser le rythme moyen.
	local now = os.clock()
	local allowed = math.floor((now - run.startedAt) / (spec.interval * Balance.RepIntervalTolerance)) + 1
	if run.reps >= allowed or now - run.lastRepAt < MIN_GAP then
		return
	end
	-- Le mode auto garde un rythme strictement régulier
	if quality == "Auto" and now - run.lastRepAt < spec.interval * Balance.RepIntervalTolerance then
		return
	end
	if not MinigameService.IsNear(player, spec.anchor) then
		MinigameService.EndRun(player, "TooFar")
		return
	end

	run.lastRepAt = now
	run.reps += 1
	local gain = if spec.onRep then spec.onRep(player, quality) else nil

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
	})
	if run.reps >= spec.total then
		MinigameService.EndRun(player, "Completed")
	end
end

function MinigameService.Start()
	Remotes.Rep.OnServerEvent:Connect(onRep)
	Remotes.StopSeries.OnServerEvent:Connect(function(player)
		MinigameService.EndRun(player, "Stopped")
	end)
	Players.PlayerRemoving:Connect(function(player)
		MinigameService.EndRun(player, "Left")
	end)
end

return MinigameService
