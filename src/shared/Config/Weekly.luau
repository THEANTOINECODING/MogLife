-- Récompenses de la semaine (D67, design/01_BOUCLES.md « Boucle de retour »). Semaine = lundi 00:00 → dimanche
-- 23:59 (UTC), la même pour tout le monde.
-- - Défis de la semaine : 3 défis (un par groupe), tirés au sort chaque lundi, identiques pour tous les joueurs.
--   Chaque défi réussi rapporte du Cash ; les 3 réussis donnent en plus un trophée hebdomadaire (titres exclusifs,
--   Config/Look.luau RewardTitles) et un bonus de Cash.
-- - Coffre de la semaine : chaque jour où l'on joue au moins MinutesForDay minutes coche une case (7 cases). Le
--   coffre s'ouvre le dimanche ; s'il n'a pas été ouvert, son contenu est versé à la connexion suivante.
-- Jamais de pénalité : une semaine sans jouer ne fait rien perdre, un défi réussi mais pas réclamé est versé la
-- semaine suivante. Les montants sont des hypothèses ❓ à régler pendant l'alpha.

return {
	-- Statistiques suivies par WeeklyService.Track (une clé = un compteur de la semaine)
	Pools = {
		-- Groupe 1 : s'entraîner
		{
			{ id = "PerfectReps", stat = "PerfectReps", target = 60 },
			{ id = "Series", stat = "SeriesDone", target = 12 },
			{ id = "GradeS", stat = "GradeS", target = 5 },
		},
		-- Groupe 2 : aider la ville
		{
			{ id = "Helps", stat = "HelpsDone", target = 10 },
			{ id = "FlawlessHelps", stat = "FlawlessHelps", target = 4 },
			{ id = "CityEvents", stat = "CityEvents", target = 3 },
		},
		-- Groupe 3 : se mesurer aux autres
		{
			{ id = "Duels", stat = "DuelsPlayed", target = 3 },
			{ id = "DuelWins", stat = "DuelsWon", target = 2 },
			{ id = "MogOffs", stat = "MogOffsWon", target = 2 },
			{ id = "Spots", stat = "SpotReps", target = 30 },
		},
	},

	-- Cash de chaque défi réussi, selon le stade du joueur au moment de réclamer ❓
	ChallengeCash = { 40, 80, 140, 240, 380, 560 },
	-- Bonus quand les 3 défis sont réclamés (en plus du trophée) ❓
	BonusCash = { 100, 200, 350, 600, 950, 1_400 },

	-- Coffre : Cash selon le nombre de jours cochés (1 à 7), multiplié par le stade ❓
	MinutesForDay = 3,
	ChestCash = { 15, 35, 60, 90, 125, 165, 210 },
	ChestStageScale = { 1, 1.6, 2.6, 4, 6, 8.5 },
	ChestDay = 7, -- jour d'ouverture (1 = lundi … 7 = dimanche)

	TickSeconds = 15, -- fréquence du suivi du temps de jeu et du changement de semaine
}
