-- Création des PNJ (boss, habitants) : vrai modèle s'il a été importé (ServerStorage.NpcModels),
-- sinon rig R15 provisoire aux couleurs et proportions de Npcs.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Npcs = require(ReplicatedStorage.Shared.Config.Npcs)

local Npc = {}

local function getFolder(): Folder
	local folder = workspace:FindFirstChild("Npcs")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Npcs"
		folder.Parent = workspace
	end
	return folder :: Folder
end

-- Nom affiché au-dessus d'un PNJ modélisé (pas de Humanoid, donc pas de nom automatique)
local function addNameTag(part: BasePart, displayName: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	-- Taille en studs (et non en pixels) : l'étiquette rapetisse avec la distance au lieu de masquer la scène
	billboard.Size = UDim2.fromScale(10, 1.6)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y / 2 + 1, 0)
	billboard.MaxDistance = 45
	billboard.Adornee = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = displayName
	label.Parent = billboard
	billboard.Parent = part
end

-- PNJ modélisé (Blender) : ServerStorage.NpcModels.<lookId>, un modèle dont la PrimaryPart est le corps.
-- Le modèle regarde vers -Z ; il est posé sur `spot` et tourné vers `facing`.
local function spawnModel(template: Model, lookId: string, displayName: string, spot: BasePart, facing: Vector3)
	local model = template:Clone()
	model.Name = lookId
	local body = model.PrimaryPart :: BasePart
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	-- On oriente le corps (droit dans le modèle d'origine), pas le pivot importé, qui peut contenir une rotation
	local pivotFromBody = body.CFrame:ToObjectSpace(model:GetPivot())
	model:PivotTo(CFrame.lookAt(spot.Position, Vector3.new(facing.X, spot.Position.Y, facing.Z)) * pivotFromBody)
	-- Recalage d'après le corps (droit) : centré sur la dalle, pieds posés dessus
	local spotTop = spot.Position.Y + spot.Size.Y / 2
	local delta = Vector3.new(
		spot.Position.X - body.Position.X,
		spotTop + body.Size.Y / 2 - body.Position.Y,
		spot.Position.Z - body.Position.Z
	)
	model:PivotTo(model:GetPivot() + delta)
	addNameTag(body, displayName)
	model.Parent = getFolder()
	return model, body
end

-- Crée un PNJ debout sur `spot`, tourné vers `facing`. Renvoie le modèle et la pièce principale
-- (où placer le ProximityPrompt). Utilise le vrai modèle s'il existe, sinon un avatar recoloré provisoire.
function Npc.Spawn(lookId: string, displayName: string, spot: BasePart, facing: Vector3): (Model, BasePart)
	local folder = ServerStorage:FindFirstChild("NpcModels")
	local template = folder and folder:FindFirstChild(lookId)
	if template and template:IsA("Model") and template.PrimaryPart then
		return spawnModel(template, lookId, displayName, spot, facing)
	end

	local look = Npcs[lookId]
	local description = Instance.new("HumanoidDescription")
	if look then
		description.HeadColor = look.skin
		description.LeftArmColor = look.skin
		description.RightArmColor = look.skin
		description.TorsoColor = look.torso
		description.LeftLegColor = look.legs
		description.RightLegColor = look.legs
		description.WidthScale = look.width
		description.HeightScale = look.height
		description.DepthScale = look.depth
		description.HeadScale = look.head
	end

	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = lookId
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = displayName
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.NameDisplayDistance = 60

	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true

	local position = spot.Position + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2 + spot.Size.Y / 2, 0)
	local lookAt = Vector3.new(facing.X, position.Y, facing.Z)
	model:PivotTo(CFrame.lookAt(position, lookAt))
	model.Parent = getFolder()
	return model, root
end

-- Effet comique : le PNJ se gonfle un instant (il « mogge » d'un regard), puis reprend sa taille.
function Npc.Pose(model: Model)
	local scale = model:GetScale()
	model:ScaleTo(scale * 1.35)
	task.delay(0.8, function()
		if model.Parent then
			model:ScaleTo(scale)
		end
	end)
end

-- Effet comique : le PNJ s'envole en tournoyant, puis revient à sa place.
function Npc.LaunchAndReturn(model: Model, height: number, returnDelay: number)
	local origin = model:GetPivot()
	local value = Instance.new("CFrameValue")
	value.Value = origin
	local connection = value.Changed:Connect(function(cframe)
		model:PivotTo(cframe)
	end)
	local up = TweenService:Create(
		value,
		TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = origin * CFrame.new(0, height, 0) * CFrame.Angles(math.pi / 2, math.pi, math.pi / 3) }
	)
	up:Play()
	task.delay(returnDelay, function()
		connection:Disconnect()
		value:Destroy()
		if model.Parent then
			model:PivotTo(origin)
		end
	end)
end

return Npc
