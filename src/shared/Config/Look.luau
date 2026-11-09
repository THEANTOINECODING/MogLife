-- Création de personnage (D55) : choix proposés dans le menu de création (et au miroir de la maison).
-- Les identifiants sont sauvegardés (data.Look) : ne pas renommer un identifiant existant, sinon le joueur
-- retombe sur la valeur par défaut. On peut ajouter, réordonner ou changer les couleurs librement.
-- Les coupes de départ sont des objets de style gratuits (StyleItems, starter = true).
-- La taille n'est PAS au choix (décision du créateur) : elle vient du stade.

export type Swatch = { id: string, color: Color3, fantasy: boolean? }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Look = {
	Genders = { "M", "F" },

	-- Peau : 10 teintes naturelles, de très claire à très foncée, puis 3 teintes fantaisie (gratuites)
	Skins = {
		{ id = "Porcelain", color = rgb(255, 226, 206) },
		{ id = "Ivory", color = rgb(246, 210, 182) },
		{ id = "Peach", color = rgb(238, 192, 156) },
		{ id = "Sand", color = rgb(224, 174, 132) },
		{ id = "Honey", color = rgb(206, 152, 106) },
		{ id = "Caramel", color = rgb(184, 126, 84) },
		{ id = "Bronze", color = rgb(156, 100, 64) },
		{ id = "Mocha", color = rgb(124, 78, 50) },
		{ id = "Cocoa", color = rgb(96, 60, 40) },
		{ id = "Ebony", color = rgb(70, 45, 32) },
		{ id = "Lime", color = rgb(136, 204, 118), fantasy = true },
		{ id = "Ocean", color = rgb(112, 164, 224), fantasy = true },
		{ id = "Lavender", color = rgb(182, 144, 222), fantasy = true },
	},

	-- Cheveux (et barbes, sourcils) : 10 naturelles puis 6 fantaisie
	HairColors = {
		{ id = "Black", color = rgb(28, 22, 22) },
		{ id = "DarkBrown", color = rgb(64, 40, 26) },
		{ id = "Brown", color = rgb(112, 72, 42) },
		{ id = "Auburn", color = rgb(140, 62, 32) },
		{ id = "Ginger", color = rgb(204, 104, 42) },
		{ id = "DarkBlond", color = rgb(176, 136, 74) },
		{ id = "Blond", color = rgb(232, 192, 104) },
		{ id = "Platinum", color = rgb(242, 232, 204) },
		{ id = "Gray", color = rgb(150, 150, 154) },
		{ id = "White", color = rgb(240, 240, 240) },
		{ id = "Pink", color = rgb(255, 112, 172), fantasy = true },
		{ id = "Red", color = rgb(222, 42, 52), fantasy = true },
		{ id = "Blue", color = rgb(72, 132, 242), fantasy = true },
		{ id = "Teal", color = rgb(42, 192, 190), fantasy = true },
		{ id = "Green", color = rgb(92, 202, 102), fantasy = true },
		{ id = "Purple", color = rgb(152, 82, 222), fantasy = true },
	},

	-- Teintures (D106) : couleurs au choix, gratuites (identifiants de HairColors). D126 : toutes les couleurs, pour
	-- la coupe ET la barbe (la même pour la paire), au choix à tout moment dans le menu Style ; "" = couleur naturelle
	-- choisie à la création.
	HairDyes = {
		"Black",
		"DarkBrown",
		"Brown",
		"Auburn",
		"Ginger",
		"DarkBlond",
		"Blond",
		"Platinum",
		"Gray",
		"White",
		"Pink",
		"Red",
		"Blue",
		"Teal",
		"Green",
		"Purple",
	},

	-- D126 : la sous-couche des coupes et barbes (pièces _HairShade) est la couleur des cheveux assombrie de cette part
	HairShade = 0.4,

	EyeColors = {
		{ id = "Brown", color = rgb(112, 70, 40) },
		{ id = "Hazel", color = rgb(142, 112, 52) },
		{ id = "Green", color = rgb(72, 142, 72) },
		{ id = "Blue", color = rgb(62, 122, 212) },
		{ id = "Gray", color = rgb(132, 142, 152) },
		{ id = "Amber", color = rgb(212, 152, 42) },
	},

	-- Haut et short de départ (les objets de la boutique gardent leurs propres couleurs)
	ClothesColors = {
		{ id = "Gray", color = rgb(142, 146, 156) },
		{ id = "White", color = rgb(236, 236, 236) },
		{ id = "Black", color = rgb(36, 36, 42) },
		{ id = "Red", color = rgb(212, 56, 56) },
		{ id = "Orange", color = rgb(240, 132, 42) },
		{ id = "Yellow", color = rgb(240, 202, 52) },
		{ id = "Green", color = rgb(62, 152, 72) },
		{ id = "Teal", color = rgb(42, 160, 168) },
		{ id = "Blue", color = rgb(52, 92, 202) },
		{ id = "Navy", color = rgb(32, 42, 82) },
		{ id = "Purple", color = rgb(132, 72, 192) },
		{ id = "Pink", color = rgb(240, 122, 172) },
	},

	-- Expressions : bouche et sourcils du corps (pièces _Mouth<Id> et _Brow<Id>)
	Expressions = { "Confident", "Nervous", "Determined" },

	-- Coupes proposées à la création : "" = coupe de base du corps, puis les objets de style gratuits
	StarterHair = { "", "Curly", "LongHair", "Bun", "Bob" },

	-- Surnom de bro affiché au-dessus de la tête : prénom + titre (textes Nick.First.<id> et Nick.Title.<id>).
	-- Choisis dans une liste (pas de texte libre : pas de surnom inapproprié possible).
	NickFirst = {
		"Brad",
		"Kyle",
		"Tyler",
		"Derek",
		"Max",
		"Jake",
		"Bruce",
		"Rex",
		"Duke",
		"Leo",
		"Sam",
		"Alex",
		"Jordan",
		"Riley",
		"Brenda",
		"Becky",
		"Tina",
		"Jess",
		"Mia",
		"Zoe",
		"Lola",
		"Gina",
	},
	NickTitle = {
		"TheWall",
		"ProteinShake",
		"NoDaysOff",
		"Spaghetti",
		"LegDay",
		"MirrorSelfie",
		"PreWorkout",
		"BeastMode",
		"SixPack",
		"ThePump",
		"TankTop",
		"TheFlex",
		"RepCounter",
		"IronLung",
		"Gains",
		"Noodle",
	},
	-- Titres exclusifs (D67), débloqués par les trophées de la semaine (3 défis réussis la même semaine) ou par les
	-- victoires en duel (bras de fer, victoires récompensées seulement). Textes : Nick.Title.<id>.
	RewardTitles = {
		{ id = "WeeklyWarrior", trophies = 1 },
		{ id = "NeverSkips", trophies = 4 },
		{ id = "CalendarCrusher", trophies = 10 },
		{ id = "WristWrecker", duelWins = 5 },
		{ id = "IronGrip", duelWins = 25 },
		{ id = "Unmoggable", duelWins = 100 },
		{ id = "GodMogger", godWins = 1 }, -- vaincre le Dieu du Pump au Colisée (D93)
		-- Titres secrets (D121, Config/Secrets.luau) : cachés dans le menu tant que le secret n'est pas trouvé
		{ id = "GhostLifter", secret = "GhostLifter" },
		{ id = "StatueBeliever", secret = "StatueBeliever" },
		{ id = "SewerGains", secret = "SewerGains" },
		{ id = "NeverForget", secret = "NeverForget" },
	},

	Defaults = {
		Gender = "M",
		Skin = "Peach",
		Hair = "Brown",
		Eyes = "Brown",
		Top = "Gray",
		Shorts = "Blue",
		Expression = "Confident",
		First = "Brad",
		Title = "Spaghetti",
	},

	-- Aperçu « Voir mon futur moi » : le stade montré
	FutureStage = "GodMogger",
}

return Look
