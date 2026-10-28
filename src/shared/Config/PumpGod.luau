-- Combat du Dieu du Pump au Colisée (D89, D90, D91). Manche 1 « L'échauffement divin » : il attaque avec des zones à
-- esquiver, et le joueur le frappe de 4 façons avec le bouton FLEX (punir, renvoyer la foudre, lancer des disques,
-- pose sacrée). Tout ce qui touche se décide sur le serveur (PumpGodService) ; les clients dessinent les zones à
-- l'heure du serveur (PumpGodController).
-- Distances en studs, temps en secondes, dégâts en points de vie.

return {
	Health = 100, -- vie du joueur
	BossHealth = 100, -- vie du dieu (manche 1)
	HitInvuln = 1.0, -- secondes d'invincibilité après un coup (pas deux coups d'un coup)
	Latency = 0.1, -- marge pour le retard d'affichage : la position est jugée un peu après l'impact
	-- Le saut et la roulade arrivent au serveur avec un peu de retard (ping) : un coup détecté n'est confirmé qu'après
	-- ce délai, et il est annulé si le joueur a sauté (onde, haltère) ou roulé entre-temps
	Grace = 0.25,
	DefeatMogShare = 0.03, -- part du Mog perdue en cas de défaite (choix d'Antoine, D89)

	-- Roulade : esquive rapide, invincible un court instant
	Roll = {
		Cooldown = 0.9,
		Invuln = 0.45, -- secondes d'invincibilité (comptées à la réception de la demande)
		Distance = 13, -- studs parcourus
		Time = 0.34, -- durée de la roulade
	},
	-- Saut : on évite une onde ou un haltère si les pieds sont au moins à cette hauteur au-dessus de la piste
	JumpClear = 1.6,

	-- Rythme : pause entre deux attaques (elle raccourcit au fil de la manche)
	Pause = { From = 2.0, To = 1.1, Over = 75 },
	-- Le dieu se déplace dans la piste entre ses attaques (cercle de ce rayon autour du centre)
	Orbit = { Radius = 22, MaxRadius = 30, MoveTime = 1.1 },
	-- Ordre des premières attaques : chaque façon de le frapper apparaît une fois, puis c'est au hasard
	Opening = { "Bolts", "Javelin", "Dumbbell", "Slam", "Wave" },
	Attacks = {
		-- Foudre : trois éclairs, chacun sur le joueur au moment où il est annoncé
		Bolts = { Weight = 3, Count = 3, Gap = 0.6, Warn = 1.0, Radius = 6.5, Damage = 18 },
		-- Haltère géant qui roule d'un bout à l'autre de la piste, en passant par le joueur : sortir de la bande ou sauter
		Dumbbell = { Weight = 2, Warn = 1.3, Width = 7, Speed = 44, Height = 3.4, Damage = 24 },
		-- Onde de flexion : un anneau part du dieu et s'élargit jusqu'au mur ; sauter au moment où il passe
		Wave = { Weight = 2, Warn = 1.1, Speed = 26, Thickness = 3, Damage = 20 },
		-- Coup de poing au sol : il fonce près du joueur et frappe en cône devant lui, puis il est essoufflé
		Slam = { Weight = 2, Approach = 13, Warn = 1.1, Length = 26, Angle = 70, Damage = 26 },
		-- Javelot d'éclair : lancé droit sur le joueur ; FLEX quand il arrive près de lui pour le renvoyer
		Javelin = { Weight = 2, Warn = 1.0, Speed = 42, Radius = 2.6, Damage = 20, Height = 3 },
	},

	-- Façons de frapper le dieu (bouton FLEX)
	-- 1. Punir : après le coup de poing au sol, il est essoufflé ; combo de 3 coups, le 3e en rythme = coup de Mog
	Winded = { Time = 3.2, Range = 14 },
	Punch = { Damage = 4, PowerDamage = 12, MinGap = 0.18, Reset = 1.3, BeatFrom = 0.4, BeatTo = 0.75 },
	-- 2. Renvoyer la foudre : FLEX quand le javelot est à moins de cette distance
	Parry = { Range = 10, Flight = 0.5, Damage = 12 },
	-- 3. Disques d'haltère dorés : tombent après la foudre et l'haltère ; FLEX pour ramasser, FLEX pour lancer
	Disc = { Max = 2, Life = 20, PickRange = 7, Flight = 0.6, Damage = 9 },
	-- 4. Pose sacrée : un cercle doré apparaît de temps en temps ; y rester en maintenant FLEX lance un rayon de Mog
	Sacred = { First = 14, Every = 18, Life = 8, Radius = 5, Charge = 2.0, Damage = 18 },

	-- Le dieu dans l'arène
	BossScale = 1.0, -- taille du modèle (le Dieu du Pump fait déjà 13 studs de haut)
	BossHover = 0.6, -- il flotte un peu au-dessus de la piste
	EndDelay = 3.5, -- secondes entre la fin du combat et le retour (gradins ou temple)
	FighterInset = 8, -- le combattant démarre à cette distance de sa porte, vers le centre (caméra hors du tunnel)
}
