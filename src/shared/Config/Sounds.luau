-- Sons du jeu (étape 7). Identifiants d'audio Roblox : "rbxassetid://123…".
-- ❓ À CHOISIR PAR LE CRÉATEUR : ils sont vides (le jeu reste muet à cet endroit). Prendre de préférence des sons
-- de la bibliothèque officielle Roblox (audio sous licence) ou les siens ; éviter les extraits d'autres jeux
-- ou de musiques connues (droits d'auteur, modération). Pour tester un son : le coller ici, Rojo synchronise.

return {
	-- Musique de fond par lieu (boucle). Town = la ville ; d'autres lieux viendront avec les zones (plage…).
	Music = {
		Town = "",
	},
	-- Effets
	Sfx = {
		RepPerfect = "", -- répétition parfaite (le plus satisfaisant : « ding » + petit gonflement)
		RepGood = "", -- répétition réussie
		RepMiss = "", -- répétition ratée (comique : « pfff », couinement)
		SeriesEnd = "", -- fin de série
		HelpDone = "", -- aide réussie (cha-ching du Cash)
		Purchase = "", -- achat à la boutique
		StageUp = "", -- transformation : nouveau corps (fanfare courte)
		BossVictory = "", -- Mog-off gagné
		BossDefeat = "", -- Mog-off perdu (trombone triste)
		MentorSay = "", -- le mentor parle (petit « hmm » mystérieux)
	},
	Volume = {
		Music = 0.25,
		Sfx = 0.6,
	},
}
