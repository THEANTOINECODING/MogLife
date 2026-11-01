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
-- Qualité (D95) : chaque coup a son élan (il se ramasse, tremble de puissance juste avant l'impact), un coup sec qui
-- dépasse sa cible puis rebondit, une rotation du buste (lancers, coups de poing) ; ses glissades ont un départ, une
-- inclinaison dans le sens du trajet, les jambes qui traînent et un rebond à l'arrivée ; au repos, il frime de temps
-- en temps (double biceps). Contour (Highlight) : rouge qui clignote quand on peut le frapper, blanc quand il est touché.
-- Avec os (Boss_PumpGod_Rig.fbx) : BossRig ; sans os (ancien modèle) : le corps entier flotte, se tourne et se baisse.
--   God.new(model, ground) -> god ; god:Play(kind, start, impact) ; god:MoveTo(from, to, start, arrive) ;
--   god:Winded(start, ends) ; god:Hurt(power) ; god:Eject() ; god:Taunt() ; god:Clash(on) ;
--   god:Leap(start, rise, lock, impact) ; god:SetHittable(on) ; god:Step(now, target) ; god:Skeleton() ;
--   god:Destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossRig = require(script.Parent.Parent.BossFights.BossRig)
local PumpGod = require(ReplicatedStorage.Shared.Config.PumpGod)

local GLOW = PumpGod.Glow

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
-- Mouvement du corps entier pour chaque attaque (lean > 0 : penché en avant ; twist > 0 : épaule droite en arrière ;
-- rise / dip : fraction de sa taille, monté pendant la préparation, plongé au coup).
--   prep : pendant l'avertissement ; coil : élan juste avant l'impact ; hit : au coup
local BODY = {
	Bolt = { prep = -0.08, coil = -0.1, hit = 0.12, twistCoil = 0.2, twistHit = -0.15, rise = 0.06, dip = 0.03 },
	Dumbbell = { prep = -0.12, coil = -0.18, hit = 0.38, twistCoil = 0, twistHit = 0, rise = 0.04, dip = 0.04 },
	Wave = { prep = 0.04, coil = -0.14, hit = 0.38, twistCoil = 0, twistHit = 0, rise = 0.07, dip = 0.13 },
	Slam = { prep = -0.1, coil = -0.14, hit = 0.55, twistCoil = 0.4, twistHit = -0.35, rise = 0.04, dip = 0.11 },
	Javelin = { prep = -0.08, coil = -0.14, hit = 0.28, twistCoil = 0.6, twistHit = -0.5, rise = 0.02, dip = 0.02 },
	Column = { prep = -0.05, coil = -0.14, hit = 0.38, twistCoil = 0.1, twistHit = -0.1, rise = 0.02, dip = 0.04 },
	Tiles = { prep = -0.1, coil = -0.1, hit = 0.42, twistCoil = 0, twistHit = 0, rise = 0.09, dip = 0.13 },
	Chariot = { prep = -0.05, coil = -0.08, hit = 0.18, twistCoil = -0.35, twistHit = 0.25, rise = 0.02, dip = 0.02 },
	Leap = { prep = 0.1, coil = 0, hit = 0.42, twistCoil = 0, twistHit = 0, rise = 0, dip = 0.15 },
	Storm = { prep = -0.22, coil = -0.1, hit = 0.05, twistCoil = 0, twistHit = 0, rise = 0.13, dip = 0.03 },
	Gaze = { prep = 0.3, coil = 0, hit = 0.05, twistCoil = 0, twistHit = 0, rise = 0, dip = 0 },
	Flex = { prep = -0.12, coil = 0, hit = 0, twistCoil = 0, twistHit = 0, rise = 0.02, dip = 0 },
}
local COIL = 0.35 -- s : l'élan avant l'impact (au plus la moitié de l'avertissement)
local SNAP = 0.07 -- s : le coup part
local RECOVER = 0.5
local HURT_TIME = 0.4
local LEAP_CROUCH = 0.2 -- s : il se ramasse avant de sauter
local LAND_TIME = 0.4 -- s : il s'écrase à l'atterrissage puis se relève
local SETTLE_TIME = 0.6 -- s : rebond à la fin d'une glissade
local FLOURISH_EVERY = 6.5 -- s de calme avant de frimer (double biceps)
local FLOURISH_TIME = 1.3

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
		hurtTwist = 0,
		hittable = false,
		highlight = nil :: Highlight?,
		calmSince = os.clock(), -- depuis quand il ne fait rien (frime)
		flourishAt = nil :: number?,
	}, God)
	return self
end

-- Contour rouge qui clignote quand le combattant peut le frapper
function God.SetHittable(self, on: boolean)
	self.hittable = on
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
	-- Le coup le fait pivoter d'un côté ou de l'autre
	self.hurtTwist = (if math.random() < 0.5 then -1 else 1) * (0.2 + 0.1 * math.random())
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
	if now > leap.impact + LAND_TIME then
		self.leap = nil
		return 0
	end
	local crouch = math.min(LEAP_CROUCH, (leap.rise - leap.start) * 0.4)
	if now < leap.start + crouch then
		-- Il se ramasse avant de bondir
		return -self.height * 0.1 * math.sin(math.clamp((now - leap.start) / crouch, 0, 1) * math.pi * 0.5)
	elseif now < leap.rise then
		local k = math.clamp((now - leap.start - crouch) / math.max(leap.rise - leap.start - crouch, 0.05), 0, 1)
		return LEAP_HEIGHT * (1 - (1 - k) ^ 3)
	elseif now < leap.lock then
		return LEAP_HEIGHT + math.sin((now - leap.rise) * 3) * 1.5
	elseif now < leap.impact then
		local k = (now - leap.lock) / math.max(leap.impact - leap.lock, 0.05)
		return LEAP_HEIGHT * (1 - k ^ 3)
	end
	-- Atterrissage : écrasé, puis il se relève
	local k = (now - leap.impact) / LAND_TIME
	return -self.height * 0.14 * (1 - k) ^ 2
end

function God.Taunt(self)
	self.taunting = true
	self.action = nil
	self.winded = nil
end

-- Poids de la pose d'attaque : monte pendant l'avertissement, tient pendant la frappe, redescend.
-- coil : l'élan juste avant l'impact (0 -> 1, retombe au coup) ; hit : 0 avant l'impact, puis un coup sec qui dépasse
-- la pose (jusqu'à ~1,2) et rebondit avant de se poser à 1.
function God.Weights(self, now: number): (string?, number, number, number)
	if self.taunting then
		return "Flex", 1, 0, 0 -- double biceps tenu
	elseif self.clashing then
		return "Clash", 1, 0, 0
	end
	local action = self.action
	if not action then
		return nil, 0, 0, 0
	end
	local strike = STRIKE[action.kind] or 0.3
	if now > action.impact + strike + RECOVER then
		self.action = nil
		return nil, 0, 0, 0
	end
	local wind = math.max(action.impact - action.start, 0.1)
	local prepare = smooth((now - action.start) / math.min(wind, 0.6))
	local fade = 1 - smooth((now - action.impact - strike) / RECOVER)
	local u = now - action.impact
	local hit
	if u < 0 then
		hit = 0
	elseif u < SNAP then
		hit = smooth(u / SNAP)
	else
		hit = 1 + 0.22 * math.exp(-(u - SNAP) * 7) * math.sin((u - SNAP) * 17)
	end
	local coilTime = math.min(COIL, wind * 0.5)
	local coil = if u < 0 then smooth((now - (action.impact - coilTime)) / coilTime) else 0
	return action.kind, math.min(prepare, fade), hit, coil
end

-- Après la glissade : un petit rebond qui s'amortit (0 en dehors)
function God.Settle(self, now: number): number
	local s = now - self.move.arrive
	if s < 0 or s > SETTLE_TIME or self.move.arrive <= self.move.start then
		return 0
	end
	return math.exp(-s * 6) * math.sin(s * 14)
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

-- Contour : blanc un instant quand il est touché, rouge qui clignote quand le combattant peut le frapper
function God.Glow(self, clock: number)
	local flash = 1 - (clock - self.hurtAt) / GLOW.HurtTime
	if flash <= 0 and not self.hittable then
		if self.highlight then
			self.highlight.Enabled = false
		end
		return
	end
	local highlight = self.highlight
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Adornee = self.model
		highlight.Parent = self.model
		self.highlight = highlight
	end
	highlight.Enabled = true
	if flash > 0 then
		highlight.FillColor = GLOW.Hurt
		highlight.OutlineColor = GLOW.Hurt
		highlight.FillTransparency = 1 - 0.7 * flash
		highlight.OutlineTransparency = 1 - flash
	else
		local blink = 0.5 + 0.5 * math.sin(clock * GLOW.BlinkSpeed)
		highlight.FillColor = GLOW.Hittable
		highlight.OutlineColor = GLOW.Hittable
		highlight.FillTransparency = 1 - (1 - GLOW.HittableFill) * blink
		highlight.OutlineTransparency = 0.6 * (1 - blink)
	end
end

-- target : position (monde) du combattant, ou nil
function God.Step(self, now: number, target: Vector3?)
	if not self.model.Parent then
		return
	end
	local clock = os.clock()
	local t = clock - self.bornAt
	local kind, w, hit, coil = self:Weights(now)
	local h = self.height
	local ground, gliding = self:Ground(now)
	self:Glow(clock)

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

	-- Frime : après un moment sans rien faire, un double biceps (le temps d'une respiration)
	local busy = kind ~= nil or winded > 0 or gliding > 0 or self.leap ~= nil or self.ejectAt ~= nil
	if busy then
		self.calmSince = clock
		self.flourishAt = nil
	elseif not self.flourishAt and clock - self.calmSince > FLOURISH_EVERY then
		self.flourishAt = clock
	end
	if self.flourishAt then
		local f = (clock - self.flourishAt) / FLOURISH_TIME
		if f >= 1 then
			self.flourishAt = nil
			self.calmSince = clock
		else
			kind, w, hit, coil = "Flex", math.sin(f * math.pi) ^ 0.6, 0, 0
		end
	end

	-- Se tourne vers le combattant (lentement : c'est un dieu ; pas quand il est à genoux). La tête devance le corps.
	local headYaw = 0
	if target and not self.ejectAt then
		local d = target - ground
		local wanted = math.atan2(-d.X, -d.Z)
		local current = self.yaw
		local delta = (wanted - current + math.pi) % (2 * math.pi) - math.pi
		self.yaw = current + delta * 0.06 * (1 - winded * 0.8)
		headYaw = math.clamp(delta, -0.6, 0.6) * (1 - winded)
	end

	-- Corps entier : penché (lean), buste tourné (twist), monté ou plongé (dip), incliné de côté (bank)
	local body = if kind then BODY[kind] else nil
	local lean, twist, dip, bank = 0, 0, 0, 0
	if body then
		local struck = math.min(hit, 1.25)
		lean = (body.prep * (1 - math.min(hit, 1)) + body.coil * coil + body.hit * struck) * w
		twist = (body.twistCoil * (1 - math.min(hit, 1)) * (0.4 + 0.6 * coil) + body.twistHit * struck) * w
		dip = h * (body.rise * (1 - math.min(hit, 1)) * (1 - coil * 0.5) - body.dip * struck) * w
	end
	if kind == "Clash" then
		lean += 0.1 + math.sin(t * 30) * 0.02
	end
	-- Glissade : penché dans le sens du trajet, incliné dans les virages ; petit recul au départ ; rebond à l'arrivée
	local move = self.move
	local travel = Vector3.new(move.to.X - move.from.X, 0, move.to.Z - move.from.Z)
	if travel.Magnitude > 0.5 then
		local dir = travel.Unit
		local facingYaw = CFrame.Angles(0, self.yaw, 0)
		local ahead = facingYaw.LookVector:Dot(dir)
		local side = facingYaw.RightVector:Dot(dir)
		local k = math.clamp((now - move.start) / math.max(move.arrive - move.start, 0.05), 0, 1)
		local launch = if k < 0.2 then math.sin(k / 0.2 * math.pi) * 0.12 else 0
		lean += (0.22 * gliding - launch) * ahead
		bank -= 0.22 * gliding * side
		local settle = self:Settle(now)
		lean -= 0.14 * settle * ahead
		bank += 0.1 * settle * side
		dip -= h * 0.03 * math.abs(settle)
	end
	-- Flotte : lente ondulation en huit
	local bob = math.sin(t * 1.7) * h * 0.025 * (1 - winded)
	local sway = math.sin(t * 0.85) * h * 0.012 * (1 - winded)
	-- Saut : il se ramasse, quitte la piste (au-dessus de l'écran), retombe et s'écrase
	local leapHeight = self:LeapHeight(now)
	dip += leapHeight
	local tuck = math.clamp(leapHeight / LEAP_HEIGHT, 0, 1)
	local squat = math.clamp(-leapHeight / (h * 0.14), 0, 1)
	-- À genoux : il tombe sur la piste, buste penché, tête basse
	dip -= h * 0.18 * winded
	lean += 0.5 * winded - 0.35 * hurt
	twist += self.hurtTwist * hurt
	-- Tremble de puissance pendant l'élan
	local shake = Vector3.new(math.sin(t * 53), math.sin(t * 61) * 0.5, math.sin(t * 47)) * h * 0.006 * coil * w
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
		bob, sway = 0, 0
	end
	local rig = self.rig
	local lift = CFrame.new(Vector3.new(sway, bob + dip, 0) + shake) * CFrame.Angles(0, 0, bank)
	if not rig then
		-- Sans os : le corps entier se penche
		self.model:PivotTo(facing * lift * CFrame.Angles(-lean * 0.5, twist * 0.5, 0) * self.offset)
		return
	end
	self.model:PivotTo(facing * lift * self.offset)

	rig:Clear()
	-- Buste : respiration (haletante quand il est essoufflé), penché et tourné selon la pose
	local breath = math.sin(t * (2.2 + 5 * winded)) * (0.04 + 0.05 * winded)
	rig:Turn("LowerTorso", CFrame.Angles(-lean * 0.4, twist * 0.35, 0))
	rig:Turn("UpperTorso", CFrame.Angles(-lean - breath, twist, 0))
	-- La tête baisse les yeux vers le combattant (il est en bas, sur la piste) et le suit avant le corps
	local look = 0
	if target then
		local head = rig:Joint("Head")
		local flatDistance = Vector3.new(target.X - head.X, 0, target.Z - head.Z).Magnitude
		look = math.clamp(math.atan2(head.Y - target.Y, math.max(flatDistance, 1)) * 0.6, 0, 0.5)
	end
	rig:Turn(
		"Head",
		CFrame.Angles(
			-lean - breath * 0.5 - look * (1 - winded) - 0.35 * winded + 0.3 * hurt,
			headYaw + twist * 0.3 - self.hurtTwist * hurt,
			0
		)
	)

	-- Bras au repos : un peu écartés, ils se balancent ; à genoux : ils pendent devant lui ; en glissade : ils traînent
	local swing = math.sin(t * 1.7 + 0.6) * 0.06
	local trail = 0.45 * gliding
	local idleL = lerp(Vector3.new(-0.45, -1, 0.1 + swing - trail), Vector3.new(-0.25, -1, 0.55), winded)
	local idleR = lerp(Vector3.new(0.45, -1, 0.1 - swing - trail), Vector3.new(0.25, -1, 0.55), winded)
	if hurt > 0 then
		idleL += Vector3.new(-0.4, 0.5, 0) * hurt
		idleR += Vector3.new(0.4, 0.5, 0) * hurt
	end
	if tuck > 0 then
		-- En l'air : bras grands ouverts
		idleL = lerp(idleL, Vector3.new(-1, 0.4, 0), tuck)
		idleR = lerp(idleR, Vector3.new(1, 0.4, 0), tuck)
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
	-- Les bras tremblent pendant l'élan
	local quiver = Vector3.new(math.sin(t * 57), math.sin(t * 43), 0) * 0.05 * coil
	if self.ejectAt then
		-- Bras en l'air, il moulinet en montant
		local e = clock - self.ejectAt
		pose.Left = armTarget(rig, facing, "Left", Vector3.new(-0.6, 1, math.sin(e * 14) * 0.5), 0.95)
		pose.Right = armTarget(rig, facing, "Right", Vector3.new(0.6, 1, -math.sin(e * 14) * 0.5), 0.95)
		w = 1
	elseif kind == "Bolt" then
		-- Bras droit au ciel (il attire la foudre), le gauche désigne la cible ; il abat le bras au coup
		pose.Right = armTarget(
			rig,
			facing,
			"Right",
			Vector3.new(0.25, 1 - 0.5 * math.min(hit, 1), 0.1 + 0.6 * hit) + quiver,
			0.95
		)
		pose.Left = armTarget(rig, facing, "Left", toward(facing, rig:Joint("LeftUpperArm"), target), 0.95)
	elseif kind == "Dumbbell" then
		-- Au-dessus de la tête (encore plus haut et en arrière pendant l'élan), puis lancé devant lui
		local up = Vector3.new(0.15, 1, -0.25 - 0.35 * coil) + quiver
		local throw = Vector3.new(0.1, -0.2, 1)
		pose.Left =
			armTarget(rig, facing, "Left", lerp(up * Vector3.new(-1, 1, 1), throw * Vector3.new(-1, 1, 1), hit), 0.9)
		pose.Right = armTarget(rig, facing, "Right", lerp(up, throw, hit), 0.9)
		bend.Left = facing:VectorToWorldSpace(Vector3.new(-1, 0, 1))
		bend.Right = facing:VectorToWorldSpace(Vector3.new(1, 0, 1))
	elseif kind == "Wave" or kind == "Tiles" then
		-- Wave : double biceps en se ramassant ; Tiles : bras au ciel ; puis les deux poings au sol devant lui
		local raised = if kind == "Wave"
			then Vector3.new(0.75, 0.55 + 0.25 * coil, 0.15)
			else Vector3.new(0.3, 1, -0.2 * coil)
		local slam = Vector3.new(0.25, -1, 0.6)
		for _, side in { "Left", "Right" } do
			local s = if side == "Left" then -1 else 1
			local dir = (lerp(raised, slam, hit) + quiver) * Vector3.new(s, 1, 1)
			local reach = if kind == "Wave" then 0.62 + 0.36 * math.min(hit, 1) else 0.95
			pose[side] = armTarget(rig, facing, side, dir, reach)
			if kind == "Wave" then
				bend[side] = facing:VectorToWorldSpace(
					lerp(Vector3.new(s, -1, -0.2), Vector3.new(s * 0.5, 0, -1), math.min(hit, 1))
				)
			end
		end
	elseif kind == "Flex" then
		-- Double biceps de frime (ou pour narguer) : les biceps pompent
		local pump = math.sin(t * 6) * 0.08
		for _, side in { "Left", "Right" } do
			local s = if side == "Left" then -1 else 1
			pose[side] = armTarget(rig, facing, side, Vector3.new(0.75 * s, 0.6 + pump, 0.15), 0.62)
			bend[side] = facing:VectorToWorldSpace(Vector3.new(s, -1, -0.2))
		end
	elseif kind == "Slam" then
		-- Poing droit armé haut derrière lui (l'élan le tire encore plus loin), abattu devant lui ; le gauche en appui
		local cocked = Vector3.new(0.45, 0.9 + 0.15 * coil, -0.6 - 0.4 * coil) + quiver
		pose.Right = armTarget(rig, facing, "Right", lerp(cocked, Vector3.new(0.15, -1, 1), hit), 0.95)
		pose.Left = armTarget(
			rig,
			facing,
			"Left",
			lerp(Vector3.new(-0.7, -0.2 + 0.2 * coil, 0.6), Vector3.new(-0.5, -1, 0.3), hit),
			0.9
		)
		bend.Right = facing:VectorToWorldSpace(lerp(Vector3.new(1, 0.2, -1), Vector3.new(1, 0, -0.3), math.min(hit, 1)))
	elseif kind == "Javelin" then
		-- Bras droit armé loin en arrière (le javelot en main), le gauche vise ; puis le lancer, le bras traverse
		local cocked = Vector3.new(0.55, 0.55 + 0.1 * coil, -0.9 - 0.3 * coil) + quiver
		pose.Right = armTarget(rig, facing, "Right", lerp(cocked, Vector3.new(0.05, 0.05, 1), hit), 0.95)
		pose.Left = armTarget(
			rig,
			facing,
			"Left",
			lerp(toward(facing, rig:Joint("LeftUpperArm"), target), Vector3.new(-0.6, -0.6, -0.3), math.min(hit, 1)),
			0.9
		)
		bend.Right = facing:VectorToWorldSpace(Vector3.new(1, -0.6, 0))
	elseif kind == "Column" then
		-- Mains ramenées à la poitrine pendant l'élan, puis il pousse à bras tendus
		for _, side in { "Left", "Right" } do
			local s = if side == "Left" then -1 else 1
			local ready = Vector3.new(0.45 * s, 0.3, 0.5 - 0.3 * coil)
			local dir = lerp(ready, Vector3.new(0.25 * s, 0.1, 1), hit) + quiver
			pose[side] = armTarget(rig, facing, side, dir, 0.7 - 0.15 * coil + 0.25 * math.min(hit, 1))
		end
	elseif kind == "Leap" then
		-- Bras au ciel en montant, puis les poings en avant pour retomber sur le joueur
		for _, side in { "Left", "Right" } do
			local s = if side == "Left" then -1 else 1
			local dir = lerp(Vector3.new(0.3 * s, 1, 0.1), Vector3.new(0.3 * s, -1, 0.6), hit)
			pose[side] = armTarget(rig, facing, side, dir, 0.95)
		end
	elseif kind == "Chariot" then
		-- Bras gauche levé (il fouette les chevaux), le droit désigne la trajectoire
		pose.Right = armTarget(rig, facing, "Right", Vector3.new(0.4, 0.35 + 0.15 * hit, 1) + quiver, 0.95)
		pose.Left = armTarget(rig, facing, "Left", Vector3.new(-0.6, 0.9 + 0.1 * coil, -0.2 * coil + 0.4 * hit), 0.9)
	elseif kind == "Storm" then
		-- Les deux bras en V au ciel ; ils tremblent de plus en plus, puis à l'impact
		local shiver = math.sin(t * 40) * (0.04 * coil + (if hit > 0 then 0.08 else 0))
		pose.Left = armTarget(rig, facing, "Left", Vector3.new(-0.6 + 0.15 * coil, 1, shiver), 0.95)
		pose.Right = armTarget(rig, facing, "Right", Vector3.new(0.6 - 0.15 * coil, 1, -shiver), 0.95)
	elseif kind == "Gaze" then
		-- Mains aux tempes, le regard droit devant
		for _, side in { "Left", "Right" } do
			local s = if side == "Left" then -1 else 1
			pose[side] = armTarget(rig, facing, side, Vector3.new(0.35 * s, 0.85, 0.35), 0.6)
			bend[side] = facing:VectorToWorldSpace(Vector3.new(s, 0, 0))
		end
	elseif kind == "Clash" then
		-- Bras droit tendu vers le combattant, le gauche tient le poignet ; tout tremble sous l'effort
		local strain = Vector3.new(math.sin(t * 37), math.sin(t * 29), 0) * 0.03
		pose.Right = armTarget(rig, facing, "Right", toward(facing, rig:Joint("RightUpperArm"), target) + strain, 0.97)
		pose.Left = armTarget(rig, facing, "Left", Vector3.new(0.3, 0, 0.7) + strain, 0.75)
	end
	for _, side in { "Left", "Right" } do
		rig:Reach(side, lerp(idle[side], pose[side], w), bend[side])
	end
	-- Jambes : elles pendent, un peu fléchies, et battent doucement (il flotte) ; à genoux, cuisses en avant ;
	-- en glissade, elles traînent derrière ; en l'air, genoux ramenés ; à l'atterrissage, accroupi
	local kick = math.sin(t * 1.7) * 0.06 * (1 - winded)
	local kneel = 1.1 * winded + 0.9 * tuck + 0.7 * squat - 0.4 * gliding
	local shin = -0.5 * winded - 1.0 * tuck - 0.9 * squat + 0.15 * gliding
	rig:Turn("LeftUpperLeg", CFrame.Angles(0.18 + kick + kneel, 0, 0.05 + 0.1 * tuck))
	rig:Turn("LeftLowerLeg", CFrame.Angles(-0.1 + kick + shin, 0, 0.05))
	rig:Turn("LeftFoot", CFrame.Angles(-0.35, 0, 0))
	rig:Turn("RightUpperLeg", CFrame.Angles(0.1 - kick + kneel, 0, -0.05 - 0.1 * tuck))
	rig:Turn("RightLowerLeg", CFrame.Angles(-0.22 - kick + shin, 0, -0.05))
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
	if self.highlight then
		self.highlight:Destroy()
		self.highlight = nil
	end
	if self.rig and self.model.Parent then
		self.rig:Release()
	end
end

return God
