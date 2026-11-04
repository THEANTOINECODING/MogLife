-- Les activités se réalisent vraiment dans le monde (décision D37) : quand un joueur (soi-même ou un autre)
-- fait une série, son personnage fait chaque répétition que le serveur a validée, avec l'amplitude de sa
-- qualité (Perfect : mouvement complet ; Good : presque ; Miss : à moitié et en tremblant).
-- Chaque client anime tous les personnages localement à partir du signal Activity du serveur.
-- Une activité = un module dans src/client/Activities/ (Stand, new, Pose, Destroy), nommé comme l'exercice ou
-- l'aide (Curl, OpenJar…). Pose(p, shake, u, time, count, successes) : count = répétitions commencées (le clou
-- s'enfonce…), successes = répétitions réussies (Good ou Perfect : le transat n'est posé que s'il est réussi).
-- Son propre personnage bouge au moment exact du geste dans le mini-jeu (LocalRep, D82), sans attendre le serveur.
-- Activity.ActionPhase (facultatif) : moment de la répétition (0 à 1) qui tombe sur le geste (la corde : l'impulsion
-- du saut à 0,5).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CameraFraming = require(script.Parent.Parent.CameraFraming)
local Ground = require(script.Parent.Parent.Ground)
local MogOff = require(script.Parent.Parent.Activities.MogOff)
local BossScene = require(script.Parent.Parent.BossFights.Scene)
local Rig = require(script.Parent.Parent.Activities.Rig)

local Activities = script.Parent.Parent.Activities
-- Duels de boss (D85) : un module par boss ; sans module, le Mog-off générique (poses de culturisme)
local BossFights = script.Parent.Parent.BossFights

-- Amplitude et tremblement du mouvement selon la qualité de la répétition
local QUALITY = {
	Perfect = { amplitude = 1, shake = 0 },
	Good = { amplitude = 0.85, shake = 0.15 },
	Miss = { amplitude = 0.45, shake = 1 },
}
-- Groupe de collision du corps pendant une activité (créé par MinigameService) : allongé sur un banc ou
-- suspendu à une barre, il ne doit pas pousser le personnage
local BODY_GROUP = "ActivityBody"

type Rep = { start: number, duration: number, amplitude: number, shake: number }

type Animator = {
	player: Player,
	character: Model,
	rig: Rig.Rig,
	activity: any,
	interval: number,
	reps: { Rep },
	count: number, -- répétitions commencées depuis le début du run
	successes: number, -- répétitions réussies (Good ou Perfect)
	kind: string,
	localDriven: boolean, -- son propre personnage, animé par les gestes du mini-jeu plutôt que par le serveur
	sweat: ParticleEmitter?, -- sueur qui coule de plus en plus fort avec le combo (exercices et aides)
	borrowed: { [BasePart]: { cframe: CFrame, transparency: number } },
	anchored: boolean?, -- son propre personnage, tenu en place pendant l'activité
	startedAt: number,
}

local localPlayer = Players.LocalPlayer
local addSweat: (Model) -> ParticleEmitter?
local startCloseUp: (Model, any, BasePart?, any) -> ()
local stopCloseUp: () -> ()
local animators: { [Player]: Animator } = {}
local SettingsController
-- Émotes (poses de culturisme, hors activité) : vues par tout le monde
type Emote = { character: Model, rig: Rig.Rig, measures: any, index: number, start: number }
local emotes: { [Player]: Emote } = {}

local ActivityController = {}

-- Montée, court maintien en haut, descente (courbe douce)
local function effort(u: number): number
	local function smooth(x: number): number
		x = math.clamp(x, 0, 1)
		return x * x * (3 - 2 * x)
	end
	if u < 0.4 then
		return smooth(u / 0.4)
	elseif u < 0.55 then
		return 1
	end
	return smooth(1 - (u - 0.55) / 0.45)
end

-- Décor de la station pris en main (barre, haltère, corde, piano, voiture…) : rendu tel quel à la fin.
-- radius : distance de recherche autour de la station (8 studs par défaut)
local function borrower(animator: Animator, anchor: BasePart)
	return function(name: string, hide: boolean?, radius: number?): BasePart?
		local folder = workspace:FindFirstChild("MapProps")
		local best, bestDistance = nil, radius or 8
		for _, part in if folder then folder:GetChildren() else {} do
			if part.Name == name and part:IsA("BasePart") then
				local distance = (part.Position - anchor.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = part, distance
				end
			end
		end
		if best and not animator.borrowed[best] then
			animator.borrowed[best] = { cframe = best.CFrame, transparency = best.Transparency }
			if hide then
				best.Transparency = 1
			end
		end
		return best
	end
end

local function setBodyGroup(character: Model, group: string)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CollisionGroup = group
		end
	end
end

-- Gouttes de sueur qui perlent du front et tombent (une émission plus forte avec le combo)
addSweat = function(character: Model): ParticleEmitter?
	local head = character:FindFirstChild("Head")
	if not head then
		return nil
	end
	local sweat = Instance.new("ParticleEmitter")
	sweat.Name = "Sweat"
	sweat.Color = ColorSequence.new(Color3.fromRGB(170, 220, 255))
	sweat.LightEmission = 0.3
	sweat.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	sweat.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0.08) })
	sweat.Lifetime = NumberRange.new(0.5, 0.9)
	sweat.Speed = NumberRange.new(2, 4)
	sweat.SpreadAngle = Vector2.new(60, 60)
	sweat.Acceleration = Vector3.new(0, -30, 0)
	sweat.Rate = 1.5
	sweat.Parent = head
	return sweat
end

-- Gros plan pendant sa propre série : caméra stable (CameraFraming.Follow) qui choisit une fois l'angle d'où l'on
-- voit tout le corps, place le personnage (et ce qu'il manipule) dans la partie de l'écran que l'interface du
-- mini-jeu laisse libre (D86) et ne bouge plus, sauf vrai déplacement (voiture poussée), interface déplacée (écran
-- tourné) ou mur qui cache durablement le corps.
local stopFollow: (() -> ())? = nil
local closeUpToken: any = nil
local SETTLE_TIME = 0.35 -- secondes avant de choisir l'angle
local MIN_DISTANCE = 6 -- studs : la caméra ne vient pas plus près (le personnage reste lisible en entier)
-- preset : réglage de caméra propre à l'activité (module Activities : CloseUp = { steps, height, scale, focus, room }),
-- facultatif ; room : marge au-dessus de la tête (saut, traction)
-- animator : pour ignorer les objets que le personnage tient ou utilise (piano, barre, bocal…)
startCloseUp = function(character: Model, preset: any, anchor: BasePart?, animator: any)
	stopCloseUp()
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	-- La station et les objets de l'activité ne gênent jamais la vue et ne sont jamais estompés
	local function activityParts(): { Instance }
		local list: { Instance } = {}
		if anchor then
			table.insert(list, anchor)
		end
		for part in (animator and animator.borrowed) or {} do
			table.insert(list, part)
		end
		return list
	end
	-- Mesures du corps au repos : hauteur (pieds -> sommet de la tête) et largeur, pour tout faire tenir à l'écran
	local _, size = character:GetBoundingBox()
	local height = math.max(size.Y, 4)
	local width = math.max(size.X, size.Z)
	-- Distance pour voir le corps entier dans la moitié gauche de l'écran, avec de la marge pour les mouvements
	local distance = (6 + math.max(height, width) * 1.1) * ((preset and preset.scale) or 1)
	local camHeight = (preset and preset.height) or 1.5
	local steps = preset and preset.steps
	-- Centre du corps au repos, par rapport à la racine (les répétitions ne le déplacent pas)
	-- (focus : décalage vertical propre à l'activité, ex. suspendu à la barre de traction, le corps monte)
	local focusUp = (preset and preset.focus) or 0
	local room = (preset and preset.room) or 0.6
	local centerOffset = Vector3.new(0, height * 0.5 - humanoid.HipHeight - root.Size.Y / 2 + focusUp, 0)
	-- L'activité place et tourne le personnage dans ses premières images : on attend qu'il soit en position
	local token = {}
	closeUpToken = token
	task.wait(SETTLE_TIME)
	-- On attend aussi que l'interface du mini-jeu soit là : sinon la caméra se placerait pour tout l'écran puis
	-- reculerait d'un coup à son arrivée (D87)
	local waited = 0
	while not CameraFraming.HasFreeArea() and waited < 1 do
		waited += task.wait(0.05)
	end
	if closeUpToken ~= token or not root.Parent then
		return
	end
	stopFollow = CameraFraming.Follow({
		anchor = function()
			return if root.Parent then root.Position else nil
		end,
		plan = function()
			local focus = root.Position + centerOffset
			-- Le personnage et ce qu'il manipule tiennent dans la partie de l'écran que le mini-jeu laisse libre
			-- (entre la colonne d'infos et le panneau du jeu sur téléphone, D86)
			local props = activityParts()
			for _, child in workspace:GetChildren() do
				if child:GetAttribute("ActivityProps") then
					table.insert(props, child)
				end
			end
			return CameraFraming.Frame(
				focus,
				-- Orientation réelle au moment du choix (certaines activités tournent le personnage au départ)
				CameraFraming.Around(root.CFrame.LookVector, distance, camHeight, 1, steps),
				activityParts(),
				CameraFraming.SubjectPoints(character, props, room),
				MIN_DISTANCE
			)
		end,
		points = function()
			return CameraFraming.BodyPoints(character)
		end,
		ignore = activityParts,
	})
end

stopCloseUp = function()
	closeUpToken = nil
	if stopFollow then
		stopFollow()
		stopFollow = nil
	end
end

local function stop(player: Player)
	local animator = animators[player]
	if not animator then
		return
	end
	animators[player] = nil
	animator.activity:Destroy()
	animator.rig:Release()
	if animator.sweat then
		animator.sweat:Destroy()
	end
	if player == localPlayer then
		stopCloseUp()
	end
	for part, saved in animator.borrowed do
		part.CFrame = saved.cframe
		part.Transparency = saved.transparency
	end
	if player == localPlayer and animator.character.Parent then
		local humanoid = animator.character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.AutoRotate = true
		end
		if animator.anchored and animator.rig.root.Parent then
			animator.rig.root.Anchored = false
		end
		setBodyGroup(animator.character, "Default")
	end
end

local function stopEmote(player: Player)
	local emote = emotes[player]
	if emote then
		emotes[player] = nil
		emote.rig:Release()
	end
end

-- Un joueur prend une pose (émote validée par le serveur) : montée, maintien, retour
local function playEmote(player: Player, index: number)
	if animators[player] then
		return
	end
	stopEmote(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rig = character and Rig.new(character)
	if not humanoid or not rig then
		return
	end
	emotes[player] = {
		character = character :: Model,
		rig = rig,
		measures = rig:Measure(humanoid),
		index = index,
		start = os.clock(),
	}
end

local function start(update)
	local player = update.player
	stop(player)
	stopEmote(player)
	-- Exercices et aides : un module par activité ; combats de boss : le duel du boss (D85), sinon le Mog-off
	local module = if update.kind == "Boss"
		then (BossFights:FindFirstChild(update.id) or Activities:FindFirstChild("MogOff"))
		else Activities:FindFirstChild(update.id)
	local anchor = update.anchor
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not module or not anchor or not humanoid then
		return
	end
	local rig = Rig.new(character)
	if not rig then
		return
	end
	local Activity = require(module)
	local top = anchor.CFrame * CFrame.new(0, anchor.Size.Y / 2, 0)

	-- Son propre personnage : placé au bon endroit de la station, les pieds sur le vrai sol (D86), sans se tourner
	-- tout seul. Il est tenu en place pendant l'activité : la physique ne le fait plus flotter au-dessus d'un rebord
	-- de dalle ni glisser pendant les mouvements.
	local anchored = false
	if player == localPlayer then
		humanoid.AutoRotate = false
		local stand = Activity.Stand(top)
		local ground = Ground.Height(stand.Position) or stand.Y
		rig.root.CFrame = CFrame.new(stand.X, ground, stand.Z)
			* stand.Rotation
			* CFrame.new(0, humanoid.HipHeight + rig.root.Size.Y / 2, 0)
		rig.root.AssemblyLinearVelocity = Vector3.zero
		setBodyGroup(character, BODY_GROUP)
		if update.kind ~= "Duel" then
			rig.root.Anchored = true
			anchored = true
		end
	end

	local animator: Animator = {
		player = player,
		character = character,
		rig = rig,
		activity = nil,
		interval = update.interval,
		reps = {},
		count = 0,
		successes = 0,
		kind = update.kind,
		localDriven = false,
		borrowed = {},
		anchored = anchored,
		startedAt = os.clock(),
	}
	animator.activity = Activity.new({
		minigame = update.minigame,
		rig = rig,
		measures = rig:Measure(humanoid),
		character = character,
		anchor = anchor,
		top = top,
		borrow = borrower(animator, anchor),
		isLocal = player == localPlayer, -- seul le joueur concerné déplace son propre personnage
		player = player,
	})
	animators[player] = animator
	if update.kind ~= "Boss" then
		animator.sweat = addSweat(character)
		-- Duel : DuelController filme les deux joueurs (pas de gros plan sur soi seul)
		if player == localPlayer and update.kind ~= "Duel" and SettingsController.Get("CloseUp") then
			task.spawn(startCloseUp, character, Activity.CloseUp, anchor, animator)
		end
	end
end

local function onRep(update)
	local animator = animators[update.player]
	local quality = QUALITY[update.quality]
	if not animator or not quality then
		return
	end
	-- Plus le combo est long, plus ça transpire
	if animator.sweat then
		local streak = math.min(update.streak or 0, 15)
		animator.sweat.Rate = if streak == 0 then 1.5 else 3 + streak * 1.6
	end
	-- Son propre personnage a déjà fait ce mouvement, au moment du geste (LocalRep)
	if animator.localDriven then
		return
	end
	local now = os.clock()
	local last = animator.reps[#animator.reps]
	local duration = math.clamp(animator.interval * 0.8, 0.45, 1.1)
	animator.count += 1
	if update.quality ~= "Miss" then
		animator.successes += 1
	end
	if animator.activity.PlayerRep then
		animator.activity:PlayerRep(update.quality)
	end
	table.insert(animator.reps, {
		-- Une répétition ne coupe jamais la précédente : elle commence quand l'autre se termine
		start = if last then math.max(now, last.start + last.duration) else now,
		duration = duration,
		amplitude = quality.amplitude,
		shake = quality.shake,
	})
end

local function step()
	local now = os.clock()
	for player, animator in animators do
		if not animator.character.Parent or not animator.rig.root.Parent then
			stop(player)
			continue
		end
		-- Répétition en cours (les terminées sont oubliées)
		while animator.reps[1] and now > animator.reps[1].start + animator.reps[1].duration do
			table.remove(animator.reps, 1)
		end
		local rep = animator.reps[1]
		local u, p, shake = 0, 0, 0
		if rep and now >= rep.start then
			u = (now - rep.start) / rep.duration
			p = effort(u) * rep.amplitude
			shake = rep.shake
		end
		animator.rig:Clear()
		animator.activity:Pose(p, shake, u, now, animator.count, animator.successes)
		animator.rig:Apply()
	end
	local duration = Balance.Emotes.Duration
	for player, emote in emotes do
		local t = now - emote.start
		if not emote.character.Parent or not emote.rig.root.Parent or t > duration then
			stopEmote(player)
			continue
		end
		-- 0,25 s pour prendre la pose, maintien, 0,35 s pour la relâcher
		local p = math.clamp(math.min(t / 0.25, (duration - t) / 0.35), 0, 1)
		p = p * p * (3 - 2 * p)
		emote.rig:Clear()
		MogOff.Strike(emote.rig, emote.measures, emote.index, p, 0, now)
		emote.rig:Apply()
	end
end

-- Ce personnage est-il déjà animé ici (activité, combat, duel, émote) ? Les autres mouvements (démarche, pareur,
-- MotionController) le laissent alors tranquille.
local externalBusy: { [Player]: boolean } = {}
function ActivityController.IsBusy(who: Player): boolean
	return animators[who] ~= nil or emotes[who] ~= nil or externalBusy[who] == true
end

-- Un autre système anime ce personnage (fin d'un duel de boss) : les autres mouvements le laissent tranquille
function ActivityController.SetBusy(who: Player, busy: boolean)
	externalBusy[who] = if busy then true else nil
end

-- Geste du joueur dans son mini-jeu (appelé par MinigameKit au moment même du geste) : son personnage fait la
-- répétition tout de suite, au lieu d'attendre la confirmation du serveur (qui peut arriver un peu plus tard)
function ActivityController.LocalRep(quality: string)
	-- Petit coup de caméra (D110), aussi pendant les duels et les combats
	CameraFraming.Kick(quality)
	local animator = animators[localPlayer]
	local look = QUALITY[quality]
	-- Duel : les deux bras sont animés ensemble par le serveur (ArmWrestle)
	if not animator or not look or animator.kind == "Duel" then
		return
	end
	animator.localDriven = true
	local now = os.clock()
	local duration = math.clamp(animator.interval * 0.8, 0.45, 1.1)
	local phase = animator.activity.ActionPhase or 0
	animator.count += 1
	if quality ~= "Miss" then
		animator.successes += 1
	end
	if animator.activity.PlayerRep then
		animator.activity:PlayerRep(quality)
	end
	-- Le geste remplace le mouvement en cours : le personnage suit le rythme du joueur
	animator.reps = {
		{ start = now - phase * duration, duration = duration, amplitude = look.amplitude, shake = look.shake },
	}
end

function ActivityController.Init(controllers)
	SettingsController = controllers.SettingsController
	BossScene.Connect(ActivityController.SetBusy, controllers.NpcController.Base)
end

function ActivityController.Start()
	-- Filet de sécurité (D88) : sa propre série est finie (mini-jeu fermé) mais l'animation n'a pas reçu sa fin :
	-- on la termine, sinon le personnage resterait tenu en place (« plus rien ne marche »)
	Remotes.SeriesUpdate.OnClientEvent:Connect(function(update)
		if typeof(update) == "table" and update.state == "Ended" then
			local animator = animators[localPlayer]
			local endedAt = os.clock()
			task.delay(0.6, function()
				if animators[localPlayer] == animator and animator and animator.startedAt < endedAt then
					stop(localPlayer)
				end
			end)
		end
	end)
	Remotes.Activity.OnClientEvent:Connect(function(update)
		if typeof(update) ~= "table" or typeof(update.player) ~= "Instance" then
			return
		end
		if update.state == "Started" then
			start(update)
		elseif update.state == "Rep" then
			onRep(update)
		elseif update.state == "OpponentRep" then
			local animator = animators[update.player]
			if animator and animator.activity.OpponentRep then
				animator.activity:OpponentRep(update.quality)
			end
		elseif update.state == "Ended" then
			stop(update.player)
		elseif update.state == "Score" then
			-- Scores officiels d'un combat de boss (le sien ou celui d'un autre joueur) : couronne, position du duel
			if typeof(update.score) == "number" and typeof(update.opponent) == "number" then
				BossScene.SetScores(update.player, update.score, update.opponent, update.won)
			end
		elseif update.state == "FightEnd" then
			-- Fin d'un combat de boss (vue par tous) : le duel joue sa fin
			BossScene.Finish(update.player, update.won == true)
		end
	end)
	Remotes.EmotePlay.OnClientEvent:Connect(function(who, index)
		if typeof(who) == "Instance" and who:IsA("Player") and typeof(index) == "number" then
			-- Célébration : la caméra ne zoome plus (D87, zooms jugés désagréables), la pose suffit
			playEmote(who, index)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		stop(player)
		stopEmote(player)
	end)
	-- Après l'Animator de Roblox et avant la physique : la pose écrite gagne
	RunService.PreSimulation:Connect(step)
end

return ActivityController
