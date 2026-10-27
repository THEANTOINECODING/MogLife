-- Squat : le joueur passe sous la barre du rack, la pose sur ses épaules et descend vraiment.
-- Pieds fixes au sol, bassin qui descend et recule, buste qui se penche.
-- p = 0 debout, 1 cuisses parallèles au sol. Une répétition ratée ne descend qu'à moitié et tremble.

local Squat = {}
Squat.__index = Squat

local STAND_Z = -2.3 -- juste devant les montants, la barre posée un peu derrière la nuque
local UNRACK_TIME = 0.5

function Squat.Stand(top: CFrame): CFrame
	return top * CFrame.new(0, 0, STAND_Z)
end

function Squat.new(ctx)
	local self = setmetatable({ ctx = ctx, started = os.clock() }, Squat)
	self.bar = ctx.borrow("Barbell")
	self.rack = if self.bar then self.bar.CFrame.Position else ctx.top * Vector3.new(0, 4.75, -1.95)
	local rig = ctx.rig
	local saved = table.clone(rig.pose)
	rig:Clear()
	-- Repos mesuré par rapport au HumanoidRootPart (sa position peut encore changer : réplication, placement)
	local root = rig.root.CFrame
	self.lower = root:ToObjectSpace(rig:PartCFrame("LowerTorso"))
	rig.pose = saved
	return self
end

function Squat:Pose(p: number, shake: number, _u: number, time: number)
	local ctx = self.ctx
	local rig, m = ctx.rig, ctx.measures
	local root = rig.root.CFrame
	local tremble = shake * math.sin(time * 36) * 0.07
	local drop = m.legLength * 0.45 * p + tremble
	local back = m.legLength * 0.22 * p
	local lower = root * self.lower
	rig:Place(
		"LowerTorso",
		CFrame.new(lower.Position - root.UpVector * drop - root.LookVector * back)
			* lower.Rotation
			* CFrame.Angles(-0.35 * p, 0, 0)
	)
	rig:Set("Waist", CFrame.Angles(-0.3 * p, 0, 0))
	rig:Set("Neck", CFrame.Angles(0.45 * p, 0, 0))
	-- Pieds à plat au sol, genoux vers l'avant et un peu en dehors
	rig:PlantFeet(nil, nil)

	-- Barre sur le haut du dos (suit le buste), décrochée au début
	local upper = rig:PartCFrame("UpperTorso")
	local torso = ctx.character:FindFirstChild("UpperTorso") :: BasePart
	local onBack = upper * Vector3.new(0, torso.Size.Y * 0.4, torso.Size.Z * 0.5 + 0.2)
	local unrack = math.clamp((os.clock() - self.started) / UNRACK_TIME, 0, 1)
	local center = self.rack:Lerp(onBack, unrack)
	for _, side in { -1, 1 } do
		local grip = center + root.RightVector * side * (m.handSpread * 1.1)
		rig:Grip(if side < 0 then "LeftArm" else "RightArm", grip, -root.UpVector + root.LookVector * -0.6)
	end
	if self.bar then
		-- Une fois décrochée, la barre est entre les vraies mains
		local held = if unrack >= 1 then (rig:Palm("Left") + rig:Palm("Right")) / 2 else center
		self.bar.CFrame = CFrame.new(held) * ctx.top.Rotation
	end
end

function Squat:Destroy() end

return Squat
