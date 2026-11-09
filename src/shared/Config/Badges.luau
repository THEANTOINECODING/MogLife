-- Badges Roblox (D126) : ils s'affichent sur le profil du joueur, que ses amis voient (design/REVIEW_2026-11-10.md).
-- Numéro 0 = badge pas encore créé : rien n'est donné. Antoine crée chaque badge dans le Creator Hub
-- (Expérience > Associated Items > Badges) et colle ici son numéro.
-- Les badges sont donnés par BadgeAwardService d'après la sauvegarde : un ancien joueur reçoit à sa prochaine
-- connexion les badges de ce qu'il a déjà accompli.

return {
	CheckEvery = 6, -- secondes entre deux vérifications de la sauvegarde de chaque joueur

	-- Stade atteint (index dans Stages.List -> numéro du badge) : 2 = Gym Rat … 7 = GOD MOGGER
	Stages = {
		GymRat = 0,
		Bro = 0,
		Alpha = 0,
		Chad = 0,
		Gigachad = 0,
		GodMogger = 0,
	},

	-- Boss battu au moins une fois (identifiant du boss -> numéro du badge)
	Bosses = {
		Kevin = 0,
		Brayan = 0,
		CoachTurbo = 0,
		NoLegs = 0,
		BlockKing = 0,
		PumpGod = 0,
	},

	-- Première série notée S (meilleure note d'un exercice ≥ ce score, Balance.Grade)
	FirstS = { id = 0, score = 95 },
}
