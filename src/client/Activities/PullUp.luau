-- Tractions : le joueur se suspend vraiment à la barre et se hisse menton au-dessus.
-- p = 0 suspendu bras tendus, 1 menton au-dessus de la barre. Une répétition ratée se balance et plafonne.

local PullUp = {}
PullUp.__index = PullUp

-- Caméra : suspendu, le corps et les mains montent au-dessus de la tête au repos : on cadre plus haut et un peu plus loin
PullUp.CloseUp = { focus = 1.6, scale = 1.1 }

local BAR = 7.9 -- hauteur de la barre au-dessus de la dalle (props_gym.py : pullup_bar)

function PullUp.Stand(top: CFrame): CFrame
	return top * CFrame.new(0, 0, 0.35)
end

function PullUp.new(ctx)
	local self = setmetatable({ ctx = ctx }, PullUp)
	local rig = ctx.rig
	local saved = table.clone(rig.pose)
	rig:Clear()
	local lower = rig:PartCFrame("LowerTorso")
	self.shoulders = lower:PointToObjectSpace(
		(rig:JointFrame("LeftShoulder").Position + rig:JointFrame("RightShoulder").Position) / 2
	)
	rig.pose = saved
	return self
end

function PullUp:Pose(p: number, shake: number, _u: number, time: number)
	local ctx = self.ctx
	local rig, m, top = ctx.rig, ctx.measures, ctx.top
	local bar = top * Vector3.new(0, BAR, 0)
	local hang = BAR - m.verticalReach * 0.97 - 0.2
	local chin = BAR - m.verticalReach * 0.32
	local height = hang + (chin - hang) * p
	local sway = shake * math.sin(time * 9) * 0.25
	local rotation = top.Rotation * CFrame.Angles(sway * 0.4, 0, 0)
	local shoulders = top * Vector3.new(0, height, 0.15)
	rig:Place("LowerTorso", CFrame.new(shoulders - rotation:VectorToWorldSpace(self.shoulders)) * rotation)
	-- Jambes repliées et croisées, tête qui regarde la barre
	rig:Set("LeftHip", CFrame.Angles(0.2, 0, 0))
	rig:Set("RightHip", CFrame.Angles(0.25, 0, -0.08))
	rig:Set("LeftKnee", CFrame.Angles(-1.1, 0, 0))
	rig:Set("RightKnee", CFrame.Angles(-1.0, 0, 0))
	rig:Set("Neck", CFrame.Angles(0.25 * (1 - p), 0, 0))
	for _, side in { -1, 1 } do
		local grip = bar + top.RightVector * side * m.handSpread - top.UpVector * 0.15
		rig:Reach(if side < 0 then "LeftArm" else "RightArm", grip, top.RightVector * side - top.UpVector * 0.6)
	end
end

function PullUp:Destroy() end

return PullUp
