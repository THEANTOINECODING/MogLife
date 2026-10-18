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

function OutfitFxController.Init(controllers)
	SettingsController = controllers.SettingsController
end

function OutfitFxController.Start()
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
