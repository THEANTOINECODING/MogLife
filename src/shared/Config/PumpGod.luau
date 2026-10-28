-- Combat du Dieu du Pump au Colisée (D89, D90). Tranche 2 : la manche 1 « L'échauffement divin », jouée en
-- esquive (le dieu ne peut pas encore être frappé : ce sera la tranche 3). Tout ce qui touche se décide sur le serveur
-- (PumpGodService) ; les clients dessinent les zones à l'heure du serveur (PumpGodController).
-- Distances en studs, temps en secondes, dégâts en points de vie (sur Health).

return {
	Health = 100, -- vie du joueur
	HitInvuln = 1.0, -- secondes d'invincibilité après un coup (pas deux coups d'un coup)
	Latency = 0.1, -- marge pour le retard d'affichage : la position est jugée un peu après l'impact
	-- Le saut et la roulade arrivent au serveur avec un peu de retard (ping) : un coup détecté n'est confirmé qu'après
	-- ce délai, et il est annulé si le joueur a sauté (onde, haltère) ou roulé entre-temps
	Grace = 0.25,

	-- Roulade : esquive rapide, invincible un court instant
	Roll = {
		Cooldown = 0.9,
		Invuln = 0.45, -- secondes d'invincibilité (comptées à la réception de la demande)
		Distance = 13, -- studs parcourus
		Time = 0.34, -- durée de la roulade
	},
	-- Saut : on évite une onde ou un haltère si les pieds sont au moins à cette hauteur au-dessus de la piste
	JumpClear = 1.6,

	-- Rythme de la manche 1 : pause entre deux attaques (elle raccourcit au fil de la manche)
	Pause = { From = 2.0, To = 1.1, Over = 60 },
	Attacks = {
		-- Foudre : trois éclairs, chacun sur le joueur au moment où il est annoncé
		Bolts = { Weight = 3, Count = 3, Gap = 0.6, Warn = 1.0, Radius = 6.5, Damage = 18 },
		-- Haltère géant qui roule d'un bout à l'autre de la piste, en passant par le joueur : sortir de la bande ou sauter
		Dumbbell = { Weight = 2, Warn = 1.3, Width = 7, Speed = 44, Height = 3.4, Damage = 24 },
		-- Onde de flexion : un anneau part du dieu et s'élargit jusqu'au mur ; sauter au moment où il passe
		Wave = { Weight = 2, Warn = 1.1, Speed = 26, Thickness = 3, Damage = 20 },
	},

	-- Le dieu dans l'arène
	BossScale = 1.0, -- taille du modèle (le Dieu du Pump fait déjà 15 studs de haut)
	BossHover = 0.6, -- il flotte un peu au-dessus de la piste
}
