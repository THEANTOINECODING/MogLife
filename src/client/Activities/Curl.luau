-- Curl : le joueur soulève vraiment l'haltère-pastèque de la station, coudes collés au corps.
-- p = 0 bras tendus, 1 haltère sous le menton. Une répétition ratée triche (le buste part en arrière).

local Curl = {}
Curl.__index = Curl

local STAND_Z = 1.4 -- le joueur se tient derrière l'haltère, face au devant de la station
local GRIP = 0.62 -- demi-écart des mains (la barre est courte : les pastèques prennent la place)

function Curl.Stand(top: CFrame): CFrame
	return top * CFrame.new(0, 0, STAND_Z)
end

function Curl.new(ctx)
	local self = setmetatable({ ctx = ctx }, Curl)
	self.bar = ctx.borrow("WatermelonDumbbell")
	return self
end

function Curl:Pose(p: number, shake: number, _u: number, time: number)
	local ctx = self.ctx
	local rig, m = ctx.rig, ctx.measures
	local root = rig.root.CFrame
	local tremble = shake * math.sin(time * 38) * 0.08
	rig:Set("Waist", CFrame.Angles(shake * p * 0.3 + tremble * 0.5, 0, 0))

	-- Le poignet décrit un arc autour du coude, qui reste le long du corps
	local angle = math.rad(12 + 135 * p)
	local half = m.armLength * 0.5
	local wrists = {}
	for _, side in { -1, 1 } do
		local shoulder =
			root:PointToObjectSpace(rig:JointFrame(if side < 0 then "LeftShoulder" else "RightShoulder").Position)
		local elbow = shoulder + Vector3.new(0, -half, -0.25)
		local wrist = elbow + Vector3.new(0, -math.cos(angle), -math.sin(angle)) * half
		local target = root * Vector3.new(side * GRIP, wrist.Y + tremble, wrist.Z)
		rig:Reach(
			if side < 0 then "LeftArm" else "RightArm",
			target,
			root.LookVector * -1 + root.RightVector * side * 0.6
		)
		wrists[side] = target
	end
	if self.bar then
		self.bar.CFrame = CFrame.new((wrists[-1] + wrists[1]) / 2) * ctx.top.Rotation
	end
end

function Curl:Destroy() end

return Curl
