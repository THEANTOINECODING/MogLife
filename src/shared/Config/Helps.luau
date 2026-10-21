-- Aides en ville : chaque aide a son PROPRE mini-jeu et rapporte du Cash. Voir design/02_MECANIQUES/AIDES.md.
-- requiredStage : index dans Stages.List (seuil, le Mog n'est jamais dépensé)
-- reps : nombre de répétitions de l'aide (Balance.Helps.Reps par défaut)
-- ❓ cash : récompense par aide réussie, valeurs de départ
-- firstCash : récompense de la toute première réussite, si elle est différente (le bocal de Maman paie 25 la
-- première fois, pour qu'un nouveau joueur puisse s'offrir un premier look dans le tutoriel : décision D48)
-- Un emplacement dans le monde = une Part avec le tag "HelperSpot" et l'attribut HelpId.

export type Help = {
	npc: string, -- apparence (Npcs.luau) et nom (Texts "Npc.<npc>")
	minigame: string,
	interval: number,
	requiredStage: number,
	cash: number,
	firstCash: number?,
	reps: number?,
}

local Helps: { [string]: Help } = {
	OpenJar = {
		npc = "Mom",
		minigame = "PeelGood",
		reps = 1,
		interval = 2.1,
		requiredStage = 1,
		cash = 5,
		firstCash = 25,
	},
	PumpTire = { npc = "Courier", minigame = "AirwayExpress", reps = 1, interval = 2.2, requiredStage = 1, cash = 8 },
	Nails = { npc = "Kid", minigame = "ChopShop", reps = 1, interval = 1.6, requiredStage = 2, cash = 15 },
	PushCar = { npc = "Neighbor", minigame = "ParkingKnot", reps = 1, interval = 1.7, requiredStage = 3, cash = 30 },
	Piano = { npc = "MrsDoRe", minigame = "PianoPolish", reps = 1, interval = 1.6, requiredStage = 3, cash = 50 },
	BeachChairs = { npc = "Lifeguard", minigame = "TowelFold", reps = 1, interval = 1.7, requiredStage = 4, cash = 80 },
	Groceries = { npc = "Grocer", minigame = "ProduceParade", reps = 1, interval = 1.7, requiredStage = 5, cash = 120 },
	Directions = {
		npc = "Tourist",
		minigame = "ShortcutChalk",
		reps = 1,
		interval = 1.9,
		requiredStage = 6,
		cash = 180,
	},
}

return Helps
