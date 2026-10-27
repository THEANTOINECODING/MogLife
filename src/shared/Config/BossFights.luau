-- Duels physiques des combats de boss (D85, src/client/BossFights/) : un duel par boss, joué dans le monde.
-- Distances en studs, angles en degrés, temps en secondes. Valeurs de départ ❓ à régler en regardant les combats.

return {
	-- Commun
	LeadGain = 2.2, -- écart de points (fraction du maximum d'une manche) qui donne une domination complète
	LeadSpeed = 3, -- vitesse à laquelle la position du duel suit l'écart
	Linger = 6, -- secondes pendant lesquelles la scène attend la manche suivante
	FinishTime = 3.2, -- durée de la fin du combat (le perdant tombe, le vainqueur exulte)
	HitTime = 0.45, -- durée d'une réaction à un coup

	-- Kevin : bataille de polochons
	Kevin = {
		Distance = 4.6,
		SwingTime = 0.4, -- un coup d'oreiller
		Feathers = 14, -- plumes à chaque coup qui porte
		SpinOnHit = 35, -- Kevin tourne sur lui-même quand il prend un coup
		Yawn = 5, -- secondes entre deux bâillements (coup spécial)
	},

	-- Brayan : choc de rayons solaires
	Brayan = {
		Distance = 10,
		MirrorSize = Vector3.new(2.2, 2.6, 0.2),
		ClashShift = 3.2, -- le point de choc avance de 3,2 studs vers celui qui perd
		BeamWidth = 0.9,
		Sparks = 8,
	},

	-- Coach Turbo : tir à la corde
	CoachTurbo = {
		Distance = 9,
		RopeShift = 2.2, -- le foulard glisse de 2,2 studs vers celui qui gagne
		Lean = 24, -- penché en arrière pour tirer
		PullBack = 0.6, -- recul des mains à chaque traction
		ShoutEvery = 1.2, -- coup de mégaphone (secondes ; plus vite pendant le coup spécial)
	},

	-- Monsieur Pas-Les-Jambes : choc de pectoraux sur un ring
	NoLegs = {
		Distance = 5.4,
		RingRadius = 6.5,
		Push = 1.6, -- les deux combattants reculent de 1,6 stud vers le bord quand ils perdent
		Lunge = 1.1, -- élan vers l'adversaire à chaque choc
		Wobble = 9, -- il vacille sur ses jambes minuscules
	},

	-- Le Roi du Quartier : battle de poses royale
	BlockKing = {
		Distance = 7.5,
		CarpetLength = 11,
		FanSpin = 900, -- degrés par seconde
		CrownHeight = 2.2, -- couronne au-dessus de celui qui mène
	},
}
