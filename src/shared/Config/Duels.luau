-- Duels entre joueurs : bras de fer (D68, design/02_MECANIQUES/DUELS.md). Contre n'importe quel joueur, n'importe
-- où : une table apparaît entre les deux. Chances égales : même motif de zones, mêmes fenêtres, mêmes vitesses pour
-- les deux joueurs ; ni le Mog ni le stade n'entrent dans le calcul. Seule exception : le Drip de la tenue (D111, au plus +5 %
-- aux poussées, Balance.Drip).
-- Les chiffres sont des hypothèses ❓ à régler pendant l'alpha.

return {
	Minigame = "Gauge", -- module dans src/client/Minigames/ (jamais utilisé ailleurs)
	Activity = "ArmWrestle", -- module dans src/client/Activities/ (les deux joueurs, coude sur la table)

	Rounds = 3,
	RoundsToWin = 2,
	RepsPerRound = 8, -- poussées par manche (un balayage de l'aiguille chacune)
	Interval = 0.95, -- secondes d'un balayage de l'aiguille (manche 1)
	SpeedByRound = { 1, 0.88, 0.78 }, -- chaque manche est plus rapide…
	TimingScaleByRound = { 1, 0.85, 0.7 }, -- … et sa zone de force plus étroite
	PanelScreenShare = 0.5, -- la jauge occupe la moitié de la hauteur d'écran sur tous les appareils (D110)
	PanelMaxScale = 1.8,
	Lead = 0.6, -- balayages d'attente avant le premier (le temps de voir la jauge)
	MinRepGap = 0.25, -- secondes minimum entre deux poussées envoyées
	-- Jauge (fractions de sa largeur) : la zone verte change de place à chaque balayage
	ZoneHalf = 0.13, -- demi-largeur de la zone verte (Good), × l'échelle de la manche
	PerfectHalf = 0.045, -- demi-largeur du cœur doré (Perfect), × l'échelle de la manche
	ZoneMin = 0.2, -- la zone reste entre ces deux bornes de la jauge
	ZoneMax = 0.8,

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

	-- Invitations
	InviteDistance = 14, -- studs max entre les deux joueurs pour inviter
	InviteTimeout = 12, -- refus automatique, sans pénalité
	InviteCooldown = 20, -- secondes entre deux invitations d'un même joueur
	DeclineBlock = 300, -- après un refus, le même joueur ne peut plus inviter celui-ci pendant 5 min

	-- Le perdant perd une part de son Mog (D110, choix d'Antoine : « il faut perdre beaucoup »), jamais sous le Mog
	-- qu'il fallait pour atteindre son stade. Annoncé dans l'invitation.
	LossMogShare = 0.15,

	-- Récompenses (Cash, selon le stade de chaque joueur).
	-- Participation valide = au moins MinHits répétitions réussies (Good ou Perfect) pendant le duel.
	-- Récompenses limitées aux RewardsPerPairPerDay premiers duels de chaque paire de joueurs par jour (UTC) ;
	-- au-delà, le duel reste possible « pour l'honneur » (sans Cash ni victoire comptée).
	MinHits = 4,
	RewardsPerPairPerDay = 3,
	WinCash = { 10, 20, 35, 60, 90, 130 }, -- ❓
	DrawCash = { 6, 12, 20, 35, 55, 80 }, -- ❓
	LossCash = { 3, 6, 10, 18, 28, 40 }, -- ❓
	-- Le vainqueur gagne aussi du Mog (D88) : une petite part de son propre Mog (il ne vaut pas une série d'exercices
	-- pour les gros joueurs, mais compte pour les petits), bornée. Mêmes conditions que le Cash (participation valide,
	-- limite par paire et par jour).
	WinMogShare = 0.006, -- 0,6 % du Mog du vainqueur
	WinMogMin = 5,
	WinMogMax = 1500,

	-- Duel d'entraînement contre un mannequin (Studio uniquement, DevCommands « DuelBot ») : sa précision
	Bot = { perfect = 0.3, good = 0.45 },
}
