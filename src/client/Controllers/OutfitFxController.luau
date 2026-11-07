-- Effets de tenue purement locaux : chaque joueur ne voit que les siens.
-- Un seul émetteur discret à la fois, supprimé dès que la tenue ou le réglage change.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StyleSets = require(ReplicatedStorage.Shared.Config.StyleSets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local SettingsController
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

-- ------------------------------------------------------------------ tenues Robux (D121)
-- Leur effet est vu par TOUS les joueurs (attribut PremiumSet du joueur, posé par StyleService) : particules en
-- deux couleurs et une lueur autour du torse. Le réglage « effets de tenue » les masque aussi.

local premium: { [Player]: { id: string, attachment: Attachment } } = {}

local function clearPremium(owner: Player)
	local entry = premium[owner]
	if entry then
		entry.attachment:Destroy()
		premium[owner] = nil
	end
end

function OutfitFxController.RefreshPremium(owner: Player)
	local id = owner:GetAttribute("PremiumSet")
	local set = typeof(id) == "string" and StyleSets.ById[id] or nil
	local spec = set and set.effect and StyleSets.PremiumEffects[set.effect]
	local character = owner.Character
	local torso = character and character:FindFirstChild("UpperTorso")
	local entry = premium[owner]
	if not spec or not set or not torso or not torso:IsA("BasePart") or not SettingsController.Get("OutfitFx") then
		clearPremium(owner)
		return
	end
	if entry and entry.id == set.id and entry.attachment.Parent == torso then
		return
	end
	clearPremium(owner)
	local point = Instance.new("Attachment")
	point.Name = "PremiumOutfitFx"
	local particles = Instance.new("ParticleEmitter")
	particles.Name = set.effect :: string
	particles.Texture = spec.texture
	particles.Color = ColorSequence.new(spec.colors[1], spec.colors[2])
	particles.LightEmission = 0.7
	particles.Lifetime = NumberRange.new(spec.lifetime * 0.7, spec.lifetime)
	particles.Rate = spec.rate
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, spec.size),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Speed = NumberRange.new(spec.speed * 0.5, spec.speed)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Acceleration = Vector3.new(0, spec.speed, 0)
	particles.Shape = Enum.ParticleEmitterShape.Box
	particles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	particles.Transparency = NumberSequence.new(0.1, 1)
	particles.Parent = point
	local light = Instance.new("PointLight")
	light.Color = spec.light
	light.Brightness = 0.8
	light.Range = 9
	light.Shadows = false
	light.Parent = point
	point.Parent = torso
	premium[owner] = { id = set.id, attachment = point }
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
end

function OutfitFxController.Start()
	for _, owner in Players:GetPlayers() do
		watchPremium(owner)
	end
	Players.PlayerAdded:Connect(watchPremium)
	Players.PlayerRemoving:Connect(clearPremium)
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
