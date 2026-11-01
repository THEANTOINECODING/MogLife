-- Combat du Dieu du Pump au Colisée (D89 à D92). Trois manches puis la finale : il attaque avec des zones à esquiver,
-- et le joueur le frappe de 4 façons avec le bouton FLEX (punir, renvoyer la foudre, lancer des disques, pose sacrée).
-- Chaque manche a sa propre jauge de vie du dieu ; la finale est un choc de rayons gagné en FLEX en rythme.
-- Les spectateurs l'encouragent depuis les gradins (Crowd). Tout ce qui touche se décide sur le serveur
-- (PumpGodService) ; les clients dessinent les zones à l'heure du serveur (PumpGodController).
-- Distances en studs, temps en secondes, dégâts en points de vie.

return {
	Health = 100, -- vie du joueur
	HitInvuln = 1.0, -- secondes d'invincibilité après un coup (pas deux coups d'un coup)
	Latency = 0.1, -- marge pour le retard d'affichage : la position est jugée un peu après l'impact
	-- Le saut et la roulade arrivent au serveur avec un peu de retard (ping) : un coup détecté n'est confirmé qu'après
	-- ce délai, et il est annulé si le joueur a sauté (onde, haltère) ou roulé entre-temps
	Grace = 0.25,
	DefeatMogShare = 0.03, -- part du Mog perdue en cas de défaite (choix d'Antoine, D89)

	-- Roulade : esquive rapide, invincible un court instant
	Roll = {
		Cooldown = 0.9,
		Invuln = 0.45, -- secondes d'invincibilité (comptées à la réception de la demande)
		Distance = 13, -- studs parcourus
		Time = 0.34, -- durée de la roulade
	},
	-- Saut : on évite une onde ou un haltère si les pieds sont au moins à cette hauteur au-dessus de la piste
	JumpClear = 1.6,

	-- Manches : vie du dieu, attaques (nom = poids du tirage), premières attaques dans l'ordre (chaque nouveauté
	-- apparaît une fois), pause entre deux attaques (elle raccourcit au fil de la manche), vie rendue au joueur au début
	Rounds = {
		{
			Title = "PumpGod.Round1", -- « L'échauffement divin »
			BossHealth = 100,
			Heal = 0,
			Opening = { "Bolts", "Javelin", "Dumbbell", "Slam", "Wave" },
			Attacks = { Bolts = 3, Dumbbell = 2, Wave = 2, Slam = 2, Javelin = 2 },
			Pause = { From = 2.0, To = 1.1, Over = 75 },
		},
		{
			Title = "PumpGod.Round2", -- « Les douze travaux »
			BossHealth = 110,
			Heal = 40,
			Opening = { "Columns", "Leap", "Tiles", "Chariot", "Javelin" },
			Attacks = { Columns = 3, Tiles = 2, Chariot = 2, Leap = 2, Javelin = 1 },
			Pause = { From = 1.7, To = 1.0, Over = 80 },
		},
		{
			Title = "PumpGod.Round3", -- « L'Olympe en colère »
			BossHealth = 100,
			Heal = 40,
			Giant = 2.2, -- il devient géant (taille du modèle) au bord de la piste
			Edge = 7, -- studs entre lui et le mur de la piste
			Opening = { "Gaze", "Storm", "Rings", "Javelin" },
			Attacks = { Storm = 2, Rings = 2, Gaze = 2, Javelin = 2, Bolts = 1 },
			Pause = { From = 1.6, To = 1.0, Over = 70 },
		},
	},
	Transition = 4.0, -- secondes entre deux manches (titre, le dieu se replace, rien n'attaque)
	-- Le dieu se déplace dans la piste entre ses attaques (cercle de ce rayon autour du centre ; pas quand il est géant)
	Orbit = { Radius = 22, MaxRadius = 30, MoveTime = 1.1 },
	Attacks = {
		-- Manche 1
		-- Foudre : trois éclairs, chacun sur le joueur au moment où il est annoncé
		Bolts = { Count = 3, Gap = 0.6, Warn = 1.0, Radius = 6.5, Damage = 18 },
		-- Haltère géant qui roule d'un bout à l'autre de la piste, en passant par le joueur : sortir de la bande ou sauter
		Dumbbell = { Warn = 1.3, Width = 7, Speed = 44, Height = 3.4, Damage = 24 },
		-- Onde de flexion : un anneau part du dieu et s'élargit jusqu'au mur ; sauter au moment où il passe
		Wave = { Warn = 1.1, Speed = 26, Thickness = 3, Damage = 20 },
		-- Coup de poing au sol : il fonce près du joueur et frappe en cône devant lui, puis il est essoufflé
		Slam = { Approach = 13, Warn = 1.1, Length = 26, Angle = 70, Damage = 26 },
		-- Javelot d'éclair : lancé droit sur le joueur ; FLEX quand il arrive près de lui pour le renvoyer
		Javelin = { Warn = 1.0, Speed = 42, Radius = 2.6, Damage = 20, Height = 3 },
		-- Manche 2
		-- Colonnes qui tombent du bord de la piste vers le joueur (bandes), l'une après l'autre ; la dernière se brise
		-- et laisse un disque doré
		Columns = { Count = 3, Gap = 0.7, Warn = 1.2, Length = 36, Width = 6, Damage = 22 },
		-- Dalles de mosaïque : un motif de cases s'allume puis jaillit, deux fois (le 2e motif est l'inverse du 1er)
		Tiles = { Cell = 11, Warn = 1.4, Gap = 0.5, Damage = 18 },
		-- Char de shake qui traverse la piste en passant par le joueur (trop haut pour être sauté : sortir de la bande)
		Chariot = { Warn = 1.3, Width = 10, Speed = 34, Height = 6, Damage = 24 },
		-- Il saute ; un grand cercle suit le joueur, se fige, et il retombe dessus ; ensuite il est essoufflé
		Leap = { Rise = 0.6, Follow = 1.6, Fall = 0.7, Radius = 9, Damage = 28 },
		-- Manche 3 (géant)
		-- Toute la piste s'allume sauf quelques cercles sûrs ; il frappe deux fois ; un disque tombe dans un cercle sûr
		Storm = { Count = 2, Safe = 3, SafeRadius = 6.5, Warn = 1.8, Gap = 0.6, Damage = 25 },
		-- Anneaux à sauter, l'un après l'autre, partis du géant
		Rings = { Count = 3, Gap = 0.9, Warn = 1.1, Speed = 30, Thickness = 3, Damage = 18 },
		-- Regard brûlant : un rayon balaie la piste depuis ses yeux ; se cacher derrière une colonne ; puis il se frotte
		-- les yeux (essoufflé)
		Gaze = { Warn = 1.3, Sweep = 3.2, Angle = 130, Width = 5, Damage = 20 },
	},
	-- Colonnes de la manche 3 (cachettes contre le regard) : nombre, distance au centre, rayon, hauteur
	Pillars = { Count = 5, Distance = 21, Radius = 2.6, Height = 16 },

	-- Façons de frapper le dieu (bouton FLEX)
	-- 1. Punir : après le coup de poing au sol (et le saut, le regard), il est essoufflé ; combo de 3 coups, le 3e en
	-- rythme = coup de Mog. Range : distance pour le frapper (GiantRange quand il est géant)
	Winded = { Time = 3.2, Range = 14, GiantRange = 22 },
	Punch = { Damage = 4, PowerDamage = 12, MinGap = 0.18, Reset = 1.3, BeatFrom = 0.4, BeatTo = 0.75 },
	-- 2. Renvoyer la foudre : FLEX quand le javelot est à moins de cette distance
	Parry = { Range = 10, Flight = 0.5, Damage = 12 },
	-- 3. Disques d'haltère dorés : tombent après la foudre et l'haltère ; FLEX pour ramasser, FLEX pour lancer
	Disc = { Max = 2, Life = 20, PickRange = 7, Flight = 0.6, Damage = 9 },
	-- 4. Pose sacrée : un cercle doré apparaît de temps en temps ; y rester en maintenant FLEX lance un rayon de Mog
	Sacred = { First = 14, Every = 18, Life = 8, Radius = 5, Charge = 2.0, Damage = 18 },

	-- Finale « Le dernier pose-off » : son éclair contre le rayon de Mog du joueur, qui ne bouge plus. Le point de
	-- choc part du milieu (0,5) ; FLEX sur le temps (Beat, fenêtre ±Window) le pousse vers le dieu de Push, à
	-- contretemps il recule de Miss ; le dieu pousse de Drift par seconde (de plus en plus fort, + DriftGrow par
	-- seconde). Choc jusqu'au dieu : victoire. Choc jusqu'au joueur : il prend Burn de dégâts et le choc repart de Reset.
	Finale = {
		Intro = 2.5,
		Beat = 0.6,
		Window = 0.16,
		Push = 0.04,
		Miss = 0.015,
		Drift = 0.02,
		DriftGrow = 0.0004,
		Burn = 30,
		Reset = 0.4,
	},

	-- Spectateurs : bouton « Encourager » dans les gradins (jamais pour le combattant, qui ne voit pas la jauge).
	-- Tous les Step encouragements, la foule agit, dans cet ordre, en boucle : amphore de shake (rend Heal de vie,
	-- ramassée en marchant dessus), pétales (le dieu attend Slow secondes de plus avant sa prochaine attaque), chant
	-- (le prochain renvoi de javelot se fait de ChantRange fois plus loin).
	Crowd = {
		Range = 140, -- studs du centre de la piste : au-delà, on ne peut pas encourager
		MinGap = 0.25, -- secondes entre deux encouragements d'un même spectateur
		Max = 60, -- encouragements comptés par spectateur et par combat
		Step = 20,
		Actions = { "Amphora", "Petals", "Chant" },
		Heal = 25,
		AmphoraLife = 12,
		AmphoraPick = 4.5,
		Slow = 1.0,
		ChantRange = 1.8,
	},

	-- Couronne de laurier des vainqueurs (D93), en fractions de la taille de la tête : rayon, hauteur au-dessus de son
	-- centre, taille des feuilles ; Gap = degrés laissés libres devant le front ; Tilt = inclinaison des feuilles
	Laurel = {
		Leaves = 16,
		Radius = 0.56,
		Height = 0.22,
		LeafWidth = 0.22,
		LeafHeight = 0.13,
		Gap = 22,
		Tilt = 25,
		Color = Color3.fromRGB(255, 200, 70),
		SpawnDelay = 3, -- secondes après l'apparition (le corps de stade est posé)
	},

	-- Caméra du combattant : de côté pendant la finale (recul et hauteur en fractions de la distance joueur-dieu) ;
	-- vers le ciel (la constellation) pendant VictoryLook secondes après la victoire
	Camera = { FinaleBack = 0.75, FinaleUp = 0.18, VictoryLook = 5.5 },
	-- Bouton FLEX (D95) : gris s'il ne fait rien, jaune qui gonfle et dégonfle quand une action est possible
	FlexButton = {
		Idle = Color3.fromRGB(105, 105, 115),
		IdleText = Color3.fromRGB(190, 190, 200),
		IdleStroke = Color3.fromRGB(200, 200, 210),
		Ready = Color3.fromRGB(255, 214, 40),
		ReadyText = Color3.fromRGB(45, 30, 5),
		ReadyStroke = Color3.fromRGB(255, 255, 210),
		Beat = Color3.fromRGB(255, 236, 120),
		Pulse = 0.09, -- grossit jusqu'à +9 %
		PulseSpeed = 7, -- radians par seconde (un peu plus d'un battement par seconde)
		BeatGrow = 0.16,
	},
	-- Le dieu frappable clignote en rouge ; un éclair blanc quand il prend un coup (contour Highlight)
	Glow = {
		Hittable = Color3.fromRGB(255, 40, 40),
		HittableFill = 0.55, -- transparence du remplissage au plus fort du clignotement
		BlinkSpeed = 9, -- radians par seconde
		Hurt = Color3.fromRGB(255, 255, 255),
		HurtTime = 0.18,
	},
	-- Caméra du combattant : petit à-coup de champ de vision quand il frappe le dieu
	HitCam = { Fov = 6, PowerFov = 11, Time = 0.25 },

	-- Le dieu dans l'arène
	BossScale = 1.0, -- taille du modèle (le Dieu du Pump fait déjà 13 studs de haut)
	BossHover = 0.6, -- il flotte un peu au-dessus de la piste
	EndDelay = 3.5, -- secondes entre la fin du combat et le retour (gradins ou temple)
	FighterInset = 8, -- le combattant démarre à cette distance de sa porte, vers le centre (caméra hors du tunnel)
}
