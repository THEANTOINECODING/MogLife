-- Color-only, low-poly presentation; gameplay geometry stays in the shared rules.
local themes = {
	Workshop = {
		accent = Color3.fromRGB(255, 180, 91),
		sky = Color3.fromRGB(42, 34, 62),
		floor = Color3.fromRGB(63, 54, 78),
	},
	Gym = {
		accent = Color3.fromRGB(173, 156, 255),
		sky = Color3.fromRGB(33, 26, 63),
		floor = Color3.fromRGB(56, 43, 88),
	},
	Home = {
		accent = Color3.fromRGB(130, 232, 194),
		sky = Color3.fromRGB(27, 53, 64),
		floor = Color3.fromRGB(43, 79, 82),
	},
	Beach = {
		accent = Color3.fromRGB(255, 210, 111),
		sky = Color3.fromRGB(31, 89, 108),
		floor = Color3.fromRGB(216, 183, 127),
	},
	Royal = {
		accent = Color3.fromRGB(255, 215, 106),
		sky = Color3.fromRGB(47, 29, 76),
		floor = Color3.fromRGB(75, 51, 103),
	},
}
local groups = {
	ScrapPress = "Workshop",
	TireDomino = "Workshop",
	MagnetHaul = "Workshop",
	SwingKing = "Gym",
	RopeRave = "Gym",
	AtlasStack = "Royal",
	PeelGood = "Home",
	AirwayExpress = "Workshop",
	ChopShop = "Workshop",
	ParkingKnot = "Workshop",
	PianoPolish = "Home",
	TowelFold = "Beach",
	ProduceParade = "Home",
	ShortcutChalk = "Beach",
	SnackVolley = "Home",
	SunbedSlalom = "Beach",
	TreadmillTakeover = "Gym",
	LegDayLandgrab = "Gym",
	CrownSneak = "Royal",
	GravityGauntlet = "Royal",
	ReadRip = "Gym",
}
return { Themes = themes, Groups = groups }
