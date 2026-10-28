-- Animation du Dieu du Pump dans l'arène (D90, D91). Il flotte, respire, suit le combattant des yeux et du buste,
-- glisse d'un point à l'autre de la piste, et chaque attaque a sa pose, calée sur l'heure du serveur : préparation
-- pendant l'avertissement, coup à l'impact, retour en douceur.
--   Bolt     : bras droit levé au ciel, bras gauche qui désigne la cible
--   Dumbbell : les deux bras au-dessus de la tête (il « appelle » l'haltère), puis il le lance vers l'avant
--   Wave     : double biceps en se ramassant, puis il frappe le sol des deux poings (l'onde part)
--   Slam     : poing droit armé haut derrière lui, puis abattu au sol devant lui
--   Javelin  : bras droit armé en arrière (le javelot en main), bras gauche qui vise, puis le lancer
--   Column   : les deux mains poussent devant lui (il renverse les colonnes)
--   Tiles    : bras levés, puis les deux poings frappent le sol (les dalles jaillissent)
--   Chariot  : bras droit tendu, il appelle le char ; Leap : bras au ciel, il saute très haut puis retombe poings
--   en avant ; Storm : les deux bras en V au ciel ; Gaze : penché en avant, mains aux tempes
--   Clash    : finale, bras droit tendu vers le combattant (l'éclair part de sa main)
-- États : essoufflé (il tombe à genoux, tête basse), touché (recul qui s'amortit), victoire du joueur (éjecté vers le
-- ciel en tournoyant), défaite du joueur (il nargue en double biceps).
-- Avec os (Boss_PumpGod_Rig.fbx) : BossRig ; sans os (ancien modèle) : le corps entier flotte, se tourne et se baisse.
--   God.new(model, ground) -> god ; god:Play(kind, start, impact) ; god:MoveTo(from, to, start, arrive) ;
--   god:Winded(start, ends) ; god:Hurt(power) ; god:Eject() ; god:Taunt() ; god:Clash(on) ;
--   god:Leap(start, rise, lock, impact) ; god:Step(now, target) ; god:Skeleton() ; god:Destroy()

local BossRig = require(script.Parent.Parent.BossFights.BossRig)

local God = {}
God.__index = God

-- Durée de la frappe après l'impact, puis du retour au repos
local STRIKE = {
	Bolt = 0.25,
	Dumbbell = 0.45,
	Wave = 0.5,
	Slam = 0.55,
	Javelin = 0.35,
	Column = 0.5,
	Tiles = 0.5,
	Chariot = 0.4,
	Leap = 0.6,
	Storm = 0.4,
	Gaze = 3.4, -- il garde la pose pendant tout le balayage
}
local LEAP_HEIGHT = 70 -- studs : il sort de l'écran par le haut
-- Articulations de la constellation (victoire) et les traits entre elles
local BONES = {
	"LowerTorso",
	"UpperTorso",
	"Head",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}
local RECOVER = 0.5
local HURT_TIME = 0.4

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- ground : point de la piste sous le dieu (celui du serveur)
function God.new(model: Model, ground: Vector3)
	-- Le devant du dieu est celui de son corps (le serveur l'a tourné vers le centre de la piste)
	local body = model.PrimaryPart
	local pivot = model:GetPivot()
	local front = if body then body.CFrame.LookVector else pivot.LookVector
	local yaw = math.atan2(-front.X, -front.Z)
	local self = setmetatable({
		model = model,
		rig = BossRig.new(model),
		-- Pivot du modèle vu depuis le point de la piste sous lui, dans le repère de son devant
		lift = (CFrame.new(ground) * CFrame.Angles(0, yaw, 0)):PointToObjectSpace(pivot.Position),
		offset = CFrame.Angles(0, yaw, 0):Inverse() * pivot.Rotation, -- pivot du modèle dans le repère du devant
		-- Taille debout : celle du corps (le pivot des modèles importés est couché, ses mesures ne disent pas le haut)
		height = if body then body.Size.Y else model:GetExtentsSize().Y,
		yaw = yaw,
		action = nil :: { kind: string, start: number, impact: number }?,
		move = { from = ground, to = ground, start = 0, arrive = 0 },
		winded = nil :: { start: number, ends: number }?,
		hurtAt = -math.huge,
		hurtPower = 0,
		ejectAt = nil :: number?,
		taunting = false,
		clashing = false,
		leap = nil :: { start: number, rise: number, lock: number, impact: number }?,
		bornAt = os.clock(),
		body = body,
	}, God)
	return self
end

function God.Play(self, kind: string, start: number, impact: number)
	self.action = { kind = kind, start = start, impact = impact }
end

function God.MoveTo(self, from: Vector3, to: Vector3, start: number, arrive: number)
	self.move = { from = from, to = to, start = start, arrive = arrive }
end

function God.Winded(self, start: number, ends: number)
	self.winded = { start = start, ends = ends }
end

function God.Hurt(self, power: number)
	self.hurtAt = os.clock()
	self.hurtPower = power
end

function God.Eject(self)
	self.ejectAt = os.clock()
end

function God.Clash(self, on: boolean)
	self.clashing = on
	self.action = nil
	self.winded = nil
end

function God.Leap(self, start: number, rise: number, lock: number, impact: number)
	self.leap = { start = start, rise = rise, lock = lock, impact = impact }
end

-- Hauteur du saut au-dessus de la piste : il monte, reste là-haut pendant que le cercle suit, puis retombe
function God.LeapHeight(self, now: number): number
	local leap = self.leap
	if not leap then
		return 0
	end
	if now > leap.impact + 0.5 then
		self.leap = nil
		return 0
	end
	if now < leap.rise then
		local k = math.clamp((now - leap.start) / math.max(leap.rise - leap.start, 0.05), 0, 1)
		return LEAP_HEIGHT * (1 - (1 - k) ^ 2)
	elseif now < leap.lock then
		return LEAP_HEIGHT
	elseif now < leap.impact then
		local k = (now - leap.lock) / math.max(leap.impact - leap.lock, 0.05)
		return LEAP_HEIGHT * (1 - k * k)
	end
	return 0
end

function God.Taunt(self)
	self.taunting = true
	self.action = nil
	self.winded = nil
end

-- Poids de la pose d'attaque : monte pendant l'avertissement, tient pendant la frappe, redescend
function God.Weights(self, now: number): (string?, number, number)
	if self.taunting then
		return "Wave", 1, 0 -- double biceps tenu
	elseif self.clashing then
		return "Clash", 1, 0
	end
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

-- Où il est sur la piste (au sol), et à quel point il glisse (0 -> 1 -> 0 pendant le trajet)
function God.Ground(self, now: number): (Vector3, number)
	local move = self.move
	if now >= move.arrive or move.arrive <= move.start then
		return move.to, 0
	end
	local k = math.clamp((now - move.start) / (move.arrive - move.start), 0, 1)
	return move.from:Lerp(move.to, k * k * (3 - 2 * k)), math.sin(k * math.pi)
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

-- Direction (repère du dieu, Z devant) vers un point du monde
local function toward(frame: CFrame, from: Vector3, point: Vector3?): Vector3
	if not point then
		return Vector3.new(0, -0.3, 1)
	end
	local v = frame:VectorToObjectSpace(point - from)
	return Vector3.new(v.X, v.Y, -v.Z)
end

-- target : position (monde) du combattant, ou nil
function God.Step(self, now: number, target: Vector3?)
	if not self.model.Parent then
		return
	end
	local clock = os.clock()
	local t = clock - self.bornAt
	local kind, w, hit = self:Weights(now)
	local h = self.height
	local ground, gliding = self:Ground(now)

	-- Essoufflé : entre en 0,25 s, ressort en 0,4 s
	local winded = 0
	if self.winded then
		local wd = self.winded
		winded = math.min(smooth((now - wd.start) / 0.25), 1 - smooth((now - wd.ends) / 0.4))
		if now > wd.ends + 0.4 then
			self.winded = nil
		end
	end
	-- Touché : recul qui s'amortit
	local hurt = math.max(1 - (clock - self.hurtAt) / HURT_TIME, 0) ^ 2 * self.hurtPower

	-- Se tourne vers le combattant (lentement : c'est un dieu ; pas quand il est à genoux)
	if target and not self.ejectAt then
		local d = target - ground
		local wanted = math.atan2(-d.X, -d.Z)
		local current = self.yaw
		local delta = (wanted - current + math.pi) % (2 * math.pi) - math.pi
		self.yaw = current + delta * 0.06 * (1 - winded * 0.8)
	end
	-- Flotte : lente ondulation ; descend en préparant l'onde, plonge au coup
	local bob = math.sin(t * 1.7) * h * 0.025 * (1 - winded)
	local dip = 0
	local lean = 0.12 * gliding -- penché dans le sens de la glissade
	if kind == "Wave" and not self.taunting then
		dip = -h * 0.05 * w - h * 0.06 * hit * w
		lean += 0.12 * w + 0.25 * hit * w
	elseif kind == "Dumbbell" then
		lean += -0.15 * w * (1 - hit) + 0.3 * hit * w
	elseif kind == "Bolt" then
		dip = -h * 0.02 * hit * w
		lean += -0.08 * w
	elseif kind == "Slam" then
		lean += -0.12 * w * (1 - hit) + 0.45 * hit * w
		dip = -h * 0.07 * hit * w
	elseif kind == "Javelin" then
		lean += -0.1 * w * (1 - hit) + 0.2 * hit * w
	elseif kind == "Column" then
		lean += -0.1 * w * (1 - hit) + 0.3 * hit * w
	elseif kind == "Tiles" then
		lean += -0.12 * w * (1 - hit) + 0.35 * hit * w
		dip = -h * 0.06 * hit * w
	elseif kind == "Storm" then
		lean += -0.2 * w
	elseif kind == "Gaze" then
		lean += 0.3 * w
	elseif kind == "Clash" then
		lean += 0.1 + math.sin(t * 30) * 0.02
	end
	-- Saut : il quitte la piste (au-dessus de l'écran) puis retombe
	dip += self:LeapHeight(now)
	-- À genoux : il tombe sur la piste, buste penché, tête basse
	dip -= h * 0.18 * winded
	lean += 0.5 * winded - 0.35 * hurt
	local facing = CFrame.new(ground) * CFrame.Angles(0, self.yaw, 0) * CFrame.new(self.lift)
	-- Recul : poussé un peu en arrière
	facing *= CFrame.new(0, 0, 1.2 * hurt)
	-- Éjecté : il s'envole en tournoyant
	if self.ejectAt then
		local e = clock - self.ejectAt
		local rise = if e < 0.35 then -0.6 * math.sin(e / 0.35 * math.pi) else (e - 0.35) ^ 2 * 45
		facing = CFrame.new(facing.Position + Vector3.new(0, rise, 0))
			* CFrame.Angles(0, self.yaw + math.max(e - 0.3, 0) ^ 2 * 14, 0)
			* CFrame.Angles(math.min(e * 0.8, 0.9), 0, 0)
		bob = 0
	end
	local rig = self.rig
	if not rig then
		-- Sans os : le corps entier se penche
		self.model:PivotTo(facing * CFrame.new(0, bob + dip, 0) * CFrame.Angles(-lean * 0.5, 0, 0) * self.offset)
		return
	end
	self.model:PivotTo(facing * CFrame.new(0, bob + dip, 0) * self.offset)

	rig:Clear()
	-- Buste : respiration (haletante quand il est essoufflé), penché selon la pose
	local breath = math.sin(t * (2.2 + 5 * winded)) * (0.04 + 0.05 * winded)
	rig:Turn("LowerTorso", CFrame.Angles(-lean * 0.4, 0, 0))
	rig:Turn("UpperTorso", CFrame.Angles(-lean - breath, 0, 0))
	-- La tête baisse les yeux vers le combattant (il est en bas, sur la piste)
	local look = 0
	if target then
		local head = rig:Joint("Head")
		local flatDistance = Vector3.new(target.X - head.X, 0, target.Z - head.Z).Magnitude
		look = math.clamp(math.atan2(head.Y - target.Y, math.max(flatDistance, 1)) * 0.6, 0, 0.5)
	end
	rig:Turn("Head", CFrame.Angles(-lean - breath * 0.5 - look * (1 - winded) - 0.35 * winded + 0.3 * hurt, 0, 0))

	-- Bras au repos : un peu écartés, ils se balancent ; à genoux : ils pendent devant lui
	local sway = math.sin(t * 1.7 + 0.6) * 0.06
	local idleL = lerp(Vector3.new(-0.45, -1, 0.1 + sway), Vector3.new(-0.25, -1, 0.55), winded)
	local idleR = lerp(Vector3.new(0.45, -1, 0.1 - sway), Vector3.new(0.25, -1, 0.55), winded)
	if hurt > 0 then
		idleL += Vector3.new(-0.4, 0.5, 0) * hurt
		idleR += Vector3.new(0.4, 0.5, 0) * hurt
	end
	local idle = {
		Left = armTarget(rig, facing, "Left", idleL, 0.92),
		Right = armTarget(rig, facing, "Right", idleR, 0.92),
	}
	local pose = { Left = idle.Left, Right = idle.Right }
	local bend = {
		Left = facing:VectorToWorldSpace(Vector3.new(-1, 0, 0.6)),
		Right = facing:VectorToWorldSpace(Vector3.new(1, 0, 0.6)),
	}
	if self.ejectAt then
		-- Bras en l'air, il moulinet en montant
		local e = clock - self.ejectAt
		pose.Left = armTarget(rig, facing, "Left", Vector3.new(-0.6, 1, math.sin(e * 14) * 0.5), 0.95)
		pose.Right = armTarget(rig, facing, "Right", Vector3.new(0.6, 1, -math.sin(e * 14) * 0.5), 0.95)
		w = 1
	elseif kind == "Bolt" then
		pose.Right = armTarget(rig, facing, "Right", Vector3.new(0.25, 1, 0.1 + 0.2 * hit), 0.95)
		pose.Left = armTarget(rig, facing, "Left", toward(facing, rig:Joint("LeftUpperArm"), target), 0.95)
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
		local pump = if self.taunting then math.sin(t * 6) * 0.08 else 0
		local flex = Vector3.new(0.75, 0.55 + pump, 0.15)
		local slam = Vector3.new(0.25, -1, 0.55)
		for _, side in { "Left", "Right" } do
			local s = if side == "Left" then -1 else 1
			local dir = lerp(flex, slam, hit) * Vector3.new(s, 1, 1)
			pose[side] = armTarget(rig, facing, side, dir, 0.62 + 0.36 * hit)
			bend[side] = facing:VectorToWorldSpace(lerp(Vector3.new(s, -1, -0.2), Vector3.new(s * 0.5, 0, -1), hit))
		end
	elseif kind == "Slam" then
		-- Poing droit armé haut derrière lui, puis abattu devant lui ; le gauche en appui
		pose.Right =
			armTarget(rig, facing, "Right", lerp(Vector3.new(0.45, 0.9, -0.6), Vector3.new(0.15, -1, 1), hit), 0.95)
		pose.Left =
			armTarget(rig, facing, "Left", lerp(Vector3.new(-0.7, -0.2, 0.6), Vector3.new(-0.5, -1, 0.3), hit), 0.9)
		bend.Right = facing:VectorToWorldSpace(lerp(Vector3.new(1, 0.2, -1), Vector3.new(1, 0, -0.3), hit))
	elseif kind == "Javelin" then
		-- Bras droit armé en arrière, le gauche vise ; puis le lancer
		pose.Right =
			armTarget(rig, facing, "Right", lerp(Vector3.new(0.55, 0.55, -0.9), Vector3.new(0.15, 0.15, 1), hit), 0.95)
		pose.Left = armTarget(rig, facing, "Left", toward(facing, rig:Joint("LeftUpperArm"), target), 0.9 - 0.3 * hit)
		bend.Right = facing:VectorToWorldSpace(Vector3.new(1, -0.6, 0))
	elseif kind == "Column" then
		-- Mains à plat devant lui, qui poussent
		for _, side in { "Left", "Right" } do
			local s = if side == "Left" then -1 else 1
			local dir = lerp(Vector3.new(0.45 * s, 0.3, 0.5), Vector3.new(0.25 * s, 0.1, 1), hit)
			pose[side] = armTarget(rig, facing, side, dir, 0.7 + 0.25 * hit)
		end
	elseif kind == "Tiles" or kind == "Leap" then
		-- Bras au ciel, puis les poings au sol (Leap : à l'atterrissage)
		for _, side in { "Left", "Right" } do
			local s = if side == "Left" then -1 else 1
			local dir = lerp(Vector3.new(0.3 * s, 1, 0.1), Vector3.new(0.3 * s, -1, 0.6), hit)
			pose[side] = armTarget(rig, facing, side, dir, 0.95)
		end
	elseif kind == "Chariot" then
		pose.Right = armTarget(rig, facing, "Right", Vector3.new(0.4, 0.35 + 0.1 * hit, 1), 0.95)
		pose.Left = armTarget(rig, facing, "Left", Vector3.new(-0.6, 0.9, 0.1), 0.9)
	elseif kind == "Storm" then
		-- Les deux bras en V au ciel ; ils tremblent à l'impact
		local shiver = if hit > 0 then math.sin(t * 40) * 0.08 else 0
		pose.Left = armTarget(rig, facing, "Left", Vector3.new(-0.6, 1, shiver), 0.95)
		pose.Right = armTarget(rig, facing, "Right", Vector3.new(0.6, 1, -shiver), 0.95)
	elseif kind == "Gaze" then
		-- Mains aux tempes, le regard droit devant
		for _, side in { "Left", "Right" } do
			local s = if side == "Left" then -1 else 1
			pose[side] = armTarget(rig, facing, side, Vector3.new(0.35 * s, 0.85, 0.35), 0.6)
			bend[side] = facing:VectorToWorldSpace(Vector3.new(s, 0, 0))
		end
	elseif kind == "Clash" then
		-- Bras droit tendu vers le combattant, le gauche tient le poignet
		pose.Right = armTarget(rig, facing, "Right", toward(facing, rig:Joint("RightUpperArm"), target), 0.97)
		pose.Left = armTarget(rig, facing, "Left", Vector3.new(0.3, 0, 0.7), 0.75)
	end
	for _, side in { "Left", "Right" } do
		rig:Reach(side, lerp(idle[side], pose[side], w), bend[side])
	end
	-- Jambes : elles pendent, un peu fléchies, et battent doucement (il flotte) ; à genoux, cuisses en avant
	local kick = math.sin(t * 1.7) * 0.06 * (1 - winded)
	local kneel = 1.1 * winded
	rig:Turn("LeftUpperLeg", CFrame.Angles(0.18 + kick + kneel, 0, 0.05))
	rig:Turn("LeftLowerLeg", CFrame.Angles(-0.1 + kick - 0.5 * winded, 0, 0.05))
	rig:Turn("LeftFoot", CFrame.Angles(-0.35, 0, 0))
	rig:Turn("RightUpperLeg", CFrame.Angles(0.1 - kick + kneel, 0, -0.05))
	rig:Turn("RightLowerLeg", CFrame.Angles(-0.22 - kick - 0.5 * winded, 0, -0.05))
	rig:Turn("RightFoot", CFrame.Angles(-0.35, 0, 0))
	rig:Apply()
end

-- Position (monde) de ses articulations, pour la constellation de la victoire
function God.Skeleton(self): { [string]: Vector3 }
	local points = {}
	if self.rig then
		for _, name in BONES do
			points[name] = self.rig:Joint(name)
		end
	end
	return points
end

God.Links = {
	{ "LowerTorso", "UpperTorso" },
	{ "UpperTorso", "Head" },
	{ "UpperTorso", "LeftUpperArm" },
	{ "LeftUpperArm", "LeftLowerArm" },
	{ "LeftLowerArm", "LeftHand" },
	{ "UpperTorso", "RightUpperArm" },
	{ "RightUpperArm", "RightLowerArm" },
	{ "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" },
	{ "LeftUpperLeg", "LeftLowerLeg" },
	{ "LeftLowerLeg", "LeftFoot" },
	{ "LowerTorso", "RightUpperLeg" },
	{ "RightUpperLeg", "RightLowerLeg" },
	{ "RightLowerLeg", "RightFoot" },
}

-- Point (monde) des mains, là où naissent les éclairs et où se tient le javelot
function God.Hand(self, side: string): Vector3
	if self.rig then
		return self.rig:Palm(side)
	end
	return self.model:GetPivot().Position + Vector3.new(0, self.height * 0.5, 0)
end

-- Point (monde) de sa poitrine : là où arrivent les coups du joueur
function God.Chest(self): Vector3
	if self.rig then
		return self.rig:Joint("UpperTorso") + Vector3.new(0, self.height * 0.12, 0)
	end
	return self.model:GetPivot().Position
end

-- Point (monde) au-dessus de sa tête (étoiles quand il est essoufflé)
-- Point (monde) de ses yeux : d'où part le regard brûlant
function God.Eyes(self): Vector3
	if self.rig then
		return self.rig:Joint("Head") + Vector3.new(0, self.height * 0.05, 0)
	end
	return self.model:GetPivot().Position + Vector3.new(0, self.height * 0.45, 0)
end

function God.Top(self): Vector3
	if self.rig then
		return self.rig:Joint("Head") + Vector3.new(0, self.height * 0.18, 0)
	end
	return self.model:GetPivot().Position + Vector3.new(0, self.height * 0.6, 0)
end

function God.Destroy(self)
	if self.rig and self.model.Parent then
		self.rig:Release()
	end
end

return God
