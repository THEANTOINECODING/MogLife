-- Combat de boss = Mog-off (D24, D37) : le joueur enchaîne de vraies poses de culturisme face au boss, une par
-- répétition (double biceps, most muscular, lat spread, pectoraux de profil, bras en V), plus ou moins réussies
-- selon son jeu. Le boss réplique en direct : il se gonfle à chacune de ses répétitions (plus s'il réussit).

local MogOff = {}
MogOff.__index = MogOff

local PULSE = { Perfect = 0.16, Good = 0.09, Miss = 0.03 }
local PULSE_TIME = 0.55

-- Face au boss, à bonne distance
function MogOff.Stand(top: CFrame): CFrame
	return top * CFrame.new(0, 0, -7) * CFrame.Angles(0, math.pi, 0)
end

-- Le modèle du boss : le PNJ le plus proche de son estrade
local function findBoss(anchor: BasePart): Model?
	local folder = workspace:FindFirstChild("Npcs")
	local best, bestDistance = nil, 12
	for _, model in if folder then folder:GetChildren() else {} do
		if model:IsA("Model") then
			local distance = (model:GetPivot().Position - anchor.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = model, distance
			end
		end
	end
	return best
end

function MogOff.new(ctx)
	local self = setmetatable({ ctx = ctx, pulse = 0, pulseAt = 0, lastFactor = 1 }, MogOff)
	self.boss = findBoss(ctx.anchor)
	self.scale = if self.boss then self.boss:GetScale() else 1
	return self
end

-- Le boss vient de jouer une répétition
function MogOff:OpponentRep(quality: string)
	self.pulse = PULSE[quality] or 0
	self.pulseAt = os.clock()
end

-- Positions des poignets (repère du personnage) et pôles des coudes, pour chaque pose
local function pose(index: number, rig, m, root: CFrame)
	local up, side, forward = root.UpVector, root.RightVector, root.LookVector
	local half = m.armLength * 0.5
	local shoulders = {
		[-1] = rig:JointFrame("LeftShoulder").Position,
		[1] = rig:JointFrame("RightShoulder").Position,
	}
	local hips = rig:JointFrame("LeftHip").Position.Y
	local targets, poles, waist = {}, {}, CFrame.identity
	for _, sx in { -1, 1 } do
		local sh = shoulders[sx]
		local out = side * sx
		if index == 1 then -- double biceps de face : coudes à hauteur d'épaule, poings vers le ciel
			targets[sx] = sh + out * half * 1.05 + up * half * 0.95
			poles[sx] = out - up * 0.3
		elseif index == 2 then -- most muscular : poings joints devant le ventre, coudes écartés
			targets[sx] = Vector3.new(0, hips + half * 0.9, 0)
				+ root.Position * Vector3.new(1, 0, 1)
				+ forward * half * 1.1
				+ out * 0.25
			poles[sx] = out + up * 0.4
			waist = CFrame.Angles(-0.25, 0, 0)
		elseif index == 3 then -- lat spread : mains sur les hanches, coudes grand ouverts
			targets[sx] = Vector3.new(0, hips + 0.4, 0)
				+ root.Position * Vector3.new(1, 0, 1)
				+ out * (m.shoulderWidth * 0.45)
				- forward * 0.1
			poles[sx] = out + forward * 0.4
		elseif index == 4 then -- pectoraux de profil : buste tourné, un bras plié devant, l'autre qui le tient
			targets[sx] = sh + forward * half * 1.2 - up * half * 0.5 - out * half * 0.4
			poles[sx] = out - up
			waist = CFrame.Angles(0, 0.55, 0)
		else -- bras en V, victoire
			targets[sx] = sh + (out * 0.6 + up * 0.85).Unit * m.armLength * 0.97
			poles[sx] = out - up * 0.5
		end
	end
	return targets, poles, waist
end

-- Prend la pose n° index (1 à 5) avec l'amplitude p (0 = bras détendus, 1 = pose complète). Utilisé aussi par
-- les émotes (Activities/Emote.luau).
function MogOff.Strike(rig, m, index: number, p: number, shake: number, time: number)
	local root = rig.root.CFrame
	local tremble = shake * math.sin(time * 36) * 0.08
	local targets, poles, waist = pose(index, rig, m, root)
	-- Le buste se cambre dans la pose (une ratée tremble)
	rig:Set("Waist", CFrame.new():Lerp(waist, p) * CFrame.Angles(0.1 * p + tremble, 0, 0))
	rig:Set("Neck", CFrame.Angles(0.15 * p, 0, 0))
	for _, sx in { -1, 1 } do
		local shoulder = rig:JointFrame(if sx < 0 then "LeftShoulder" else "RightShoulder").Position
		local relaxed = shoulder - root.UpVector * m.armLength * 0.95 + root.RightVector * sx * 0.25
		local target = relaxed:Lerp(targets[sx], p) + root.UpVector * tremble
		rig:Reach(if sx < 0 then "LeftArm" else "RightArm", target, poles[sx])
	end
end

MogOff.PoseCount = 5

function MogOff:Pose(p: number, shake: number, _u: number, time: number, count: number)
	local index = (math.max(count, 1) - 1) % MogOff.PoseCount + 1
	MogOff.Strike(self.ctx.rig, self.ctx.measures, index, p, shake, time)
	-- Le boss se gonfle à chacune de ses répétitions, puis reprend sa taille
	if self.boss and self.boss.Parent then
		local t = (os.clock() - self.pulseAt) / PULSE_TIME
		local factor = if t < 1 then 1 + self.pulse * math.sin(t * math.pi) else 1
		if factor ~= self.lastFactor then
			self.lastFactor = factor
			self.boss:ScaleTo(self.scale * factor)
		end
	end
end

function MogOff:Destroy()
	if self.boss and self.boss.Parent then
		self.boss:ScaleTo(self.scale)
	end
end

return MogOff
