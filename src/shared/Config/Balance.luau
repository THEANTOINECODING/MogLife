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
		PumpGodWins = 0, -- victoires contre le Dieu du Pump au Colisée (titre, laurier, statue dorée, D93)
		HelpsDone = {}, -- aides déjà réussies au moins une fois (réplique unique la première fois)
		HelpReadyAt = {}, -- heure serveur où chaque aide redevient disponible (délai Helps.Cooldown, D108)
		Funnel = {}, -- étapes du funnel des premières minutes déjà envoyées aux mesures Roblox (Config/Analytics, D109)
		StyleOwned = {},
		StyleEquipped = {},
		FurnitureOwned = {}, -- meubles achetés
		FurniturePlaced = {}, -- emplacement de la maison -> meuble posé
		Tutorial = { Step = 1, Done = false }, -- tutoriel des 5 premières minutes (TutorialService)
		Boost = { Id = "", EndsAt = 0 }, -- boost temporaire en cours (BoostService), EndsAt en os.time()
		Records = {}, -- meilleure note de série par exercice (0 à 100)
		Tips = {}, -- conseils du mentor déjà donnés
		-- Réglages du joueur (Config/Settings.luau), tous activés par défaut
		Settings = {
			Music = true,
			Sounds = true,
			ScreenFx = true,
			Vibration = true,
			OutfitFx = true,
			CloseUp = true,
			Names = true,
			Players = true,
			Duels = true,
		},
		-- Récompenses de la semaine (WeeklyService, Config/Weekly.luau). Week = numéro de semaine (0 = jamais ouvert) ;
		-- Challenges = ids des 3 défis de la semaine ; Stats = compteurs de la semaine (WeeklyService.Track) ;
		-- Days = { D1 = true… } jours cochés du coffre ; Seconds et DayStamp = temps de jeu du jour en cours ;
		-- Trophies = semaines aux 3 défis réussis (titres exclusifs)
		Weekly = {
			Week = 0,
			Challenges = {},
			Claimed = {},
			Bonus = false,
			Days = {},
			Chest = false,
			Seconds = 0,
			DayStamp = 0,
			Trophies = 0,
			Stats = {},
		},
		-- Duels de bras de fer (DuelService) : bilan, et compteur du jour par adversaire (récompenses plafonnées)
		Duels = { Wins = 0, Losses = 0, Draws = 0, Day = 0, Pairs = {} },
		-- Apparence choisie dans le menu de création (D55, Config/Look.luau) ; Created = menu déjà validé une fois
		Look = {
			Created = false,
			Gender = "M",
			Skin = "Peach",
			Hair = "Brown",
			Eyes = "Brown",
			Top = "Gray",
			Shorts = "Blue",
			Expression = "Confident",
			First = "Brad",
			Title = "Spaghetti",
			Dye = "", -- teinture du coiffeur (D106), "" = couleur d'origine de la coupe
		},
	},

	-- Séries d'exercices
	SeriesLength = 20,
	-- Le serveur refuse une répétition arrivée avant repInterval × cette tolérance
	RepIntervalTolerance = 0.85,
	GamepadDeadzone = 0.2,
	-- Distance max (studs) entre le joueur et la station pendant une série
	MaxStationDistance = 12,
	Movement = {
		WalkSpeed = 16,
		SprintSpeed = 24,
	},

	-- Émotes : poses de culturisme (MogOff.Strike), visibles par tous
	-- Fenêtre de la semaine (D96) : elle s'ouvre à l'arrivée, une fois le joueur libre depuis ArrivalDelay secondes
	WeeklyWindow = { ArrivalDelay = 2.5, ArrivalGiveUp = 180, RaySpeed = 14 }, -- RaySpeed : degrés/s des rayons
	-- Interface vivante (D84) : compteurs qui défilent, icônes qui s'envolent vers le HUD
	-- Bandeau des événements de ville (D106) : une ligne de Height pixels (+ DetailHeight pour la consigne, montrée
	-- DetailSeconds secondes), Width de large hors téléphone en portrait ; position du haut en portrait / ordinateur
	EventBanner = {
		Height = 48,
		DetailHeight = 34,
		DetailSeconds = 6,
		Width = 340,
		PortraitTop = 106,
		DesktopTop = 120,
	},

	HudFx = {
		RollTime = 0.6, -- secondes pour que le compteur atteigne sa nouvelle valeur
		PulseScale = 1.25, -- rebond du compteur quand il monte
		GainColor = Color3.fromRGB(255, 235, 120),
		FlyCount = 7, -- icônes qui s'envolent
		FlyStagger = 0.06,
		FlyTime = 0.55,
	},

	Emotes = {
		Duration = 2.6, -- secondes de pose
		Cooldown = 3, -- secondes minimum entre deux émotes
		Count = 5, -- nombre de poses (doit suivre MogOff.PoseCount)
		CelebratePose = 1, -- pose de victoire (double biceps) après un boss battu ou une série notée S (D83)
		CelebrateDelay = 0.8, -- secondes après la fin (le personnage quitte d'abord son activité)
	},

	-- Pareur : un joueur en pare un autre pendant sa série d'exercice
	Spot = {
		Distance = 12, -- studs max entre le pareur et le pratiquant
		LifterBonus = 0.2, -- +20 % de Mog pour le pratiquant paré
		SpotterShare = 0.25, -- le pareur reçoit 25 % du Mog de chaque répétition
		CheerPose = 1, -- pose d'encouragement du pareur (double biceps)
	},

	-- Délai minimum (secondes) entre deux appels d'un même remote par un joueur (D108, src/server/Throttle.luau)
	RemoteThrottle = {
		RequestStats = 0.5, -- l'interface redemande tout l'état (ouverture d'un menu)
		Style = 0.2, -- équiper une pièce, une tenue ou une teinture
	},

	-- Création de personnage (D55)
	Look = {
		OpenDelay = 2, -- secondes après l'arrivée avant d'ouvrir le menu de création (le temps que l'interface charge)
		RequestCooldown = 1, -- secondes minimum entre deux validations d'apparence
	},

	-- Combo (série de répétitions réussies d'affilée, D49) : multiplie le Mog des exercices. Un raté remet à zéro ;
	-- Paliers : à partir de `at` répétitions réussies.
	Combo = {
		Steps = {
			{ at = 0, multiplier = 1 },
			{ at = 5, multiplier = 1.2 },
			{ at = 10, multiplier = 1.5 },
			{ at = 15, multiplier = 2 }, -- « ON FIRE »
		},
	},

	-- Note de fin de série (D51) : précision moyenne des répétitions. Lettre et étoiles selon le score.
	Grade = {
		Points = { Perfect = 100, Good = 70, Miss = 20 },
		MinManualShare = 0.5, -- au moins la moitié des répétitions jouées à la main pour être noté
		Letters = {
			{ letter = "S", min = 95, stars = 3 },
			{ letter = "A", min = 85, stars = 2 },
			{ letter = "B", min = 70, stars = 1 },
			{ letter = "C", min = 0, stars = 0 },
		},
	},

	-- Plafond discret contre la triche (D108) : le client note ses répétitions, le serveur vérifie que le taux
	-- de « Perfect » reste humain sur les dernières répétitions jouées à la main (toutes activités confondues).
	-- Au-delà, un Perfect compte comme Good, sans message. La note S (95) reste atteignable sous ce plafond.
	RepPlausibility = {
		Window = 60, -- répétitions gardées en mémoire
		MinSamples = 30, -- pas de plafond avant ce nombre de répétitions
		MaxPerfectShare = 0.92,
	},

	-- Multiplicateur de Mog selon la qualité de la répétition
	Quality = {
		Miss = 0.25, -- une répétition ratée ne rapporte presque rien (D80)
		Good = 1.25,
		Perfect = 1.6,
	},

	-- Fenêtres de timing (secondes d'écart avec le temps fort du mini-jeu)
	TimingWindows = {
		Perfect = 0.12,
		Good = 0.3,
	},

	-- Réglages propres à chaque mini-jeu (valeurs de départ, à ajuster en jouant ; design/02_MECANIQUES/MINIJEUX.md)
	-- « Level » : difficulté envoyée par le serveur. Entraînements et aides : stades au-dessus du stade de déblocage ;
	-- boss et duel : manche - 1. Chaque jeu débloque ses surprises à partir d'un niveau (…Level) (D81).
	Minigames = {
		-- Les fenêtres de notation se resserrent pendant la série : à la dernière répétition,
		-- elles valent (1 - SeriesTightening) × leur taille de départ (D80)
		SeriesTightening = 0.3,
		-- Commun (MinigameKit)
		SwipeMinPixels = 28, -- un glissé compte à partir de ce déplacement du doigt...
		SwipeScreenFraction = 0.05, -- ...ou de cette part de la hauteur de l'écran si elle est plus grande
		RepSafetyMargin = 0.12, -- secondes de marge sur la cadence du serveur avant d'envoyer une répétition
		GuideSessions = 2, -- la main fantôme se montre les 2 premières parties de chaque mini-jeu (par session)
		GuideMaxReps = 3, -- et disparaît à la première réussite, ou au plus tard après 3 répétitions
		AnnounceTime = 2.2, -- secondes d'affichage d'une nouveauté (« anneau rouge : ne touche pas ! »)
		DragSensitivity = 1.15, -- glisser-déplacer : 1 = l'objet suit exactement le doigt

		-- Curl : glisser vers le haut quand le repère touche la ligne dorée
		Swipe = {
			HitPhase = 0.7, -- le repère touche la ligne à 70 % du cycle
			SlowLevel = 1, -- répétitions lentes (tortue) à partir de ce niveau
			SlowChance = 0.25,
			SlowFactor = 1.6, -- un cycle lent dure 1,6 intervalle
		},
		-- Pompes : un anneau se resserre et touche la cible à HitPhase × intervalle
		Ring = {
			HitPhase = 0.6,
			DoubleLevel = 1, -- anneaux doubles (deux appuis rapides)
			DoubleChance = 0.25,
			DoubleGap = 0.28, -- part du cycle entre les deux anneaux
			RedLevel = 2, -- anneaux rouges : ne pas toucher
			RedChance = 0.2,
		},
		-- Développé couché : maintenir remplit la jauge en FillFactor × intervalle, relâcher dans la zone verte
		HoldRelease = {
			FillFactor = 1.0, -- jauge pleine en 1 intervalle : Perfect ≈ ±55 ms, Good ≈ ±140 ms au départ
			ZoneCenterMin = 0.45, -- le centre de la zone est tiré au sort à chaque répétition
			ZoneCenterMax = 0.85,
			ZoneHalfWidth = 0.1,
			ZoneShrinkPerLevel = 0.012,
			PerfectHalfWidth = 0.04,
			ShakeStart = 0.25, -- secondes passées au-dessus de la zone avant que la barre tremble fort
			DriftLevel = 2, -- la zone bouge pendant qu'on pousse
			DriftSpeed = 0.18,
		},
		-- Squat : glisser vers le bas jusqu'à la ligne, puis remonter (lever le doigt)
		Tilt = {
			RangeFraction = 0.6, -- part de la hauteur de l'écran à parcourir pour descendre tout en bas (iPhone : ~230 pt)
			KeySpeed = 1.3, -- descente au clavier / manette (profondeur par seconde)
			RiseSpeed = 2.2, -- remontée quand on lâche
			TargetMin = 0.55,
			TargetMax = 0.9,
			PerfectMax = 0.06, -- ≈ ±14 pt du pouce sur iPhone
			GoodMax = 0.13,
			StandBelow = 0.08, -- debout
			StartAbove = 0.18, -- la répétition commence quand on descend plus bas que ça
			PauseLevel = 1, -- squats avec pause en bas
			PauseChance = 0.3,
			PauseTime = 0.5,
		},
		-- Tractions : la main indiquée, à gauche ou à droite, sur le temps
		Alternate = {
			BothLevel = 1, -- « les deux mains » : toucher les deux côtés ensemble
			BothChance = 0.2,
			BothWindow = 0.18, -- secondes entre les deux appuis
			SwingLevel = 2, -- rythme irrégulier (jamais plus rapide que l'intervalle)
			SwingMax = 0.35, -- un temps peut durer jusqu'à 1,35 intervalle
		},
		-- Corde à sauter : sauter quand la corde passe sous les pieds
		Rope = {
			PerfectTime = 0.08, -- écart (secondes) avec le passage sous les pieds
			GoodTime = 0.18,
			PeriodMin = 1.05, -- durée d'un tour (× intervalle)
			PeriodMax = 1.5,
			FastLevel = 1, -- tours rapides (rouges)
			FastChance = 0.25,
			FakeLevel = 2, -- fausses accélérations : la corde fonce puis ralentit juste avant les pieds
			FakeChance = 0.3,
		},

		-- Bocal de maman (refait en D106) : taper Taps fois le couvercle (l'air sort), puis un glissé pour dévisser
		Twist = {
			Taps = 3, -- tapes pour faire sortir l'air
			PerfectTime = 0.8, -- bocal ouvert (tapes + glissé) en moins de 0,8 intervalle = Perfect
			MissTime = 1.6, -- au-delà de 1,6 intervalle = raté
			PopTime = 0.7, -- secondes de la scène d'ouverture avant le bocal suivant
			TightLevel = 1, -- couvercle coriace : plus de tapes
			TightChance = 0.35,
			TightTaps = 5,
		},

		-- Pneu du coursier (refait en D106) : pompe à pied, écraser la pédale quand elle est tout en haut (au temps)
		Pressure = {
			Steps = 4, -- crans pour remplir un pneu
			FirstBeat = 1.2, -- le premier temps arrive après 1,2 intervalle (le temps de voir la pédale monter)
			RideTime = 0.8, -- secondes : le vélo s'en va, le suivant arrive
			LeakLevel = 1, -- pneu qui fuit : un raté fait perdre un cran
			BigLevel = 2, -- gros pneu de cargo : plus de crans
			BigChance = 0.35,
			BigSteps = 6,
		},
		-- Marteau : allers-retours à vitesse constante, un passage au-dessus du clou par pulsation (D106)
		Hammer = {
			PerfectTime = 0.08, -- secondes d'écart avec le passage au-dessus du clou
			GoodTime = 0.18,
			BentLevel = 1, -- clous tordus : deux coups
			BentChance = 0.3,
			ThumbLevel = 2, -- le pouce du petit voisin est sur la planche
			ThumbChance = 0.5,
		},
		-- Voiture : glisser pour rester sur la route et éviter les obstacles
		Steer = {
			RoadWidth = 0.38, -- D82 : un peu plus large et des virages plus doux
			CurveAmplitude = 0.17,
			CurvePerLevel = 0.025,
			ScrollSpeed = 1.0,
			ObstacleEvery = 2, -- un obstacle toutes les 2 pulsations...
			ObstacleEveryMin = 1, -- ...jusqu'à 1 aux niveaux élevés
			HitRadius = 0.08,
			PerfectMax = 0.09, -- écart moyen au milieu de la route
			GoodMax = 0.18, -- au-delà : sorti de la route (raté)
		},
		-- Piano : glisser à gauche / à droite vers la voie libre
		Lanes = {
			FallFactor = 1.6, -- temps de chute d'une vague (× intervalle)
			FallPerLevel = 0.12,
			FallMin = 1.1,
			DoubleLevel = 1, -- deux vagues rapprochées
			DoubleChance = 0.25,
			LastSecond = 0.3, -- esquive dans les 0,3 dernières secondes = Good
		},
		-- Transats : lâcher le transat pile au-dessus de la pile, ce qui dépasse tombe
		Stack = {
			StartWidth = 0.4,
			MinWidth = 0.1,
			SweepFactor = 2, -- un aller-retour du transat dure 2 intervalles
			PerfectSnap = 0.03, -- à moins de 3 % : posé parfaitement, rien ne tombe
			GoodMax = 0.12, -- au-delà : raté (le transat tombe à côté)
			SpeedPerLevel = 0.12,
			Visible = 6, -- transats visibles avant que la vue monte
		},
		-- Courses : rattraper les fruits, éviter les objets interdits
		Catch = {
			FallFactor = 1.3,
			MinDistance = 0.25, -- chaque objet tombe au moins à cette distance du panier
			PerfectMax = 0.06,
			GoodMax = 0.13,
			HazardLevel = 1,
			HazardChance = 0.25,
			BounceLevel = 2, -- fruits qui rebondissent de gauche à droite
			BounceChance = 0.35,
		},
		-- Touriste : retenir le chemin sur le plan, puis le refaire en glissant
		Sequence = {
			Grid = 6, -- plan de 6 × 6 rues
			Length = 5, -- 5 pas dès le départ (l'aide se débloque au dernier stade : niveau 0 presque toujours)
			LengthPerLevel = 1,
			MaxLength = 7,
			ShowPerStep = 0.36, -- secondes d'affichage par pas
			PerfectPerStep = 0.45, -- refait en moins de 0,45 s par pas = Perfect
		},

		-- Kevin : glisser dans le sens de son bras, le plus vite possible
		Reaction = {
			WaitMin = 0.2, -- attente avant que Kevin bouge (on ne peut pas deviner)
			WaitMax = 0.45,
			PerfectMax = 0.5, -- secondes pour réagir (D82 : plus simple)
			GoodMax = 0.9,
			FourLevel = 1, -- manche 1 : gauche ou droite ; ensuite les 4 directions
			FeintLevel = 2, -- feintes à la dernière manche : le bras part d'un côté puis change
			FeintChance = 0.25,
			FeintTime = 0.35,
		},
		-- Brayan : garder sa crème solaire dans le soleil, éviter les nuages
		Spotlight = {
			Radius = 0.16,
			JumpEvery = 1.8, -- le soleil saute (secondes)...
			JumpWarn = 0.45, -- ...annoncé par un cercle à sa prochaine place
			CloudLevel = 1,
			CloudSpeed = 0.25,
			PerfectInside = 0.8,
			GoodInside = 0.5,
		},
		-- Coach Turbo : deux pistes, toucher le côté de la note quand elle touche la ligne
		Beats = {
			PanelHeight = 0.5, -- part de la hauteur de l'écran (panneau large, en bas)
			FallFactor = 1.5,
			FallPerLevel = 0.15,
			LongLevel = 1, -- notes longues : maintenir jusqu'au bout
			LongChance = 0.3,
			LongLength = 0.7, -- longueur (× intervalle)
		},
		-- Monsieur Pas-Les-Jambes : glisser vers son poing au moment du choc
		Wobble = {
			Approach = 1.1, -- temps d'arrivée du poing (× intervalle)
			ApproachPerLevel = 0.1,
			PerfectTime = 0.15, -- écart (secondes) avec le choc
			GoodTime = 0.36,
			DoubleLevel = 2, -- deux poings à la suite
			DoubleChance = 0.2,
			UpLevel = 1, -- coups venant aussi d'en haut
		},
		-- Roi du Quartier : glisser la combinaison avant que le ventilateur l'efface
		Combo = {
			Length = 4,
			LongLevel = 2, -- 5 flèches à la dernière manche
			PerfectFraction = 0.6, -- fini en moins de 60 % du temps = Perfect (D87, plus facile)
			GoodFraction = 1.0,
		},
	},

	-- Aides en ville (voir design/02_MECANIQUES/AIDES.md)
	Helps = {
		Reps = 12, -- environ 20 à 40 s selon le mini-jeu
		Cooldown = 120, -- secondes avant de pouvoir refaire la même aide ❓ (seulement si l'aide a rapporté)
		-- Récompense selon la réussite (D57) : chaque répétition rapporte (cash de l'aide / répétitions)
		-- x qualité x combo (Balance.Combo) x bonus de chaîne de Perfect. Tout raté = 0 Cash.
		-- Ordres de grandeur (12 répétitions) : tout Perfect sans faute = environ 1,75 x le cash de l'aide ;
		-- partie moyenne (Perfect, Good et quelques ratés) = environ 1 x ; tout raté = 0. ❓ à calibrer.
		Reward = {
			Scale = 0.8, -- ramène le gain moyen au cash de l'aide (le combo et les chaînes de Perfect le gonflent)
			Quality = { Perfect = 1, Good = 0.6, Miss = 0 },
			PerfectChainStep = 0.1, -- +10 % par Perfect d'affilée...
			PerfectChainMax = 0.5, -- ...jusqu'à +50 %
			Flawless = 1.25, -- aide entière jouée à la main sans aucun raté : x1,25 sur le total
		},
	},

	-- Maison et meubles
	Style = {
		ShopDistance = 14, -- achat uniquement près du magasin concerné ; l'équipement reste possible partout
	},
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

	-- Le Colisée du Pump (D89) : piliers de lumière entre le temple et le colisée, sécurité de la piste
	Colosseum = {
		PortalDistance = 12, -- distance max (studs) au portail pour l'utiliser
		PortalCooldown = 4, -- secondes entre deux voyages
		TravelDelay = 1.3, -- secondes de lumière avant d'arriver (la colonne monte, l'écran blanchit)
		-- Tourbillon doré dans l'arche des portails (D105) : bras de lumière en spirale qui tournent vers le centre
		Vortex = {
			Arms = 3, -- bras de la spirale
			Dots = 6, -- éclats de lumière par bras
			Spin = 1.6, -- radians par seconde
			Twist = 2.4, -- radians d'enroulement d'un bras, du bord au centre
			Pulse = 2.2, -- battements par seconde du cœur
			Range = 160, -- studs : au-delà, le tourbillon ne s'anime plus (téléphone)
		},
		PitCheckEvery = 1, -- secondes entre deux contrôles de la piste (un joueur qui n'y combat pas en ressort)
		CrowdBounce = 0.18, -- studs : la foule sautille
		CrowdSpeed = 3.2, -- sautillements par seconde
		FireRange = 220, -- studs : au-delà, les braseros sont éteints (téléphone)
		PitRadius = 44, -- rayon de la piste (= tools/blender/props_colosseum.py, LAYOUT.pit_radius)
		PitHeight = 9, -- hauteur du mur de la piste
	},

	-- Mur des Colosses (D107) : rayons dorés des yeux et sceptres qui pulsent (StatueWallController)
	StatueWall = {
		Range = 420, -- studs : au-delà, les effets du mur sont coupés (téléphone)
		EyeBeamLength = 46, -- studs : longueur des rayons sortant des yeux
		EyeBeamWidth = { 0.9, 7 }, -- largeur du rayon à l'œil, puis au bout
		EyeFlicker = 0.6, -- battements par seconde de l'intensité des rayons
		ScepterPulse = 0.8, -- battements par seconde de la lumière des sceptres
		ScepterLight = { Range = 22, Brightness = { 0.3, 1 } }, -- lumière autour du sceptre (réduite à la demande d'Antoine)
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
		ChampionScale = 1.8, -- statues dorées du Panthéon du Colisée (vainqueurs du Dieu du Pump)
		Gold = Color3.fromRGB(255, 196, 64),
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
		-- Le boss joue en direct ; à égalité parfaite de points, la manche va au joueur (D88)
		-- Défaite automatique (Mog insuffisant) : perte de Cash, annoncée avant le combat
		DefeatCashLossPercent = 0.10,
		ChallengeCooldown = 2, -- secondes entre deux défis (un double appui ne fait pas perdre deux fois)
		DefeatCashLossCap = { 50, 120, 300, 600, 1_200, 2_500 }, -- par stade du joueur ❓
		-- Mog-off perdu (avec assez de Mog) : perte plus faible, annoncée aussi ❓
		MogOffLossPercent = 0.05,
		MogOffLossCap = { 20, 50, 120, 250, 500, 1_000 },
		PauseBetweenRounds = 3, -- secondes entre deux manches (annonce de la manche suivante)
		VictoryLaunchDelay = 3.2, -- le boss vaincu s'envole après la fin du duel (BossFights.FinishTime, D85)
		IntroTime = 6, -- secondes de présentation avant la 1re manche (écran VS ~2,5 s, puis 3-2-1-MOG!)
		MeetDistance = 24, -- studs : la première fois qu'on s'approche d'un boss, il est présenté (cinématique)
	},

	-- Boutique de boosts (camion à shakes, distributeur)
	BoostShop = {
		Distance = 14, -- distance max (studs) au comptoir pour acheter
		MaxDuration = 900, -- un boost prolongé ne dépasse jamais 15 minutes
		MinExtension = 0.5, -- refusé (sans payer) si l'achat ajouterait moins de cette part de sa durée
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
		-- Croissance continue (D60) : pendant un stade, le corps va vers celui du stade suivant (pièces et squelette).
		-- MaxScale ne sert plus qu'au dernier stade : +X % d'épaisseur quand la progression est complète.
		MaxScale = 0.22,
		-- Le squelette n'est redimensionné que si la progression a bougé d'au moins ce pas (évite de le recalculer à
		-- chaque petite répétition)
		SkeletonStep = 0.01,
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
		PumpPerRep = { Perfect = 0.035, Good = 0.025, Miss = 0.01 },
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
