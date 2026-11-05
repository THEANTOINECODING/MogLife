-- Stades et boss. Voir design/02_MECANIQUES/BOSS.md.
-- Le joueur est au stade List[data.Stage]. Battre le boss de ce stade fait passer au suivant.
-- mogRequired : Mog nécessaire pour défier le boss sans défaite automatique.
-- minigame / interval : le mini-jeu PROPRE à ce boss (src/client/Minigames/), jamais utilisé ailleurs.
-- skill : comment le boss joue en direct (probabilité de Perfect et de Good à chaque répétition).
-- firstWinCash / styleReward : récompenses de la première victoire.
-- comingSoon : boss annoncé mais pas encore présent dans le jeu (prochaine mise à jour).
-- arena : pas de Mog-off ; le défi emmène au Colisée du Pump (PumpGodService, D94), d'où l'absence de
-- minigame / interval / skill (obligatoires pour tous les autres boss).
-- ❓ Toutes les valeurs sont des hypothèses de départ (voir tools/simulate_economy.luau).

export type Boss = {
	id: string,
	mogRequired: number,
	minigame: string?,
	interval: number?,
	skill: { perfect: number, good: number }?,
	firstWinCash: number,
	styleReward: string?,
	comingSoon: boolean?,
	arena: boolean?,
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
			mogRequired = 600,
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
			mogRequired = 3_800,
			minigame = "Beats",
			interval = 0.67, -- D110 : +35 % de vitesse (0,9 avant), notes et boss plus rapides
			skill = { perfect = 0.25, good = 0.5 },
			firstWinCash = 100,
			styleReward = "CoachWhistle",
		},
	},
	{
		id = "Alpha",
		boss = {
			id = "NoLegs",
			mogRequired = 13_000,
			minigame = "Trace", -- D110 : « Tracer la pose » remplace Wobble (trop proche du jeu de Kevin)
			interval = 2.2, -- une pose à tracer par répétition
			skill = { perfect = 0.38, good = 0.47 }, -- D110 : plus dur (« trop facile » ; 0,25 / 0,5 avant)
			firstWinCash = 200,
			styleReward = "TinySocks",
		},
	},
	{
		id = "Chad",
		boss = {
			id = "BlockKing",
			mogRequired = 36_000,
			minigame = "Combo",
			interval = 2.8,
			skill = { perfect = 0.2, good = 0.52 }, -- ~63 points par répétition (D87 : encore plus facile à battre)
			firstWinCash = 400,
			styleReward = "RoyalFan",
		},
	},
	{
		id = "Gigachad",
		boss = {
			id = "PumpGod",
			mogRequired = 85_000,
			firstWinCash = 800,
			arena = true,
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
