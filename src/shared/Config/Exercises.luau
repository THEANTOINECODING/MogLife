-- Liste des exercices. Voir design/02_MECANIQUES/MINIJEUX.md.
-- Chaque exercice a son PROPRE mini-jeu (module dans src/client/Minigames/), jamais réutilisé ailleurs.
-- repInterval : durée d'une répétition (secondes), aussi le rythme moyen max accepté par le serveur
-- requiredStage : index dans Stages.List
-- Une station dans le monde = une Part avec le tag "Station" et l'attribut ExerciseId.
-- ❓ mogPerRep : hypothèses de départ (voir tools/simulate_economy.luau)

export type Exercise = {
	minigame: string,
	mogPerRep: number,
	repInterval: number,
	requiredStage: number,
}

local Exercises: { [string]: Exercise } = {
	Curl = {
		minigame = "ScrapPress",
		mogPerRep = 20.0000,
		repInterval = 26,
		requiredStage = 1,
	},
	PushUp = {
		minigame = "TireDomino",
		mogPerRep = 52.0000,
		repInterval = 26,
		requiredStage = 2,
	},
	BenchPress = {
		minigame = "MagnetHaul",
		mogPerRep = 74.2857,
		repInterval = 26,
		requiredStage = 3,
	},
	Squat = {
		minigame = "SwingKing",
		mogPerRep = 138.6667,
		repInterval = 26,
		requiredStage = 4,
	},
	PullUp = {
		minigame = "RopeRave",
		mogPerRep = 303.3333,
		repInterval = 26,
		requiredStage = 5,
	},
	JumpRope = {
		minigame = "AtlasStack",
		mogPerRep = 624.0000,
		repInterval = 26,
		requiredStage = 6,
	},
}

return Exercises
