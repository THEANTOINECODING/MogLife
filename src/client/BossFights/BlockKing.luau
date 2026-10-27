-- Le Roi du Quartier : battle de poses royale (D85). Sur un tapis rouge, chacun enchaîne ses poses de culturisme : le
-- joueur à chaque combinaison réussie, le Roi à chacun de ses coups (double biceps, most muscular, lat spread…).
-- Son ventilateur royal souffle confettis et vent ; une couronne flotte au-dessus de celui qui mène. Dernière
-- manche : le vent souffle fort, le joueur résiste. Fin : le perdant met un genou à terre.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fights = require(ReplicatedStorage.Shared.Config.BossFights)
local MogOff = require(script.Parent.Parent.Activities.MogOff)
local Fx = require(script.Parent.Fx)
local Poses = require(script.Parent.Poses)
local Scene = require(script.Parent.Scene)

local SETTINGS = Fights.BlockKing
local CARPET = Color3.fromRGB(170, 25, 40)
local GOLD = Color3.fromRGB(230, 185, 60)

local def = {
	Distance = SETTINGS.Distance,
	BossShift = SETTINGS.BossShift,
}

function def.Setup(scene)
	local frame = scene:Frame()
	local carpet = scene.props:Part(Vector3.new(3.2, 0.06, SETTINGS.CarpetLength), CARPET, Enum.Material.Fabric)
	carpet.CFrame = frame * CFrame.new(0, 0.04, 0)
	for _, sx in { -1, 1 } do
		local trim = scene.props:Part(Vector3.new(0.2, 0.07, SETTINGS.CarpetLength), GOLD, Enum.Material.Fabric)
		trim.CFrame = frame * CFrame.new(sx * 1.6, 0.05, 0)
	end
	-- Le ventilateur royal, à côté du Roi : un pied, une tête, des pales qui tournent
	local base = frame * CFrame.new(-3.2, 0, -(SETTINGS.Distance + SETTINGS.BossShift) * 0.5)
	local pole = scene.props:Part(Vector3.new(0.3, 4, 0.3), GOLD, Enum.Material.Metal)
	pole.CFrame = base * CFrame.new(0, 2, 0)
	local hub = scene.props:Part(Vector3.new(0.8, 0.8, 0.8), GOLD, Enum.Material.Metal, "Ball")
	hub.CFrame = base * CFrame.new(0, 4.2, 0)
	scene.data.fanHub = hub
	scene.data.blades = {}
	for index = 1, 3 do
		local blade =
			scene.props:Part(Vector3.new(0.12, 2.6, 0.6), Color3.fromRGB(110, 40, 140), Enum.Material.SmoothPlastic)
		scene.data.blades[index] = blade
	end
	-- Le vent (et des confettis) souffle du ventilateur vers le joueur
	local emitterAt = Instance.new("Attachment")
	emitterAt.Parent = hub
	local wind = Instance.new("ParticleEmitter")
	wind.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	wind.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 90)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 90, 120)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 180, 255)),
	})
	wind.Size = NumberSequence.new(0.3, 0.15)
	wind.Lifetime = NumberRange.new(1, 1.5)
	wind.Speed = NumberRange.new(10, 16)
	wind.SpreadAngle = Vector2.new(20, 20)
	wind.Rate = 12
	wind.RotSpeed = NumberRange.new(-180, 180)
	wind.Parent = emitterAt
	scene.data.wind = wind
	scene.data.windAt = emitterAt
	scene.data.playerPoses = 0
	scene.data.bossPoses = 0
end

-- Le joueur : une pose à chaque combinaison réussie (les poses du Mog-off), il résiste au vent royal
function def.PlayerPose(scene, rig, m, p, shake, now)
	local gust = if scene:Special() then 0.5 + 0.5 * math.sin(now * 3) else 0
	local index = (math.max(scene.data.playerPoses, 1) - 1) % MogOff.PoseCount + 1
	MogOff.Strike(rig, m, index, p, shake, now)
	-- Penché contre le vent pendant le coup spécial
	if gust > 0 then
		rig:Set("Waist", CFrame.Angles(-0.25 * gust, 0, 0))
	end
	local head = rig:PartCFrame("Head")
	scene.data.playerHead = head.Position
end

-- Poses du Roi (os) : 1 double biceps, 2 most muscular, 3 lat spread
local function bossPose(scene, rig, index: number, k: number)
	local side = rig:Side()
	local toward = scene.toPlayer
	local up = Vector3.yAxis
	for _, name in { "Left", "Right" } do
		local sx = if name == "Right" then 1 else -1
		local shoulder = rig:Joint(name .. "UpperArm")
		local rest = rig:Joint(name .. "Hand")
		local target
		if index == 1 then
			target = shoulder + side * sx * 1.4 + up * 1.4
		elseif index == 2 then
			target = rig:Joint("LowerTorso") + toward * 1.4 + up * 0.6 + side * sx * 0.3
		else
			target = rig:Joint("LowerTorso") + side * sx * 1.2 + up * 0.4 - toward * 0.2
		end
		rig:Reach(name, rest:Lerp(target, k), if index == 1 then -side * sx else side * sx + up * 0.5)
	end
	rig:Turn("UpperTorso", CFrame.Angles(if index == 2 then -0.25 * k else 0.1 * k, 0, 0))
end

function def.Boss(scene, _dt, now)
	local data = scene.data
	-- Pales du ventilateur
	local hub = data.fanHub
	local spin = math.rad(SETTINGS.FanSpin) * now * (if scene:Special() then 1.8 else 1)
	local facing = CFrame.lookAt(hub.Position, hub.Position + scene.toPlayer)
	for index, blade in data.blades do
		blade.CFrame = facing * CFrame.Angles(0, 0, spin + index * 2 * math.pi / 3) * CFrame.new(0, 1.3, -0.5)
	end
	data.windAt.WorldCFrame = facing
	data.wind.EmissionDirection = Enum.NormalId.Front
	data.wind.Rate = if scene:Special() then 45 else 12
	local part = scene.bossPart
	if not part then
		return
	end
	local pose = scene:Pulse(now - scene.bossHitAt, 0.8) * (if scene.bossQuality == "Miss" then 0.4 else 1)
	local struck = scene:Recoil(now - scene.playerHitAt) * (if scene.playerQuality == "Miss" then 0 else 1)
	scene:MoveBoss(CFrame.new(0, 0, struck * 0.3) * CFrame.Angles(math.rad(6) * struck, 0, 0))
	local rig = scene.bossRig
	if rig then
		local index = (math.max(data.bossPoses, 1) - 1) % 3 + 1
		bossPose(scene, rig, index, pose)
	end
	-- Couronne au-dessus de celui qui mène
	if not data.crown then
		data.crown = Fx.Badge(scene, part, "👑", part.Size.Y * 0.5 + SETTINGS.CrownHeight, 2.4)
	end
	local billboard = data.crown.Parent :: BillboardGui
	local character = scene.player.Character
	local playerHead = character and character:FindFirstChild("Head") :: BasePart?
	if scene.lead > 0.15 and playerHead then
		billboard.Adornee = playerHead
		billboard.StudsOffsetWorldSpace = Vector3.new(0, SETTINGS.CrownHeight, 0)
	else
		billboard.Adornee = part
		billboard.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y * 0.5 + SETTINGS.CrownHeight * 0.4, 0)
	end
	data.crown.Rotation = math.sin(now * 2) * 8
end

function def.PlayerRep(scene, quality)
	scene.data.playerPoses += 1
	if quality == "Perfect" and scene.data.playerHead then
		Fx.Burst(scene, scene.data.playerHead, "Sparks", 14)
	end
end

function def.BossRep(scene, quality)
	scene.data.bossPoses += 1
	if quality ~= "Miss" and scene.bossPart then
		Fx.Burst(scene, scene.bossPart.Position + Vector3.new(0, scene.bossPart.Size.Y * 0.3, 0), "Sparks", 10, GOLD)
	end
end

function def.Finish(scene, won, t, rig, m)
	local k = Poses.Ease(t * 2)
	local bossRig = scene.bossRig
	if won then
		-- Le Roi met un genou à terre, tête basse ; la couronne passe au joueur
		scene:MoveBoss(CFrame.new(0, -k * 1.2, 0) * CFrame.Angles(math.rad(-15) * k, 0, 0))
		if bossRig then
			bossRig:Turn("LeftUpperLeg", CFrame.Angles(math.rad(80) * k, 0, 0))
			bossRig:Turn("LeftLowerLeg", CFrame.Angles(math.rad(-10) * k, 0, 0))
			bossRig:Turn("RightUpperLeg", CFrame.Angles(math.rad(-20) * k, 0, 0))
			bossRig:Turn("RightLowerLeg", CFrame.Angles(math.rad(-100) * k, 0, 0))
			bossRig:Turn("Head", CFrame.Angles(-0.5 * k, 0, 0))
			-- Bras qui retombent, mains vers le sol
			local side = bossRig:Side()
			for _, name in { "Left", "Right" } do
				local sx = if name == "Right" then 1 else -1
				local shoulder = bossRig:Joint(name .. "UpperArm")
				local down = shoulder + side * sx * 0.8 - Vector3.yAxis * bossRig:ArmLength(name) * 0.95
				bossRig:Reach(name, bossRig:Joint(name .. "Hand"):Lerp(down, k), side * sx)
			end
		end
		-- La couronne passe sur la tête du joueur
		local character = scene.player.Character
		local head = character and character:FindFirstChild("Head") :: BasePart?
		if scene.data.crown and head then
			local billboard = scene.data.crown.Parent :: BillboardGui
			billboard.Adornee = head
			billboard.StudsOffsetWorldSpace = Vector3.new(0, SETTINGS.CrownHeight, 0)
		end
		if rig and m then
			Poses.Victory(rig, m, t)
		end
	else
		-- Double biceps royal et pluie de confettis
		if bossRig then
			bossPose(scene, bossRig, 1, k)
		end
		scene.data.wind.Rate = 60
		if rig and m then
			Poses.Slump(rig, m, t, 0)
		end
	end
end

return Scene.Activity("BlockKing", def)
