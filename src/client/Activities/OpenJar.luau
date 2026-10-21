-- Le joueur casse le vide du bocal puis arrache le couvercle à chaque répétition.

local Props = require(script.Parent.Props)

local OpenJar = {}
OpenJar.__index = OpenJar

-- Face à Maman, à 3,6 studs devant elle
function OpenJar.Stand(top: CFrame): CFrame
	return top * CFrame.new(0, 0, -3.6) * CFrame.Angles(0, math.pi, 0)
end

function OpenJar.new(ctx)
	local self = setmetatable({ ctx = ctx, props = Props.new("Jar") }, OpenJar)
	self.jar =
		self.props:Part(Vector3.new(0.9, 0.75, 0.75), Color3.fromRGB(95, 165, 60), Enum.Material.Glass, "Cylinder")
	self.jar.Transparency = 0.25
	self.pickles = self.props:Part(Vector3.new(0.75, 0.6, 0.6), Color3.fromRGB(70, 120, 40), nil, "Cylinder")
	self.lid =
		self.props:Part(Vector3.new(0.18, 0.8, 0.8), Color3.fromRGB(230, 185, 60), Enum.Material.Metal, "Cylinder")
	self.bubble =
		self.props:Part(Vector3.new(0.16, 0.16, 0.16), Color3.fromRGB(170, 235, 255), Enum.Material.Neon, "Ball")
	return self
end

function OpenJar:Pose(p: number, shake: number, _u: number, time: number, _count: number)
	local rig = self.ctx.rig
	local root = rig.root.CFrame
	local tremble = shake * math.sin(time * 40) * 0.06
	-- Le buste se penche vers le joint, puis recule quand le vide cède
	rig:Set("Waist", CFrame.Angles(-0.1 + 0.2 * p, tremble, 0))
	local upper = rig:PartCFrame("UpperTorso")
	local torso = self.ctx.character:FindFirstChild("UpperTorso") :: BasePart
	local jar = upper * CFrame.new(0, -torso.Size.Y * 0.15, -torso.Size.Z * 0.5 - 0.65) * Props.Upright
	self.jar.CFrame = jar
	self.pickles.CFrame = jar * CFrame.new(-0.05, 0, 0)
	-- Le petit point d'air disparaît, puis le couvercle saute vers la main droite
	self.bubble.CFrame = jar * CFrame.new(0.58, 0.25, 0)
	self.bubble.Transparency = if p > 0.3 then 1 else 0.1
	self.lid.CFrame = jar * CFrame.new(0.52 + 0.3 * p, 0.22 * p, 0) * CFrame.Angles(0, 0, -0.38 * p + tremble)
	-- Main gauche sur le bocal, main droite suit le couvercle
	local up = root.UpVector
	local side = root.RightVector
	local grip = jar.Position - up * 0.1
	rig:Reach("LeftArm", grip - side * 0.45, -root.LookVector - side * 0.5)
	local lidGrip = self.lid.Position + up * 0.25 + side * 0.15
	rig:Reach("RightArm", lidGrip, -root.LookVector + side * 0.5)
end

function OpenJar:Destroy()
	self.props:Destroy()
end

return OpenJar
