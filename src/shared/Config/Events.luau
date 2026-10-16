-- Événements de ville (validés le 16/10) : toutes les 9 à 12 minutes environ, un événement pour tout le serveur,
-- annoncé à l'écran. Rien n'est obligatoire : c'est un bonus pour ceux qui sont là. ❓ Récompenses à calibrer.
-- - GoldenDumbbells : des haltères dorés apparaissent dans la ville ; le premier qui en touche un le ramasse.
-- - FreeShakes : un distributeur de shakes gratuits sur la place (un boost par joueur et par événement).
-- - RunawayPiano : un piano dévale la place ; le premier qui l'arrête gagne une récompense.
-- Cash selon le stade du joueur (index dans Stages.List), pour rester intéressant du début à la fin.

return {
	FirstDelay = 240, -- secondes avant le premier événement d'un serveur
	Interval = { 540, 720 }, -- secondes entre deux événements (au hasard dans cet intervalle)
	Center = Vector3.new(0, 0, 0), -- centre de la ville (la place et sa fontaine)

	GoldenDumbbells = {
		Count = 8,
		Duration = 90,
		Radius = 110, -- studs autour du centre où ils peuvent apparaître (au sol, en plein air)
		CashByStage = { 6, 12, 25, 45, 75, 120, 170 },
		Model = "Furniture_GoldenDumbbell", -- ServerStorage.Props
	},
	FreeShakes = {
		Duration = 60,
		Boost = "ProteinShake",
		Offset = Vector3.new(12, 0, 14), -- position du distributeur par rapport au centre
		Model = "ShakeVendingMachine",
	},
	RunawayPiano = {
		Duration = 45,
		From = Vector3.new(-50, 0, -14), -- trajet du piano (il suit le sol), dégagé sur la place
		To = Vector3.new(50, 0, -14),
		CashByStage = { 15, 30, 60, 110, 180, 280, 400 },
		Model = "UprightPiano",
	},
}
