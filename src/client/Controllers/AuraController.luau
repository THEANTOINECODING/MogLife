-- Aura des boosts (D121) : tant qu'un joueur a un boost actif, une légère lueur de la couleur de son aliment
-- (Boosts[id].color) l'entoure, visible par tous. Le serveur publie le boost en attributs du joueur (BoostService :
-- BoostAura = id ou "", BoostAuraEnds = fin en os.time) ; chaque client dessine l'aura des personnages proches et
-- la retire quand le boost se termine (heure du serveur) ou qu'un autre la remplace.
-- Purement visuel : rien n'est envoyé au serveur. Réglages dans Balance.BoostAura.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)

local SOFT = "rbxasset://textures/particles/smoke_main.dds" -- bouffée douce : une lueur, pas des étincelles
local AURA_NAME = "BoostAura"
local CHECK_INTERVAL = 0.5

type Aura = { id: string, attachment: Attachment, emitter: ParticleEmitter, light: PointLight }

local auras: { [Player]: Aura } = {}

local AuraController = {}

local function remove(player: Player)
	local aura = auras[player]
	if not aura then
		return
	end
	auras[player] = nil
	local cfg = Balance.BoostAura
	aura.emitter.Enabled = false
	TweenService:Create(aura.light, TweenInfo.new(cfg.FadeTime), { Brightness = 0 }):Play()
	-- Les dernières particules finissent leur vie avant la suppression
	task.delay(cfg.Lifetime + cfg.FadeTime, function()
		aura.attachment:Destroy()
	end)
end

local function build(root: BasePart, id: string): Aura
	local cfg = Balance.BoostAura
	local color = Boosts[id].color
	local attachment = Instance.new("Attachment")
	attachment.Name = AURA_NAME
	attachment.Position = Vector3.new(0, 0.4, 0)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Glow"
	emitter.Texture = SOFT
	emitter.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.35))
	emitter.LightEmission = 0.6
	emitter.LightInfluence = 0
	emitter.Lifetime = NumberRange.new(cfg.Lifetime * 0.8, cfg.Lifetime)
	emitter.Rate = cfg.Rate
	emitter.Size = NumberSequence.new(cfg.Size[1], cfg.Size[2])
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, cfg.Transparency[1]),
		NumberSequenceKeypoint.new(1, cfg.Transparency[2]),
	})
	emitter.Speed = NumberRange.new(cfg.Speed * 0.5, cfg.Speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, cfg.Rise, 0)
	emitter.RotSpeed = NumberRange.new(-30, 30)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.ZOffset = -1 -- derrière le personnage : une lueur, pas un nuage devant lui
	emitter.Shape = Enum.ParticleEmitterShape.Cylinder
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Parent = attachment

	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Color = color
	light.Range = cfg.LightRange
	light.Brightness = 0
	light.Shadows = false
	light.Parent = attachment

	attachment.Parent = root
	TweenService:Create(light, TweenInfo.new(cfg.FadeTime), { Brightness = cfg.LightBrightness }):Play()
	return { id = id, attachment = attachment, emitter = emitter, light = light }
end

-- Boost à montrer pour ce joueur (nil s'il n'en a pas, s'il est fini ou trop loin)
local function wanted(player: Player, here: Vector3?): (string?, BasePart?)
	local id = player:GetAttribute("BoostAura")
	local endsAt = player:GetAttribute("BoostAuraEnds")
	if typeof(id) ~= "string" or not Boosts[id] or typeof(endsAt) ~= "number" then
		return nil, nil
	end
	if workspace:GetServerTimeNow() >= endsAt then
		return nil, nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil, nil
	end
	if here and (root.Position - here).Magnitude > Balance.BoostAura.MaxDistance then
		return nil, nil
	end
	return id, root
end

function AuraController.Refresh(player: Player)
	local camera = workspace.CurrentCamera
	local id, root = wanted(player, camera and camera.CFrame.Position)
	local aura = auras[player]
	if aura and (aura.id ~= id or not aura.attachment.Parent or aura.attachment.Parent ~= root) then
		remove(player)
		aura = nil
	end
	if id and root and not aura then
		auras[player] = build(root, id)
	end
end

-- Pour les tests dans Studio : boost dont l'aura est affichée pour ce joueur (nil sans aura)
function AuraController.Shown(player: Player): string?
	local aura = auras[player]
	return aura and aura.id
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("BoostAura"):Connect(function()
		AuraController.Refresh(player)
	end)
	player:GetAttributeChangedSignal("BoostAuraEnds"):Connect(function()
		AuraController.Refresh(player)
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		AuraController.Refresh(player)
	end)
	AuraController.Refresh(player)
end

function AuraController.Start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		local aura = auras[player]
		auras[player] = nil
		if aura then
			aura.attachment:Destroy()
		end
	end)
	-- Fin du boost (aucun attribut ne change à ce moment-là) et joueurs qui entrent ou sortent de la distance
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				AuraController.Refresh(player)
			end
		end
	end)
end

return AuraController
