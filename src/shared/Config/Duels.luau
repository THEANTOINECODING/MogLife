-- Duels entre joueurs : « Tug of Mog » (D67, design/02_MECANIQUES/DUELS.md). Un bras de fer en rythme sur une
-- estrade de la salle (tag DuelSpot). Chances égales : même motif de nœuds, mêmes fenêtres, mêmes vitesses pour les
-- deux joueurs ; ni le Mog, ni le stade, ni la tenue n'entrent dans le calcul.
-- Les chiffres sont des hypothèses ❓ à régler pendant l'alpha.

return {
	Minigame = "Tug", -- module dans src/client/Minigames/ (jamais utilisé ailleurs)
	Activity = "Tug", -- module dans src/client/Activities/ (les deux joueurs tirent sur la corde)

	Rounds = 3,
	RoundsToWin = 2,
	RepsPerRound = 8, -- nœuds par manche
	Interval = 0.95, -- secondes entre deux nœuds (manche 1)
	SpeedByRound = { 1, 0.88, 0.78 }, -- chaque manche est plus rapide…
	TimingScaleByRound = { 1, 0.9, 0.8 }, -- … et ses fenêtres plus serrées
	HoldChanceByRound = { 0.15, 0.3, 0.4 }, -- part de nœuds longs (maintenir puis relâcher)
	Lead = 1.5, -- intervalles avant l'arrivée du premier nœud (temps de traversée de la corde à l'écran)
	MinRepGap = 0.25, -- secondes minimum entre deux répétitions envoyées (une fin de nœud long suivie d'un nœud)
	HoldLength = 0.4, -- longueur d'un nœud long, en intervalles (court : le nœud suivant arrive juste après)

	-- Traction de chaque répétition sur la corde (en « crans »). La corde va de -RopeLimit à +RopeLimit :
	-- l'atteindre fait gagner la manche tout de suite (K.-O.) ; sinon, la manche va au côté vers lequel penche la
	-- corde après le dernier nœud (0 = manche nulle).
	Pull = { Perfect = 3, Good = 2, Miss = 0 },
	RopeLimit = 12,

	IntroTime = 5, -- secondes de présentation (bandeau VS, 3-2-1) avant la 1re manche
	PauseBetweenRounds = 3,
	ResultTime = 4, -- secondes avant le retour des deux joueurs à leur place d'avant le duel

	-- Invitations
	InviteDistance = 16, -- studs max entre les deux joueurs pour inviter
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
