-- Corde à sauter : le joueur prend la corde et saute vraiment par-dessus à chaque répétition.
-- Un tour de corde par répétition : elle passe sous les pieds au sommet du saut.
-- Une répétition ratée saute à peine (la corde fouette les tibias).

local JumpRope = {}
JumpRope.__index = JumpRope

local CURVE = 3.6 -- taille de la boucle de corde
local HANDLE_COLOR = Color3.fromRGB(205, 45, 45)

function JumpRope.Stand(top: CFrame): CFrame
	return top * CFrame.new(0, 0, 0.3)
end

local function handle(parent: Instance): (Part, Attachment)
	local part = Instance.new("Part")
	part.Name = "RopeHandle"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(1.1, 0.32, 0.32)
	part.Color = HANDLE_COLOR
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
	local tip = Instance.new("Attachment")
	tip.Parent = part
	return part, tip
end

function JumpRope.new(ctx)
	local self = setmetatable({ ctx = ctx }, JumpRope)
	-- La corde posée au sol disparaît : le joueur l'a dans les mains
	ctx.borrow("JumpRope", true)
	local folder = Instance.new("Folder")
	folder.Name = "JumpRope"
	folder.Parent = workspace
	self.folder = folder
	self.left, self.leftTip = handle(folder)
	self.right, self.rightTip = handle(folder)
	local rope = Instance.new("Beam")
	rope.Attachment0 = self.leftTip
	rope.Attachment1 = self.rightTip
	rope.Width0 = 0.14
	rope.Width1 = 0.14
	rope.Segments = 24
	rope.FaceCamera = true
	rope.Color = ColorSequence.new(Color3.fromRGB(25, 25, 28))
	rope.LightInfluence = 1
	rope.Parent = self.left
	self.rope = rope

	local rig = ctx.rig
	local saved = table.clone(rig.pose)
	rig:Clear()
	self.lower = rig.root.CFrame:ToObjectSpace(rig:PartCFrame("LowerTorso"))
	rig.pose = saved
	return self
end

function JumpRope:Pose(p: number, shake: number, u: number, time: number)
	local ctx = self.ctx
	local rig, m = ctx.rig, ctx.measures
	local root = rig.root.CFrame
	local up, back = root.UpVector, -root.LookVector

	-- Saut : au sommet aux trois quarts du tour, quand la corde passe sous les pieds
	local jump = if u > 0.5 and u < 1 then math.sin(math.pi * (u - 0.5) / 0.5) else 0
	local height = jump * (0.35 + 1.1 * p) * (1 - shake * 0.5)
	rig:Place("LowerTorso", CFrame.new(up * height) * (root * self.lower))
	for _, side in { -1, 1 } do
		local hip = if side < 0 then "LeftHip" else "RightHip"
		local knee = if side < 0 then "LeftKnee" else "RightKnee"
		rig:Set(hip, CFrame.Angles(0.35 * jump, 0, 0))
		rig:Set(knee, CFrame.Angles(-0.7 * jump, 0, 0))
	end

	-- La corde tourne : derrière -> au-dessus de la tête -> devant -> sous les pieds
	local angle = math.pi / 2 + 2 * math.pi * u
	local direction = -up * math.cos(angle) + back * math.sin(angle)
	local hips = rig:JointFrame("LeftHip").Position
	hips = Vector3.new(root.Position.X, hips.Y, root.Position.Z)
	for _, side in { -1, 1 } do
		-- Petits cercles des poignets qui font tourner la corde
		local circle = direction * 0.18
		local wrist = hips + up * 0.2 + root.RightVector * side * (m.shoulderWidth * 0.95) - back * 0.35 + circle
		rig:Reach(if side < 0 then "LeftArm" else "RightArm", wrist, back + root.RightVector * side * 0.5)
		local hand = if side < 0 then self.left else self.right
		local tip = if side < 0 then self.leftTip else self.rightTip
		hand.CFrame = CFrame.fromMatrix(wrist - up * 0.45, up, root.RightVector)
		-- L'axe X de l'attache donne la direction de la boucle
		tip.WorldCFrame = CFrame.fromMatrix(wrist - up * 0.95, direction, root.RightVector:Cross(direction))
	end
	self.rope.CurveSize0 = CURVE
	self.rope.CurveSize1 = -CURVE
end

function JumpRope:Destroy()
	self.folder:Destroy()
end

return JumpRope
