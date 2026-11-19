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

	-- Course (sprint) : lignes de vitesse derrière le personnage, buste penché en avant
	Sprint = {
		MinSpeed = 20, -- au-dessus : il court
		LineRate = 22,
		Lean = 9, -- degrés de buste penché en avant à pleine course (tous gabarits)
		LeanFrom = 17, -- studs/s : le buste commence à se pencher (marche normale : 16, course : 24)
	},

	-- D134 : transitions et inertie. Les couches ne sautent plus d'un état à l'autre : chaque facteur rejoint sa
	-- cible à cette vitesse (par seconde ; 10 = rejoint aux deux tiers en 0,1 s)
	Smooth = {
		Walk = 7, -- passage attente ↔ marche
		Air = 9, -- passage sol ↔ air
		Lean = 6, -- penché d'élan et virage
		Look = 5, -- tête qui se tourne vers ce qu'elle regarde
	},

	-- D134 : inertie du corps (effet cartoon de « retard ») : le buste traîne en arrière quand il démarre, bascule en
	-- avant quand il s'arrête net, et se penche dans les virages
	Inertia = {
		Accel = 0.45, -- degrés de buste par stud/s² d'accélération (le signe suit l'élan)
		MaxAccel = 11, -- degrés au plus
		Bank = 7, -- degrés de buste penché dans le virage par radian/s de rotation, à pleine vitesse
		MaxBank = 12,
	},

	-- D134 : chaque pas « tombe » : petit coup de buste et rebond des épaules, plus lourd avec le gabarit
	Stomp = {
		Chest = 1.2, -- degrés de buste au premier stade...
		ChestPerBulk = 3.3, -- ...plus celui-ci au gabarit maximal (le Gigachad écrase le sol)
		Shoulders = 2.5, -- degrés de rebond des bras à chaque pas (gabarit maximal)
	},

	-- D134 : en l'air (saut, chute) : bras qui s'ouvrent pour l'équilibre, buste qui suit la vitesse verticale
	Air = {
		-- (s'ajoute à l'animation de saut de Roblox, qui lève déjà les bras et les genoux : rester mesuré)
		Arms = 16, -- degrés de bras écartés en l'air
		ArmsFall = 12, -- en plus en chute rapide (bras qui battent vers le haut)
		FallFull = 60, -- studs/s de chute pour l'effet plein
		Chest = 4, -- degrés : buste cambré en montée, penché en avant en descente
		Legs = 6, -- degrés : genoux remontés en l'air (hanches pliées)
	},

	-- D134 : atterrissage encaissé par le corps (en plus de l'anneau de poussière) : buste et tête plongent, bras
	-- projetés vers le bas puis remontent, le tout proportionnel à la vitesse de chute
	Recoil = {
		Time = 0.42, -- durée de l'encaissement
		Attack = 0.05, -- temps pour atteindre le plus bas
		Chest = 16, -- degrés de buste au plus fort (chute de FallFull studs/s)
		Neck = 8,
		Arms = 18,
		Min = 0.25, -- force minimale d'un atterrissage visible (petits sauts)
	},

	-- D134 : regard. La tête (et un peu le buste) se tourne vers le joueur le plus proche devant soi ; son propre
	-- personnage regarde sinon là où regarde la caméra
	Look = {
		Distance = 16, -- studs : au-delà, on ne regarde pas les autres
		MaxYaw = 65, -- degrés de rotation de la tête au plus
		MaxPitch = 25,
		Cone = 110, -- degrés : on ne remarque que ceux qui sont dans ce cône devant soi
		WaistShare = 0.3, -- part du regard prise par le buste (le reste par le cou)
		PickEvery = 0.35, -- secondes entre deux choix de cible
		Camera = true, -- son propre personnage suit la caméra sans cible
		CameraShare = 0.6, -- et seulement en partie (sinon c'est raide)
	},

	-- D134 : séries des activités. Montée nette, court maintien, descente contrôlée plus lente (comme à la salle),
	-- et respiration entre les répétitions. Parts de la durée d'une répétition (la somme vaut moins de 1).
	Reps = {
		Up = 0.34,
		Hold = 0.14,
		Breath = 1.6, -- degrés de respiration du buste entre deux répétitions
		BreathRate = 0.45, -- respirations par seconde (essoufflé)
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
		-- D125 : Empereur cosmique : port de tête royal, lévite presque, lent balancement
		Cosmic = { waist = { 5, 0 }, neck = { 7, 0 }, arms = 10, hip = 0, breath = 0.6, sway = 6, swayRate = 0.08 },
		-- Titan d'or : massif, épaules en avant, respiration lourde de forge
		Molten = { waist = { -3, 0 }, neck = { -2, 0 }, arms = 16, hip = 0, breath = 1.8, sway = 0, swayRate = 0 },
		-- Fantôme néon : déhanché, tête qui glitche par à-coups
		Neon = { waist = { 0, 10 }, neck = { 3, -12 }, arms = 4, hip = 5, breath = 0.5, scan = 10, scanEvery = 0.7 },
		-- Démon : voûté, menaçant, tête qui rôde, respiration lourde
		Demon = { waist = { -9, 0 }, neck = { -4, 0 }, arms = 14, hip = 0, breath = 2, sway = 10, swayRate = 0.12 },
	},
}
