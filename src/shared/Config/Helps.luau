-- Aides en ville : chaque aide réutilise un mini-jeu et rapporte du Cash. Voir design/02_MECANIQUES/AIDES.md.
-- requiredStage : index dans Stages.List (seuil, le Mog n'est jamais dépensé)
-- cash : récompense par aide réussie ❓ valeurs de départ
-- Un emplacement dans le monde = une Part avec le tag "HelperSpot" et l'attribut HelpId.

export type Help = {
	npc: string, -- apparence (Npcs.luau) et nom (Texts "Npc.<npc>")
	minigame: string,
	interval: number,
	requiredStage: number,
	cash: number,
}

local Helps: { [string]: Help } = {
	OpenJar = { npc = "Mom", minigame = "Ring", interval = 1.0, requiredStage = 1, cash = 5 },
	PumpTire = { npc = "Courier", minigame = "Swipe", interval = 1.3, requiredStage = 1, cash = 8 },
	Nails = { npc = "Kid", minigame = "Ring", interval = 1.0, requiredStage = 2, cash = 15 },
	PushCar = { npc = "Neighbor", minigame = "HoldRelease", interval = 1.4, requiredStage = 3, cash = 30 },
	Piano = { npc = "MrsDoRe", minigame = "Tilt", interval = 1.5, requiredStage = 3, cash = 50 },
}

return Helps
