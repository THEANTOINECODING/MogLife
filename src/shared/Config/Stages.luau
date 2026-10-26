-- Stades et boss. Voir design/02_MECANIQUES/BOSS.md.
-- Le joueur est au stade List[data.Stage]. Battre le boss de ce stade fait passer au suivant.
-- mogRequired : Mog nécessaire pour défier le boss sans défaite automatique.
-- minigame / interval : le mini-jeu PROPRE à ce boss (src/client/Minigames/), jamais utilisé ailleurs.
-- skill : comment le boss joue en direct (probabilité de Perfect et de Good à chaque répétition).
-- firstWinCash / styleReward : récompenses de la première victoire.
-- comingSoon : boss annoncé mais pas encore présent dans le jeu (prochaine mise à jour).
-- ❓ Toutes les valeurs sont des hypothèses de départ (voir tools/simulate_economy.luau).

export type Boss = {
	id: string,
	mogRequired: number,
	minigame: string,
	interval: number,
	skill: { perfect: number, good: number },
	firstWinCash: number,
	styleReward: string?,
	comingSoon: boolean?,
}

export type Stage = {
	id: string,
	boss: Boss?,
}

local List: { Stage } = {
	{
		id = "Normie",
		boss = {
			id = "Kevin",
			mogRequired = 50,
			minigame = "Reaction",
			interval = 1.4,
			skill = { perfect = 0.1, good = 0.45 },
			firstWinCash = 20,
			styleReward = "PajamaTop",
		},
	},
	{
		id = "GymRat",
		boss = {
			id = "Brayan",
			mogRequired = 400,
			minigame = "Spotlight",
			interval = 1.5,
			skill = { perfect = 0.18, good = 0.5 },
			firstWinCash = 50,
			styleReward = "BronzeMedal",
		},
	},
	{
		id = "Bro",
		boss = {
			id = "CoachTurbo",
			mogRequired = 2_500,
			minigame = "Beats",
			interval = 0.9,
			skill = { perfect = 0.25, good = 0.5 },
			firstWinCash = 100,
			styleReward = "CoachWhistle",
		},
	},
	{
		id = "Alpha",
		boss = {
			id = "NoLegs",
			mogRequired = 7_500,
			minigame = "Wobble",
			interval = 1.5,
			skill = { perfect = 0.25, good = 0.5 }, -- ~65 points par répétition (D82 : un peu plus facile)
			firstWinCash = 200,
			styleReward = "TinySocks",
		},
	},
	{
		id = "Chad",
		boss = {
			id = "BlockKing",
			mogRequired = 20_000,
			minigame = "Combo",
			interval = 2.6,
			skill = { perfect = 0.32, good = 0.5 }, -- ~71 points par répétition (D82 : un peu plus facile)
			firstWinCash = 400,
			styleReward = "RoyalFan",
		},
	},
	{
		id = "Gigachad",
		boss = {
			id = "PumpGod",
			mogRequired = 45_000,
			minigame = "Combo",
			interval = 2.2,
			skill = { perfect = 0.55, good = 0.4 },
			firstWinCash = 800,
			comingSoon = true,
		},
	},
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
