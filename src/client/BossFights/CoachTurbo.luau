-- Coach Turbo : tir à la corde (D85). Une vraie corde entre le joueur et le Coach, un foulard rouge au milieu et une
-- ligne blanche au sol. Le joueur, penché en arrière, tire main sur main à chaque note réussie ; le Coach tire d'une
-- main et hurle le rythme dans son mégaphone de l'autre. Le foulard glisse vers celui qui mène, le Coach avance vers
-- la ligne quand il perd. Dernière manche : il hurle de plus en plus vite. Fin : le perdant passe la ligne et tombe.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fights = require(ReplicatedStorage.Shared.Config.BossFights)
local Fx = require(script.Parent.Fx)
local Poses = require(script.Parent.Poses)
local Scene = require(script.Parent.Scene)

local SETTINGS = Fights.CoachTurbo
local ROPE = Color3.fromRGB(196, 160, 100)
local FLAG = Color3.fromRGB(230, 40, 40)

local function ropeBetween(part: BasePart, from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	part.Size = Vector3.new(math.max(length, 0.1), 0.22, 0.22)
	part.CFrame = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.pi / 2, 0)
end

local def = {
	Distance = SETTINGS.Distance,
	BossShift = SETTINGS.BossShift,
	-- En fente pour tirer : pied gauche devant, pied droit derrière
	BossFeet = { Left = Vector3.new(-0.1, 0, -0.45), Right = Vector3.new(0.1, 0, 0.5) },
}

function def.Setup(scene)
	local data = scene.data
	-- La corde en trois morceaux : du Coach à la main avant du joueur, entre ses deux mains, et le bout qui pend
	-- derrière lui
	data.rope = scene.props:Part(Vector3.new(1, 0.22, 0.22), ROPE, Enum.Material.Fabric, "Cylinder")
	data.ropeMid = scene.props:Part(Vector3.new(1, 0.22, 0.22), ROPE, Enum.Material.Fabric, "Cylinder")
	data.ropeTail = scene.props:Part(Vector3.new(1, 0.22, 0.22), ROPE, Enum.Material.Fabric, "Cylinder")
	data.flag = scene.props:Part(Vector3.new(0.12, 0.9, 0.5), FLAG, Enum.Material.Fabric)
	local line = scene.props:Part(Vector3.new(4, 0.05, 0.25), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	line.CFrame = scene:Frame() * CFrame.new(0, 0.03, 0)
	data.nextShout = 0
	-- Prises de départ (remplacées dès la première image par les vraies mains)
	data.bossGrip = scene.middle - scene.toPlayer * 2 + Vector3.new(0, 3, 0)
	data.frontHand = scene.middle + scene.toPlayer * 2 + Vector3.new(0, 3, 0)
	data.backHand = data.frontHand + scene.toPlayer * 0.6
end

-- La corde passe exactement par les mains : main du Coach -> main avant du joueur -> main arrière -> bout qui pend
-- derrière lui jusqu'au sol. Le foulard est au milieu de la partie tendue et glisse vers celui qui mène.
local function drawRope(scene)
	local data = scene.data
	local boss, front, back = data.bossGrip, data.frontHand, data.backHand
	ropeBetween(data.rope, boss, front)
	ropeBetween(data.ropeMid, front, back)
	local away = (back - front) * Vector3.new(1, 0, 1)
	away = if away.Magnitude > 0.01 then away.Unit else scene.toPlayer
	local tail = back + away * 1.4 - Vector3.new(0, math.max(back.Y - scene.ground - 0.15, 0), 0)
	ropeBetween(data.ropeTail, back, tail)
	local dir = (front - boss).Unit
	local along = (front - boss).Magnitude / 2 - scene.lead * SETTINGS.RopeShift
	local at = boss + dir * along
	data.flag.CFrame = CFrame.lookAt(at, at + dir) * CFrame.new(0, -0.4, 0)
end

function def.PlayerPose(scene, rig, m, p, shake, now)
	local data = scene.data
	local yank = scene:Pulse(now - scene.bossHitAt, Fights.HitTime) * (if scene.bossQuality == "Miss" then 0.2 else 1)
	local lean = math.rad(SETTINGS.Lean) * (0.75 + 0.35 * p) - yank * 0.35
	-- Genoux pliés, penché en arrière, en fente ; un coup du Coach le tire vers l'avant
	Poses.Pelvis(rig, Vector3.new(0, -m.legLength * 0.18, -yank * 0.4), lean)
	Poses.Lunge(rig, m, 1)
	local stand = rig.root.CFrame
	-- La corde arrive de la main du Coach jusqu'à la taille du joueur ; ses deux mains sont posées dessus, l'une
	-- derrière l'autre, et ramènent la corde vers lui à chaque traction
	local waist = (rig:JointFrame("LeftHip").Position + rig:JointFrame("RightHip").Position) / 2
		+ stand.UpVector * 0.5
		+ stand.RightVector * 0.25
	local along = data.bossGrip - waist
	along = if along.Magnitude > 0.1 then along.Unit else stand.LookVector
	local reach = m.armLength * (0.95 - SETTINGS.PullBack * 0.45 * p)
	local jitter = if shake > 0 then Vector3.new(0, math.sin(now * 40) * 0.08 * shake, 0) else Vector3.zero
	rig:Grip("RightArm", waist + along * reach + jitter, -stand.UpVector + stand.RightVector * 0.6)
	rig:Grip("LeftArm", waist + along * (reach - 0.6) + jitter, -stand.UpVector - stand.RightVector * 0.6)
	rig:Set("Neck", CFrame.Angles(0.15 + 0.1 * p, 0, 0))
	-- La corde suit les vraies mains (même si un bras court n'atteint pas tout à fait la corde)
	data.frontHand = rig:Palm("Right")
	data.backHand = rig:Palm("Left")
	drawRope(scene)
end

function def.Boss(scene, _dt, now)
	local data = scene.data
	local pull = scene:Pulse(now - scene.bossHitAt, Fights.HitTime) * (if scene.bossQuality == "Miss" then 0.3 else 1)
	local yanked = scene:Pulse(now - scene.playerHitAt, Fights.HitTime)
		* (if scene.playerQuality == "Miss" then 0 else 1)
	-- Il avance vers la ligne quand il perd, recule quand il gagne
	local slide = -scene.lead * SETTINGS.RopeShift * 0.7 - yanked * 0.35 + pull * 0.25
	local lean = math.rad(SETTINGS.Lean) * (0.8 + 0.3 * pull - 0.4 * yanked)
	local rig = scene.bossRig
	local part = scene.bossPart
	if not part then
		return
	end
	if not rig then
		scene:MoveBoss(CFrame.new(0, 0, slide) * CFrame.Angles(lean * 0.6, 0, 0))
		-- Ancien modèle sans os : la corde va à sa hanche
		data.bossGrip = part.Position + scene.toPlayer * 2 - Vector3.new(0, part.Size.Y * 0.1, 0)
		drawRope(scene)
		return
	end
	-- Penché en arrière autour de ses pieds, qui restent au sol (genoux pliés)
	scene:MoveBoss(CFrame.new(0, -0.25 - 0.15 * pull, slide))
	rig:Turn("LowerTorso", CFrame.Angles(lean, 0, 0))
	-- Main droite sur la corde, devant lui un peu sous l'épaule ; il tire en ramenant la main
	-- Main gauche : le mégaphone à la bouche
	local toward = scene.toPlayer
	local shoulder = rig:Joint("RightUpperArm")
	local reach = rig:ArmLength("Right") * (0.9 - pull * 0.2)
	rig:Reach("Right", shoulder + (toward - Vector3.yAxis * 0.55).Unit * reach, -Vector3.yAxis)
	local head = rig:Joint("Head")
	local side = rig:Side()
	local shouting = now < (data.shoutUntil or 0)
	rig:Reach("Left", head + toward * (if shouting then 1.1 else 0.8) - side * 0.6 + Vector3.new(0, 0.2, 0), side)
	rig:Turn("Head", CFrame.Angles(if shouting then 0.25 else 0.05, 0, 0))
	-- La corde part du creux de sa main
	data.bossGrip = rig:Palm("Right")
	-- Coups de mégaphone (plus rapprochés pendant le coup spécial)
	if now >= data.nextShout then
		data.nextShout = now + SETTINGS.ShoutEvery * (if scene:Special() then 0.45 else 1)
		data.shoutUntil = now + 0.3
		Fx.Float(scene, head + toward * 1.6 + Vector3.new(0, 0.8, 0), "📣", 2)
	end
	drawRope(scene)
end

function def.PlayerRep(scene, quality)
	if quality ~= "Miss" then
		Fx.Burst(scene, scene.data.frontHand, "Dust", 4)
	end
end

function def.BossRep(scene, quality)
	if quality ~= "Miss" then
		Fx.Burst(scene, scene.data.bossGrip - Vector3.new(0, 2.5, 0), "Dust", 6)
	end
end

function def.Finish(scene, won, t, rig, m)
	local fall = Poses.Ease((t - 0.25) / 0.5)
	if won then
		-- Le Coach passe la ligne et s'étale face contre terre ; la corde tombe
		-- Il tourne en tombant : il s'étale en travers du ring, à côté du joueur
		scene:MoveBoss(
			CFrame.new(0, -fall * 1.2, -Poses.Ease(t * 2) * 1.6)
				* CFrame.Angles(0, math.rad(75) * fall, 0)
				* CFrame.Angles(-math.rad(85) * fall, 0, 0)
		)
		if rig and m then
			Poses.Victory(rig, m, t)
		end
	else
		-- Le joueur est tiré par-dessus la ligne et tombe à genoux ; le Coach hurle sa victoire
		scene:MoveBoss(CFrame.new(0, 0, Poses.Ease(t * 2) * 1.2))
		local bossRig = scene.bossRig
		if bossRig then
			local head = bossRig:Joint("Head")
			bossRig:Reach("Left", head + scene.toPlayer * 1 + Vector3.new(0, 0.4, 0), Vector3.yAxis)
			bossRig:Reach(
				"Right",
				head + Vector3.new(0, 2.5, 0) + scene.bossPart.CFrame.RightVector * 1.2,
				Vector3.yAxis
			)
		end
		if rig and m then
			Poses.Slump(rig, m, t, 1.4)
		end
	end
	-- La corde lâchée tombe au sol
	for _, piece in { scene.data.rope, scene.data.ropeMid, scene.data.ropeTail } do
		local flat = CFrame.new(piece.Position.X, scene.ground + 0.11, piece.Position.Z) * piece.CFrame.Rotation
		local level = CFrame.lookAt(flat.Position, flat.Position + flat.RightVector * Vector3.new(1, 0, 1))
			* CFrame.Angles(0, math.pi / 2, 0)
		piece.CFrame = piece.CFrame:Lerp(level, fall * 0.15)
	end
end

return Scene.Activity("CoachTurbo", def)
