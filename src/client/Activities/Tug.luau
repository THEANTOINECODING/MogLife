-- Tug of Mog (duel entre joueurs, D67) : les deux joueurs se font face sur l'estrade et tirent sur la même corde,
-- assis en arrière, pieds plantés. À chaque répétition validée, le joueur donne un grand coup de reins (p = 1).
-- La corde et son drapeau sont dessinés localement entre les mains des deux joueurs ; le drapeau suit l'attribut
-- Rope des emplacements (publié par DuelService) : tout le monde voit qui est en train de gagner.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Duels = require(ReplicatedStorage.Shared.Config.Duels)

local ROPE_COLOR = Color3.fromRGB(226, 182, 112)
local FLAG_COLOR = Color3.fromRGB(230, 50, 50)

type RopeVisual = {
	count: number,
	rope: Part,
	flag: Part,
	grips: { [string]: Vector3 },
}

-- Une corde par estrade, partagée par les deux joueurs qui s'y affrontent
local visuals: { [string]: RopeVisual } = {}

local Tug = {}
Tug.__index = Tug

-- Sur l'emplacement, face à l'adversaire (l'emplacement regarde vers l'autre)
function Tug.Stand(top: CFrame): CFrame
	return top
end

local function folder(): Folder
	local existing = workspace:FindFirstChild("DuelRopes")
	if existing then
		return existing :: Folder
	end
	local created = Instance.new("Folder")
	created.Name = "DuelRopes"
	-- Accessoire d'activité : la caméra ne le prend jamais pour un obstacle (CameraFraming)
	created:SetAttribute("ActivityProps", true)
	created.Parent = workspace
	return created
end

local function newPart(name: string, shape: Enum.PartType, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Color = color
	part.Material = Enum.Material.Fabric
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = folder()
	return part
end

-- L'autre emplacement de la même estrade
local function otherSpot(anchor: BasePart): BasePart?
	local arena = anchor:GetAttribute("Arena")
	for _, spot in game:GetService("CollectionService"):GetTagged("DuelSpot") do
		if spot ~= anchor and spot:IsA("BasePart") and spot:GetAttribute("Arena") == arena then
			return spot
		end
	end
	return nil
end

function Tug.new(ctx)
	local self = setmetatable({ ctx = ctx }, Tug)
	local anchor = ctx.anchor :: BasePart
	self.arena = tostring(anchor:GetAttribute("Arena"))
	self.side = tostring(anchor:GetAttribute("Side"))
	self.other = otherSpot(anchor)
	local visual = visuals[self.arena]
	if not visual then
		local rope = newPart("Rope", Enum.PartType.Cylinder, ROPE_COLOR)
		local flag = newPart("Flag", Enum.PartType.Block, FLAG_COLOR)
		flag.Size = Vector3.new(0.2, 1.6, 1.3)
		visual = { count = 0, rope = rope, flag = flag, grips = {} }
		visuals[self.arena] = visual
	end
	visual.count += 1
	self.visual = visual

	-- Repos mesuré par rapport au HumanoidRootPart (comme le squat) : bassin et chevilles
	local rig = ctx.rig
	local saved = table.clone(rig.pose)
	rig:Clear()
	local root = rig.root.CFrame
	self.lower = root:ToObjectSpace(rig:PartCFrame("LowerTorso"))
	self.ankles = {
		[-1] = root:PointToObjectSpace(rig:JointFrame("LeftAnkle").Position),
		[1] = root:PointToObjectSpace(rig:JointFrame("RightAnkle").Position),
	}
	rig.pose = saved
	return self
end

-- Corde entre les mains des deux joueurs (ou vers l'autre emplacement si l'adversaire n'a pas de personnage animé)
local function drawRope(self, grip: Vector3)
	local visual = self.visual
	visual.grips[self.side] = grip
	local otherSide = if self.side == "A" then "B" else "A"
	local far = visual.grips[otherSide]
	if not far and self.other then
		far = self.other.Position + Vector3.new(0, grip.Y - self.ctx.anchor.Position.Y, 0)
	end
	if not far then
		return
	end
	-- La corde dépasse un peu derrière les mains de chacun
	local direction = far - grip
	local length = direction.Magnitude
	if length < 0.5 then
		return
	end
	local unit = direction.Unit
	local from, to = grip - unit * 1.2, far + unit * 1.2
	visual.rope.Size = Vector3.new((to - from).Magnitude, 0.45, 0.45)
	visual.rope.CFrame = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.pi / 2, 0)
	-- Drapeau : au milieu quand la corde est à 0, vers le côté qui gagne (Rope > 0 : côté A)
	local rope = tonumber(self.ctx.anchor:GetAttribute("Rope")) or 0
	local share = math.clamp(rope / Duels.RopeLimit, -1, 1)
	local towardA = if self.side == "A" then -unit else unit
	local middle = (grip + far) / 2 + towardA * share * (length / 2 - 1.5)
	visual.flag.CFrame = CFrame.lookAt(middle - Vector3.new(0, 0.8, 0), middle - Vector3.new(0, 0.8, 0) + unit)
		* CFrame.Angles(0, math.pi / 2, 0)
end

function Tug:Pose(p: number, shake: number, _u: number, time: number)
	local ctx = self.ctx
	local rig, m = ctx.rig, ctx.measures
	local root = rig.root.CFrame
	local tremble = shake * math.sin(time * 34) * 0.06
	-- Assis en arrière, et un grand coup de reins à chaque répétition
	local drop = m.legLength * (0.2 + 0.08 * p) + tremble
	local back = m.legLength * (0.18 + 0.12 * p)
	local lean = 0.3 + 0.25 * p
	local lower = root * self.lower
	rig:Place(
		"LowerTorso",
		CFrame.new(lower.Position - root.UpVector * drop - root.LookVector * back)
			* lower.Rotation
			* CFrame.Angles(lean, 0, 0)
	)
	rig:Set("Waist", CFrame.Angles(0.12 + 0.1 * p, 0, 0))
	rig:Set("Neck", CFrame.Angles(-0.35 - 0.1 * p, 0, 0))
	-- Pied avant en avant, pied arrière derrière (appui de tir)
	for _, side in { -1, 1 } do
		local ankle = root * self.ankles[side] + root.LookVector * (if side < 0 then 0.5 else -0.4)
		rig:Reach(if side < 0 then "LeftLeg" else "RightLeg", ankle, root.LookVector + root.RightVector * side * 0.3)
	end
	-- Mains l'une devant l'autre sur la corde, devant le ventre ; elles ramènent la corde pendant le coup
	local pelvis = rig:PartCFrame("LowerTorso").Position
	local grip = Vector3.new(0, pelvis.Y + 0.6, 0)
		+ root.Position * Vector3.new(1, 0, 1)
		+ root.LookVector * (m.armLength * (0.85 - 0.25 * p))
	for _, side in { -1, 1 } do
		local hand = grip + root.LookVector * (if side < 0 then 0.35 else -0.1) + root.UpVector * tremble
		rig:Reach(if side < 0 then "LeftArm" else "RightArm", hand, -root.UpVector + root.RightVector * side * 0.8)
	end
	drawRope(self, grip)
end

function Tug:Destroy()
	local visual = self.visual
	visual.grips[self.side] = nil
	visual.count -= 1
	if visual.count <= 0 then
		visual.rope:Destroy()
		visual.flag:Destroy()
		visuals[self.arena] = nil
	end
end

return Tug
