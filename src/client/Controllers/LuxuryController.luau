-- Articles de luxe à effets (D112), côté client :
-- - Entrées : le serveur annonce l'entrée d'un joueur (début de duel ou de combat de boss), chaque client joue
--   l'explosion de particules autour de lui pendant Luxury.EntranceDuration.
-- - Le réglage « Outfit effects » coupe chez soi les traînées et auras de tous les joueurs (petits téléphones).
-- Les traînées et auras elles-mêmes sont posées par le serveur (StyleService) et vues par tous.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Luxury = require(ReplicatedStorage.Shared.Config.Luxury)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local SettingsController

local LuxuryController = {}

local function colorSequence(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local keys = {}
	for index, color in colors do
		table.insert(keys, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(keys)
end

local function isLuxury(instance: Instance): boolean
	return (instance:IsA("ParticleEmitter") and instance:GetAttribute("Luxury") == true)
		or (instance:IsA("Trail") and instance.Name == "LuxuryTrail")
end

-- Applique le réglage à un effet de luxe posé par le serveur
local function applySetting(instance: Instance)
	if isLuxury(instance) then
		(instance :: any).Enabled = SettingsController.Get("OutfitFx")
	end
end

function LuxuryController.Refresh()
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if character then
			for _, descendant in character:GetDescendants() do
				applySetting(descendant)
			end
		end
	end
end

local function playEntrance(other: Player, entranceId: string)
	local entry = Luxury.ById[entranceId]
	local character = other.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not entry or entry.category ~= "Entrance" or not root or not SettingsController.Get("OutfitFx") then
		return
	end
	local fx = entry.fx
	local attachment = Instance.new("Attachment")
	attachment.Name = "LuxuryEntrance"
	attachment.Position = Vector3.new(0, -1.5, 0)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = fx.texture
	emitter.Color = colorSequence(fx.colors)
	-- Les ondes de choc (vitesse nulle) grandissent ; les autres rétrécissent en s'éloignant
	emitter.Size = if fx.speed == 0
		then NumberSequence.new(fx.size * 0.2, fx.size)
		else NumberSequence.new(fx.size, fx.size * 0.4)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.7, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(fx.lifetime * 0.7, fx.lifetime)
	emitter.Speed = NumberRange.new(fx.speed * 0.6, fx.speed)
	emitter.SpreadAngle = Vector2.new(fx.spread or 0, fx.spread or 0)
	emitter.LightEmission = fx.light or 0
	emitter.RotSpeed = NumberRange.new(-(fx.rotSpeed or 0), fx.rotSpeed or 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Acceleration = if fx.speed > 10 then Vector3.new(0, -25, 0) else Vector3.zero
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Orientation = if fx.speed == 0
		then Enum.ParticleOrientation.VelocityPerpendicular
		else Enum.ParticleOrientation.FacingCamera
	emitter.Rate = 0
	emitter.Parent = attachment
	attachment.Parent = root
	-- Trois salves : l'effet se voit même si l'on regarde ailleurs une fraction de seconde
	local bursts = 3
	local each = math.max(math.floor(fx.rate / bursts), 1)
	task.spawn(function()
		for _ = 1, bursts do
			if not attachment.Parent then
				return
			end
			emitter:Emit(each)
			task.wait(Luxury.EntranceDuration / bursts)
		end
		task.wait(fx.lifetime)
		attachment:Destroy()
	end)
end

local function watchCharacter(character: Model)
	character.DescendantAdded:Connect(applySetting)
	for _, descendant in character:GetDescendants() do
		applySetting(descendant)
	end
end

local function watchPlayer(other: Player)
	other.CharacterAdded:Connect(watchCharacter)
	if other.Character then
		watchCharacter(other.Character)
	end
end

function LuxuryController.Init(controllers)
	SettingsController = controllers.SettingsController
end

function LuxuryController.Start()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	Remotes.LuxuryEntrance.OnClientEvent:Connect(function(other, entranceId)
		if typeof(other) == "Instance" and other:IsA("Player") and typeof(entranceId) == "string" then
			playEntrance(other, entranceId)
		end
	end)
end

return LuxuryController
