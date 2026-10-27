-- Duels physiques des combats de boss (D85, src/client/BossFights/) : un duel par boss, joué dans le monde.
-- Distances en studs, angles en degrés, temps en secondes. Valeurs de départ ❓ à régler en regardant les combats.

return {
	-- Commun
	LeadGain = 2.2, -- écart de points (fraction du maximum d'une manche) qui donne une domination complète
	LeadSpeed = 3, -- vitesse à laquelle la position du duel suit l'écart
	Linger = 6, -- secondes pendant lesquelles la scène attend la manche suivante
	FinishTime = 3.2, -- durée de la fin du combat (le perdant tombe, le vainqueur exulte)
	HitTime = 0.45, -- durée d'une réaction à un coup
	-- Mouvements naturels (D87) : élan avant un coup, coup encaissé qui fait vaciller, vie entre les coups
	StrikeTime = 0.7, -- durée d'un coup : élan en arrière, frappe rapide, retour
	ImpactAt = 0.4, -- moment (part de StrikeTime) où le coup porte : l'adversaire réagit à cet instant
	RecoilTime = 0.8, -- durée d'une réaction élastique (il part, revient en oscillant)
	IdleBounce = 0.08, -- studs : les combattants rebondissent sur leurs appuis entre les coups
	IdleBounceSpeed = 1.3, -- rebonds par seconde

	-- Kevin : bataille de polochons
	-- Distance : du centre de l'estrade du boss (8 × 8) au joueur ; BossShift : le boss recule vers le fond.
	-- Les deux combattants restent sur l'estrade (au-delà de 4 studs, on tombe en contrebas).
	Kevin = {
		Distance = 1.7,
		BossShift = 1.6,
		SwingTime = 0.4, -- un coup d'oreiller
		Feathers = 14, -- plumes à chaque coup qui porte
		SpinOnHit = 35, -- Kevin tourne sur lui-même quand il prend un coup
		Yawn = 5, -- secondes entre deux bâillements (coup spécial)
	},

	-- Brayan : choc de rayons solaires
	Brayan = {
		Distance = 3.3,
		BossShift = 2.6,
		MirrorSize = Vector3.new(2.2, 2.6, 0.2),
		ClashShift = 2, -- le point de choc avance de 2 studs vers celui qui perd
		BeamWidth = 0.9,
		Sparks = 8,
	},

	-- Coach Turbo : tir à la corde
	CoachTurbo = {
		Distance = 3.2,
		BossShift = 2.6,
		RopeShift = 1.4, -- le foulard glisse de 1,4 stud vers celui qui gagne
		Lean = 24, -- penché en arrière pour tirer
		PullBack = 0.6, -- recul des mains à chaque traction
		ShoutEvery = 1.2, -- coup de mégaphone (secondes ; plus vite pendant le coup spécial)
	},

	-- Monsieur Pas-Les-Jambes : choc de pectoraux sur un ring
	NoLegs = {
		Distance = 1.7,
		BossShift = 1.7,
		RingHalf = 3.9, -- l'estrade devient le ring : poteaux et cordes à ses coins
		Push = 1.5, -- les deux combattants reculent de 1,5 stud vers le bord quand ils perdent
		Lunge = 1.1, -- élan vers l'adversaire à chaque choc
		Wobble = 9, -- il vacille sur ses jambes minuscules
	},

	-- Le Roi du Quartier : battle de poses royale
	BlockKing = {
		Distance = 3.4,
		BossShift = 1.8,
		CarpetLength = 7.5,
		FanSpin = 900, -- degrés par seconde
		CrownHeight = 2.2, -- couronne au-dessus de celui qui mène
	},
}
