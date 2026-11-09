-- Effets de tenue purement locaux : chaque joueur ne voit que les siens.
-- Un seul émetteur discret à la fois, supprimé dès que la tenue ou le réglage change.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StyleSets = require(ReplicatedStorage.Shared.Config.StyleSets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local SettingsController
local SignatureFxController
local equipped: { [string]: string } = {}
local attachment: Attachment? = nil

local OutfitFxController = {}

local function clear()
	if attachment then
		attachment:Destroy()
		attachment = nil
	end
end

function OutfitFxController.Refresh()
	clear()
	OutfitFxController.RefreshAllPremium()
	SignatureFxController.RefreshAll()
	if not StyleSets.Active or not SettingsController.Get("OutfitFx") then
		return
	end
	local character = player.Character
	local torso = character and character:FindFirstChild("UpperTorso")
	if not torso or not torso:IsA("BasePart") then
		return
	end
	for _, set in StyleSets.List do
		if set.effect and equipped.Top == set.top and equipped.Bottom == set.bottom then
			local spec = StyleSets.Effects[set.effect]
			if not spec then
				return
			end
			local emitterPoint = Instance.new("Attachment")
			emitterPoint.Name = "LocalOutfitFx"
			emitterPoint.Parent = torso
			local particles = Instance.new("ParticleEmitter")
			particles.Name = set.effect
			particles.Color = ColorSequence.new(set.color:Lerp(Color3.new(1, 1, 1), 0.65))
			particles.LightEmission = 0.18
			particles.Lifetime = NumberRange.new(spec.lifetime)
			particles.Rate = spec.rate
			particles.Size = NumberSequence.new(spec.size)
			particles.Speed = NumberRange.new(spec.speed)
			particles.SpreadAngle = Vector2.new(180, 180)
			particles.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.28, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			})
			particles.Parent = emitterPoint
			attachment = emitterPoint
			return
		end
	end
end

-- ------------------------------------------------------------------ tenues Robux (D121, refait en D125)
-- Leur aura est vue par TOUS les joueurs (attribut PremiumSet du joueur, posé par StyleService) : plusieurs couches de
-- particules (StyleSets.Auras) et une lumière. Le réglage « effets de tenue » les masque aussi. Au-delà de
-- SignatureFx.AuraMaxDistance, les émetteurs d'un autre joueur sont coupés (téléphones).

local PARTICLES = "rbxasset://textures/particles/"
local premium: { [Player]: { id: string, character: Model, instances: { Instance }, emitters: { ParticleEmitter } } } =
	{}

local function clearPremium(owner: Player)
	local entry = premium[owner]
	if entry then
		for _, instance in entry.instances do
			instance:Destroy()
		end
		premium[owner] = nil
	end
end

type Layer = typeof(StyleSets.Auras.InfernalDemon.layers[1])

local function auraEmitter(layer: Layer): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "PremiumAura"
	particles.Texture = PARTICLES .. layer.texture
	particles.Color = ColorSequence.new(layer.colors[1], layer.colors[2])
	particles.LightEmission = layer.emission
	particles.LightInfluence = 1 - layer.emission
	particles.Lifetime = NumberRange.new(layer.life[1], layer.life[2])
	particles.Rate = layer.rate
	particles.Speed = NumberRange.new(layer.speed[1], layer.speed[2])
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, layer.size[1]),
		NumberSequenceKeypoint.new(0.5, layer.size[2]),
		NumberSequenceKeypoint.new(1, layer.size[3]),
	})
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1 - layer.alpha[1]),
		NumberSequenceKeypoint.new(0.35, 1 - layer.alpha[2]),
		NumberSequenceKeypoint.new(1, 1 - layer.alpha[3]),
	})
	local spread = layer.spread or 0
	particles.SpreadAngle = Vector2.new(spread, spread)
	particles.Acceleration = layer.accel or Vector3.zero
	local spin = layer.spin or 0
	particles.RotSpeed = NumberRange.new(-spin, spin)
	particles.Rotation = NumberRange.new(0, if spin > 0 then 360 else 0)
	particles.LockedToPart = layer.locked == true
	if layer.flat then
		-- couché au sol : la particule est perpendiculaire à sa vitesse, émise vers le haut
		particles.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		particles.EmissionDirection = Enum.NormalId.Top
		particles.SpreadAngle = Vector2.zero
		particles.LockedToPart = true
	end
	return particles
end

function OutfitFxController.RefreshPremium(owner: Player)
	local id = owner:GetAttribute("PremiumSet")
	local set = typeof(id) == "string" and StyleSets.ById[id] or nil
	local aura = set and StyleSets.Auras[set.id]
	local character = owner.Character
	local torso = character and character:FindFirstChild("UpperTorso")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local entry = premium[owner]
	if
		not aura
		or not set
		or not character
		or not torso
		or not torso:IsA("BasePart")
		or not root
		or not root:IsA("BasePart")
		or not SettingsController.Get("OutfitFx")
	then
		clearPremium(owner)
		return
	end
	if entry and entry.id == set.id and entry.character == character and torso.Parent == character then
		return
	end
	clearPremium(owner)
	local instances: { Instance } = {}
	local emitters: { ParticleEmitter } = {}
	local feet: Attachment? = nil
	for _, layer in aura.layers do
		local particles = auraEmitter(layer)
		if layer.anchor == "Feet" then
			if not feet then
				local point = Instance.new("Attachment")
				point.Name = "PremiumAuraFeet"
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				local hip = humanoid and humanoid.HipHeight or 2
				point.Position = Vector3.new(0, -(root.Size.Y / 2 + hip) + 0.15, 0)
				point.Parent = root
				table.insert(instances, point)
				feet = point
			end
			particles.Parent = feet
		else
			-- émis depuis tout le volume de la partie du corps
			local part = character:FindFirstChild(layer.anchor)
			if not part or not part:IsA("BasePart") then
				particles:Destroy()
				continue
			end
			if not layer.flat and not layer.locked then
				particles.Shape = Enum.ParticleEmitterShape.Box
				particles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			end
			particles.Parent = part
			table.insert(instances, particles)
		end
		table.insert(emitters, particles)
	end
	local light = Instance.new("PointLight")
	light.Name = "PremiumAuraLight"
	light.Color = aura.light.color
	light.Brightness = aura.light.brightness
	light.Range = aura.light.range
	light.Shadows = false
	light.Parent = torso
	table.insert(instances, light)
	premium[owner] = { id = set.id, character = character, instances = instances, emitters = emitters }
end

-- Coupe les auras trop loin de la caméra (téléphones : pas de particules qu'on ne voit pas)
local function cullAuras()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local origin = camera.CFrame.Position
	for owner, entry in premium do
		local root = entry.character:FindFirstChild("HumanoidRootPart")
		local near = owner == player
			or (
				root ~= nil
				and root:IsA("BasePart")
				and (root.Position - origin).Magnitude <= StyleSets.SignatureFx.AuraMaxDistance
			)
		for _, particles in entry.emitters do
			particles.Enabled = near
		end
	end
end

local function watchPremium(owner: Player)
	owner:GetAttributeChangedSignal("PremiumSet"):Connect(function()
		OutfitFxController.RefreshPremium(owner)
	end)
	owner.CharacterAdded:Connect(function(character)
		character:WaitForChild("UpperTorso", 10)
		OutfitFxController.RefreshPremium(owner)
	end)
	OutfitFxController.RefreshPremium(owner)
end

function OutfitFxController.RefreshAllPremium()
	for _, owner in Players:GetPlayers() do
		OutfitFxController.RefreshPremium(owner)
	end
end

function OutfitFxController.Init(controllers)
	SettingsController = controllers.SettingsController
	SignatureFxController = controllers.SignatureFxController
end

function OutfitFxController.Start()
	for _, owner in Players:GetPlayers() do
		watchPremium(owner)
	end
	Players.PlayerAdded:Connect(watchPremium)
	Players.PlayerRemoving:Connect(clearPremium)
	task.spawn(function()
		while true do
			task.wait(0.5)
			cullAuras()
		end
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("UpperTorso", 10)
		OutfitFxController.Refresh()
	end)
	Remotes.StyleState.OnClientEvent:Connect(function(state)
		equipped = if typeof(state) == "table" and typeof(state.equipped) == "table" then state.equipped else {}
		OutfitFxController.Refresh()
	end)
end

return OutfitFxController
