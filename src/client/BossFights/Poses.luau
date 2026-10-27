-- Poses du joueur partagées par les duels de boss (D85), sur le Rig de son personnage (Activities/Rig.luau).
-- Conventions du Rig : rig:Place("LowerTorso", monde) place le bassin ; angle X positif = penché en arrière.
-- Les jambes ne sont jamais tournées à la main : les pieds sont posés à plat sur le vrai sol (rig:PlantFeet, D86) et
-- les genoux se plient d'eux-mêmes ; à appeler APRÈS avoir placé le bassin.

local Ground = require(script.Parent.Parent.Ground)

local Poses = {}

-- Bassin au repos, par rapport à la racine (à prendre après rig:Clear())
function Poses.Lower(rig): CFrame
	return rig.root.CFrame:ToObjectSpace(rig:PartCFrame("LowerTorso"))
end

local function ease(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
Poses.Ease = ease

-- Bassin placé : `offset` dans le repère du joueur (avance = -Z), penché de `lean` radians (positif = en arrière)
function Poses.Pelvis(rig, offset: Vector3, lean: number, twist: number?)
	local stand = rig.root.CFrame
	local lower = Poses.Lower(rig)
	rig:Place("LowerTorso", stand * CFrame.new(offset) * lower * CFrame.Angles(lean, twist or 0, 0))
end

-- Jambes en fente : pied gauche devant, pied droit derrière, posés à plat (genoux pliés sous un bassin abaissé).
-- shift : les pieds suivent le bassin quand il avance ou recule beaucoup (studs, avance = négatif, comme Pelvis)
function Poses.Lunge(rig, m, amount: number, shift: number?)
	local stride = m.legLength * amount
	local z = shift or 0
	rig:PlantFeet({
		Left = Vector3.new(-0.1 * stride, 0, -0.32 * stride + z),
		Right = Vector3.new(0.1 * stride, 0, 0.28 * stride + z),
	})
end

-- Victoire : bras en V vers le ciel, torse bombé (t de 0 à 1)
function Poses.Victory(rig, m, t: number)
	local k = ease(t * 2)
	Poses.Pelvis(rig, Vector3.zero, 0.12 * k)
	local stand = rig.root.CFrame
	for _, sx in { -1, 1 } do
		local shoulder = rig:JointFrame(if sx < 0 then "LeftShoulder" else "RightShoulder").Position
		local down = shoulder - stand.UpVector * m.armLength * 0.95 + stand.RightVector * sx * 0.3
		local up = shoulder + stand.UpVector * m.armLength * 0.8 + stand.RightVector * sx * m.armLength * 0.45
		-- Petits coups de poing vers le ciel
		local pump = math.sin(t * 18) * 0.25 * k
		rig:Reach(
			if sx < 0 then "LeftArm" else "RightArm",
			down:Lerp(up + stand.UpVector * pump, k),
			stand.RightVector * sx - stand.LookVector * 0.3
		)
	end
	rig:Set("Neck", CFrame.Angles(0.25 * k, 0, 0))
	rig:PlantFeet()
end

-- Défaite : il tombe à genoux, épuisé, tête basse (t de 0 à 1) ; `forward` : élan vers l'avant.
-- Les genoux touchent le sol, les tibias sont à plat derrière lui (dessus du pied au sol).
function Poses.Slump(rig, m, t: number, forward: number?)
	local k = ease(t * 1.6)
	local stand = rig.root.CFrame
	local ahead = -(forward or 0) * k
	-- Genou au sol : la hanche descend jusqu'à une cuisse (la moitié de la jambe) au-dessus du sol
	local thigh = m.legLength * 0.5
	-- Repoussé hors de l'estrade : il tombe à genoux sur le sol d'en bas
	local below = Ground.Height(stand.Position + stand.LookVector * -ahead)
	local step = if below then math.min(below - m.ground, 0) * k else 0
	local drop = math.max(m.hipHeight - (thigh + 0.3), 0) * k - step
	Poses.Pelvis(rig, Vector3.new(0, -drop, ahead), -0.25 * k)
	for _, side in { "Left", "Right" } do
		local sx = if side == "Left" then -1 else 1
		local rest = stand * CFrame.new(0, 0, ahead) * rig:RestFrame(side .. "Foot")
		-- Pied à genoux : derrière le genou d'un tibia, dessus du pied au sol (orteils vers l'arrière)
		local kneeling = CFrame.new(rest.Position + stand.LookVector * -(thigh * 0.95) + stand.UpVector * (0.05 + step))
			* stand.Rotation
			* CFrame.Angles(math.rad(-160), 0, 0)
		local foot = rest:Lerp(kneeling, k)
		rig:Plant(side, foot, stand.LookVector + stand.RightVector * sx * 0.2)
	end
	rig:Set("Neck", CFrame.Angles(-0.5 * k, 0, 0))
	for _, sx in { -1, 1 } do
		local shoulder = rig:JointFrame(if sx < 0 then "LeftShoulder" else "RightShoulder").Position
		rig:Reach(
			if sx < 0 then "LeftArm" else "RightArm",
			shoulder - stand.UpVector * m.armLength * 0.95 - stand.LookVector * 0.3 + stand.RightVector * sx * 0.25,
			-stand.LookVector + stand.RightVector * sx
		)
	end
end

return Poses
