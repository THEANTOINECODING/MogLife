-- Développé couché : le joueur est allongé sur le banc, décroche la barre et la pousse vraiment.
-- p = 0 bras tendus (barre au-dessus des épaules), 1 barre sur la poitrine.
-- Une répétition ratée reste à mi-course et tremble.

local BenchPress = {}
BenchPress.__index = BenchPress

-- Caméra : de profil et en hauteur (vu des pieds, la barre et les disques cachent le corps)
BenchPress.CloseUp = {
	-- La barre est en travers du corps : vue de côté, ses disques cachent tout. On filme depuis les pieds (le
	-- personnage allongé regarde vers sa tête), en hauteur, la barre en travers de l'image.
	steps = { { 155, 0.6 }, { -155, 0.6 }, { 180, 0.7 }, { 130, 0.8 }, { -130, 0.8 }, { 25, 0.9 }, { -25, 0.9 } },
	height = 2,
	scale = 0.75, -- allongé : le corps est moins haut, la caméra peut venir plus près
}

local SEAT = 1.975 -- dessus du banc au-dessus de la dalle (props_gym.py : bench_press)
local PELVIS_Z = 0.9 -- bassin vers le bout du banc, la tête sous les crochets
local UNRACK_TIME = 0.6
local FOOT_SIDE = 1.3 -- pieds de part et d'autre du banc

function BenchPress.Stand(top: CFrame): CFrame
	return top * CFrame.new(2.6, 0, 0.6)
end

function BenchPress.new(ctx)
	local self = setmetatable({ ctx = ctx, started = os.clock() }, BenchPress)
	self.bar = ctx.borrow("Barbell")
	self.rack = if self.bar then self.bar.CFrame.Position else ctx.top * Vector3.new(0, 4, -2.5)
	-- Allongé sur le dos, la tête vers le devant de la station
	local lower = ctx.character:FindFirstChild("LowerTorso") :: BasePart
	local rotation = ctx.top.Rotation * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.Angles(0, math.pi, 0)
	self.body = CFrame.new(ctx.top * Vector3.new(0, SEAT + lower.Size.Z / 2, PELVIS_Z)) * rotation
	return self
end

function BenchPress:Pose(p: number, shake: number, _u: number, time: number)
	local ctx = self.ctx
	local rig, m, top = ctx.rig, ctx.measures, ctx.top
	rig:Place("LowerTorso", self.body)
	local up = top.UpVector

	-- Jambes : pieds à plat au sol de chaque côté du banc, genoux vers le haut. Les pieds se posent aussi loin vers le
	-- bout du banc que la jambe le permet (banc haut, grand corps : ils se rapprochent) : jamais en l'air.
	for _, side in { -1, 1 } do
		local name = if side < 0 then "Left" else "Right"
		local hip = rig:JointFrame(name .. "Hip").Position
		local flatHip = top:PointToObjectSpace(hip)
		local drop = hip.Y - (top.Y + m.ankleHeight)
		local spread = math.abs(side * FOOT_SIDE - flatHip.X)
		local reach = m.legLength * 0.96
		local along = math.sqrt(math.max(reach * reach - drop * drop - spread * spread, 0))
		local spot = top * Vector3.new(side * FOOT_SIDE, 0, flatHip.Z + math.min(along, m.legLength * 0.62))
		-- Orteils vers le bout du banc (à l'opposé de la tête) ; le sol de la station (un rayon toucherait le coussin)
		local foot = CFrame.new(spot.X, top.Y + rig:Sole(name), spot.Z) * top.Rotation * CFrame.Angles(0, math.pi, 0)
		rig:Plant(name, foot, up - top.LookVector * 0.4)
	end

	-- Barre : décrochée au début, puis entre bras tendus et poitrine
	local shoulders = (rig:JointFrame("LeftShoulder").Position + rig:JointFrame("RightShoulder").Position) / 2
	local lockout = shoulders + up * (m.verticalReach * 0.95)
	local chest = shoulders + up * 0.55 - top.LookVector * 0.35
	local tremble = shake * math.sin(time * 42) * 0.12
	local center = lockout:Lerp(chest, p) + up * tremble
	local unrack = math.clamp((os.clock() - self.started) / UNRACK_TIME, 0, 1)
	center = self.rack:Lerp(center, unrack)

	for _, side in { -1, 1 } do
		local grip = center + top.RightVector * side * m.handSpread
		rig:Grip(if side < 0 then "LeftArm" else "RightArm", grip, -up + top.RightVector * side * 0.7)
	end
	-- La barre est toujours dans les mains (même si un bras court n'atteint pas tout à fait la cible)
	if self.bar then
		local hands = (rig:Palm("Left") + rig:Palm("Right")) / 2
		local held = if unrack < 1 then center else hands
		self.bar.CFrame = CFrame.new(held) * top.Rotation
	end
end

function BenchPress:Destroy() end

return BenchPress
