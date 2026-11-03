-- Mesures de l'alpha (design/08_TESTS_ET_MESURES.md, D109) envoyées aux tableaux de bord Roblox (AnalyticsService).
-- Funnel : les étapes des premières minutes, dans l'ordre où un nouveau joueur les rencontre. Chacune n'est envoyée
-- qu'une fois par joueur (data.Funnel). Ne jamais renuméroter une étape publiée : Roblox perdrait la suite des
-- données ; ajouter les nouvelles à la fin.

return {
	Funnel = {
		{ step = 1, name = "Joined" },
		{ step = 2, name = "LookCreated" },
		{ step = 3, name = "FirstRep" },
		{ step = 4, name = "FirstHelp" },
		{ step = 5, name = "FirstStylePurchase" },
		{ step = 6, name = "FirstBossWin" },
		{ step = 7, name = "TutorialDone" },
		{ step = 8, name = "SecondStage" }, -- 2e boss battu (Brayan)
	},
}
