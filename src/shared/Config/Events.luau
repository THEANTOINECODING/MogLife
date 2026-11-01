-- Événements de ville (validés le 16/10, refaits en D100) : toutes les 9 à 12 minutes environ, un événement pour tout
-- le serveur, annoncé à l'écran. Rien n'est obligatoire : c'est un bonus pour ceux qui sont là. ❓ Récompenses à calibrer.
-- - GoldenDumbbells : des haltères dorés tournent sous des colonnes de lumière dans la ville ; le premier qui en touche
--   un le ramasse. L'un d'eux est un MÉGA haltère (plus gros, rapporte plus).
-- - FreeShakes : des shakes descendent du ciel en parachute sur la place ; un shake gratuit (boost) par joueur.
-- - RunawayPiano : un piano sur pattes court autour de la fontaine et fuit les joueurs ; il se fatigue après avoir
--   sprinté. Il faut le plaquer plusieurs fois : le dernier plaquage gagne, chaque plaqueur reçoit une part.
-- Cash selon le stade du joueur (index dans Stages.List), pour rester intéressant du début à la fin.
-- Distances en studs, vitesses en studs/s, temps en secondes.

return {
	FirstDelay = 240, -- secondes avant le premier événement d'un serveur
	Interval = { 540, 720 }, -- secondes entre deux événements (au hasard dans cet intervalle)
	Center = Vector3.new(0, 0, 0), -- centre de la ville (la place et sa fontaine)
	EndDelay = 5, -- secondes entre la fin d'un événement réussi (piano arrêté, tout ramassé) et sa clôture

	GoldenDumbbells = {
		Count = 8,
		Duration = 90,
		Radius = 110, -- studs autour du centre où ils peuvent apparaître (au sol, en plein air)
		CashByStage = { 6, 12, 25, 45, 75, 120, 170 },
		Model = "Furniture_GoldenDumbbell", -- ServerStorage.Props
		Mega = { Count = 1, Scale = 1.8, CashMultiplier = 3 },
		Hover = 1.2, -- hauteur au-dessus du sol (le client le fait tourner et flotter)
	},
	FreeShakes = {
		Duration = 60,
		Boost = "ProteinShake",
		Count = 12, -- shakes largués (un par joueur ; les autres restent pour les suivants)
		Ring = { 16, 40 }, -- ils atterrissent entre ces deux distances du centre (autour de la fontaine)
		DropOver = 18, -- les largages s'étalent sur les premières secondes de l'événement
		FallTime = 6, -- durée de la descente en parachute
		FallHeight = 70,
		Model = "ProteinShaker",
		Scale = 1.6,
	},
	RunawayPiano = {
		Duration = 75,
		Model = "UprightPiano",
		Arena = { Inner = 17, Outer = 30 }, -- anneau autour de la fontaine où il court
		Speed = { Trot = 10, Panic = 21, Tired = 3.5 }, -- un joueur marche à 16 et sprinte à 24
		PanicDistance = 18, -- un joueur plus près : il panique et sprinte
		Stamina = 3, -- secondes de sprint avant d'être essoufflé
		TiredTime = 2.2, -- essoufflé : presque immobile, c'est le moment de le plaquer
		TurnRate = 3.4, -- radians par seconde
		Tackles = 3, -- plaquages pour l'arrêter
		StunTime = 1.4, -- sonné après un plaquage
		TackleDistance = 11,
		TackleCooldown = 2, -- secondes avant qu'un même joueur puisse le replaquer
		CashByStage = { 15, 30, 60, 110, 180, 280, 400 },
		HelperShare = 0.35, -- part du gain pour chaque autre plaqueur
	},
}
