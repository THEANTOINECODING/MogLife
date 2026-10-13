-- Stades et boss. Voir design/02_MECANIQUES/BOSS.md.
-- Le joueur est au stade List[data.Stage]. Battre le boss de ce stade fait passer au suivant.
-- mogRequired : Mog nécessaire pour défier le boss sans défaite automatique.

export type Boss = {
	id: string,
	mogRequired: number,
}

export type Stage = {
	id: string,
	boss: Boss?,
}

local List: { Stage } = {
	{ id = "Normie", boss = { id = "Kevin", mogRequired = 50 } },
	{ id = "GymRat", boss = { id = "Brayan", mogRequired = 250 } },
	{ id = "Bro", boss = { id = "CoachTurbo", mogRequired = 800 } },
	{ id = "Alpha", boss = { id = "NoLegs", mogRequired = 2_500 } },
	{ id = "Chad", boss = { id = "BlockKing", mogRequired = 7_000 } },
	{ id = "Gigachad", boss = { id = "PumpGod", mogRequired = 15_000 } },
	{ id = "GodMogger" },
}

return {
	List = List,
}
