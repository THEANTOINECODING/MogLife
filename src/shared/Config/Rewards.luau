-- Récompenses et rendez-vous (D131, design/ANALYSE_JEU_2026-11-19.md, demande d'Antoine : « fais les rapides et les
-- moyennes ») : groupe Roblox, codes, nouveautés, invitation d'un ami, bonus entre amis, Golden Pump Hour, gain
-- pendant l'absence. ❓ Tous les montants sont des hypothèses de départ, à régler pendant l'alpha.

return {
	-- Rejoindre le groupe Roblox du jeu : titre exclusif + Cash, une seule fois. GroupId = 0 : bouton caché.
	-- ❓ Antoine : renseigner l'identifiant du groupe (Creator Hub > Communities).
	Group = {
		GroupId = 0,
		Cash = 500,
		Title = "GymFamily",
	},

	-- Codes (en majuscules) : une fois par joueur. Expires = os.time() de fin (0 = jamais).
	-- Rewards : Cash, et/ou un boost de Mog (multiplicateur, secondes de jeu) comme le boost Robux.
	Codes = {
		MOGLAUNCH = { Cash = 1_000, Expires = 0 },
		LEGDAY = { BoostMultiplier = 2, BoostSeconds = 10 * 60, Expires = 0 },
	},
	CodeMaxLength = 24,
	CodeCooldown = 2, -- secondes entre deux essais

	-- Nouveautés : la case « News » du menu porte une pastille tant que le joueur n'a pas vu cette version.
	-- Lines : clés de Texts.luau (News.Line.*), dans l'ordre. News.Line.Badges : à remettre quand les badges existeront.
	News = {
		Version = 1,
		Lines = { "News.Line.Codes", "News.Line.Friends", "News.Line.GoldenHour", "News.Line.Away" },
	},

	-- Un ami invité (Roblox : invitation ou lien de partage) fait sa première série : celui qui l'a invité, s'il est
	-- sur le serveur, reçoit ce Cash et le titre exclusif (une fois par ami invité).
	Referral = {
		Cash = 1_000,
		Title = "Recruiter",
	},

	-- Bonus d'équipe : +10 % de Mog des exercices par ami Roblox présent sur le serveur, plafonné à +30 %
	Friends = {
		BonusPerFriend = 0.1,
		MaxBonus = 0.3,
	},

	-- Golden Pump Hour : rendez-vous chaque semaine, Mog des exercices × Multiplier pour tout le serveur.
	-- WeekDay : 1 = dimanche … 7 = samedi ; Hour en UTC (18 h UTC = 19 h à Paris en hiver, 20 h en été).
	GoldenHour = {
		WeekDay = 7,
		Hour = 18,
		Duration = 60 * 60,
		Multiplier = 1.5,
		AnnounceBefore = 2 * 60 * 60, -- le compte à rebours s'affiche 2 h avant
	},

	-- Shaker de protéines : pendant l'absence, il produit du Cash (par heure, selon le stade), versé au retour.
	-- Rien n'est perdu à ne pas revenir : c'est plafonné, jamais retiré.
	Away = {
		MinSeconds = 15 * 60, -- absence minimale pour un versement
		MaxSeconds = 8 * 60 * 60, -- plafond (8 h)
		SaveEvery = 60, -- secondes entre deux enregistrements de l'heure de présence
		CashPerHourByStage = { 15, 30, 50, 80, 120, 160, 200 },
	},
}
