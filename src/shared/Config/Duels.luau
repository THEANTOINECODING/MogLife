-- Duels entre joueurs : bras de fer (D68, design/02_MECANIQUES/DUELS.md). Contre n'importe quel joueur, n'importe
-- où : une table apparaît entre les deux. Chances égales : mêmes règles et mêmes vitesses pour
-- les deux joueurs ; ni le Mog, ni le stade, ni la tenue n'entrent dans le calcul.
-- Les chiffres sont des hypothèses ❓ à régler pendant l'alpha.

return {
	Minigame = "ReadRip", -- prise puis contre, identique pour les deux joueurs
	Activity = "ArmWrestle", -- module dans src/client/Activities/ (les deux joueurs, coude sur la table)

	Rounds = 3,
	RoundsToWin = 2,
	RepsPerRound = 8, -- échanges par manche (quota de la cadence du serveur)
	Interval = 1.55, -- temps d'un échange : choisir la prise, tenir, contrer
	SpeedByRound = { 1, 0.93, 0.87 },
	TimingScaleByRound = { 1, 0.9, 0.82 },

	-- Poussée de chaque répétition (en « crans »). Le bras va de -LeanLimit à +LeanLimit : l'atteindre, c'est plaquer
	-- le bras de l'adversaire sur la table (manche gagnée tout de suite) ; sinon, la manche va au côté vers lequel
	-- penchent les bras après la dernière poussée (0 = manche nulle).
	Push = { Perfect = 3, Good = 2, Miss = 0 },
	LeanLimit = 12,

	-- Table de bras de fer (studs) : elle apparaît au sol entre les deux joueurs
	Table = {
		Height = 3.3, -- hauteur du plateau (on se tient debout)
		Spacing = 1.9, -- distance entre le centre de la table et chaque joueur
		MaxStep = 1.2, -- écart de hauteur de sol accepté sous la table et les joueurs
		Room = Vector3.new(3, 5.5, 3.4), -- place libre autour des joueurs, y compris derrière eux près d'un mur
		TryAngles = { 0, 90, -90, 45, -45, 135, -135, 180 }, -- sens essayés autour de l'axe entre les joueurs
	},

	IntroTime = 5, -- secondes de présentation (bandeau VS, 3-2-1) avant la 1re manche
	PauseBetweenRounds = 3,
	ResultTime = 4, -- secondes avant que la table disparaisse
	FinishSlamTime = 0.38, -- bras gagnant plaqué sur le coussin en fin de manche
	FinishPoseTime = 1.1, -- maintien de la pose après la fin du mini-jeu

	-- Invitations
	InviteDistance = 14, -- studs max entre les deux joueurs pour inviter
	InviteTimeout = 12, -- refus automatique, sans pénalité
	InviteCooldown = 20, -- secondes entre deux invitations d'un même joueur
	DeclineBlock = 300, -- après un refus, le même joueur ne peut plus inviter celui-ci pendant 5 min

	-- Récompenses (Cash, selon le stade de chaque joueur) : rien n'est jamais perdu.
	-- Participation valide = au moins MinHits répétitions réussies (Good ou Perfect) pendant le duel.
	-- Récompenses limitées aux RewardsPerPairPerDay premiers duels de chaque paire de joueurs par jour (UTC) ;
	-- au-delà, le duel reste possible « pour l'honneur » (sans Cash ni victoire comptée).
	MinHits = 4,
	RewardsPerPairPerDay = 3,
	WinCash = { 10, 20, 35, 60, 90, 130 }, -- ❓
	DrawCash = { 6, 12, 20, 35, 55, 80 }, -- ❓
	LossCash = { 3, 6, 10, 18, 28, 40 }, -- ❓

	-- Duel d'entraînement contre un mannequin (Studio uniquement, DevCommands « DuelBot ») : sa précision
	Bot = { perfect = 0.3, good = 0.45 },
}
