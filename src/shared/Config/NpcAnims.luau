-- Animations des habitants et des boss (D83, NpcController) : on anime le corps entier, par le code, chez chaque
-- joueur : respiration, balancement, regard vers le joueur proche, sautillements, et réactions (joie, déception, coup
-- encaissé, moquerie, fête). Les boss ont en plus un squelette (D85) : buste qui respire, tête qui suit le joueur,
-- bras qui bougent (D86). Le corps bascule autour de ses pieds, qui restent au sol (D86).
-- Distances en studs, angles en degrés, temps en secondes, fréquences en oscillations par seconde.

export type Style = {
	bob: number?, -- ampleur de la respiration (le buste se gonfle : léger tangage, os du buste chez les boss)
	bobSpeed: number?,
	sway: number?, -- balancement de côté (roulis)
	swaySpeed: number?,
	lean: number?, -- penché en avant / en arrière (tangage)
	leanSpeed: number?,
	turn: number?, -- regarde à gauche et à droite (lacet), en plus du regard vers le joueur
	turnSpeed: number?,
	hopEvery: number?, -- petit saut régulier (secondes entre deux sauts)
	hopHeight: number?,
	slump: number?, -- pique du nez lentement (degrés) puis se redresse d'un coup (Kevin qui s'endort debout)
	slumpEvery: number?,
	float: number?, -- flotte en l'air (Dieu du Pump)
	sparkle: string?, -- particules autour : "Shine" (Brayan), "Wind" (ventilateur du Roi), "Glow" (Dieu du Pump)
}

return {
	MaxDistance = 160, -- au-delà, le PNJ n'est pas animé (téléphone)
	LookDistance = 22, -- distance à laquelle il se tourne vers le joueur
	LookMaxAngle = 55, -- il ne se tourne pas plus que ça
	LookSpeed = 4, -- vitesse à laquelle il tourne la tête (le corps)
	AvailableHopEvery = 2.2, -- habitant dont l'aide est disponible : il sautille pour attirer l'attention
	AvailableHopHeight = 0.7,

	-- Réactions (impulsions qui s'ajoutent à l'attitude)
	Reactions = {
		Happy = { duration = 0.45, height = 0.9 }, -- répétition réussie pendant l'aide
		Sad = { duration = 0.5, shake = 6 }, -- répétition ratée : il secoue la tête
		Celebrate = { duration = 1.1, height = 2.6, spins = 1 }, -- aide réussie : grand saut, tour sur lui-même, confettis
		Thanks = { duration = 0.6, height = 1.2 }, -- fin d'une aide (vu par les autres joueurs)
		Hit = { duration = 0.45, tilt = 14, push = 0.8 }, -- boss qui encaisse un Perfect (incliné en arrière, recule)
		HitSmall = { duration = 0.35, tilt = 7, push = 0.4 }, -- boss qui encaisse un Good
		Taunt = { duration = 0.6, height = 0.6, wiggle = 10 }, -- boss qui se moque d'un raté
		Worried = { duration = 0.6, shake = 3 }, -- l'habitant s'inquiète au début de l'aide
	},
	ConfettiCount = 45,
	BreathAngle = 14, -- degrés de tangage par stud de « bob » (respiration du corps entier)
	-- Squelette des boss : buste, tête et bras
	Bones = {
		Breath = 4, -- degrés de respiration du buste
		HeadLook = 0.5, -- part du regard prise par la tête (le reste par le corps)
		ArmSwing = 5, -- degrés de balancement des bras
	},

	-- Attitude par personnage (lookId : boss, habitants, vendeurs, mentor). Default pour les autres.
	Default = { bob = 0.06, bobSpeed = 0.35, sway = 1.2, swaySpeed = 0.25 },
	Styles = {
		-- Boss
		Kevin = { bob = 0.05, bobSpeed = 0.22, lean = 4, leanSpeed = 0.12, slump = 9, slumpEvery = 5 },
		Brayan = { bob = 0.05, bobSpeed = 0.3, turn = 18, turnSpeed = 0.18, sparkle = "Shine" },
		CoachTurbo = { bob = 0.04, bobSpeed = 0.5, hopEvery = 0.75, hopHeight = 0.45, sway = 2, swaySpeed = 1.3 },
		NoLegs = { bob = 0.04, bobSpeed = 0.4, sway = 7, swaySpeed = 0.9, lean = 3, leanSpeed = 0.55 },
		BlockKing = { bob = 0.08, bobSpeed = 0.2, turn = 8, turnSpeed = 0.1, sparkle = "Wind" },
		-- flex : tient le double biceps avec ses os (son modèle est en bras en A, D90)
		PumpGod = { float = 0.8, bobSpeed = 0.25, turn = 10, turnSpeed = 0.08, sparkle = "Glow", flex = true },
		-- Habitants
		Mom = { bob = 0.05, bobSpeed = 0.5, sway = 3, swaySpeed = 0.8 }, -- elle s'agite avec son bocal
		Courier = { bob = 0.05, bobSpeed = 0.9, turn = 25, turnSpeed = 0.6 }, -- stressé, il regarde partout
		Kid = { hopEvery = 1.4, hopHeight = 0.5, sway = 3, swaySpeed = 1 },
		Neighbor = { bob = 0.05, bobSpeed = 0.4, lean = 3, leanSpeed = 0.5 },
		MrsDoRe = { bob = 0.06, bobSpeed = 0.5, sway = 5, swaySpeed = 0.5 }, -- elle chantonne
		Lifeguard = { bob = 0.04, bobSpeed = 0.3, turn = 30, turnSpeed = 0.15 }, -- il surveille la plage
		Grocer = { bob = 0.05, bobSpeed = 0.45, sway = 2, swaySpeed = 0.7 },
		Tourist = { bob = 0.05, bobSpeed = 0.35, turn = 35, turnSpeed = 0.3 }, -- perdu, il cherche son chemin
		Mentor = { bob = 0.04, bobSpeed = 0.2, lean = 2, leanSpeed = 0.15 },
	},
}
