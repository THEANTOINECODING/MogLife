-- Ressenti des coups (D126, design/REVIEW_2026-11-10.md) : chaque coup se sent par plusieurs canaux à la fois
-- (son en couches, caméra, flash, vibration) et la force de l'effet suit l'importance du coup.
-- ❓ Valeurs de départ, à régler en jouant.

return {
	-- Son de la répétition joué au moment même du geste (et plus à la confirmation du serveur, qui arrive plus tard) ;
	-- la confirmation du serveur ne rejoue pas le son si un geste a été fait il y a moins de EchoWindow secondes
	EchoWindow = 1.2,

	-- Combat de boss : le joueur porte un coup
	PlayerHit = {
		-- Couches de son ajoutées au son de la répétition (Config/Sounds.luau), par qualité
		Layers = {
			Good = { "HitPunch" },
			Perfect = { "HitPunch", "HitBoom" },
		},
		FreezePerfect = 0.06, -- secondes de caméra figée sur un Perfect (« hit-stop »), avant le coup de zoom
		FlashPerfect = 0.18, -- luminosité ajoutée un instant à l'image sur un Perfect
		FlashTime = 0.12,
	},

	-- Combat de boss : le boss marque (le joueur « prend » le coup)
	BossHit = {
		Layers = {
			Miss = { "HitWhiff" },
			Good = { "BossPunch" },
			Perfect = { "BossPunch", "HitBoom" },
		},
		Jolt = { Good = 0.5, Perfect = 1 }, -- force de la secousse latérale de la caméra (0 à 1)
		Vignette = { Good = 0.55, Perfect = 0.3 }, -- transparence la plus forte du voile rouge des bords (1 = invisible)
		VignetteTime = 0.35,
		VignetteColor = Color3.fromRGB(220, 30, 40),
		VignetteDepth = 0.22, -- part de l'écran couverte par chaque bord
		Delay = 0.12, -- secondes : le coup touche un peu après le début de son geste
	},

	-- D126 : pièces souples des tenues Robux (PremiumMotionController). Nom de la pièce : <Partie>_<Teinte>, la teinte
	-- contient Cape, Tail, WingA/WingB ou Spin (ex. « UpperTorso_CapeDeco », « LowerTorso_GlowTailDeco »).
	-- Chaque pièce tourne autour de son attache (bord du haut côté corps), avec un ressort : elle suit le mouvement en
	-- retard et dépasse un peu (follow-through). Angles en radians.
	Sway = {
		MaxDistance = 120, -- studs : au-delà de la caméra, les pièces restent immobiles
		RunSpeed = 24, -- studs/s : vitesse qui donne l'effet plein
		Stiffness = 60, -- raideur du ressort
		Damping = 9, -- amortissement (plus bas = rebonds plus longs)
		Cape = {
			Lift = -1.0, -- angle à pleine course (le signe envoie la cape vers l'arrière)
			Idle = 0.05, -- ondulation au repos
			IdleSpeed = 1.6,
			Flutter = 0.08, -- battement en course
			FlutterSpeed = 9,
			Turn = 0.25, -- inclinaison de côté quand on tourne (par rad/s de rotation)
			Fall = 0.5, -- se soulève en tombant (par 10 studs/s de chute)
			Max = 1.2,
		},
		Tail = {
			Wag = 0.22,
			WagSpeed = 2.4,
			RunWag = 0.12,
			Lift = -0.35,
			Turn = 0.35,
			Max = 0.8,
		},
		Wing = {
			PivotY = -0.15, -- hauteur de l'attache (part de la taille de la pièce)
			Flap = 0.1, -- battement au repos
			FlapSpeed = 1.8,
			RunFlap = 0.22,
			RunFlapSpeed = 5,
			Fold = 0.35, -- les ailes se replient vers l'arrière en course
			Max = 0.6,
		},
		SpinSpeed = 0.6, -- radians par seconde (auréole, couronne d'étoiles)
	},
	-- Traces de pas des tenues Robux (StyleSets.Footsteps)
	Footsteps = {
		StepDistance = 3.2, -- studs parcourus au sol entre deux pas
		FootSpread = 0.55, -- studs de chaque côté du centre
		Life = 2, -- secondes avant de retirer l'émetteur d'un personnage parti
	},

	-- D127 : aperçu des effets dans la boutique (src/client/PreviewFx.luau). Un ViewportFrame n'affiche ni particules ni
	-- traînées : l'aperçu les imite avec des images tournées vers la caméra.
	ShopFx = {
		MaxParticles = 90, -- au-delà, les nouvelles particules attendent (téléphone)
		TrailRate = 30, -- morceaux de traînée par seconde
		TrailDrift = 0.6, -- studs/s : la traînée s'éloigne vers l'arrière
		BurstEvery = 2.4, -- secondes entre deux « entrées » rejouées
		BurstMax = 36, -- particules par entrée au plus
		BurstSpeedScale = 0.22, -- vitesse de l'entrée réduite pour rester dans le cadre
		BurstGravity = 6, -- studs/s²
		RateScale = 1, -- multiplie le débit des auras
	},

	-- Secousse latérale de la caméra (CameraFraming.Jolt) à pleine force
	Jolt = {
		Side = 0.35, -- studs
		Roll = 0.035, -- radians
		Time = 0.32, -- secondes pour s'éteindre
		Frequency = 28, -- oscillations (radians par seconde de décroissance)
	},
}
