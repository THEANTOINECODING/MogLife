-- Toutes les valeurs d'équilibrage du jeu. Ne jamais mettre ces chiffres en dur ailleurs.

return {
	-- Données d'un nouveau joueur (aussi utilisé comme template ProfileStore).
	-- Tout nouveau champ s'ajoute ici ; incrémenter schemaVersion si un champ change de sens.
	StartingData = {
		schemaVersion = 1,
		Mog = 0,
		Cash = 0,
		Stage = 1, -- index dans Stages.List
		BossesBeaten = {},
		HelpsDone = {}, -- aides déjà réussies au moins une fois (réplique unique la première fois)
		StyleOwned = {},
		StyleEquipped = {},
		FurnitureOwned = {}, -- meubles achetés
		FurniturePlaced = {}, -- emplacement de la maison -> meuble posé
		Tutorial = { Step = 1, Done = false }, -- tutoriel des 5 premières minutes (TutorialService)
		Tips = {}, -- conseils du mentor déjà donnés
	},

	-- Séries d'exercices
	SeriesLength = 20,
	-- Le serveur refuse une répétition arrivée avant repInterval × cette tolérance
	RepIntervalTolerance = 0.85,
	-- Distance max (studs) entre le joueur et la station pendant une série
	MaxStationDistance = 12,

	-- Multiplicateur de Mog selon la qualité de la répétition ("Auto" = mode auto)
	Quality = {
		Miss = 1,
		Good = 1.25,
		Perfect = 1.6,
		Auto = 1,
	},

	-- Fenêtres de timing (secondes d'écart avec le temps fort du mini-jeu)
	TimingWindows = {
		Perfect = 0.12,
		Good = 0.3,
	},

	-- Réglages propres à chaque mini-jeu (valeurs de départ, à ajuster en jouant)
	Minigames = {
		-- Pompes : un anneau rétrécit et touche la cible à HitPhase × intervalle
		Ring = {
			HitPhase = 0.75,
		},
		-- Développé couché : maintenir remplit la jauge en FillFactor × intervalle, relâcher dans la zone
		HoldRelease = {
			FillFactor = 0.75,
			ZoneMin = 0.68,
			ZoneMax = 0.9,
			PerfectHalfWidth = 0.045, -- autour du centre de la zone
		},
		-- Squat : la barre penche ; on note l'inclinaison moyenne sur chaque répétition (0 = droite, 1 = max)
		Tilt = {
			DriftStrength = 0.9, -- force de la dérive aléatoire
			DriftChangeTime = 0.8, -- secondes entre deux changements de dérive
			Instability = 1.2, -- plus la barre penche, plus elle continue de pencher
			ControlStrength = 2.6, -- force de correction du joueur
			PerfectMax = 0.15,
			GoodMax = 0.35,
		},
	},

	-- Aides en ville (voir design/02_MECANIQUES/AIDES.md)
	Helps = {
		Reps = 12, -- environ 20 à 40 s selon le mini-jeu
		Cooldown = 120, -- secondes avant de pouvoir refaire la même aide ❓
	},

	-- Maison et meubles
	Furniture = {
		ShopDistance = 14, -- distance max (studs) au comptoir du magasin pour acheter
		PlaceDistance = 16, -- distance max à l'emplacement pour poser un meuble
	},

	-- Déplacements : bouton « Maison » et arrêts de bus
	Travel = {
		HomeCooldown = 5, -- secondes entre deux retours à la maison
		BusCooldown = 3, -- secondes entre deux trajets en bus
		BusStopDistance = 12, -- distance max (studs) à un arrêt pour prendre le bus
	},

	-- Cycle jour / nuit (heure de Lighting.ClockTime, de 0 à 24)
	DayNight = {
		DayMinutes = 12, -- durée réelle d'une journée (6 h -> 18 h)
		NightMinutes = 4, -- durée réelle d'une nuit (18 h -> 6 h), plus courte
		StartClock = 9, -- heure au démarrage du serveur
		LightsOn = 18, -- les lampadaires s'allument
		LightsOff = 6.5, -- et s'éteignent
	},

	-- Portes automatiques (maisons, garage ↔ maison, magasins)
	Doors = {
		OpenDistance = 8, -- studs : la porte s'ouvre quand un joueur est plus près que ça
		OpenAngle = 90, -- degrés ; elle s'ouvre toujours du côté opposé au joueur
		SwingTime = 0.35,
		CheckInterval = 0.2,
	},

	-- Statues des 3 plus gros moggers du serveur, sur la place
	Statues = {
		RefreshSeconds = 20,
		Scale = { 2.2, 1.8, 1.6 }, -- taille de la statue selon le rang
	},

	-- Boss et Mog-off (voir design/02_MECANIQUES/BOSS.md)
	Boss = {
		Rounds = 3,
		RoundsToWin = 2,
		RepsPerRound = 6,
		-- Chaque manche est plus dure : rythme plus rapide et fenêtres de timing plus serrées
		SpeedByRound = { 1, 0.92, 0.85 }, -- multiplie l'intervalle du mini-jeu du boss
		TimingScaleByRound = { 0.95, 0.85, 0.75 }, -- multiplie les fenêtres Perfect / Good
		BossSkillBonusPerRound = 0.03, -- le boss gagne +3 % de chances de Perfect à chaque manche
		QualityScore = { Perfect = 100, Good = 70, Miss = 20 },
		-- Le boss joue en direct : il gagne la manche en cas d'égalité
		-- Défaite automatique (Mog insuffisant) : perte de Cash, annoncée avant le combat
		DefeatCashLossPercent = 0.10,
		DefeatCashLossCap = { 50, 120, 300, 600, 1_200, 2_500 }, -- par stade du joueur ❓
		-- Mog-off perdu (avec assez de Mog) : perte plus faible, annoncée aussi ❓
		MogOffLossPercent = 0.05,
		MogOffLossCap = { 20, 50, 120, 250, 500, 1_000 },
		PauseBetweenRounds = 2,
	},

	-- Apparence provisoire (avatar Roblox) en attendant le personnage du jeu
	BodyScale = {
		MinWidth = 1,
		MaxWidth = 2.2,
		MinDepth = 1,
		MaxDepth = 1.8,
		MogForMax = 45_000, -- taille max atteinte au niveau du Dieu du Pump
	},

	-- Le personnage prend du muscle à chaque séance (décision D40). Échelles des pièces de la coque.
	Growth = {
		-- Croissance permanente : +X % d'épaisseur quand le Mog atteint celui du boss suivant
		MaxScale = 0.22,
		-- Part de la croissance (et du pump) que prend chaque pièce
		Weights = {
			UpperArm = 1,
			LowerArm = 0.8,
			UpperTorso = 1,
			LowerTorso = 0.4,
			UpperLeg = 0.7,
			LowerLeg = 0.6,
			Hand = 0.3,
			Foot = 0,
			Head = 0,
			Head_Hair = 0,
		},
		-- Les os s'allongent beaucoup moins que les muscles ne s'épaississent (les articulations restent en place)
		LengthShare = 0.25,
		-- Pump : gonflement par répétition validée, plafond, temps pour redescendre du plafond à zéro
		PumpPerRep = { Perfect = 0.035, Good = 0.025, Auto = 0.02, Miss = 0.01 },
		PumpMax = 0.2,
		PumpDecayTime = 20,
		PumpUpdateInterval = 0.25,
		-- Muscles travaillés par exercice
		PumpMuscles = {
			Curl = { "UpperArm", "LowerArm" },
			PushUp = { "UpperTorso", "UpperArm" },
			BenchPress = { "UpperTorso", "UpperArm", "LowerArm" },
			Squat = { "UpperLeg", "LowerLeg" },
			PullUp = { "UpperTorso", "UpperArm", "LowerArm" },
			JumpRope = { "LowerLeg", "UpperLeg" },
		},
	},
}
