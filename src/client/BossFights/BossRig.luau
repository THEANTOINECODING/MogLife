-- Squelette d'un boss (D85) : ses modèles importés de Blender (tools/blender/rig_bosses.py) sont une seule pièce
-- (MeshPart) avec des os (Bone) aux noms des pièces R15 : Root, LowerTorso, UpperTorso, Head, (Left|Right)UpperArm,
-- (Left|Right)LowerArm, (Left|Right)Hand, (Left|Right)UpperLeg, (Left|Right)LowerLeg, (Left|Right)Foot.
-- On écrit à chaque image la rotation voulue de chaque os, dans le repère du personnage (X = sa droite, Y = le haut,
-- Z = derrière lui, comme les CFrame de Roblox) et en absolu (par rapport au repos) : BossRig calcule lui-même la part
-- de chaque os par rapport à son parent.
--   rig:Clear()                        tout au repos
--   rig:Turn(bone, rotation)           rotation absolue d'un os (repère du personnage)
--   rig:Reach(side, target, bend?)     le bras ("Left"/"Right") va chercher un point du monde
--   rig:Apply()                        écrit les os (à chaque image)
--   rig:Joint(bone)                    position actuelle (monde) de l'articulation d'un os
--   rig:Side()                         sa droite (monde), d'après ses épaules
-- Un boss sans os (ancien modèle) : BossRig.new renvoie nil, les scènes animent alors le corps entier.

local BossRig = {}
BossRig.__index = BossRig

local NAMES = {
	"Root",
	"LowerTorso",
	"UpperTorso",
	"Head",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}

export type BossRig = typeof(setmetatable(
	{} :: {
		part: BasePart,
		bones: { [string]: Bone },
		parentOf: { [string]: string? },
		restPos: { [string]: Vector3 }, -- position de repos de chaque articulation (repère de la pièce)
		restRot: { [string]: CFrame }, -- orientation de repos de chaque os (repère de la pièce)
		toChar: CFrame, -- repère du personnage dans celui de la pièce (rotation)
		wanted: { [string]: CFrame },
		orders: { string },
	},
	BossRig
))

-- Rotation la plus courte qui amène la direction `from` sur `to`
local function arc(from: Vector3, to: Vector3): CFrame
	local a, b = from.Unit, to.Unit
	local axis = a:Cross(b)
	local dot = math.clamp(a:Dot(b), -1, 1)
	if axis.Magnitude < 1e-6 then
		if dot > 0 then
			return CFrame.identity
		end
		local other = if math.abs(a.X) < 0.9 then Vector3.xAxis else Vector3.yAxis
		return CFrame.fromAxisAngle(a:Cross(other).Unit, math.pi)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
end
BossRig.Arc = arc

function BossRig.new(model: Model): BossRig?
	local part = model.PrimaryPart or model:FindFirstChildWhichIsA("MeshPart", true)
	if not part then
		return nil
	end
	local bones: { [string]: Bone } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Bone") and table.find(NAMES, descendant.Name) then
			bones[descendant.Name] = descendant
		end
	end
	for _, name in NAMES do
		if not bones[name] then
			return nil
		end
	end
	local parentOf, restPos, restRot = {}, {}, {}
	local partInverse = part.CFrame:Inverse()
	for name, bone in bones do
		bone.Transform = CFrame.identity
		local parent = bone.Parent
		parentOf[name] = if parent and parent:IsA("Bone") then parent.Name else nil
	end
	for name, bone in bones do
		local world = partInverse * bone.WorldCFrame
		restPos[name] = world.Position
		restRot[name] = world.Rotation
	end
	-- Repère du personnage : sa droite d'après ses épaules, le haut de la pièce, Z vers l'arrière
	local right = (restPos.RightUpperArm - restPos.LeftUpperArm) * Vector3.new(1, 0, 1)
	right = if right.Magnitude > 1e-3 then right.Unit else Vector3.xAxis
	local up = Vector3.yAxis
	local back = right:Cross(up)
	local toChar = CFrame.fromMatrix(Vector3.zero, right, up, back)
	-- Ordre parent avant enfant
	local orders, seen = {}, {}
	local function visit(name: string)
		if seen[name] then
			return
		end
		local parent = parentOf[name]
		if parent then
			visit(parent)
		end
		seen[name] = true
		table.insert(orders, name)
	end
	for _, name in NAMES do
		visit(name)
	end
	return setmetatable({
		part = part,
		bones = bones,
		parentOf = parentOf,
		restPos = restPos,
		restRot = restRot,
		toChar = toChar,
		wanted = {},
		orders = orders,
	}, BossRig)
end

function BossRig.Clear(self: BossRig)
	table.clear(self.wanted)
end

-- Rotation absolue d'un os, dans le repère du personnage (par rapport à sa pose de repos)
function BossRig.Turn(self: BossRig, name: string, rotation: CFrame)
	self.wanted[name] = self.toChar * rotation * self.toChar:Inverse()
end

-- Rotation totale d'un os (repère de la pièce) : la sienne, ou héritée de son parent
function BossRig.Total(self: BossRig, name: string): CFrame
	local own = self.wanted[name]
	if own then
		return own
	end
	local parent = self.parentOf[name]
	return if parent then self:Total(parent) else CFrame.identity
end

-- Position actuelle de l'articulation d'un os (repère de la pièce), poses des parents comprises
function BossRig.LocalJoint(self: BossRig, name: string): Vector3
	local parent = self.parentOf[name]
	if not parent then
		return self.restPos[name]
	end
	local origin = self:LocalJoint(parent)
	return origin + self:Total(parent) * (self.restPos[name] - self.restPos[parent])
end

function BossRig.Joint(self: BossRig, name: string): Vector3
	return self.part.CFrame * self:LocalJoint(name)
end

-- Direction (monde) de son épaule gauche vers sa droite : sa « droite », quelle que soit l'orientation de la pièce
function BossRig.Side(self: BossRig): Vector3
	local side = (self:Joint("RightUpperArm") - self:Joint("LeftUpperArm")) * Vector3.new(1, 0, 1)
	return if side.Magnitude > 1e-3 then side.Unit else self.part.CFrame.RightVector
end

-- Longueur d'un bras (épaule -> poignet)
function BossRig.ArmLength(self: BossRig, side: string): number
	local r = self.restPos
	return (r[side .. "LowerArm"] - r[side .. "UpperArm"]).Magnitude
		+ (r[side .. "Hand"] - r[side .. "LowerArm"]).Magnitude
end

-- Le bras va chercher `target` (monde) : épaule -> coude -> poignet, coude plié vers `bend` (monde, facultatif)
function BossRig.Reach(self: BossRig, side: string, target: Vector3, bend: Vector3?)
	local upper, lower, hand = side .. "UpperArm", side .. "LowerArm", side .. "Hand"
	local shoulder = self:LocalJoint(upper)
	local goal = self.part.CFrame:PointToObjectSpace(target)
	local a = (self.restPos[lower] - self.restPos[upper]).Magnitude
	local b = (self.restPos[hand] - self.restPos[lower]).Magnitude
	local toGoal = goal - shoulder
	local distance = math.clamp(toGoal.Magnitude, math.abs(a - b) + 0.01, a + b - 0.01)
	local dir = toGoal.Unit
	local pole = if bend then self.part.CFrame:VectorToObjectSpace(bend) else Vector3.new(0, -1, 0.3)
	local side2 = pole - dir * pole:Dot(dir)
	side2 = if side2.Magnitude > 1e-3 then side2.Unit else Vector3.new(0, 1, 0):Cross(dir).Unit
	local angle = math.acos(math.clamp((a * a + distance * distance - b * b) / (2 * a * distance), -1, 1))
	local elbow = shoulder + (dir * math.cos(angle) + side2 * math.sin(angle)) * a
	local wrist = shoulder + dir * distance
	local restUpper = self.restPos[lower] - self.restPos[upper]
	local restLower = self.restPos[hand] - self.restPos[lower]
	self.wanted[upper] = arc(restUpper, elbow - shoulder)
	self.wanted[lower] = arc(restLower, wrist - elbow)
	self.wanted[hand] = self.wanted[lower]
end

-- Écrit les os : la part de chaque os = sa rotation totale moins celle de son parent, dans son propre repère
function BossRig.Apply(self: BossRig)
	for _, name in self.orders do
		local bone = self.bones[name]
		local total = self:Total(name)
		local parent = self.parentOf[name]
		local relative = if parent then self:Total(parent):Inverse() * total else total
		local rest = self.restRot[name]
		bone.Transform = rest:Inverse() * relative * rest
	end
end

function BossRig.Release(self: BossRig)
	for _, bone in self.bones do
		bone.Transform = CFrame.identity
	end
end

return BossRig
