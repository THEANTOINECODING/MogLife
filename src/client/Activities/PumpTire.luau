-- Aide « Gonfler le pneu du vélo » (le livreur dépassé) : le joueur actionne vraiment une pompe à pied, poignée
-- tout en bas à chaque répétition (à moitié et en tremblant si elle est ratée). Un tuyau relie la pompe au vélo. D37.

local Props = require(script.Parent.Props)

local PumpTire = {}
PumpTire.__index = PumpTire

-- Hauteur de la poignée en proportion de la hanche (s'adapte à tous les corps)
local HANDLE_UP = 1.4
local HANDLE_DOWN = 0.8

-- Devant le livreur, un peu sur le côté du vélo
function PumpTire.Stand(top: CFrame): CFrame
	return top * CFrame.new(1.5, 0, -3.8) * CFrame.Angles(0, math.pi, 0)
end

function PumpTire.new(ctx)
	local self = setmetatable({ ctx = ctx, props = Props.new("Pump") }, PumpTire)
	local props = self.props
	self.base = props:Part(Vector3.new(0.2, 1.4, 0.5), Color3.fromRGB(40, 40, 46), Enum.Material.Metal)
	self.barrel = props:Part(Vector3.new(1.6, 0.36, 0.36), Color3.fromRGB(220, 50, 50), Enum.Material.Metal, "Cylinder")
	self.rod = props:Part(Vector3.new(1.4, 0.1, 0.1), Color3.fromRGB(200, 200, 205), Enum.Material.Metal, "Cylinder")
	self.handle = props:Part(Vector3.new(1.3, 0.16, 0.16), Color3.fromRGB(30, 30, 34), nil, "Cylinder")
	self.hose = props:Part(Vector3.new(0.08, 0.08, 1), Color3.fromRGB(30, 30, 34))
	-- Le vélo du livreur, s'il est là, reçoit le tuyau
	self.bike = ctx.borrow("Bicycle")
	-- Repos (par rapport au HumanoidRootPart) : bassin et chevilles, pour plier les jambes pieds au sol
	local rig = ctx.rig
	local saved = table.clone(rig.pose)
	rig:Clear()
	local root = rig.root.CFrame
	self.lower = root:ToObjectSpace(rig:PartCFrame("LowerTorso"))
	self.ankles = {
		Left = root:PointToObjectSpace(rig:JointFrame("LeftAnkle").Position),
		Right = root:PointToObjectSpace(rig:JointFrame("RightAnkle").Position),
	}
	rig.pose = saved
	return self
end

function PumpTire:Pose(p: number, shake: number, _u: number, time: number)
	local rig, m = self.ctx.rig, self.ctx.measures
	local root = rig.root.CFrame
	local tremble = shake * math.sin(time * 38) * 0.05
	local floor = root.Position - root.UpVector * (root.Position.Y - m.ground)
	local pump = CFrame.new(floor) * root.Rotation * CFrame.new(0, 0, -1.2)
	local handleHeight = m.hipHeight * (HANDLE_UP + (HANDLE_DOWN - HANDLE_UP) * p) + tremble
	self.base.CFrame = pump * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2)
	self.barrel.CFrame = pump * CFrame.new(0, 0.95, 0) * Props.Upright
	self.rod.CFrame = pump * CFrame.new(0, (handleHeight + 1.75) / 2, 0) * Props.Upright
	self.handle.CFrame = pump * CFrame.new(0, handleHeight, 0)
	-- Le joueur appuie de tout son poids : bassin qui descend, buste penché, pieds au sol
	rig:Place("LowerTorso", root * self.lower * CFrame.new(0, -0.4 * p, 0))
	rig:Set("Waist", CFrame.Angles(-0.45 * p, 0, 0))
	for side, ankle in self.ankles do
		rig:Reach(side .. "Leg", root * ankle, root.LookVector)
	end
	for _, sx in { -1, 1 } do
		local grip = (self.handle.CFrame * CFrame.new(sx * 0.45, 0, 0)).Position + Vector3.new(0, 0.1, 0)
		rig:Reach(if sx < 0 then "LeftArm" else "RightArm", grip, root.RightVector * sx - root.LookVector * 0.3)
	end
	-- Tuyau jusqu'à la roue du vélo (ou posé au sol)
	local from = (pump * CFrame.new(0, 0.3, 0)).Position
	local to = if self.bike
		then self.bike.Position - Vector3.new(0, self.bike.Size.Y * 0.3, 0)
		else from + root.RightVector * 2
	local length = (to - from).Magnitude
	self.hose.Size = Vector3.new(0.08, 0.08, length)
	self.hose.CFrame = CFrame.lookAt((from + to) / 2, to)
end

function PumpTire:Destroy()
	self.props:Destroy()
end

return PumpTire
