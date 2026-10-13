-- Stades et boss. Voir design/02_MECANIQUES/BOSS.md.
-- Le joueur est au stade List[data.Stage]. Battre le boss de ce stade fait passer au suivant.
-- mogRequired : Mog nécessaire pour défier le boss sans défaite automatique.
-- targetScore : score moyen (0–100) à dépasser dans une manche de Mog-off. ❓ valeurs de départ
-- firstWinCash / styleReward : récompenses de la première victoire. ❓ valeurs de départ

export type Boss = {
	id: string,
	mogRequired: number,
	targetScore: number,
	firstWinCash: number,
	styleReward: string?, -- id dans StyleItems.luau
}

export type Stage = {
	id: string,
	boss: Boss?,
}

local List: { Stage } = {
	{
		id = "Normie",
		boss = { id = "Kevin", mogRequired = 50, targetScore = 45, firstWinCash = 20, styleReward = "PajamaTop" },
	},
	{
		id = "GymRat",
		boss = { id = "Brayan", mogRequired = 250, targetScore = 58, firstWinCash = 50, styleReward = "BronzeMedal" },
	},
	{
		id = "Bro",
		boss = {
			id = "CoachTurbo",
			mogRequired = 800,
			targetScore = 68,
			firstWinCash = 100,
			styleReward = "CoachWhistle",
		},
	},
	{ id = "Alpha", boss = { id = "NoLegs", mogRequired = 2_500, targetScore = 74, firstWinCash = 200 } },
	{ id = "Chad", boss = { id = "BlockKing", mogRequired = 7_000, targetScore = 80, firstWinCash = 400 } },
	{ id = "Gigachad", boss = { id = "PumpGod", mogRequired = 15_000, targetScore = 86, firstWinCash = 800 } },
	{ id = "GodMogger" },
}

-- Retrouve un boss et l'index du stade qu'il garde
local function findBoss(bossId: string): (Boss?, number?)
	for index, stage in List do
		if stage.boss and stage.boss.id == bossId then
			return stage.boss, index
		end
	end
	return nil, nil
end

return {
	List = List,
	FindBoss = findBoss,
}
