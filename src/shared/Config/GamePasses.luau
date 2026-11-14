-- Game Passes (achats en Robux) : identifiants créés par Antoine sur le tableau de bord Roblox (Créations > le jeu >
-- Monétisation > Passes). Tant qu'un identifiant vaut 0, l'objet correspondant reste caché dans le jeu.
-- Tenues Robux (D121, divergence assumée avec D15 : elles donnent le Drip maximal, voir design/DECISIONS.md).

-- Prix conseillés en commentaire (D129, design/06_MONETISATION.md) : le prix réel est celui du Creator Hub, le jeu le lit
-- sur Roblox.

return {
	-- Ensemble (StyleSets, id) -> identifiant du Game Pass
	StyleSets = {
		CosmicEmperor = 0, -- 599 R$
		GoldenTitan = 0, -- 599 R$
		NeonPhantom = 0, -- 299 R$
		GymDragon = 0, -- 499 R$ (D122)
		EternalSun = 0, -- 399 R$
		MechaMogger = 0, -- 399 R$
		MarbleStatue = 0, -- 299 R$
		InfernalDemon = 0, -- 499 R$
	},
}
