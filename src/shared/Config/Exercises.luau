-- Liste des exercices. Pour en ajouter un : copier une entrée et changer les valeurs.
-- requiresEquipment = true : le joueur doit être près d'une Part taguée "Equipment"
-- avec l'attribut ExerciseId correspondant.

export type Exercise = {
	displayName: string,
	strengthPerRep: number,
	cashPerRep: number,
	requiredStrength: number,
	requiresEquipment: boolean,
}

local Exercises: { [string]: Exercise } = {
	Curl = {
		displayName = "Curl haltère",
		strengthPerRep = 1,
		cashPerRep = 1,
		requiredStrength = 0,
		requiresEquipment = false,
	},
	PushUp = {
		displayName = "Pompes",
		strengthPerRep = 3,
		cashPerRep = 2,
		requiredStrength = 100,
		requiresEquipment = false,
	},
	BenchPress = {
		displayName = "Développé couché",
		strengthPerRep = 10,
		cashPerRep = 5,
		requiredStrength = 1_000,
		requiresEquipment = true,
	},
	Squat = {
		displayName = "Squat",
		strengthPerRep = 35,
		cashPerRep = 15,
		requiredStrength = 10_000,
		requiresEquipment = true,
	},
}

return Exercises
