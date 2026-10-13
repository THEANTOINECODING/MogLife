-- Création des PNJ provisoires (boss, habitants) : rig R15 généré, couleurs et proportions de Npcs.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

-- Crée un PNJ debout sur `spot`, tourné vers `facing`. Renvoie le modèle et sa HumanoidRootPart.
function Npc.Spawn(lookId: string, displayName: string, spot: BasePart, facing: Vector3): (Model, BasePart)
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
