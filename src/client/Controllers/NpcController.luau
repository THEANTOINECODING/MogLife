-- Les habitants et les boss prennent vie (D83) : leurs modèles sont une seule pièce 3D, sans squelette ; on anime donc
-- le corps entier, chez chaque joueur (fluide, rien sur le réseau). Réglages dans Config/NpcAnims.luau.
-- - Attitude propre à chacun : respiration, balancement, regards, sautillements (Coach Turbo), affaissement (Kevin
--   dans son canapé), particules (reflets de Brayan, vent du ventilateur du Roi, halo du Dieu du Pump).
-- - Il se tourne vers le joueur proche ; un habitant dont l'aide est disponible sautille pour attirer l'attention.
-- - Réactions : pendant une aide (inquiet au début, content sur une réussite, déçu sur un raté, grande fête avec
--   confettis quand l'aide est réussie) et pendant un combat de boss (il encaisse les Perfect, se moque des ratés).
-- Le serveur met l'attribut « Scripted » pendant ses propres mouvements (boss vaincu qui s'envole) : on le laisse faire.
-- On déplace la pièce du corps (PrimaryPart), toujours droite : les autres pièces éventuelles y sont soudées.
-- Un PNJ avec l'attribut « NpcStill » n'est jamais animé (mannequin du duel d'entraînement).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NpcAnims = require(ReplicatedStorage.Shared.Config.NpcAnims)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local REACTIONS = NpcAnims.Reactions
local CONFETTI = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 210, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 220, 100)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 120, 255)),
})

type Impulse = { kind: string, start: number }
type Entry = {
	model: Model,
	part: BasePart,
	base: CFrame,
	style: NpcAnims.Style,
	phase: number,
	lookYaw: number,
	impulses: { Impulse },
	focus: Player?, -- joueur qui l'aide ou le combat : il le regarde
	confetti: ParticleEmitter?,
}

local HelpController
local entries: { [Model]: Entry } = {}
local runs: { [Player]: Model } = {} -- PNJ concerné par l'aide ou le combat en cours de chaque joueur

local NpcController = {}

local function wave(amplitude: number?, speed: number?, t: number): number
	if not amplitude or amplitude == 0 then
		return 0
	end
	return amplitude * math.sin(2 * math.pi * (speed or 0.3) * t)
end

-- Petit saut régulier : 0 la plupart du temps, une bosse de 0,35 s toutes les `every` secondes
local function hop(every: number, height: number, t: number): number
	local u = t % every
	return if u < 0.35 then height * math.sin(math.pi * u / 0.35) else 0
end

local function addParticles(entry: Entry)
	local style = entry.style
	local part = entry.part
	local top = Instance.new("Attachment")
	top.Name = "NpcFx"
	top.Position = Vector3.new(0, part.Size.Y * 0.45, 0)
	top.Parent = part
	-- Confettis de fête (émis d'un coup)
	local confetti = Instance.new("ParticleEmitter")
	confetti.Name = "Confetti"
	confetti.Color = CONFETTI
	confetti.Size = NumberSequence.new(0.35, 0.25)
	confetti.Lifetime = NumberRange.new(1.2, 1.8)
	confetti.Speed = NumberRange.new(18, 28)
	confetti.SpreadAngle = Vector2.new(55, 55)
	confetti.Acceleration = Vector3.new(0, -35, 0)
	confetti.RotSpeed = NumberRange.new(-300, 300)
	confetti.Rate = 0
	confetti.EmissionDirection = Enum.NormalId.Top
	confetti.Parent = top
	entry.confetti = confetti

	if style.sparkle == "Shine" then
		-- Brayan brille (bronzage huilé)
		local shine = Instance.new("ParticleEmitter")
		shine.Color = ColorSequence.new(Color3.fromRGB(255, 230, 150))
		shine.LightEmission = 1
		shine.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.6),
			NumberSequenceKeypoint.new(1, 0),
		})
		shine.Lifetime = NumberRange.new(0.5, 0.9)
		shine.Speed = NumberRange.new(0.5, 1.5)
		shine.Rate = 6
		shine.SpreadAngle = Vector2.new(180, 180)
		shine.Parent = top
	elseif style.sparkle == "Wind" then
		-- Le ventilateur du Roi souffle devant lui
		local wind = Instance.new("ParticleEmitter")
		wind.Color = ColorSequence.new(Color3.new(1, 1, 1))
		wind.Transparency = NumberSequence.new(0.5, 1)
		wind.Size = NumberSequence.new(0.25, 0.1)
		wind.Lifetime = NumberRange.new(0.5, 0.8)
		wind.Speed = NumberRange.new(14, 20)
		wind.Rate = 18
		wind.SpreadAngle = Vector2.new(15, 25)
		wind.EmissionDirection = Enum.NormalId.Front
		local front = Instance.new("Attachment")
		front.Position = Vector3.new(0, part.Size.Y * 0.1, -part.Size.Z * 0.5)
		front.Parent = part
		wind.Parent = front
	elseif style.sparkle == "Glow" then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 230, 140)
		light.Brightness = 2
		light.Range = 14
		light.Parent = part
		local glow = Instance.new("ParticleEmitter")
		glow.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160))
		glow.LightEmission = 1
		glow.Size = NumberSequence.new(0.5, 0)
		glow.Lifetime = NumberRange.new(0.8, 1.4)
		glow.Speed = NumberRange.new(1, 3)
		glow.Rate = 10
		glow.SpreadAngle = Vector2.new(180, 180)
		glow.Parent = top
	end
end

-- Le décor arrive par morceaux autour du joueur (streaming) : un PNJ peut exister sans sa pièce 3D, ou la perdre en
-- sortant de la zone chargée. On le (re)prend dès que sa pièce arrive.
local watched: { [Model]: boolean } = {}
local function track(model: Instance)
	if not model:IsA("Model") or model:GetAttribute("NpcStill") then
		return
	end
	if not watched[model] then
		watched[model] = true
		model.ChildAdded:Connect(function()
			task.wait()
			track(model)
		end)
		model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(workspace) then
				entries[model] = nil
				watched[model] = nil
			end
		end)
		-- Après un mouvement du serveur (s'envoler, revenir), la position de repos est relue
		model:GetAttributeChangedSignal("Scripted"):Connect(function()
			local entry = entries[model]
			if entry and not model:GetAttribute("Scripted") then
				task.wait()
				entry.base = entry.part.CFrame
			end
		end)
	end
	local existing = entries[model]
	if existing and existing.part:IsDescendantOf(model) then
		return
	end
	local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not part then
		return
	end
	local look = model:GetAttribute("NpcLook")
	local style = (typeof(look) == "string" and NpcAnims.Styles[look]) or NpcAnims.Default
	local entry: Entry = {
		model = model,
		part = part,
		-- Le corps est toujours droit et regarde vers -Z ; le pivot importé de Blender, lui, peut être couché
		base = part.CFrame,
		style = style,
		phase = math.random() * 10,
		lookYaw = 0,
		impulses = {},
	}
	entries[model] = entry
	addParticles(entry)
end

local function react(model: Model?, kind: string)
	local entry = model and entries[model]
	if not entry or not REACTIONS[kind] then
		return
	end
	table.insert(entry.impulses, { kind = kind, start = os.clock() })
	if kind == "Celebrate" and entry.confetti then
		entry.confetti:Emit(NpcAnims.ConfettiCount)
	end
end

-- PNJ le plus proche de la station (anchor) qui porte cet attribut (HelpId ou BossId)
local function npcFor(anchor: Instance?, attribute: string, id: string): Model?
	if not anchor or not anchor:IsA("BasePart") then
		return nil
	end
	local best, bestDistance = nil, 30
	for model in entries do
		if model:GetAttribute(attribute) == id then
			local distance = (model:GetPivot().Position - anchor.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = model, distance
			end
		end
	end
	return best
end

-- Décalage dû aux réactions en cours : hauteur, recul, lacet, tangage, roulis
local function impulseOffset(entry: Entry, now: number): (number, number, number, number, number)
	local y, z, yaw, pitch, roll = 0, 0, 0, 0, 0
	for index = #entry.impulses, 1, -1 do
		local impulse = entry.impulses[index]
		local settings = REACTIONS[impulse.kind]
		local u = (now - impulse.start) / settings.duration
		if u >= 1 then
			table.remove(entry.impulses, index)
			continue
		end
		local bump = math.sin(math.pi * u)
		if impulse.kind == "Happy" or impulse.kind == "Thanks" then
			y += settings.height * bump
		elseif impulse.kind == "Celebrate" then
			y += settings.height * bump
			yaw += 360 * settings.spins * (u * u * (3 - 2 * u))
		elseif impulse.kind == "Sad" then
			yaw += settings.shake * math.sin(u * 6 * math.pi) * (1 - u)
			pitch += 8 * bump -- tête basse
		elseif impulse.kind == "Worried" then
			roll += settings.shake * math.sin(u * 8 * math.pi) * (1 - u)
		elseif impulse.kind == "Hit" or impulse.kind == "HitSmall" then
			pitch -= settings.tilt * bump
			z += settings.push * bump
		elseif impulse.kind == "Taunt" then
			y += settings.height * math.abs(math.sin(2 * math.pi * u))
			roll += settings.wiggle * math.sin(4 * math.pi * u) * (1 - u)
		end
	end
	return y, z, yaw, pitch, roll
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local myRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local now = os.clock()
	for model, entry in entries do
		if not entry.part:IsDescendantOf(model) then
			-- Sorti de la zone chargée : repris quand sa pièce reviendra (ChildAdded)
			entries[model] = nil
			continue
		end
		if model:GetAttribute("Scripted") or model:GetAttribute("NpcStill") then
			continue
		end
		local base = entry.base
		-- Trop loin du joueur (ou de la caméra s'il n'a pas de personnage) : pas animé, pour le téléphone
		local viewer = if myRoot then myRoot.Position elseif camera then camera.CFrame.Position else base.Position
		if (viewer - base.Position).Magnitude > NpcAnims.MaxDistance then
			continue
		end
		local style = entry.style
		local t = now + entry.phase
		local y = wave(style.bob, style.bobSpeed, t)
		if style.float then
			y += style.float * (1 + math.sin(2 * math.pi * (style.bobSpeed or 0.25) * t))
		end
		if style.hopEvery then
			y += hop(style.hopEvery, style.hopHeight or 0.4, t)
		end
		if style.sink and style.sinkEvery then
			-- S'affaisse doucement, puis se redresse d'un coup
			local u = (t % style.sinkEvery) / style.sinkEvery
			y -= style.sink * (if u < 0.85 then u / 0.85 else 1 - (u - 0.85) / 0.15)
		end
		local helpId = model:GetAttribute("HelpId")
		local near = myRoot and (myRoot.Position - base.Position).Magnitude < NpcAnims.LookDistance * 2
		if typeof(helpId) == "string" and near and HelpController.IsAvailable(helpId) and not entry.focus then
			y += hop(NpcAnims.AvailableHopEvery, NpcAnims.AvailableHopHeight, t)
		end
		local roll = wave(style.sway, style.swaySpeed, t)
		local pitch = wave(style.lean, style.leanSpeed, t)
		local yaw = wave(style.turn, style.turnSpeed, t)

		-- Regard : vers le joueur qui l'aide / le combat, sinon vers le joueur proche
		local target: Vector3? = nil
		local focusRoot = entry.focus
			and entry.focus.Character
			and entry.focus.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if focusRoot then
			target = focusRoot.Position
		elseif myRoot and (myRoot.Position - base.Position).Magnitude < NpcAnims.LookDistance then
			target = myRoot.Position
		end
		local wanted = 0
		if target then
			local localTarget = base:PointToObjectSpace(target)
			wanted = math.deg(math.atan2(-localTarget.X, -localTarget.Z))
			wanted = math.clamp(wanted, -NpcAnims.LookMaxAngle, NpcAnims.LookMaxAngle)
		end
		entry.lookYaw += (wanted - entry.lookYaw) * math.min(dt * NpcAnims.LookSpeed, 1)
		if target then
			yaw *= 0.3 -- il regarde le joueur plutôt qu'autour de lui
		end

		local iy, iz, iyaw, ipitch, iroll = impulseOffset(entry, now)
		local cframe = base
			* CFrame.new(0, y + iy, iz)
			* CFrame.Angles(0, math.rad(yaw + entry.lookYaw + iyaw), 0)
			* CFrame.Angles(math.rad(pitch + ipitch), 0, math.rad(roll + iroll))
		entry.part.CFrame = cframe
	end
end

local function onActivity(update)
	if typeof(update) ~= "table" or typeof(update.player) ~= "Instance" then
		return
	end
	local who = update.player :: Player
	if update.kind ~= "Help" and update.kind ~= "Boss" then
		return
	end
	if update.state == "Started" then
		local model = npcFor(update.anchor, if update.kind == "Help" then "HelpId" else "BossId", update.id)
		runs[who] = model
		local entry = model and entries[model]
		if entry then
			entry.focus = who
		end
		if update.kind == "Help" then
			react(model, "Worried")
		end
	elseif update.state == "Rep" then
		local model = runs[who]
		if update.kind == "Help" then
			react(model, if update.quality == "Miss" then "Sad" else "Happy")
		else
			-- Le boss encaisse les bonnes poses du joueur et se moque des ratées
			react(
				model,
				if update.quality == "Perfect" then "Hit" elseif update.quality == "Good" then "HitSmall" else "Taunt"
			)
		end
	elseif update.state == "Ended" then
		local model = runs[who]
		runs[who] = nil
		local entry = model and entries[model]
		if entry and entry.focus == who then
			entry.focus = nil
		end
		-- Les autres joueurs voient l'habitant remercier ; son propre résultat arrive par SeriesUpdate
		if update.kind == "Help" and who ~= player then
			react(model, "Thanks")
		end
	end
end

-- PNJ de l'aide que le joueur vient de finir (runs est déjà vidé par Activity « Ended »)
local lastHelpNpc: Model? = nil

function NpcController.Init(controllers)
	HelpController = controllers.HelpController
end

function NpcController.Start()
	local function watchFolder(folder: Instance)
		for _, model in folder:GetChildren() do
			track(model)
		end
		folder.ChildAdded:Connect(function(model)
			task.wait() -- le modèle arrive avec ses pièces
			track(model)
		end)
	end
	local folder = workspace:FindFirstChild("Npcs")
	if folder then
		watchFolder(folder)
	end
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Npcs" then
			watchFolder(child)
		end
	end)

	Remotes.Activity.OnClientEvent:Connect(function(update)
		if typeof(update) == "table" and update.player == player and update.kind == "Help" then
			if update.state == "Started" then
				task.defer(function()
					lastHelpNpc = runs[player]
				end)
			end
		end
		onActivity(update)
	end)
	-- Son propre résultat d'aide : grande fête si elle a rapporté, déception sinon
	Remotes.SeriesUpdate.OnClientEvent:Connect(function(update)
		if update.state == "Ended" and update.kind == "Help" and lastHelpNpc then
			local success = update.reason == "Completed" and (update.cash or 0) > 0
			react(lastHelpNpc, if success then "Celebrate" else "Sad")
			lastHelpNpc = nil
		end
	end)
	-- Le boss se moque quand il gagne le combat (s'il perd, le serveur le fait s'envoler)
	Remotes.BossUpdate.OnClientEvent:Connect(function(update)
		if update.state == "Defeat" then
			for model in entries do
				if model:GetAttribute("BossId") == update.bossId then
					react(model, "Taunt")
				end
			end
		end
	end)
	RunService.RenderStepped:Connect(step)
end

-- Réaction déclenchée par un autre contrôleur (ex. tutoriel) : Happy, Sad, Celebrate, Thanks, Hit, Taunt…
NpcController.React = react
-- Une image d'animation (tests dans Studio réduit, où RenderStepped est en pause)
NpcController.Step = step

return NpcController
