-- Sons du jeu (étape 7, D54). Identifiants d'audio Roblox : "rbxassetid://123…". Un identifiant vide = pas de son.
-- Musique : bibliothèque APM (sous licence Roblox) ou Distrokid (mis à disposition des créateurs).
-- Volumes (16/10) : les fichiers n'ont pas du tout le même niveau (la musique de la ville est ~10 fois plus faible que
-- celle des boss). Chaque son a donc son propre volume, calculé à partir de son niveau mesuré dans Studio
-- (PlaybackLoudness à volume 1 : « moy » = moyenne, « crête » = maximum ; volume = cible / niveau).
-- Musiques réglées sur leur moyenne (~14 à 16, en fond). Effets réglés sur leur crête, car un son court s'entend
-- surtout à son pic : répétitions ~20 (à chaque mouvement), mentor ~18, récompenses ~38, jingles ~42.
-- (Le créateur trouvait les jingles de boss et les sons de combat trop forts avec un réglage sur la moyenne.)

return {
	-- Musiques d'ambiance : chaque ambiance est une liste jouée à la suite
	Music = {
		-- En ville : choisie par le créateur le 16/10 parmi 31 propositions
		Town = {
			{ id = "rbxassetid://74451963781528", volume = 0.7 }, -- « Groove in Motion », 4 min 53, moy 20, crête 36
		},
		-- Pendant un exercice ou une aide : un peu plus entraînante, mais douce
		Workout = {
			{ id = "rbxassetid://1840383344", volume = 0.16 }, -- « Positive Attitude (A) » (APM), 2 min 56, moy 92, crête 233
		},
		-- Combat de boss (et sa présentation) : la plus intense, sans être agressive
		Boss = {
			{ id = "rbxassetid://1837046455", volume = 0.075 }, -- « Fight For The Win » (APM), 2 min 48, moy 207, crête 373
			{ id = "rbxassetid://1837049200", volume = 0.065 }, -- « Title Shot » (APM), 2 min 34, moy 237, crête 502
		},
	},
	-- Effets
	Sfx = {
		-- Deux couches courtes pour sentir le contact et l'impact, avant la note serveur.
		SceneTouch = { id = "rbxassetid://140323850218372", volume = 0.12 },
		SceneImpact = { id = "rbxassetid://18448089848", volume = 0.28 },
		-- Couches d'impact des combats de boss (D126, Config/Feel.luau) : sons déjà vérifiés ci-dessous (Pro Sound
		-- Effects), ❓ volumes de départ à régler à l'oreille
		HitPunch = { id = "rbxassetid://9113573976", volume = 0.22, pitch = 1.15 }, -- le coup du joueur porte
		HitBoom = { id = "rbxassetid://9118628772", volume = 0.16, pitch = 1.35 }, -- grave d'un Perfect
		BossPunch = { id = "rbxassetid://9113573976", volume = 0.3, pitch = 0.72 }, -- le boss touche le joueur
		HitWhiff = { id = "rbxassetid://9120718279", volume = 0.1, pitch = 1.4 }, -- le boss rate (souffle)
		-- Répétitions (à chaque mouvement) : discrètes
		RepPerfect = { id = "rbxassetid://18448089848", volume = 0.4 }, -- « ding » + gonflement, crête 55
		RepGood = { id = "rbxassetid://140323850218372", volume = 0.34 }, -- répétition réussie, crête 64
		RepMiss = { id = "rbxassetid://109359226723492", volume = 0.14 }, -- ratée (« pfff » comique), crête 145
		-- Toucher d'une case du menu (D124) : le son de répétition réussie, plus aigu et très bas (❓ à régler à l'oreille)
		UiTap = { id = "rbxassetid://140323850218372", volume = 0.12, steady = true, pitch = 1.35 },
		MentorSay = { id = "rbxassetid://72467819049463", volume = 0.34, steady = true }, -- le mentor parle (« hmm »), crête 53
		-- Récompenses : nettes
		SeriesEnd = { id = "rbxassetid://9045129322", volume = 0.11, steady = true }, -- fin de série, crête 336
		HelpDone = { id = "rbxassetid://134810204798705", volume = 0.3 }, -- aide réussie (cha-ching), crête 125
		Purchase = { id = "rbxassetid://134810204798705", volume = 0.3 }, -- achat à la boutique, crête 125
		-- Jingles : les plus forts (la musique baisse en même temps)
		StageUp = { id = "rbxassetid://9042409054", volume = 0.2, steady = true }, -- transformation (fanfare), crête 218
		BossVictory = { id = "rbxassetid://1836860398", volume = 0.078, steady = true }, -- Mog-off gagné, crête 542
		BossDefeat = { id = "rbxassetid://190705984", volume = 0.1, steady = true }, -- Mog-off perdu (trombone triste), crête 402
		-- Combat du Dieu du Pump au Colisée (D93). Sons de la boutique Roblox (gratuits, vérifiés dans Studio : ils se
		-- chargent). Volumes de départ à régler à l'oreille (❓) : pas encore mesurés avec PlaybackLoudness.
		PumpGodWarn = { id = "rbxassetid://9117060349", volume = 0.12 }, -- nouvelle zone (bip court, Pro Sound Effects)
		PumpGodBolt = { id = "rbxassetid://72827145254925", volume = 0.25 }, -- éclair (« thunder crack »)
		PumpGodStorm = { id = "rbxassetid://9126099928", volume = 0.3 }, -- orage de la manche 3 (Pro Sound Effects)
		PumpGodSlam = { id = "rbxassetid://9118628772", volume = 0.5 }, -- coup au sol, chute (Pro Sound Effects)
		PumpGodWhoosh = { id = "rbxassetid://9120718279", volume = 0.3 }, -- javelot, saut, regard (Pro Sound Effects)
		PumpGodRoll = { id = "rbxassetid://9126283592", volume = 0.25 }, -- roulade (Pro Sound Effects)
		PumpGodPunch = { id = "rbxassetid://9113573976", volume = 0.4 }, -- coup porté au dieu (Pro Sound Effects)
		PumpGodHurt = { id = "rbxassetid://9113573976", volume = 0.35, pitch = 0.7 }, -- le combattant est touché
		PumpGodCrowd = { id = "rbxassetid://7755719721", volume = 0.25 }, -- la foule acclame
		-- Événements de ville (D100) : sons déjà vérifiés ci-dessus, réutilisés ❓ volumes à régler à l'oreille
		EventStart = { id = "rbxassetid://9042409054", volume = 0.14, pitch = 1.15 }, -- fanfare courte
		EventPickup = { id = "rbxassetid://134810204798705", volume = 0.3 }, -- haltère doré ramassé (cha-ching)
		EventMega = { id = "rbxassetid://9042409054", volume = 0.2 }, -- MÉGA haltère
		EventLand = { id = "rbxassetid://140323850218372", volume = 0.2, pitch = 0.8 }, -- un shake atterrit tout près
		EventDrink = { id = "rbxassetid://18448089848", volume = 0.35 }, -- shake bu
		EventTackle = { id = "rbxassetid://9113573976", volume = 0.35 }, -- plaquage du piano
		EventWhoosh = { id = "rbxassetid://9120718279", volume = 0.18 }, -- le piano détale
		EventCheer = { id = "rbxassetid://7755719721", volume = 0.22 }, -- piano arrêté : la foule acclame
		-- Repas de boost (D114), joués sur la tête de celui qui mange (les joueurs proches l'entendent). Chargement vérifié
		-- dans Studio ; ❓ volumes de départ, pas encore écoutés ni mesurés (PlaybackLoudness).
		SnackBite = { id = "rbxassetid://137096768206416", volume = 0.45 }, -- croc croustillant (aliment solide)
		SnackGulp = { id = "rbxassetid://9114171849", volume = 0.4 }, -- grosse gorgée (Pro Sound Effects, boissons)
		SnackPower = { id = "rbxassetid://9116394545", volume = 0.3 }, -- scintillement magique : le boost démarre (PSE)
	},
	Volume = {
		Music = 1, -- volume général de la musique (multiplie celui de chaque morceau)
		Sfx = 1, -- volume général des effets
		Duck = 0.35, -- part du volume de la musique gardée pendant un jingle
	},
	-- Variation aléatoire de chaque effet (± part de la hauteur et du volume), sauf les sons marqués steady (D126)
	Jitter = { Pitch = 0.05, Volume = 0.1 },
	-- Les répétitions réussies d'affilée jouent un peu plus aigu (on entend le combo monter), sans devenir criardes
	ComboPitch = { Step = 0.02, MaxStreak = 15 },
	Timing = {
		Fade = 1.6, -- secondes de fondu entre deux ambiances
		WorkoutGrace = 8, -- secondes de musique d'entraînement gardées après une série (enchaîner sans couper)
		BossIntro = 5.5, -- secondes de musique de boss pendant sa présentation (cinématique)
		Duck = 3.5, -- secondes pendant lesquelles la musique est baissée pour un jingle
		TrackGap = 2, -- secondes de silence entre deux morceaux d'une même ambiance
	},
}
