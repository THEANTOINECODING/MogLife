-- Aide « Ouvrir le bocal de cornichons » (Maman) : le joueur tient le bocal contre lui et dévisse vraiment le
-- couvercle, un quart de tour par répétition (une répétition ratée glisse et tremble). D37.

local Props = require(script.Parent.Props)
local HelperStand = require(script.Parent.HelperStand)

local OpenJar = {}
OpenJar.__index = OpenJar

-- Face à Maman, devant sa dalle
function OpenJar.Stand(top: CFrame): CFrame
	return HelperStand.Around(top)
end

function OpenJar.new(ctx)
	local self = setmetatable({ ctx = ctx, props = Props.new("Jar") }, OpenJar)
	self.jar =
		self.props:Part(Vector3.new(0.9, 0.75, 0.75), Color3.fromRGB(95, 165, 60), Enum.Material.Glass, "Cylinder")
	self.jar.Transparency = 0.25
	self.pickles = self.props:Part(Vector3.new(0.75, 0.6, 0.6), Color3.fromRGB(70, 120, 40), nil, "Cylinder")
	self.lid =
		self.props:Part(Vector3.new(0.18, 0.8, 0.8), Color3.fromRGB(230, 185, 60), Enum.Material.Metal, "Cylinder")
	return self
end

function OpenJar:Pose(p: number, shake: number, _u: number, time: number, count: number)
	local rig = self.ctx.rig
	local root = rig.root.CFrame
	local tremble = shake * math.sin(time * 40) * 0.06
	-- Le buste force en tournant un peu, le bocal reste contre la poitrine
	rig:Set("Waist", CFrame.Angles(-0.1, 0.18 * p + tremble, 0))
	local upper = rig:PartCFrame("UpperTorso")
	local torso = self.ctx.character:FindFirstChild("UpperTorso") :: BasePart
	local jar = upper * CFrame.new(0, -torso.Size.Y * 0.15, -torso.Size.Z * 0.5 - 0.65) * Props.Upright
	self.jar.CFrame = jar
	self.pickles.CFrame = jar * CFrame.new(-0.05, 0, 0)
	-- Couvercle : un quart de tour de plus à chaque répétition
	local turned = math.rad(90) * (math.max(count - 1, 0) + p)
	self.lid.CFrame = jar * CFrame.new(0.52, 0, 0) * CFrame.Angles(turned + tremble * 3, 0, 0)
	-- Main gauche sur le bocal, main droite sur le couvercle (qui tourne avec lui)
	local up = root.UpVector
	local side = root.RightVector
	-- (la paume contre le verre, et posée sur le couvercle)
	local radius = self.jar.Size.Y / 2
	rig:Grip("LeftArm", jar.Position - up * 0.1 - side * (radius + 0.12), -root.LookVector - side * 0.5)
	local lidGrip = self.lid.Position
		+ up * (self.lid.Size.X / 2 + 0.14)
		+ side * (0.2 * math.cos(turned))
		- root.LookVector * (0.1 * math.sin(turned))
	rig:Grip("RightArm", lidGrip, -root.LookVector + side * 0.5)
end

function OpenJar:Destroy()
	self.props:Destroy()
end

return OpenJar
