-- Les activités se réalisent vraiment dans le monde (décision D37) : quand un joueur (soi-même ou un autre)
-- fait une série, son personnage fait chaque répétition que le serveur a validée, avec l'amplitude de sa
-- qualité (Perfect : mouvement complet ; Good : presque ; Miss : à moitié et en tremblant).
-- Chaque client anime tous les personnages localement à partir du signal Activity du serveur.
-- Une activité = un module dans src/client/Activities/ (Stand, new, Pose, Destroy), nommé comme l'exercice ou
-- l'aide (Curl, OpenJar…). Pose(p, shake, u, time, count) : count = répétitions commencées (le clou s'enfonce…).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
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
	borrowed: { [BasePart]: { cframe: CFrame, transparency: number } },
}

local localPlayer = Players.LocalPlayer
local animators: { [Player]: Animator } = {}

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

local function stop(player: Player)
	local animator = animators[player]
	if not animator then
		return
	end
	animators[player] = nil
	animator.activity:Destroy()
	animator.rig:Release()
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

local function start(update)
	local player = update.player
	stop(player)
	local module = Activities:FindFirstChild(update.id)
	local anchor = update.anchor
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if (update.kind ~= "Exercise" and update.kind ~= "Help") or not module or not anchor or not humanoid then
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
		elseif update.state == "Ended" then
			stop(update.player)
		end
	end)
	Players.PlayerRemoving:Connect(stop)
	-- Après l'Animator de Roblox et avant la physique : la pose écrite gagne
	RunService.PreSimulation:Connect(step)
end

return ActivityController
