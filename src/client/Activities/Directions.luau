-- Aide « Indiquer le chemin » (le touriste perdu) : à chaque répétition, le joueur montre vraiment une direction
-- du bras (gauche, droite, tout droit, derrière…), le corps tourné vers elle ; une ratée hésite et montre le ciel. D37.

local HelperStand = require(script.Parent.HelperStand)

local Directions = {}
Directions.__index = Directions

-- Directions montrées, dans le repère du joueur (il fait face au touriste)
local POINTS = {
	Vector3.new(-1, 0.15, -0.3),
	Vector3.new(1, 0.15, -0.3),
	Vector3.new(0.2, 0.2, -1),
	Vector3.new(-0.8, 0.1, 0.6),
	Vector3.new(0.9, 0.3, 0.4),
	Vector3.new(-0.3, 0.25, -1),
}

function Directions.Stand(top: CFrame): CFrame
	return HelperStand.Around(top)
end

function Directions.new(ctx)
	return setmetatable({ ctx = ctx }, Directions)
end

function Directions:Pose(p: number, shake: number, _u: number, time: number, count: number)
	local rig, m = self.ctx.rig, self.ctx.measures
	local root = rig.root.CFrame
	local point = POINTS[(math.max(count, 1) - 1) % #POINTS + 1]
	if shake > 0.5 then
		point = Vector3.new(math.sin(time * 3) * 0.4, 1, -0.2) -- il hésite et montre le ciel
	end
	local direction = root:VectorToWorldSpace(point.Unit)
	-- Le buste se tourne vers la direction, le bras droit se tend dans l'axe, la main gauche sur la hanche
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local yaw = if flat.Magnitude > 0.1 then math.atan2(-root.RightVector:Dot(flat), -root.LookVector:Dot(flat)) else 0
	rig:Set("Waist", CFrame.Angles(0, math.clamp(yaw, -0.9, 0.9) * 0.5 * p, 0))
	rig:Set("Neck", CFrame.Angles(0, math.clamp(yaw, -0.9, 0.9) * 0.4 * p, 0))
	local shoulder = rig:JointFrame("RightShoulder").Position
	local rest = shoulder - Vector3.yAxis * m.armLength * 0.95
	local pointing = shoulder + direction * m.armLength * 0.98
	rig:Reach("RightArm", rest:Lerp(pointing, p), -Vector3.yAxis + root.RightVector * 0.3)
	local hip = rig:JointFrame("LeftHip").Position
	rig:Reach("LeftArm", hip - root.RightVector * 0.5 + Vector3.yAxis * 0.3, -root.RightVector - root.LookVector * 0.3)
end

function Directions:Destroy() end

return Directions
