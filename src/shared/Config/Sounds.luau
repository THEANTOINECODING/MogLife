-- Sons du jeu (étape 7, D54). Identifiants d'audio Roblox : "rbxassetid://123…". Un identifiant vide = pas de son.
-- Musique : bibliothèque APM (sous licence Roblox) ou Distrokid (mis à disposition des créateurs).
-- Volumes (16/10) : les fichiers n'ont pas du tout le même niveau (la musique de la ville est ~10 fois plus faible que
-- celle des boss). Chaque son a donc son propre volume, calculé à partir de son niveau mesuré dans Studio
-- (PlaybackLoudness moyen à volume 1, noté « niveau ») pour viser un niveau perçu cohérent :
--   musique ~14 à 20 (fond), répétitions ~16 à 20 (très fréquentes, discrètes), récompenses ~30, jingles ~40.
-- Pour remplacer un son : coller son identifiant, mesurer son niveau, et ajuster le volume (cible / niveau).

return {
	-- Musiques d'ambiance : chaque ambiance est une liste jouée à la suite
	Music = {
		-- En ville : choisie par le créateur le 16/10 parmi 31 propositions
		Town = {
			{ id = "rbxassetid://74451963781528", volume = 0.7 }, -- « Groove in Motion », 4 min 53, niveau 20
		},
		-- Pendant un exercice ou une aide : un peu plus entraînante, mais douce
		Workout = {
			{ id = "rbxassetid://1840383344", volume = 0.19 }, -- « Positive Attitude (A) » (APM), 2 min 56, niveau 92
		},
		-- Combat de boss (et sa présentation) : la plus intense, sans être agressive
		Boss = {
			{ id = "rbxassetid://1837046455", volume = 0.1 }, -- « Fight For The Win » (APM), 2 min 48, niveau 207
			{ id = "rbxassetid://1837049200", volume = 0.09 }, -- « Title Shot » (APM), 2 min 34, niveau 237
		},
	},
	-- Effets
	Sfx = {
		-- Répétitions (à chaque mouvement) : discrètes
		RepPerfect = { id = "rbxassetid://18448089848", volume = 0.9 }, -- « ding » + gonflement, niveau 21
		RepGood = { id = "rbxassetid://140323850218372", volume = 0.65 }, -- répétition réussie, niveau 27
		RepMiss = { id = "rbxassetid://109359226723492", volume = 0.3 }, -- ratée (« pfff » comique), niveau 50
		MentorSay = { id = "rbxassetid://72467819049463", volume = 0.38 }, -- le mentor parle (« hmm »), niveau 40
		-- Récompenses : nettes
		SeriesEnd = { id = "rbxassetid://9045129322", volume = 0.23 }, -- fin de série, niveau 128
		HelpDone = { id = "rbxassetid://134810204798705", volume = 0.8 }, -- aide réussie (cha-ching), niveau 36
		Purchase = { id = "rbxassetid://134810204798705", volume = 0.8 }, -- achat à la boutique, niveau 36
		-- Jingles : les plus forts (la musique baisse en même temps)
		StageUp = { id = "rbxassetid://9042409054", volume = 0.29 }, -- transformation (fanfare), niveau 139
		BossVictory = { id = "rbxassetid://1836860398", volume = 0.15 }, -- Mog-off gagné, niveau 274
		BossDefeat = { id = "rbxassetid://190705984", volume = 0.22 }, -- Mog-off perdu (trombone triste), niveau 158
	},
	Volume = {
		Music = 1, -- volume général de la musique (multiplie celui de chaque morceau)
		Sfx = 1, -- volume général des effets
		Duck = 0.4, -- part du volume de la musique gardée pendant un jingle
	},
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
