-- Mouvements et effets du personnage hors activité (D84, MotionController) : démarche selon le stade, respiration,
-- flex spontané, poussière des pas, atterrissages, course, posture du pareur. Calculés chez chaque joueur pour tous les
-- personnages proches (rien de plus sur le réseau). Angles en degrés, distances en studs, temps en secondes.
-- « Gabarit » : 0 au premier stade (Normie), 1 au dernier (Gigachad et au-delà).

return {
	MaxDistance = 90, -- au-delà, un personnage n'a ni démarche spéciale ni poussière (téléphone)
	LastStage = 6, -- stade où le gabarit vaut 1

	-- Démarche (s'ajoute à l'animation de marche de Roblox)
	Walk = {
		ChestOut = 7, -- buste cambré (torse bombé), au gabarit maximal
		Twist = 9, -- le buste tourne à chaque pas (épaules qui roulent)
		ArmsOut = 16, -- bras écartés (gros dorsaux)
		Sway = 4, -- le bassin se dandine
		ChinUp = 6, -- menton relevé
		StepRate = 0.2, -- pas par seconde et par stud/s de vitesse (rythme du balancement)
	},

	-- Attente (debout, immobile)
	Idle = {
		Breath = 2.5, -- amplitude de la respiration (buste), plus forte avec le gabarit
		BreathRate = 0.28, -- respirations par seconde (lentes et profondes)
		ShoulderLift = 3, -- les épaules montent à l'inspiration
		ArmsOut = 10, -- bras un peu écartés, même à l'arrêt (gabarit maximal)
		FlexAfter = 12, -- son propre personnage, immobile depuis 12 s : il prend une pose de culturisme
		FlexAgain = 18, -- puis à nouveau toutes les 18 s s'il ne bouge toujours pas
	},

	-- Poussière des pas (à chaque pas, au pied qui touche le sol)
	Dust = {
		MinSpeed = 3, -- vitesse (studs/s) à partir de laquelle les pas soulèvent de la poussière
		StepDistance = 3.2, -- studs parcourus entre deux pas
		Puffs = 2, -- bouffées par pas au premier stade...
		PuffsPerStage = 0.6, -- ...plus celles du gabarit (les gros font plus de poussière)
		SprintBonus = 2, -- en courant
		Size = 0.9, -- taille d'une bouffée au premier stade
		SizePerStage = 0.25,
		Lifetime = 0.7,
		-- Couleur selon le sol (Enum.Material) ; Default pour les autres
		Colors = {
			Grass = Color3.fromRGB(150, 175, 105),
			LeafyGrass = Color3.fromRGB(150, 175, 105),
			Sand = Color3.fromRGB(230, 210, 160),
			Ground = Color3.fromRGB(165, 135, 100),
			Mud = Color3.fromRGB(120, 95, 70),
			WoodPlanks = Color3.fromRGB(190, 160, 120),
			Wood = Color3.fromRGB(190, 160, 120),
			Default = Color3.fromRGB(205, 200, 195),
		},
	},

	-- Atterrissage après un saut ou une chute : anneau de poussière, petite secousse pour les gros gabarits
	Landing = {
		MinFall = 12, -- vitesse de chute (studs/s) minimale pour un anneau
		Puffs = 10,
		PuffsPerStage = 4,
		ShakeFromStage = 4, -- à partir de ce stade, sa propre caméra tremble un peu (le sol encaisse)
		Shake = 0.25, -- studs
		ShakeTime = 0.22,
	},

	-- Course (sprint) : lignes de vitesse derrière le personnage
	Sprint = {
		MinSpeed = 20, -- au-dessus : il court
		LineRate = 22,
	},

	-- Pareur : applaudit en rythme en regardant le pratiquant, saute de joie sur ses Perfect
	Spotter = {
		ClapRate = 1.6, -- applaudissements par seconde
		CheerJump = 0.6, -- saut sur un Perfect du pratiquant
		CheerTime = 0.5,
	},

	-- Attitude au repos des tenues haut de gamme (D122, StyleSets.Signature[...].style), en degrés, à l'arrêt seulement
	-- waist / neck : { tangage (+ = buste ou menton relevé), lacet } ; arms : bras écartés en plus ; hip : bascule
	-- du bassin ; breath : multiplie la respiration ; sway : balancement lent (degrés, sur le lacet de la tête)
	Stances = {
		-- Dragon : penché en avant, tête basse qui rôde de gauche à droite, griffes écartées
		Dragon = { waist = { -7, 0 }, neck = { -6, 0 }, arms = 8, hip = 0, breath = 1.6, sway = 14, swayRate = 0.18 },
		-- Soleil : buste fier, menton levé vers le ciel, bras ouverts qui flottent
		Sun = { waist = { 6, 0 }, neck = { 10, 0 }, arms = 14, hip = 0, breath = 0.8, sway = 0, swayRate = 0 },
		-- Mecha : la tête balaie par à-coups (gauche, centre, droite), presque pas de respiration
		Mecha = { waist = { 2, 0 }, neck = { 0, 0 }, arms = 6, hip = 0, breath = 0.25, scan = 22, scanEvery = 1.1 },
		-- Statue : contrapposto (bassin basculé, tête tournée), immobile comme du marbre
		Marble = { waist = { 3, -8 }, neck = { 4, 18 }, arms = 5, hip = 4, breath = 0.15, sway = 0, swayRate = 0 },
	},
}
