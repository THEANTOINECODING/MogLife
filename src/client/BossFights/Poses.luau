-- Poses du joueur partagées par les duels de boss (D85), sur le Rig de son personnage (Activities/Rig.luau).
-- Conventions du Rig : rig:Place("LowerTorso", monde) place le bassin ; angle X positif = penché en arrière ;
-- hanches : X positif = jambe vers l'avant ; genoux : X négatif = plié.

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

-- Jambes en fente : une devant, une derrière, genoux pliés
function Poses.Lunge(rig, amount: number)
	rig:Set("LeftHip", CFrame.Angles(0.5 * amount, 0, 0))
	rig:Set("LeftKnee", CFrame.Angles(-0.7 * amount, 0, 0))
	rig:Set("RightHip", CFrame.Angles(-0.25 * amount, 0, 0))
	rig:Set("RightKnee", CFrame.Angles(-0.35 * amount, 0, 0))
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
end

-- Défaite : il tombe à genoux, épuisé, tête basse (t de 0 à 1) ; `forward` : élan vers l'avant
function Poses.Slump(rig, m, t: number, forward: number?)
	local k = ease(t * 1.6)
	local drop = m.legLength * 0.55 * k
	Poses.Pelvis(rig, Vector3.new(0, -drop, -(forward or 0) * k), -0.35 * k)
	rig:Set("LeftHip", CFrame.Angles(1.3 * k, 0, 0))
	rig:Set("RightHip", CFrame.Angles(1.3 * k, 0, 0))
	rig:Set("LeftKnee", CFrame.Angles(-2.0 * k, 0, 0))
	rig:Set("RightKnee", CFrame.Angles(-2.0 * k, 0, 0))
	rig:Set("Neck", CFrame.Angles(-0.5 * k, 0, 0))
	local stand = rig.root.CFrame
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
