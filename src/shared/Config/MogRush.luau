-- Mog Rush (D132, demande d'Antoine : « le tableau mondial des Mog, réinitialisé toutes les 30 min, impressionnant
-- et esthétiquement beau ») : classement MONDIAL (tous les serveurs) du Mog gagné aux exercices pendant la manche
-- en cours. Les manches sont calées sur l'horloge (xx:00 et xx:30 UTC) : tous les serveurs partagent la même manche.
-- Seul le Mog des exercices compte (pas les packs de Mog en Robux : le classement ne s'achète pas).

return {
	RoundSeconds = 30 * 60,
	StoreName = "MogRush_v1", -- un OrderedDataStore, une portée par manche (ne pas renommer en cours de manche)
	TopSize = 10, -- lignes du tableau
	PodiumSize = 3, -- champions de la manche précédente affichés en bas
	FlushEvery = 30, -- secondes entre deux envois du Mog gagné vers le classement mondial
	ReadEvery = 45, -- secondes entre deux lectures du classement mondial
	PodiumReadDelay = 50, -- après la fin d'une manche, attente avant de lire ses champions (les serveurs envoient)
	SendEvery = 5, -- secondes entre deux envois du tableau aux joueurs (le Mog local avance plus vite)

	-- Tableau géant au-dessus de la fontaine de la place (4 écrans dos à dos, un par avenue)
	Board = {
		Center = Vector3.new(0, 27, 0), -- bas des écrans à 14 studs (la fontaine monte à 11)
		ScreenWidth = 22,
		ScreenHeight = 26,
		Bob = 0.6, -- amplitude du flottement (studs)
		BobPeriod = 6, -- secondes
		CrownSpin = 12, -- secondes par tour de la couronne
		PixelsPerStud = 40, -- résolution des écrans
		MaxDistance = 260, -- au-delà, l'écran ne se dessine plus (téléphones)
	},
}
