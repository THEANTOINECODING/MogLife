-- Liste des exercices. Voir design/02_MECANIQUES/MINIJEUX.md.
-- minigame : nom du module dans src/client/Minigames/
-- repInterval : durée d'une répétition (secondes), aussi la cadence max acceptée par le serveur
-- requiredStage : index dans Stages.List
-- Une station dans le monde = une Part avec le tag "Station" et l'attribut ExerciseId.

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
		minigame = "Ring", -- pas encore implémenté (étape B)
		mogPerRep = 2,
		repInterval = 1.0,
		requiredStage = 2,
	},
	BenchPress = {
		minigame = "HoldRelease", -- pas encore implémenté (étape B)
		mogPerRep = 4,
		repInterval = 1.4,
		requiredStage = 3,
	},
	Squat = {
		minigame = "Balance", -- pas encore implémenté (étape B)
		mogPerRep = 8,
		repInterval = 1.5,
		requiredStage = 4,
	},
}

return Exercises
