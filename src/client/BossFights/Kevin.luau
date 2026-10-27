-- Kevin : bataille de polochons (D85). Chacun un oreiller à la main, face à face. À chaque coup réussi, le joueur
-- abat son oreiller sur Kevin : plumes, Kevin tourne sur lui-même. Quand Kevin frappe (ou quand le joueur rate),
-- c'est le joueur qui encaisse. Des étoiles tournent au-dessus de celui qui est en retard. Dernière manche : Kevin
-- bâille et pique du nez (Zzz). Fin : le perdant s'effondre dans une explosion de plumes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fights = require(ReplicatedStorage.Shared.Config.BossFights)
local Fx = require(script.Parent.Fx)
local Poses = require(script.Parent.Poses)
local Scene = require(script.Parent.Scene)

local SETTINGS = Fights.Kevin
local PILLOW = Vector3.new(2.4, 0.8, 1.5) -- assez gros pour se lire de loin, même face à un Gigachad

local def = {
	Distance = SETTINGS.Distance,
	BossShift = SETTINGS.BossShift,
}

function def.Setup(scene)
	scene.data.playerPillow = scene.props:Part(PILLOW, Color3.fromRGB(245, 245, 250), Enum.Material.Fabric)
	scene.data.bossPillow = scene.props:Part(PILLOW, Color3.fromRGB(150, 190, 235), Enum.Material.Fabric)
	scene.data.nextYawn = os.clock() + SETTINGS.Yawn
	scene.data.dizzy = nil
end

-- Le joueur : en garde, oreiller au-dessus de l'épaule ; il l'abat sur Kevin à chaque coup réussi
function def.PlayerPose(scene, rig, m, p, shake, now)
	local hit = if scene.playerQuality ~= "Miss" then p else 0
	-- Il encaisse : un coup de Kevin, ou son propre raté (Kevin le devance)
	local taken = math.max(
		math.max(scene:Recoil(scene:SinceBossImpact(now)), 0) * (if scene.bossQuality == "Miss" then 0 else 1),
		if scene.playerQuality == "Miss" then p else 0
	)
	Poses.Pelvis(rig, Vector3.new(0, -m.legLength * 0.08, taken * 0.4), -0.1 * hit + 0.15 * taken, 0.3 * hit)
	Poses.Lunge(rig, m, 0.6)
	local stand = rig.root.CFrame
	local shoulder = rig:JointFrame("RightShoulder").Position
	local raised = shoulder + stand.UpVector * m.armLength * 0.7 + stand.RightVector * 0.4 + stand.LookVector * 0.2
	local strike = shoulder + stand.LookVector * m.armLength * 0.95 + stand.UpVector * 0.3 - stand.RightVector * 0.3
	local jitter = if shake > 0 then stand.RightVector * math.sin(now * 40) * 0.1 * shake else Vector3.zero
	rig:Reach("RightArm", raised:Lerp(strike, hit) + jitter, stand.RightVector - stand.LookVector * 0.4)
	local left = rig:JointFrame("LeftShoulder").Position
	rig:Reach("LeftArm", left + stand.LookVector * m.armLength * 0.6, -stand.UpVector - stand.RightVector * 0.5)
	-- Tête qui part sur le côté quand il encaisse
	rig:Set("Neck", CFrame.Angles(0, 0.6 * taken, 0.3 * taken))
	-- L'oreiller suit la main droite
	local hand = rig:PartCFrame("RightHand")
	scene.data.playerPillow.CFrame = hand * CFrame.new(0, -0.5, 0) * CFrame.Angles(0, 0, math.rad(80))
	scene.data.playerHead = rig:PartCFrame("Head").Position
end

function def.Boss(scene, _dt, now)
	local part = scene.bossPart
	if not part then
		return
	end
	local swing = scene:Strike(now - scene.bossHitAt) * (if scene.bossQuality == "Miss" then 0.6 else 1)
	-- Il prend un coup : il tourne sur lui-même et recule
	local struck = scene:Recoil(now - scene.playerHitAt) * (if scene.playerQuality == "Miss" then 0 else 1)
	-- Dernière manche : il bâille et pique du nez
	local nap = 0
	if scene:Special() then
		if now >= scene.data.nextYawn then
			scene.data.nextYawn = now + SETTINGS.Yawn
			scene.data.yawnAt = now
			Fx.Float(scene, part.Position + Vector3.new(0, part.Size.Y * 0.55, 0), "💤", 3)
		end
		nap = scene:Pulse(now - (scene.data.yawnAt or -math.huge), 1.4)
	end
	scene:MoveBoss(CFrame.new(0, -nap * 0.4, struck * 0.6) * CFrame.Angles(0, math.rad(SETTINGS.SpinOnHit) * struck, 0))
	local rig = scene.bossRig
	if not rig then
		scene.data.bossPillow.CFrame = part.CFrame * CFrame.new(1.2, 0.5 + swing, -1 - swing)
		return
	end
	rig:Turn("UpperTorso", CFrame.Angles(-0.2 * swing - 0.35 * nap, 0.3 * swing, 0))
	rig:Turn("Head", CFrame.Angles(-0.4 * nap, -0.5 * struck, 0.3 * struck))
	local toward = scene.toPlayer
	local shoulder = rig:Joint("RightUpperArm")
	local up = Vector3.yAxis
	local raised = shoulder + up * 1.6 - toward * 0.3
	local strike = shoulder + toward * 2.2 + up * 0.3
	rig:Reach("Right", raised:Lerp(strike, swing), up)
	rig:Reach("Left", rig:Joint("LeftUpperArm") + toward * 1.2 - up * 0.6, -up)
	-- L'oreiller est tenu par un coin, dans le creux de la main
	local hand = rig:Palm("Right")
	scene.data.bossPillow.CFrame = CFrame.lookAt(hand, hand + toward) * CFrame.new(0, PILLOW.Y * 0.5, -PILLOW.Z * 0.4)
	scene.data.bossHead = rig:Joint("Head") + up * 0.8

	-- Étoiles au-dessus de celui qui est en retard
	local character = scene.player.Character
	local playerHead = character and character:FindFirstChild("Head") :: BasePart?
	if math.abs(scene.lead) > 0.3 then
		if not scene.data.dizzy then
			scene.data.dizzy = Fx.Badge(scene, part, "💫", part.Size.Y * 0.6, 2.2)
		end
		local billboard = scene.data.dizzy.Parent :: BillboardGui
		if scene.lead > 0 then
			billboard.Adornee = part
			billboard.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y * 0.6, 0)
		elseif playerHead then
			billboard.Adornee = playerHead
			billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
		end
		billboard.Enabled = true
		scene.data.dizzy.Rotation = (now * 200) % 360
	elseif scene.data.dizzy then
		(scene.data.dizzy.Parent :: BillboardGui).Enabled = false
	end
end

function def.PlayerRep(scene, quality)
	-- Le coup porte : plumes sur la tête de Kevin ; raté : c'est Kevin qui touche
	local target = if quality == "Miss" then scene.data.playerHead else scene.data.bossHead
	if target then
		Fx.Burst(scene, target, "Feathers", if quality == "Perfect" then SETTINGS.Feathers else SETTINGS.Feathers // 2)
	end
end

function def.BossRep(scene, quality)
	if quality ~= "Miss" and scene.data.playerHead then
		task.delay(SETTINGS.SwingTime * 0.5, function()
			Fx.Burst(scene, scene.data.playerHead, "Feathers", SETTINGS.Feathers // 2, Color3.fromRGB(190, 215, 245))
		end)
	end
end

function def.Finish(scene, won, t, rig, m)
	local fall = Poses.Ease((t - 0.1) / 0.45)
	-- Le joueur lâche son oreiller : il tombe au sol devant lui
	local pillow = scene.data.playerPillow
	if not scene.data.droppedFrom then
		scene.data.droppedFrom = pillow.CFrame
	end
	local ground = CFrame.new(scene.playerSpot + Vector3.new(0, 0.4, 0) - scene.toPlayer * 0.8)
	pillow.CFrame = scene.data.droppedFrom:Lerp(ground, Poses.Ease(t * 3))
	if won then
		-- Kevin part en arrière et s'étale ; explosion de plumes
		scene:MoveBoss(CFrame.new(0, -fall * 1.5, fall * 1.4) * CFrame.Angles(math.rad(80) * fall, 0, 0))
		if t < 0.12 and not scene.data.boom and scene.data.bossHead then
			scene.data.boom = true
			Fx.Burst(scene, scene.data.bossHead, "Feathers", SETTINGS.Feathers * 3)
		end
		if rig and m then
			Poses.Victory(rig, m, t)
		end
	else
		-- Le joueur s'effondre ; Kevin brandit son oreiller en sautillant
		local hop = math.abs(math.sin(t * math.pi * 4)) * 0.6
		scene:MoveBoss(CFrame.new(0, hop, 0))
		local bossRig = scene.bossRig
		if bossRig then
			bossRig:Reach("Right", bossRig:Joint("RightUpperArm") + Vector3.new(0, 2.2, 0), Vector3.yAxis)
			local hand = bossRig:Palm("Right")
			scene.data.bossPillow.CFrame = CFrame.new(hand + Vector3.new(0, PILLOW.Y * 0.5, 0))
		end
		if rig and m then
			Poses.Slump(rig, m, t, 0)
		end
	end
end

return Scene.Activity("Kevin", def)
