-- Animation du Dieu du Pump dans l'arène (D90). Il flotte, respire, suit le combattant des yeux et du buste, et
-- chaque attaque a sa pose, calée sur l'heure du serveur : préparation pendant l'avertissement, coup à l'impact,
-- retour en douceur.
--   Bolt     : bras droit levé au ciel, bras gauche qui désigne la cible ; il s'abaisse un peu à chaque éclair
--   Dumbbell : les deux bras au-dessus de la tête (il « appelle » l'haltère), puis il le lance vers l'avant
--   Wave     : double biceps en se ramassant, puis il frappe le sol des deux poings (l'onde part)
-- Avec os (Boss_PumpGod_Rig.fbx) : BossRig ; sans os (ancien modèle) : le corps entier flotte, se tourne et se baisse.
--   God.new(model) -> god ; god:Play(kind, start, impact) ; god:Step(target) à chaque image ; god:Destroy()

local BossRig = require(script.Parent.Parent.BossFights.BossRig)

local God = {}
God.__index = God

-- Durée de la frappe après l'impact, puis du retour au repos
local STRIKE = { Bolt = 0.25, Dumbbell = 0.45, Wave = 0.5 }
local RECOVER = 0.5

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

function God.new(model: Model)
	-- Le devant du dieu est celui de son corps (le serveur l'a tourné vers le centre de la piste)
	local body = model.PrimaryPart
	local pivot = model:GetPivot()
	local front = if body then body.CFrame.LookVector else pivot.LookVector
	local yaw = math.atan2(-front.X, -front.Z)
	local self = setmetatable({
		model = model,
		rig = BossRig.new(model),
		base = pivot,
		offset = CFrame.Angles(0, yaw, 0):Inverse() * pivot.Rotation, -- pivot du modèle dans le repère du devant
		height = model:GetExtentsSize().Y,
		yaw = yaw,
		action = nil :: { kind: string, start: number, impact: number }?,
		bornAt = os.clock(),
		body = body,
	}, God)
	return self
end

function God.Play(self, kind: string, start: number, impact: number)
	self.action = { kind = kind, start = start, impact = impact }
end

-- Poids de la pose d'attaque : monte pendant l'avertissement, tient pendant la frappe, redescend
function God.Weights(self, now: number): (string?, number, number)
	local action = self.action
	if not action then
		return nil, 0, 0
	end
	local strike = STRIKE[action.kind] or 0.3
	if now > action.impact + strike + RECOVER then
		self.action = nil
		return nil, 0, 0
	end
	local wind = math.max(action.impact - action.start, 0.1)
	local prepare = smooth((now - action.start) / math.min(wind, 0.6))
	local fade = 1 - smooth((now - action.impact - strike) / RECOVER)
	-- hit : 0 avant l'impact, puis un coup sec (0 -> 1 en 0,08 s)
	local hit = if now < action.impact then 0 else smooth((now - action.impact) / 0.08)
	return action.kind, math.min(prepare, fade), hit
end

-- Main vers une direction du repère du dieu (X à sa droite, Y en haut, Z devant), à une fraction de la longueur du bras
local function armTarget(rig, frame: CFrame, side: string, dir: Vector3, reach: number): Vector3
	local shoulder = rig:Joint(side .. "UpperArm")
	local world = frame:VectorToWorldSpace(Vector3.new(dir.X, dir.Y, -dir.Z))
	return shoulder + world.Unit * rig:ArmLength(side) * reach
end

local function lerp(a: Vector3, b: Vector3, k: number): Vector3
	return a + (b - a) * k
end

-- target : position (monde) du combattant, ou nil
function God.Step(self, now: number, target: Vector3?, aim: Vector3?)
	if not self.model.Parent then
		return
	end
	local t = os.clock() - self.bornAt
	local kind, w, hit = self:Weights(now)
	local h = self.height

	-- Se tourne vers le combattant (lentement : c'est un dieu)
	local pos = self.base.Position
	if target then
		local d = target - pos
		local wanted = math.atan2(-d.X, -d.Z)
		local current = self.yaw
		local delta = (wanted - current + math.pi) % (2 * math.pi) - math.pi
		self.yaw = current + delta * 0.06
	end
	-- Flotte : lente ondulation ; descend en préparant l'onde, plonge au coup
	local bob = math.sin(t * 1.7) * h * 0.025
	local dip = 0
	local lean = 0
	if kind == "Wave" then
		dip = -h * 0.05 * w - h * 0.06 * hit * w
		lean = 0.12 * w + 0.25 * hit * w
	elseif kind == "Dumbbell" then
		lean = -0.15 * w * (1 - hit) + 0.3 * hit * w
	elseif kind == "Bolt" then
		dip = -h * 0.02 * hit * w
		lean = -0.08 * w
	end
	local facing = CFrame.new(pos) * CFrame.Angles(0, self.yaw, 0)
	local rig = self.rig
	if not rig then
		-- Sans os : le corps entier se penche
		self.model:PivotTo(facing * CFrame.new(0, bob + dip, 0) * CFrame.Angles(-lean * 0.5, 0, 0) * self.offset)
		return
	end
	self.model:PivotTo(facing * CFrame.new(0, bob + dip, 0) * self.offset)

	rig:Clear()
	-- Buste : respiration, penché selon la pose, tourné un peu vers la cible
	local breath = math.sin(t * 2.2) * 0.04
	rig:Turn("LowerTorso", CFrame.Angles(-lean * 0.4, 0, 0))
	rig:Turn("UpperTorso", CFrame.Angles(-lean - breath, 0, 0))
	-- La tête baisse les yeux vers le combattant (il est en bas, sur la piste)
	local look = 0
	if aim then
		local head = rig:Joint("Head")
		local flat = Vector3.new(aim.X - head.X, 0, aim.Z - head.Z).Magnitude
		look = math.clamp(math.atan2(head.Y - aim.Y, math.max(flat, 1)) * 0.6, 0, 0.5)
	end
	rig:Turn("Head", CFrame.Angles(-lean - breath * 0.5 - look, 0, 0))

	-- Bras au repos : un peu écartés, ils se balancent
	local sway = math.sin(t * 1.7 + 0.6) * 0.06
	local idle = {
		Left = armTarget(rig, facing, "Left", Vector3.new(-0.45, -1, 0.1 + sway), 0.92),
		Right = armTarget(rig, facing, "Right", Vector3.new(0.45, -1, 0.1 - sway), 0.92),
	}
	local pose = { Left = idle.Left, Right = idle.Right }
	local bend = {
		Left = facing:VectorToWorldSpace(Vector3.new(-1, 0, 0.6)),
		Right = facing:VectorToWorldSpace(Vector3.new(1, 0, 0.6)),
	}
	if kind == "Bolt" then
		pose.Right = armTarget(rig, facing, "Right", Vector3.new(0.25, 1, 0.1 + 0.2 * hit), 0.95)
		local point = if aim then aim - rig:Joint("LeftUpperArm") else facing.LookVector
		local localPoint = facing:VectorToObjectSpace(point)
		pose.Left = armTarget(rig, facing, "Left", Vector3.new(localPoint.X, localPoint.Y, -localPoint.Z), 0.95)
	elseif kind == "Dumbbell" then
		-- Au-dessus de la tête, puis lancé devant lui
		local up = Vector3.new(0.15, 1, -0.25)
		local throw = Vector3.new(0.1, -0.2, 1)
		pose.Left =
			armTarget(rig, facing, "Left", lerp(up * Vector3.new(-1, 1, 1), throw * Vector3.new(-1, 1, 1), hit), 0.9)
		pose.Right = armTarget(rig, facing, "Right", lerp(up, throw, hit), 0.9)
		bend.Left = facing:VectorToWorldSpace(Vector3.new(-1, 0, 1))
		bend.Right = facing:VectorToWorldSpace(Vector3.new(1, 0, 1))
	elseif kind == "Wave" then
		-- Double biceps (coudes à hauteur d'épaules, poings en haut), puis les poings au sol devant lui
		local flex = Vector3.new(0.75, 0.55, 0.15)
		local slam = Vector3.new(0.25, -1, 0.55)
		for _, side in { "Left", "Right" } do
			local s = if side == "Left" then -1 else 1
			local dir = lerp(flex, slam, hit) * Vector3.new(s, 1, 1)
			pose[side] = armTarget(rig, facing, side, dir, 0.62 + 0.36 * hit)
			bend[side] = facing:VectorToWorldSpace(lerp(Vector3.new(s, -1, -0.2), Vector3.new(s * 0.5, 0, -1), hit))
		end
	end
	for _, side in { "Left", "Right" } do
		rig:Reach(side, lerp(idle[side], pose[side], w), bend[side])
	end
	-- Jambes : elles pendent, un peu fléchies, et battent doucement (il flotte)
	local kick = math.sin(t * 1.7) * 0.06
	rig:Turn("LeftUpperLeg", CFrame.Angles(0.18 + kick, 0, 0.05))
	rig:Turn("LeftLowerLeg", CFrame.Angles(-0.1 + kick, 0, 0.05))
	rig:Turn("LeftFoot", CFrame.Angles(-0.35, 0, 0))
	rig:Turn("RightUpperLeg", CFrame.Angles(0.1 - kick, 0, -0.05))
	rig:Turn("RightLowerLeg", CFrame.Angles(-0.22 - kick, 0, -0.05))
	rig:Turn("RightFoot", CFrame.Angles(-0.35, 0, 0))
	rig:Apply()
end

-- Point (monde) des mains, là où naissent les éclairs
function God.Hand(self, side: string): Vector3
	if self.rig then
		return self.rig:Palm(side)
	end
	return self.model:GetPivot().Position + Vector3.new(0, self.height * 0.5, 0)
end

function God.Destroy(self)
	if self.rig and self.model.Parent then
		self.rig:Release()
	end
end

return God
