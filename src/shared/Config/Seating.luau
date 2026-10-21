-- Sièges automatiques : le joueur s'assoit tout seul en montant sur un banc, un canapé ou un fauteuil (SeatService).
-- Clé = nom du décor (le préfixe « Furniture_ » est ignoré : même meuble en vitrine et chez soi).
-- seats : nombre de places côte à côte. La hauteur et la profondeur de l'assise sont mesurées sur le modèle.
-- Tous les modèles ont l'avant vers -Z (local), le dossier vers +Z.

return {
	Props = {
		Bench = { seats = 2 }, -- bancs du parc
		SaggyCouch = { seats = 2 }, -- canapé défoncé du garage
		LeopardSofa = { seats = 2 },
		BenchSofa = { seats = 3 }, -- banquette d'attente du coiffeur
		ThroneSofa = { seats = 1 },
		BarberChair = { seats = 1 },
	},
	SeatSize = Vector3.new(1.8, 0.4, 1.6),
	-- Pendant une activité, un combat ou un duel, et ce nombre de secondes après, un siège n'assoit pas le joueur
	-- (il se retrouvait assis sur le canapé de Kevin à la fin du combat, sans pouvoir marcher)
	BusyGrace = 6,
}
