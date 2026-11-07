-- Secrets de la ville (D121, choisis par Antoine dans design/IDEES.md) : simples, drôles, mystérieux, sans aucun
-- indice dans l'interface. Récompense : un titre secret (Config/Look.luau RewardTitles, champ `secret`), caché dans
-- le menu de création tant qu'il n'est pas trouvé, et l'annonce « SECRET FOUND ». Aucun Mog, aucun avantage.
-- Le serveur valide tout (SecretService) ; les scènes sont jouées par tous les clients (SecretController).
-- Les identifiants servent aussi de clés de titre (Nick.Title.<id>) et de clés de sauvegarde (Secrets.<id>).
-- ❓ Réglages de départ, à ajuster en jouant.

return {
	-- Haltère fantôme : la nuit seulement, il flotte à l'un des emplacements tagués GhostSpot (tiré au hasard).
	-- Le soulever (appui long) le fait disparaître ; il revient ailleurs après Respawn secondes (toujours la nuit).
	GhostLifter = {
		HoldDuration = 2, -- secondes d'appui
		Respawn = 90,
		FloatHeight = 3.5, -- studs au-dessus de l'emplacement
		PromptDistance = 8,
		NightStart = 19, -- heures de jeu (Lighting.ClockTime) : la nuit va de NightStart à NightEnd
		NightEnd = 5,
		Scene = 3.6, -- D122 : durée de la scène (le fantôme fait ses curls puis s'envole)
	},
	-- Statue qui cligne : taper Taps fois en Window secondes sur le socle de la plus haute statue de la place
	StatueBeliever = {
		Taps = 10,
		Window = 4,
		ClickDistance = 24,
		Cooldown = 6, -- secondes entre deux scènes (tous joueurs confondus)
		Scene = 3.4, -- D122 : elle se tourne, cligne de l'œil et fait un double biceps
		ShakePerTap = 0.012, -- studs de tremblement par tape déjà donnée (indice discret)
		Pose = { Shoulder = 95, Elbow = 100, Pump = 7 }, -- degrés du double biceps (vérifié dans Studio)
	},
	-- Le rat coach : frapper sur la plaque d'égout de la ruelle (tag RatManhole) ; le couvercle se soulève, le rat
	-- fait ses pompes et donne son conseil pendant Show secondes
	SewerGains = {
		PromptDistance = 6,
		Show = 6,
		Cooldown = 10,
		LidLift = 1.6, -- studs
		Pushups = 4, -- D122 : pompes comptées à voix haute avant qu'il gonfle les bras
	},
	-- Miroir du passé : au dernier stade (GOD MOGGER), faire une pose devant un miroir du coiffeur et ne plus bouger
	-- pendant Hold secondes : le reflet redevient le Normie du joueur, qui lui fait coucou
	NeverForget = {
		Hold = 5,
		MirrorDistance = 9,
		StillDistance = 2.5, -- studs de déplacement tolérés pendant la pose
		Show = 5,
		Store = "Barber", -- attribut Store des miroirs concernés
	},
}
