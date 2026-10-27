-- Brayan : choc de rayons solaires (D85). Chacun tient un grand miroir ; deux rayons de soleil se rencontrent entre
-- eux et le point de choc crépite. Chaque coup réussi pousse le point de choc vers l'adversaire (il avance vers celui
-- qui perd). Dernière manche : Brayan éblouit (éclair doré), le joueur se protège les yeux. Fin : le perdant est
-- soufflé par le rayon.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fights = require(ReplicatedStorage.Shared.Config.BossFights)
local Fx = require(script.Parent.Fx)
local Poses = require(script.Parent.Poses)
local Scene = require(script.Parent.Scene)

local SETTINGS = Fights.Brayan
local MIRROR = Color3.fromRGB(185, 220, 245)
local FRAME = Color3.fromRGB(230, 185, 60)
local PLAYER_BEAM = Color3.fromRGB(255, 225, 110)
local BOSS_BEAM = Color3.fromRGB(255, 140, 50)

local function beam(scene, a0: Attachment, a1: Attachment, color: Color3): Beam
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Width0 = SETTINGS.BeamWidth
	b.Width1 = SETTINGS.BeamWidth * 0.6
	b.Color = ColorSequence.new(color)
	b.LightEmission = 1
	b.LightInfluence = 0
	b.FaceCamera = true
	b.Segments = 1
	b.Transparency = NumberSequence.new(0.1, 0.25)
	b.Parent = scene.props.folder
	return b
end

local def = {
	Distance = SETTINGS.Distance,
	BossShift = SETTINGS.BossShift,
}

function def.Setup(scene)
	local data = scene.data
	-- Miroirs : une surface qui reflète, dans un cadre doré (un peu plus grand derrière)
	local function mirror(size: Vector3): (Part, Part)
		local glass = scene.props:Part(size, MIRROR, Enum.Material.SmoothPlastic)
		glass.Reflectance = 0.65
		local frame = scene.props:Part(size + Vector3.new(0.3, 0.3, -0.05), FRAME, Enum.Material.Metal)
		return glass, frame
	end
	data.playerMirror, data.playerFrame = mirror(SETTINGS.MirrorSize)
	data.bossMirror, data.bossFrame = mirror(SETTINGS.MirrorSize * 1.2)
	data.clash = scene.props:Part(Vector3.new(1.4, 1.4, 1.4), Color3.fromRGB(255, 250, 220), Enum.Material.Neon, "Ball")
	data.clash.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 140)
	light.Range = 16
	light.Brightness = 3
	light.Parent = data.clash
	data.light = light
	-- Attachements des rayons (dans le point de choc et les miroirs)
	data.clashPoint = Instance.new("Attachment")
	data.clashPoint.Parent = data.clash
	data.playerPoint = Instance.new("Attachment")
	data.playerPoint.Parent = data.playerMirror
	data.bossPoint = Instance.new("Attachment")
	data.bossPoint.Parent = data.bossMirror
	beam(scene, data.playerPoint, data.clashPoint, PLAYER_BEAM)
	beam(scene, data.bossPoint, data.clashPoint, BOSS_BEAM)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.5, 0)
	sparks.Lifetime = NumberRange.new(0.2, 0.4)
	sparks.Speed = NumberRange.new(6, 12)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 25
	sparks.Parent = data.clash
	data.nextGlare = os.clock() + 2.5
end

-- Le joueur tient son miroir à deux mains devant lui ; il pousse à chaque coup réussi
function def.PlayerPose(scene, rig, m, p, shake, now)
	local push = if scene.playerQuality ~= "Miss" then p else 0
	local blinded = scene:Pulse(now - (scene.data.glareAt or -math.huge), 0.9)
	Poses.Pelvis(rig, Vector3.new(0, -m.legLength * 0.06, -push * 0.3), -0.12 * push + 0.1 * blinded)
	Poses.Lunge(rig, m, 0.7)
	local stand = rig.root.CFrame
	local chest = (rig:JointFrame("LeftShoulder").Position + rig:JointFrame("RightShoulder").Position) / 2
	local center = chest + stand.LookVector * (m.armLength * (0.7 + 0.25 * push)) - stand.UpVector * 0.2
	local jitter = if shake > 0 then stand.RightVector * math.sin(now * 40) * 0.08 * shake else Vector3.zero
	local half = SETTINGS.MirrorSize.X * 0.5
	-- Mains sur les bords du cadre ; ébloui, la main gauche protège les yeux
	local covering = blinded > 0.2
	for _, sx in { -1, 1 } do
		local hand = center + stand.RightVector * sx * half + jitter
		if sx < 0 and covering then
			hand = rig:PartCFrame("Head").Position + stand.LookVector * 0.6 + stand.UpVector * 0.2
		end
		rig:Grip(if sx < 0 then "LeftArm" else "RightArm", hand, -stand.UpVector + stand.RightVector * sx)
	end
	rig:Set("Neck", CFrame.Angles(-0.1 - 0.3 * blinded, 0, 0))
	-- Le miroir est entre les vraies mains (d'une seule main quand l'autre protège les yeux)
	local right = rig:Palm("Right")
	local held = if covering then right - stand.RightVector * half else (rig:Palm("Left") + right) / 2
	scene.data.playerMirror.CFrame = CFrame.lookAt(held, held + stand.LookVector)
	scene.data.playerFrame.CFrame = scene.data.playerMirror.CFrame * CFrame.new(0, 0, 0.08)
end

function def.Boss(scene, _dt, now)
	local data = scene.data
	local part = scene.bossPart
	local toward = scene.toPlayer
	local push = scene:Strike(now - scene.bossHitAt) * (if scene.bossQuality == "Miss" then 0.2 else 1)
	local struck = scene:Recoil(now - scene.playerHitAt) * (if scene.playerQuality == "Miss" then 0 else 1)
	scene:MoveBoss(CFrame.new(0, 0, struck * 0.5 - push * 0.3))
	local center
	local rig = scene.bossRig
	if rig and part then
		local chest = (rig:Joint("LeftUpperArm") + rig:Joint("RightUpperArm")) / 2
		center = chest + toward * (2.2 + push * 0.4) - Vector3.new(0, 0.4, 0)
		local side = rig:Side()
		rig:Turn("UpperTorso", CFrame.Angles(0.12 * struck - 0.1 * push, 0, 0))
		for _, name in { "Left", "Right" } do
			local sx = if name == "Right" then 1 else -1
			rig:Reach(name, center + side * sx * SETTINGS.MirrorSize.X * 0.6, -Vector3.yAxis + side * sx)
		end
		-- Le miroir est entre ses vraies mains
		center = (rig:Palm("Left") + rig:Palm("Right")) / 2
	elseif part then
		center = part.Position + toward * 2.2
	else
		center = scene.bossSpot + toward * 2.2 + Vector3.new(0, 4, 0)
	end
	data.bossMirror.CFrame = CFrame.lookAt(center, center + toward)
	data.bossFrame.CFrame = data.bossMirror.CFrame * CFrame.new(0, 0, 0.08)
	data.bossMirrorOffset = if part then part.CFrame:ToObjectSpace(data.bossMirror.CFrame) else nil
	-- Point de choc : au milieu, poussé vers celui qui perd ; il grossit à chaque coup
	local from = data.playerMirror.Position
	local to = center
	local mid = (from + to) / 2 - toward * scene.lead * SETTINGS.ClashShift
	local pulse = math.max(push, struck)
	local size = 1.4 + pulse * 1.2 + math.sin(now * 25) * 0.1
	data.clash.Size = Vector3.new(size, size, size)
	data.clash.Position = mid
	-- Dernière manche : éclairs de bronzage
	if scene:Special() and now >= data.nextGlare then
		data.nextGlare = now + 3
		data.glareAt = now
		Fx.Burst(scene, center, "Sparks", 30, Color3.fromRGB(255, 180, 60))
	end
	data.light.Brightness = 3 + 8 * scene:Pulse(now - (data.glareAt or -math.huge), 0.5)
end

function def.PlayerRep(scene, quality)
	if quality ~= "Miss" then
		Fx.Burst(scene, scene.data.clash.Position, "Sparks", SETTINGS.Sparks * (if quality == "Perfect" then 2 else 1))
	end
end

function def.BossRep(scene, quality)
	if quality ~= "Miss" then
		Fx.Burst(scene, scene.data.clash.Position, "Sparks", SETTINGS.Sparks, Color3.fromRGB(255, 150, 60))
	end
end

function def.Finish(scene, won, t, rig, m)
	local blast = Poses.Ease(t * 2.5)
	local data = scene.data
	if won then
		-- Le rayon du joueur l'emporte : Brayan est soufflé en tournoyant
		data.clash.Position = data.clash.Position:Lerp(data.bossMirror.Position, blast)
		scene:MoveBoss(
			CFrame.new(0, blast * 1.5, blast * 4) * CFrame.Angles(math.rad(30) * blast, math.rad(540) * blast, 0)
		)
		-- Son miroir part avec lui
		if scene.bossPart and data.bossMirrorOffset then
			data.bossMirror.CFrame = scene.bossPart.CFrame * data.bossMirrorOffset
			data.bossFrame.CFrame = data.bossMirror.CFrame * CFrame.new(0, 0, 0.08)
		end
		if rig and m then
			Poses.Victory(rig, m, t)
		end
	else
		data.clash.Position = data.clash.Position:Lerp(data.playerMirror.Position, blast)
		local bossRig = scene.bossRig
		if bossRig then
			-- Double biceps de victoire
			for _, name in { "Left", "Right" } do
				local shoulder = bossRig:Joint(name .. "UpperArm")
				local side = bossRig:Side() * (if name == "Right" then 1 else -1)
				bossRig:Reach(name, shoulder + side * 1.2 + Vector3.new(0, 1.3, 0), -side)
			end
		end
		if rig and m then
			Poses.Slump(rig, m, t, -1)
		end
	end
	data.clash.Transparency = blast * 0.8
end

return Scene.Activity("Brayan", def)
