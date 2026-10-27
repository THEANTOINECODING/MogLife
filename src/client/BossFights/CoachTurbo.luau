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
}

function def.Setup(scene)
	scene.data.rope = scene.props:Part(Vector3.new(1, 0.22, 0.22), ROPE, Enum.Material.Fabric, "Cylinder")
	scene.data.flag = scene.props:Part(Vector3.new(0.12, 0.9, 0.5), FLAG, Enum.Material.Fabric)
	local line = scene.props:Part(Vector3.new(4, 0.05, 0.25), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	line.CFrame = scene:Frame() * CFrame.new(0, 0.03, 0)
	scene.data.nextShout = 0
	scene.data.playerGrip = scene.middle + scene.toPlayer * 3 + Vector3.new(0, 3, 0)
	scene.data.bossGrip = scene.middle - scene.toPlayer * 3 + Vector3.new(0, 3, 0)
end

-- Corde et foulard : de la main du joueur à celle du Coach ; le foulard suit qui mène
local function drawRope(scene)
	local from, to = scene.data.playerGrip, scene.data.bossGrip
	ropeBetween(scene.data.rope, from, to)
	local dir = (to - from).Unit
	local length = (to - from).Magnitude
	local along = length / 2 - scene.lead * SETTINGS.RopeShift
	scene.data.flag.CFrame = CFrame.lookAt(from + dir * along, from + dir * along + dir) * CFrame.new(0, -0.4, 0)
end

function def.PlayerPose(scene, rig, m, p, shake, now)
	local yank = scene:Pulse(now - scene.bossHitAt, Fights.HitTime) * (if scene.bossQuality == "Miss" then 0.2 else 1)
	local lean = math.rad(SETTINGS.Lean) * (0.75 + 0.35 * p) - yank * 0.35
	-- Genoux pliés, penché en arrière ; un coup du Coach le tire vers l'avant
	Poses.Pelvis(rig, Vector3.new(0, -m.legLength * 0.18, -yank * 0.4), lean)
	Poses.Lunge(rig, 1)
	local stand = rig.root.CFrame
	local hip = stand.Position + Vector3.new(0, m.hipHeight - (stand.Position.Y - m.ground) + 0.5, 0)
	local reach = m.armLength * (1.05 - SETTINGS.PullBack * 0.5 * p)
	local front = hip + stand.LookVector * reach
	-- Mains l'une derrière l'autre sur la corde ; la main avant tremble sur un raté
	local jitter = if shake > 0 then Vector3.new(0, math.sin(now * 40) * 0.08 * shake, 0) else Vector3.zero
	rig:Reach("RightArm", front + jitter, -stand.UpVector + stand.RightVector * 0.6)
	rig:Reach("LeftArm", front - stand.LookVector * 0.55 + jitter, -stand.UpVector - stand.RightVector * 0.6)
	rig:Set("Neck", CFrame.Angles(0.15 + 0.1 * p, 0, 0))
	scene.data.playerGrip = front + stand.LookVector * 0.2
end

function def.Boss(scene, _dt, now)
	local pull = scene:Pulse(now - scene.bossHitAt, Fights.HitTime) * (if scene.bossQuality == "Miss" then 0.3 else 1)
	local yanked = scene:Pulse(now - scene.playerHitAt, Fights.HitTime)
		* (if scene.playerQuality == "Miss" then 0 else 1)
	-- Il avance vers la ligne quand il perd, recule quand il gagne
	local slide = -scene.lead * SETTINGS.RopeShift * 0.7 - yanked * 0.35 + pull * 0.25
	local lean = math.rad(SETTINGS.Lean) * (0.8 + 0.3 * pull - 0.4 * yanked)
	scene:MoveBoss(CFrame.new(0, 0, slide))
	local rig = scene.bossRig
	local part = scene.bossPart
	if not part then
		return
	end
	if not rig then
		scene:MoveBoss(CFrame.new(0, 0, slide) * CFrame.Angles(lean * 0.6, 0, 0))
		-- Ancien modèle sans os : la corde va à sa hanche
		scene.data.bossGrip = part.Position + scene.toPlayer * 2 - Vector3.new(0, part.Size.Y * 0.1, 0)
		drawRope(scene)
		return
	end
	rig:Turn("LowerTorso", CFrame.Angles(lean, 0, 0))
	rig:Turn("LeftUpperLeg", CFrame.Angles(math.rad(35), 0, 0))
	rig:Turn("LeftLowerLeg", CFrame.Angles(math.rad(10), 0, 0))
	rig:Turn("RightUpperLeg", CFrame.Angles(math.rad(-5), 0, 0))
	-- Main droite sur la corde, devant lui à hauteur de hanche ; main gauche : le mégaphone à la bouche
	-- Prise à bout de bras (presque tendu), devant lui un peu sous l'épaule ; il tire en ramenant la main
	local toward = scene.toPlayer
	local shoulder = rig:Joint("RightUpperArm")
	local reach = rig:ArmLength("Right") * (0.9 - pull * 0.2)
	local grip = shoulder + (toward - Vector3.yAxis * 0.55).Unit * reach
	rig:Reach("Right", grip, -Vector3.yAxis)
	local head = rig:Joint("Head")
	local side = rig:Side()
	local shouting = now < (scene.data.shoutUntil or 0)
	rig:Reach("Left", head + toward * (if shouting then 1.1 else 0.8) - side * 0.6 + Vector3.new(0, 0.2, 0), side)
	rig:Turn("Head", CFrame.Angles(if shouting then 0.25 else 0.05, 0, 0))
	scene.data.bossGrip = grip
	-- Coups de mégaphone (plus rapprochés pendant le coup spécial)
	if now >= scene.data.nextShout then
		scene.data.nextShout = now + SETTINGS.ShoutEvery * (if scene:Special() then 0.45 else 1)
		scene.data.shoutUntil = now + 0.3
		Fx.Float(scene, head + toward * 1.6 + Vector3.new(0, 0.8, 0), "📣", 2)
	end
	drawRope(scene)
end

function def.PlayerRep(scene, quality)
	if quality ~= "Miss" then
		Fx.Burst(scene, scene.data.playerGrip, "Dust", 4)
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
	local drop = scene.data.rope
	if drop then
		drop.CFrame = drop.CFrame:Lerp(drop.CFrame - Vector3.new(0, 2, 0), fall * 0.1)
	end
end

return Scene.Activity("CoachTurbo", def)
