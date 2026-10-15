-- Squelette R15 piloté par le code, pour que les activités se réalisent vraiment (décision D37).
-- On écrit la rotation de chaque articulation (Transform) à chaque image, après l'Animator de Roblox :
-- le corps prend exactement la pose voulue. Fonctionne avec les articulations récentes (AnimationConstraint)
-- comme avec les anciennes (Motor6D). La coque du corps (BodyService) est soudée aux pièces : elle suit.
--
-- Outils :
--   rig:Set(joint, rotation)          rotation d'une articulation (repère de l'articulation)
--   rig:Place(part, worldCFrame)      place une pièce dans le monde en réglant l'articulation qui la porte
--   rig:Reach(limb, target, pole)     bras ou jambe qui atteint un point (deux os, coude ou genou vers `pole`)
--   rig:PartCFrame(part)              position d'une pièce selon la pose en cours

local Rig = {}
Rig.__index = Rig

-- Articulation -> pièce qu'elle porte
local JOINT_PARTS = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	Neck = "Head",
	LeftShoulder = "LeftUpperArm",
	LeftElbow = "LeftLowerArm",
	LeftWrist = "LeftHand",
	RightShoulder = "RightUpperArm",
	RightElbow = "RightLowerArm",
	RightWrist = "RightHand",
	LeftHip = "LeftUpperLeg",
	LeftKnee = "LeftLowerLeg",
	LeftAnkle = "LeftFoot",
	RightHip = "RightUpperLeg",
	RightKnee = "RightLowerLeg",
	RightAnkle = "RightFoot",
}

-- Membres à deux os : articulation haute, articulation du milieu, articulation du bout, sens de pliage
-- (bras : l'avant-bras se plie vers l'avant ; jambe : le tibia se plie vers l'arrière)
local LIMBS = {
	LeftArm = { "LeftShoulder", "LeftElbow", "LeftWrist", 1 },
	RightArm = { "RightShoulder", "RightElbow", "RightWrist", 1 },
	LeftLeg = { "LeftHip", "LeftKnee", "LeftAnkle", -1 },
	RightLeg = { "RightHip", "RightKnee", "RightAnkle", -1 },
}

type Joint = {
	name: string,
	instance: any, -- AnimationConstraint ou Motor6D
	part0: BasePart,
	part1: BasePart,
}

export type Rig = typeof(setmetatable(
	{} :: {
		character: Model,
		root: BasePart,
		joints: { [string]: Joint },
		byPart: { [string]: Joint },
		pose: { [string]: CFrame },
	},
	Rig
))

local function frames(joint: Joint): (CFrame, CFrame)
	local instance = joint.instance
	if instance:IsA("Motor6D") then
		return instance.C0, instance.C1
	end
	return instance.Attachment0.CFrame, instance.Attachment1.CFrame
end

function Rig.new(character: Model): Rig?
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local joints, byPart = {}, {}
	for name, partName in JOINT_PARTS do
		local part1 = character:FindFirstChild(partName)
		local instance = part1 and part1:FindFirstChild(name)
		local part0: BasePart? = nil
		if instance and instance:IsA("Motor6D") then
			part0 = instance.Part0
		elseif instance and instance:IsA("AnimationConstraint") and instance.Attachment0 and instance.Attachment1 then
			part0 = instance.Attachment0.Parent :: BasePart
		end
		if not part0 then
			return nil
		end
		local joint = { name = name, instance = instance, part0 = part0, part1 = part1 :: BasePart }
		joints[name] = joint
		byPart[partName] = joint
	end
	return setmetatable({ character = character, root = root, joints = joints, byPart = byPart, pose = {} }, Rig)
end

function Rig.Set(self: Rig, joint: string, rotation: CFrame)
	self.pose[joint] = rotation
end

function Rig.Clear(self: Rig)
	table.clear(self.pose)
end

-- Écrit la pose dans le squelette (à appeler à chaque image, après l'Animator)
function Rig.Apply(self: Rig)
	for name, joint in self.joints do
		joint.instance.Transform = self.pose[name] or CFrame.identity
	end
end

-- Rend la main aux animations de Roblox
function Rig.Release(self: Rig)
	self:Clear()
	self:Apply()
end

function Rig.PartCFrame(self: Rig, partName: string): CFrame
	if partName == self.root.Name then
		return self.root.CFrame
	end
	local joint = self.byPart[partName]
	local c0, c1 = frames(joint)
	return self:PartCFrame(joint.part0.Name) * c0 * (self.pose[joint.name] or CFrame.identity) * c1:Inverse()
end

-- Repère monde d'une articulation (côté pièce parente), pose en cours comprise pour les parents
function Rig.JointFrame(self: Rig, joint: string): CFrame
	local j = self.joints[joint]
	local c0 = frames(j)
	return self:PartCFrame(j.part0.Name) * c0
end

-- Place une pièce à un endroit du monde en réglant l'articulation qui la porte
function Rig.Place(self: Rig, partName: string, world: CFrame)
	local joint = self.byPart[partName]
	local c0, c1 = frames(joint)
	self.pose[joint.name] = (self:PartCFrame(joint.part0.Name) * c0):Inverse() * world * c1
end

-- Os de l'articulation `from` (sur la pièce) à l'articulation suivante `to`, dans le repère de `from`
local function bone(self: Rig, from: string, to: string): Vector3
	local _, c1 = frames(self.joints[from])
	local c0 = frames(self.joints[to])
	return c1:VectorToObjectSpace(c0.Position - c1.Position)
end

local function boneLength(self: Rig, from: string, to: string): number
	return bone(self, from, to).Magnitude
end

-- Angle signé de `a` vers `b` autour de `axis`
local function signedAngle(a: Vector3, b: Vector3, axis: Vector3): number
	return math.atan2(a:Cross(b):Dot(axis), a:Dot(b))
end

-- Repère d'un os : Y opposé à sa direction, X = axe de pliage
local function boneFrame(direction: Vector3, axis: Vector3): CFrame
	local x = (axis - direction * axis:Dot(direction)).Unit
	return CFrame.fromMatrix(Vector3.zero, x, -direction)
end

-- Bras ou jambe qui atteint `target` (position de l'articulation du bout : poignet ou cheville).
-- `pole` : direction (monde) vers laquelle pointe le coude ou le genou.
-- Les os d'un avatar ne pendent pas forcément tout droit : on part de leur vraie direction au repos.
function Rig.Reach(self: Rig, limb: string, target: Vector3, pole: Vector3)
	local upper, middle, tip, sign = table.unpack(LIMBS[limb])
	local restUpper = bone(self, upper, middle)
	local restLower = bone(self, middle, tip)
	local a, b = restUpper.Magnitude, restLower.Magnitude
	local frame = self:JointFrame(upper)
	local localTarget = frame:PointToObjectSpace(target)
	local distance = math.clamp(localTarget.Magnitude, math.abs(a - b) + 0.01, a + b - 0.001)
	local dir = localTarget.Unit

	local localPole = frame:VectorToObjectSpace(pole)
	local side = localPole - dir * localPole:Dot(dir)
	if side.Magnitude < 1e-3 then
		side = Vector3.new(0, 0, -sign)
	end
	side = side.Unit

	-- Os du haut : écarté de la cible vers le pôle, pour que le coude (genou) pointe du bon côté
	local angle = math.acos(math.clamp((a * a + distance * distance - b * b) / (2 * a * distance), -1, 1))
	local up = dir * math.cos(angle) + side * math.sin(angle)
	local lower = (dir * distance - up * a).Unit
	local bend = lower - up * lower:Dot(up)
	bend = if bend.Magnitude < 1e-3 then Vector3.new(0, 0, -sign) else bend.Unit
	-- Axe de pliage : au repos X (le coude plie l'avant-bras vers l'avant, le genou le tibia vers l'arrière)
	local axis = up:Cross(bend) * sign
	local rest = boneFrame(restUpper.Unit, Vector3.xAxis)
	local wanted = boneFrame(up, axis)
	self.pose[upper] = wanted * rest:Inverse()
	-- Pliage du milieu : écart entre l'angle voulu et l'angle de repos des deux os
	local restAngle = signedAngle(restUpper.Unit, restLower.Unit, rest.XVector)
	local wantedAngle = signedAngle(up, lower, wanted.XVector)
	self.pose[middle] = CFrame.Angles(wantedAngle - restAngle, 0, 0)
end

-- Mesures du corps au repos (pour adapter les poses à toutes les tailles de personnage)
export type Measures = {
	ground: number, -- hauteur du sol sous le personnage debout
	hipHeight: number, -- articulation de hanche au-dessus du sol
	shoulderHeight: number,
	shoulderWidth: number, -- écart entre les deux épaules
	armLength: number, -- épaule -> poignet
	legLength: number, -- hanche -> cheville
	ankleHeight: number, -- cheville au-dessus du sol
}

function Rig.Measure(self: Rig, humanoid: Humanoid): Measures
	local saved = table.clone(self.pose)
	self:Clear()
	local rootCF = self.root.CFrame
	local ground = rootCF.Position.Y - self.root.Size.Y / 2 - humanoid.HipHeight
	local function height(joint: string): number
		return self:JointFrame(joint).Position.Y - ground
	end
	local measures = {
		ground = ground,
		hipHeight = height("LeftHip"),
		shoulderHeight = height("LeftShoulder"),
		shoulderWidth = (self:JointFrame("LeftShoulder").Position - self:JointFrame("RightShoulder").Position).Magnitude,
		armLength = boneLength(self, "LeftShoulder", "LeftElbow") + boneLength(self, "LeftElbow", "LeftWrist"),
		legLength = boneLength(self, "LeftHip", "LeftKnee") + boneLength(self, "LeftKnee", "LeftAnkle"),
		ankleHeight = height("LeftAnkle"),
	}
	self.pose = saved
	return measures
end

return Rig
