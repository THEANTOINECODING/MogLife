-- Les activités se réalisent vraiment dans le monde (décision D37) : quand un joueur (soi-même ou un autre)
-- fait une série, son personnage fait chaque répétition que le serveur a validée, avec l'amplitude de sa
-- qualité (Perfect : mouvement complet ; Good : presque ; Miss : à moitié et en tremblant).
-- Chaque client anime tous les personnages localement à partir du signal Activity du serveur.
-- Une activité = un module dans src/client/Activities/ (Stand, new, Pose, Destroy), nommé comme l'exercice ou
-- l'aide (Curl, OpenJar…). Pose(p, shake, u, time, count) : count = répétitions commencées (le clou s'enfonce…).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CameraFraming = require(script.Parent.Parent.CameraFraming)
local MogOff = require(script.Parent.Parent.Activities.MogOff)
local Rig = require(script.Parent.Parent.Activities.Rig)

local Activities = script.Parent.Parent.Activities

-- Amplitude et tremblement du mouvement selon la qualité de la répétition
local QUALITY = {
	Perfect = { amplitude = 1, shake = 0 },
	Good = { amplitude = 0.85, shake = 0.15 },
	Auto = { amplitude = 0.8, shake = 0 },
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
	sweat: ParticleEmitter?, -- sueur qui coule de plus en plus fort avec le combo (exercices et aides)
	borrowed: { [BasePart]: { cframe: CFrame, transparency: number } },
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

-- Gros plan pendant sa propre série : la caméra regarde le personnage de face, un peu de côté, et le place dans la
-- partie gauche de l'écran (le mini-jeu est à droite). Elle suit le corps (pompes, tractions, voiture poussée…).
local closeUp: RBXScriptConnection? = nil
local closeUpFader: CameraFraming.Fader? = nil
-- preset : réglage de caméra propre à l'activité (module Activities : CloseUp = { steps, height }), facultatif
-- animator : pour ignorer les objets que le personnage tient ou utilise (piano, barre, bocal…)
startCloseUp = function(character: Model, preset: any, anchor: BasePart?, animator: any)
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
	stopCloseUp()
	local camera = Workspace.CurrentCamera
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local torso = character:FindFirstChild("UpperTorso") :: BasePart?
	if not camera or not root or not torso then
		return
	end
	local startedAt = os.clock()
	local facing = root.CFrame -- orientation du personnage au début (il ne tourne pas pendant la série)
	-- Distance selon la taille du corps
	local extent = character:GetExtentsSize()
	local distance = 6 + extent.Y * 0.9
	camera.CameraType = Enum.CameraType.Scriptable
	-- Angle sans obstacle (murs du garage, toit, meubles) : recalculé deux fois par seconde (le personnage peut se
	-- déplacer, ex. en poussant la voiture), la caméra y glisse en douceur
	local eye: Vector3? = nil
	local nextCheck = 0
	local nextFade = 0
	closeUpFader = CameraFraming.NewFader()
	closeUp = RunService.RenderStepped:Connect(function(dt)
		if not torso.Parent then
			return
		end
		local focus = torso.Position
		local now = os.clock()
		if now >= nextCheck then
			nextCheck = now + 0.5
			local steps = preset and preset.steps
			local height = (preset and preset.height) or 1.5
			local wanted = CameraFraming.Best(
				focus,
				CameraFraming.Around(facing.LookVector, distance, height, 1, steps),
				-- La dalle ou la station de l'activité ne gêne jamais la vue
				activityParts(),
				CameraFraming.BodyPoints(character)
			)
			eye = if eye then eye:Lerp(wanted, 0.5) else wanted
		end
		local target = eye :: Vector3
		-- Le personnage à gauche de l'écran (le mini-jeu est à droite) : on vise un peu à droite de lui
		local look = (focus - target).Unit
		local right = look:Cross(Vector3.new(0, 1, 0))
		local aim = focus + right * (distance * 0.3)
		local wanted = CFrame.lookAt(target, aim)
		local blend = math.clamp((now - startedAt) / 0.6, 0, 1)
		local follow = if blend < 1 then blend * blend * (3 - 2 * blend) else math.min(dt * 6, 1)
		camera.CFrame = camera.CFrame:Lerp(wanted, follow)
		-- Ce qui reste entre la caméra et le corps (PNJ, arbre) est estompé
		if now >= nextFade and closeUpFader then
			nextFade = now + 0.15
			CameraFraming.Fade(
				closeUpFader,
				camera.CFrame.Position,
				CameraFraming.BodyPoints(character),
				activityParts()
			)
		end
	end)
end

stopCloseUp = function()
	if closeUpFader then
		CameraFraming.ClearFade(closeUpFader)
		closeUpFader = nil
	end
	if closeUp then
		closeUp:Disconnect()
		closeUp = nil
		local camera = Workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
		end
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
	-- Exercices et aides : un module par activité ; combats de boss : le Mog-off (duel de poses), pour tous les boss
	local module = Activities:FindFirstChild(if update.kind == "Boss" then "MogOff" else update.id)
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

	-- Son propre personnage : placé au bon endroit de la station, sans se tourner tout seul
	if player == localPlayer then
		humanoid.AutoRotate = false
		rig.root.CFrame = Activity.Stand(top) * CFrame.new(0, humanoid.HipHeight + rig.root.Size.Y / 2, 0)
		rig.root.AssemblyLinearVelocity = Vector3.zero
		setBodyGroup(character, BODY_GROUP)
	end

	local animator: Animator = {
		player = player,
		character = character,
		rig = rig,
		activity = nil,
		interval = update.interval,
		reps = {},
		count = 0,
		borrowed = {},
	}
	animator.activity = Activity.new({
		rig = rig,
		measures = rig:Measure(humanoid),
		character = character,
		anchor = anchor,
		top = top,
		borrow = borrower(animator, anchor),
		isLocal = player == localPlayer, -- seul le joueur concerné déplace son propre personnage
	})
	animators[player] = animator
	if update.kind ~= "Boss" then
		animator.sweat = addSweat(character)
		if player == localPlayer and SettingsController.Get("CloseUp") then
			startCloseUp(character, Activity.CloseUp, anchor, animator)
		end
	end
end

local function onRep(update)
	local animator = animators[update.player]
	local quality = QUALITY[update.quality]
	if not animator or not quality then
		return
	end
	local now = os.clock()
	local last = animator.reps[#animator.reps]
	local duration = math.clamp(animator.interval * 0.8, 0.45, 1.1)
	animator.count += 1
	-- Plus le combo est long, plus ça transpire
	if animator.sweat then
		local streak = math.min(update.streak or 0, 15)
		animator.sweat.Rate = if streak == 0 then 1.5 else 3 + streak * 1.6
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
		animator.activity:Pose(p, shake, u, now, animator.count)
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

function ActivityController.Init(controllers)
	SettingsController = controllers.SettingsController
end

function ActivityController.Start()
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
		end
	end)
	Remotes.EmotePlay.OnClientEvent:Connect(function(who, index)
		if typeof(who) == "Instance" and who:IsA("Player") and typeof(index) == "number" then
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
