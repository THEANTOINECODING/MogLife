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
	OpenJar = { npc = "Mom", minigame = "Twist", interval = 1.6, requiredStage = 1, cash = 5, firstCash = 25, reps = 8 },
	PumpTire = { npc = "Courier", minigame = "Pressure", interval = 1.2, requiredStage = 1, cash = 8 },
	Nails = { npc = "Kid", minigame = "Hammer", interval = 1.4, requiredStage = 2, cash = 15 },
	PushCar = { npc = "Neighbor", minigame = "Steer", interval = 1.0, requiredStage = 3, cash = 30 },
	Piano = { npc = "MrsDoRe", minigame = "Lanes", interval = 1.1, requiredStage = 3, cash = 50 },
	BeachChairs = { npc = "Lifeguard", minigame = "Stack", interval = 1.4, requiredStage = 4, cash = 80 },
	Groceries = { npc = "Grocer", minigame = "Catch", interval = 1.1, requiredStage = 5, cash = 120 },
	Directions = { npc = "Tourist", minigame = "Sequence", interval = 3.5, requiredStage = 6, cash = 180, reps = 6 },
}

return Helps
