-- Effet de transformation quand un joueur passe au corps du stade suivant (décision D40) :
-- éclat doré sur le personnage, gerbe d'étincelles et onde au sol. Vu par tout le monde.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local GOLD = Color3.fromRGB(255, 205, 60)
local DURATION = 1.4

local BodyFxController = {}

local function transform(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return
	end

	-- Le corps s'illumine puis l'éclat s'estompe
	local highlight = Instance.new("Highlight")
	highlight.FillColor = GOLD
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.1
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = character
	TweenService:Create(highlight, TweenInfo.new(DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		FillTransparency = 1,
		OutlineTransparency = 1,
	}):Play()
	Debris:AddItem(highlight, DURATION + 0.1)

	-- Gerbe d'étincelles
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(GOLD)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.6, 1.2)
	sparks.Speed = NumberRange.new(10, 22)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 0
	sparks.Parent = root
	sparks:Emit(70)
	Debris:AddItem(sparks, 2)

	-- Onde dorée au sol
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local ground = root.Position - Vector3.new(0, root.Size.Y / 2 + (if humanoid then humanoid.HipHeight else 2), 0)
	local ring = Instance.new("Part")
	ring.Name = "TransformWave"
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = GOLD
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.CFrame = CFrame.new(ground + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, 26, 26),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 1)
end

function BodyFxController.Start()
	Remotes.BodyTransform.OnClientEvent:Connect(function(player)
		if typeof(player) == "Instance" and player:IsA("Player") then
			transform(player)
		end
	end)
end

return BodyFxController
