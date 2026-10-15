-- Aide « Planter les clous de la cabane » (le petit voisin) : le joueur tient la planche et frappe vraiment le clou
-- au marteau ; le clou s'enfonce un peu à chaque répétition (une ratée tape à côté, la main tremble). D37.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Props = require(script.Parent.Props)

local Nails = {}
Nails.__index = Nails

local WOOD = Color3.fromRGB(190, 140, 90)

function Nails.Stand(top: CFrame): CFrame
	return top * CFrame.new(0, 0, -3.6) * CFrame.Angles(0, math.pi, 0)
end

function Nails.new(ctx)
	local self = setmetatable({ ctx = ctx, props = Props.new("Nails") }, Nails)
	local props = self.props
	self.plank = props:Part(Vector3.new(3, 0.25, 1), WOOD, Enum.Material.WoodPlanks)
	self.trestles = {
		props:Part(Vector3.new(0.3, 1, 0.9), Color3.fromRGB(120, 85, 55), Enum.Material.WoodPlanks),
		props:Part(Vector3.new(0.3, 1, 0.9), Color3.fromRGB(120, 85, 55), Enum.Material.WoodPlanks),
	}
	self.nail = props:Part(Vector3.new(0.7, 0.08, 0.08), Color3.fromRGB(200, 200, 205), Enum.Material.Metal, "Cylinder")
	self.handle = props:Part(Vector3.new(0.12, 0.12, 1.1), Color3.fromRGB(120, 80, 45), Enum.Material.Wood)
	self.head = props:Part(Vector3.new(0.6, 0.25, 0.25), Color3.fromRGB(60, 60, 66), Enum.Material.Metal)
	-- Le nombre de répétitions d'une aide, pour que le clou soit entièrement planté au dernier coup
	self.total = Balance.Helps.Reps
	return self
end

function Nails:Pose(p: number, shake: number, u: number, time: number, count: number)
	local rig, m = self.ctx.rig, self.ctx.measures
	local root = rig.root.CFrame
	local floor = root.Position - Vector3.new(0, root.Position.Y - m.ground, 0)
	local benchHeight = m.hipHeight * 0.55
	local bench = CFrame.new(floor) * root.Rotation * CFrame.new(0, benchHeight, -1.4)
	self.plank.CFrame = bench
	for k, sx in { -1, 1 } do
		self.trestles[k].CFrame = bench * CFrame.new(sx * 1.2, -benchHeight / 2, 0)
		self.trestles[k].Size = Vector3.new(0.3, benchHeight, 0.9)
	end
	-- Le clou s'enfonce d'un cran à chaque coup réussi
	local sunk = math.clamp((math.max(count - 1, 0) + (if u > 0.5 then 1 else 0)) / self.total, 0, 1)
	local nailTop = bench * CFrame.new(0.4, 0.12 + 0.35 * (1 - sunk), 0)
	self.nail.CFrame = nailTop * CFrame.new(0, -0.35, 0) * Props.Upright

	-- Main gauche tient la planche ; le bras droit monte le marteau puis frappe (p = 1 : coup porté)
	rig:Set("Waist", CFrame.Angles(-0.3, 0, 0))
	rig:Reach("LeftArm", (bench * CFrame.new(-0.6, 0.25, 0.1)).Position, -root.LookVector - root.RightVector * 0.5)
	local raised = (bench * CFrame.new(0.55, 2.0, 0.6)).Position
	local miss = shake * 0.35 * math.sin(time * 30)
	local strike = (nailTop * CFrame.new(0.25 + miss, 0.25, 0.55)).Position
	local wrist = raised:Lerp(strike, p)
	rig:Reach("RightArm", wrist, -root.LookVector + root.RightVector * 0.6)
	-- Marteau dans la main, dans le prolongement de l'avant-bras : la tête vient frapper le clou
	local hand = rig:JointFrame("RightWrist").Position
	local direction = (hand - rig:JointFrame("RightElbow").Position).Unit
	local tip = hand + direction * 1.1
	self.handle.CFrame = CFrame.lookAt((hand + tip) / 2, tip)
	self.handle.Size = Vector3.new(0.12, 0.12, 1.1)
	self.head.CFrame = CFrame.lookAt(tip, tip + direction) * CFrame.Angles(0, math.pi / 2, 0)
end

function Nails:Destroy()
	self.props:Destroy()
end

return Nails
