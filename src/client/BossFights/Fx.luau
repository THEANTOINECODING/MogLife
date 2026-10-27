-- Effets partagés des duels de boss (D85) : gerbes de particules (plumes, étincelles, poussière), onde de choc au sol,
-- icônes flottantes (étoiles, Zzz, couronne). Tout est rangé dans le dossier d'accessoires de la scène.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Fx = {}

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

-- Gerbe de particules à un endroit. kind : "Feathers", "Sparks", "Dust"
function Fx.Burst(scene, position: Vector3, kind: string, count: number, color: Color3?)
	local holder = Instance.new("Part")
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Position = position
	holder.Parent = scene.props.folder
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-200, 200)
	emitter.SpreadAngle = Vector2.new(180, 180)
	if kind == "Feathers" then
		emitter.Texture = SMOKE
		emitter.Color = ColorSequence.new(color or Color3.new(1, 1, 1))
		emitter.Size = NumberSequence.new(0.35, 0.25)
		emitter.Lifetime = NumberRange.new(1, 1.6)
		emitter.Speed = NumberRange.new(5, 10)
		emitter.Drag = 4
		emitter.Acceleration = Vector3.new(0, -3, 0)
		emitter.Transparency = NumberSequence.new(0, 1)
	elseif kind == "Sparks" then
		emitter.Texture = SPARKLE
		emitter.Color = ColorSequence.new(color or Color3.fromRGB(255, 220, 90))
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new(0.7, 0)
		emitter.Lifetime = NumberRange.new(0.3, 0.6)
		emitter.Speed = NumberRange.new(10, 18)
	else
		emitter.Texture = SMOKE
		emitter.Color = ColorSequence.new(color or Color3.fromRGB(205, 200, 195))
		emitter.Size = NumberSequence.new(1, 2.2)
		emitter.Lifetime = NumberRange.new(0.6, 0.9)
		emitter.Speed = NumberRange.new(4, 8)
		emitter.Drag = 3
		emitter.SpreadAngle = Vector2.new(90, 20)
		emitter.Transparency = NumberSequence.new(0.4, 1)
	end
	emitter.Parent = holder
	emitter:Emit(count)
	Debris:AddItem(holder, 2.5)
end

-- Onde de choc : un anneau plat qui s'élargit et s'efface au sol
function Fx.Ring(scene, position: Vector3, color: Color3, radius: number)
	local ring = scene.props:Part(Vector3.new(0.15, 1, 1), color, Enum.Material.Neon, "Cylinder")
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Transparency = 0.3
	ring.CastShadow = false
	TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.15, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.5)
end

-- Icône au-dessus d'une pièce (couronne, étoiles) : renvoie le label pour la changer ou la cacher
function Fx.Badge(scene, adornee: BasePart, text: string, height: number, size: number?): TextLabel
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(size or 2.4, size or 2.4)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.Adornee = adornee
	billboard.Parent = scene.props.folder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard
	return label
end

-- Icône qui monte et s'efface (Zzz, 💫, 📣)
function Fx.Float(scene, position: Vector3, text: string, rise: number?)
	local holder = Instance.new("Part")
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Position = position
	holder.Parent = scene.props.folder
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(1.6, 1.6)
	billboard.LightInfluence = 0
	billboard.Adornee = holder
	billboard.Parent = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard
	TweenService:Create(holder, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = position + Vector3.new(0, rise or 3, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(1.2), { TextTransparency = 1 }):Play()
	Debris:AddItem(holder, 1.3)
end

return Fx
