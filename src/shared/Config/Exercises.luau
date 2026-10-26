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
		minigame = "Swipe",
		mogPerRep = 1,
		repInterval = 1.3,
		requiredStage = 1,
	},
	PushUp = {
		minigame = "Ring",
		mogPerRep = 2,
		repInterval = 1.0,
		requiredStage = 2,
	},
	BenchPress = {
		minigame = "HoldRelease",
		mogPerRep = 4,
		repInterval = 1.4,
		requiredStage = 3,
	},
	Squat = {
		minigame = "Tilt",
		mogPerRep = 8,
		repInterval = 1.5,
		requiredStage = 4,
	},
	PullUp = {
		minigame = "Alternate",
		mogPerRep = 14,
		repInterval = 1.2,
		requiredStage = 5,
	},
	JumpRope = {
		minigame = "Rope",
		mogPerRep = 24,
		repInterval = 1.0,
		requiredStage = 6,
	},
}

return Exercises
