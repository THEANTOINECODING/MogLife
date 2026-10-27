-- Monsieur Pas-Les-Jambes : choc de pectoraux sur un ring (D85). Son estrade est un ring (dans la carte). À chaque coup réussi,
-- le joueur fonce torse en avant : onde de choc, le boss recule en vacillant sur ses jambes minuscules. Quand le boss
-- charge, c'est le joueur qui recule. Celui qui perd est repoussé vers le bord. Dernière manche : le ring tremble.
-- Fin : le perdant bascule hors du ring.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fights = require(ReplicatedStorage.Shared.Config.BossFights)
local Fx = require(script.Parent.Fx)
local Poses = require(script.Parent.Poses)
local Scene = require(script.Parent.Scene)

local SETTINGS = Fights.NoLegs
local WAVE = Color3.fromRGB(255, 235, 150)

local def = {
	Distance = SETTINGS.Distance,
	BossShift = SETTINGS.BossShift,
}

function def.Setup(scene)
	-- Son estrade est déjà un ring dans la carte (poteaux et cordes) : rien à ajouter
	scene.data.nextQuake = os.clock() + 2
end

local function contact(scene): Vector3
	return scene.middle + Vector3.new(0, 3, 0) - scene.toPlayer * scene.lead * SETTINGS.Push * 0.5
end

-- Le joueur : en garde, bras écartés vers l'arrière ; il fonce torse en avant à chaque coup réussi
function def.PlayerPose(scene, rig, m, p, shake, now)
	local bump = if scene.playerQuality ~= "Miss" then p else 0
	local hit = math.max(
		scene:Pulse(now - scene.bossHitAt, Fights.HitTime) * (if scene.bossQuality == "Miss" then 0 else 1),
		if scene.playerQuality == "Miss" then p else 0
	)
	-- Repoussé vers le bord quand il perd ; élan en avant à chaque choc, recul quand il encaisse
	local back = math.max(-scene.lead, 0) * SETTINGS.Push + hit * 0.7 - bump * SETTINGS.Lunge
	Poses.Pelvis(rig, Vector3.new(0, -m.legLength * 0.12, back), 0.25 * bump - 0.15 * hit + 0.1)
	-- Les pieds suivent l'élan et le recul (à moitié : la fente s'ouvre)
	Poses.Lunge(rig, m, 0.8, back * 0.5)
	local stand = rig.root.CFrame
	local jitter = if shake > 0 then math.sin(now * 40) * 0.1 * shake else 0
	for _, sx in { -1, 1 } do
		local shoulder = rig:JointFrame(if sx < 0 then "LeftShoulder" else "RightShoulder").Position
		local hand = shoulder
			+ stand.RightVector * sx * m.armLength * 0.6
			- stand.LookVector * m.armLength * (0.3 + 0.4 * bump)
			- stand.UpVector * (m.armLength * 0.4 + jitter)
		rig:Reach(if sx < 0 then "LeftArm" else "RightArm", hand, stand.RightVector * sx + stand.UpVector * 0.5)
	end
	rig:Set("Neck", CFrame.Angles(0.15 * bump, 0, 0))
end

function def.Boss(scene, _dt, now)
	local part = scene.bossPart
	if not part then
		return
	end
	local charge = scene:Pulse(now - scene.bossHitAt, Fights.HitTime) * (if scene.bossQuality == "Miss" then 0.3 else 1)
	local struck = scene:Pulse(now - scene.playerHitAt, Fights.HitTime)
		* (if scene.playerQuality == "Miss" then 0 else 1)
	-- Repoussé vers le bord quand il perd ; il charge à chacun de ses coups ; il vacille sans arrêt
	local back = math.max(scene.lead, 0) * SETTINGS.Push + struck * 0.8 - charge * SETTINGS.Lunge
	local wobble = math.rad(SETTINGS.Wobble) * (math.sin(now * 5.5) * (0.4 + struck) + math.sin(now * 13) * 0.15)
	local quake = 0
	if scene:Special() then
		if now >= scene.data.nextQuake then
			scene.data.nextQuake = now + 2.4
			scene.data.quakeAt = now
			Fx.Burst(scene, scene.top.Position + Vector3.new(0, 0.3, 0), "Dust", 20)
			Fx.Ring(
				scene,
				scene.top.Position + Vector3.new(0, 0.3, 0),
				Color3.fromRGB(210, 190, 150),
				SETTINGS.RingHalf
			)
		end
		quake = scene:Pulse(now - (scene.data.quakeAt or -math.huge), 0.6)
	end
	-- Le ring tremble : il sautille sur place
	local bounce = math.abs(math.sin(now * 25)) * 0.35 * quake
	scene:MoveBoss(CFrame.new(0, bounce, back) * CFrame.Angles(math.rad(10) * struck - math.rad(8) * charge, 0, wobble))
	local rig = scene.bossRig
	if not rig then
		return
	end
	-- Bras écartés vers l'arrière, torse bombé ; jambes minuscules qui tremblent
	local side = rig:Side()
	local toward = scene.toPlayer
	for _, name in { "Left", "Right" } do
		local sx = if name == "Right" then 1 else -1
		local shoulder = rig:Joint(name .. "UpperArm")
		rig:Reach(name, shoulder + side * sx * 1.8 - toward * (0.8 + charge) - Vector3.new(0, 1, 0), side * sx)
	end
	rig:Turn("UpperTorso", CFrame.Angles(0.2 * struck - 0.25 * charge, 0, 0))
	local tremble = math.sin(now * 30) * 0.12 * (0.5 + struck + quake)
	rig:Turn("LeftUpperLeg", CFrame.Angles(tremble, 0, 0))
	rig:Turn("RightUpperLeg", CFrame.Angles(-tremble, 0, 0))
end

function def.PlayerRep(scene, quality)
	if quality ~= "Miss" then
		Fx.Ring(scene, contact(scene) - Vector3.new(0, 2.7, 0), WAVE, 3.5)
		Fx.Burst(scene, contact(scene), "Sparks", if quality == "Perfect" then 16 else 8)
	end
end

function def.BossRep(scene, quality)
	if quality ~= "Miss" then
		Fx.Ring(scene, contact(scene) - Vector3.new(0, 2.7, 0), Color3.fromRGB(255, 120, 90), 3)
	end
end

function def.Finish(scene, won, t, rig, m)
	local fall = Poses.Ease((t - 0.15) / 0.55)
	if won then
		-- Il bascule en arrière hors du ring
		scene:MoveBoss(
			CFrame.new(0, -fall * 2.5, SETTINGS.Push + fall * (SETTINGS.RingHalf + 1 - SETTINGS.Push))
				* CFrame.Angles(math.rad(100) * fall, 0, 0)
		)
		if rig and m then
			Poses.Victory(rig, m, t)
		end
	else
		-- Le joueur est repoussé hors du ring et s'assoit ; le boss gonfle les pectoraux
		scene:MoveBoss(CFrame.new(0, 0, -SETTINGS.Push) * CFrame.Angles(-math.rad(8), 0, 0))
		if rig and m then
			Poses.Slump(rig, m, t, -(SETTINGS.Push + 1.5))
		end
	end
end

return Scene.Activity("NoLegs", def)
