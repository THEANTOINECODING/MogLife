-- Pompes : le joueur est vraiment allongé sur le tapis, mains au sol, et descend puis remonte.
-- Le corps pivote sur la pointe des pieds ; les bras se plient tout seuls (mains fixes au sol).
-- p = 0 bras tendus, 1 poitrine près du sol. Une répétition ratée s'effondre (bassin qui s'affaisse).

local PushUp = {}
PushUp.__index = PushUp

-- Caméra : de trois quarts et un peu en hauteur, pour voir le corps allongé en entier
PushUp.CloseUp = {
	steps = { { 60, 0.4 }, { -60, 0.4 }, { 85, 0.5 }, { -85, 0.5 }, { 30, 0.7 }, { -30, 0.7 }, { 0, 1 } },
	height = 2,
}

local MAT = 0.16 -- épaisseur du tapis
local WRIST_HEIGHT = 0.35 -- poignet au-dessus du sol (la main est à plat)

function PushUp.Stand(top: CFrame): CFrame
	return top * CFrame.new(0, 0, 1.2)
end

function PushUp.new(ctx)
	local self = setmetatable({ ctx = ctx }, PushUp)
	local rig = ctx.rig
	-- Positions de repos des chevilles et des épaules dans le repère du bassin (corps droit)
	local saved = table.clone(rig.pose)
	rig:Clear()
	local lower = rig:PartCFrame("LowerTorso")
	local function rest(joint: string): Vector3
		return lower:PointToObjectSpace(rig:JointFrame(joint).Position)
	end
	self.ankles = (rest("LeftAnkle") + rest("RightAnkle")) / 2
	self.shoulders = (rest("LeftShoulder") + rest("RightShoulder")) / 2
	rig.pose = saved

	self.floor = ctx.top * CFrame.new(0, MAT, 0)
	local length = (self.shoulders - self.ankles).Magnitude
	self.feet = self.floor * Vector3.new(0, ctx.measures.ankleHeight * 0.6, 0.4 + length * 0.55)
	self.wrists = nil
	return self
end

-- Bassin placé pour un corps incliné de `tilt` (radians au-dessus du sol), pieds fixes
function PushUp:Body(tilt: number): CFrame
	local rotation = self.floor.Rotation * CFrame.Angles(-(math.pi / 2 - tilt), 0, 0)
	return CFrame.new(self.feet - rotation:VectorToWorldSpace(self.ankles)) * rotation
end

-- Inclinaison qui met les épaules à la hauteur voulue au-dessus du tapis
function PushUp:TiltFor(height: number): number
	local low, high = 0, math.rad(80)
	for _ = 1, 18 do
		local mid = (low + high) / 2
		local shoulders = self:Body(mid) * self.shoulders
		if self.floor:PointToObjectSpace(shoulders).Y < height then
			low = mid
		else
			high = mid
		end
	end
	return (low + high) / 2
end

function PushUp:Pose(p: number, shake: number, _u: number, time: number)
	local ctx = self.ctx
	local rig, m = ctx.rig, ctx.measures
	local high = m.armLength * 0.96 + WRIST_HEIGHT
	local low = m.armLength * 0.42 + WRIST_HEIGHT
	local tremble = shake * math.sin(time * 40) * 0.05
	local tilt = self:TiltFor(high + (low - high) * p + tremble)
	local body = self:Body(tilt)
	rig:Place("LowerTorso", body)
	-- Ratée : le bassin s'affaisse et la tête tombe
	rig:Set("Waist", CFrame.Angles(-shake * p * 0.25, 0, 0))
	rig:Set("Neck", CFrame.Angles(0.35 - shake * p * 0.5, 0, 0))

	-- Mains posées une fois pour toutes sous les épaules, bras tendus
	if not self.wrists then
		local top = self:Body(self:TiltFor(high))
		self.wrists = {}
		for _, side in { -1, 1 } do
			local shoulder = top * (self.shoulders + Vector3.new(side * m.shoulderWidth * 0.62, 0, 0))
			local onFloor = self.floor:PointToObjectSpace(shoulder)
			self.wrists[side] = self.floor * Vector3.new(onFloor.X, WRIST_HEIGHT, onFloor.Z)
		end
	end
	local feetward = -self.floor.LookVector
	for _, side in { -1, 1 } do
		local limb = if side < 0 then "LeftArm" else "RightArm"
		rig:Reach(limb, self.wrists[side], feetward + self.floor.RightVector * side * 0.8)
	end
end

function PushUp:Destroy() end

return PushUp
