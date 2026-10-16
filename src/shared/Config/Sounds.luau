-- Sons du jeu (étape 7). Identifiants d'audio Roblox : "rbxassetid://123…".
-- Choisis par Claude le 16/10 (à la demande du créateur, qui signalera en jouant ceux qui ne conviennent pas) parmi
-- design/SONS_CANDIDATS.md : musique et jingles de la bibliothèque APM (sous licence Roblox), effets courts publics.
-- Tous vérifiés dans Studio (chargés, durée adaptée). Pour changer un son : coller ici son identifiant, Rojo synchronise.
-- Un identifiant vide = pas de son.

return {
	-- Musiques d'ambiance (D54) : chaque ambiance est une liste jouée à la suite (moins de lassitude qu'une seule
	-- boucle). APM (sous licence Roblox) ou Distrokid (mis à disposition des créateurs), vérifié dans Studio.
	Music = {
		-- En ville : choisie par le créateur le 16/10 parmi 31 propositions (D54)
		Town = {
			"rbxassetid://74451963781528", -- « Groove in Motion » (Distrokid) : groove léger, 4 min 53 en boucle
		},
		-- Pendant un exercice ou une aide : plus entraînante
		Workout = {
			"rbxassetid://1848365782", -- « Fighting Fit (b) », 2 min 51
		},
		-- Combat de boss (et sa présentation) : la plus intense
		Boss = {
			"rbxassetid://1837046455", -- « Fight For The Win », 2 min 48
			"rbxassetid://1837049200", -- « Title Shot », 2 min 34
		},
	},
	-- Effets
	Sfx = {
		RepPerfect = "rbxassetid://18448089848", -- répétition parfaite (le plus satisfaisant : « ding » + petit gonflement)
		RepGood = "rbxassetid://140323850218372", -- répétition réussie
		RepMiss = "rbxassetid://109359226723492", -- répétition ratée (comique : « pfff », couinement)
		SeriesEnd = "rbxassetid://9045129322", -- fin de série
		HelpDone = "rbxassetid://134810204798705", -- aide réussie (cha-ching du Cash)
		Purchase = "rbxassetid://134810204798705", -- achat à la boutique
		StageUp = "rbxassetid://9042409054", -- transformation : nouveau corps (fanfare courte)
		BossVictory = "rbxassetid://1836860398", -- Mog-off gagné
		BossDefeat = "rbxassetid://190705984", -- Mog-off perdu (trombone triste)
		MentorSay = "rbxassetid://72467819049463", -- le mentor parle (petit « hmm » mystérieux)
	},
	Volume = {
		-- Volume de chaque ambiance (la ville reste discrète, les combats passent devant)
		Music = { Town = 0.14, Workout = 0.28, Boss = 0.34 },
		Sfx = 0.6,
		Duck = 0.3, -- part du volume de la musique gardée pendant un jingle (transformation, victoire, défaite)
	},
	Timing = {
		Fade = 1.2, -- secondes de fondu entre deux ambiances
		WorkoutGrace = 8, -- secondes de musique d'entraînement gardées après une série (enchaîner sans couper)
		BossIntro = 5.5, -- secondes de musique de boss pendant sa présentation (cinématique)
		Duck = 3, -- secondes pendant lesquelles la musique est baissée pour un jingle
		TrackGap = 2, -- secondes de silence entre deux morceaux de la ville
	},
}
