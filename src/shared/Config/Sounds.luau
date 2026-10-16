-- Sons du jeu (étape 7). Identifiants d'audio Roblox : "rbxassetid://123…".
-- Choisis par Claude le 16/10 (à la demande du créateur, qui signalera en jouant ceux qui ne conviennent pas) parmi
-- design/SONS_CANDIDATS.md : musique et jingles de la bibliothèque APM (sous licence Roblox), effets courts publics.
-- Tous vérifiés dans Studio (chargés, durée adaptée). Pour changer un son : coller ici son identifiant, Rojo synchronise.
-- Un identifiant vide = pas de son.

return {
	-- Musique de fond par lieu (boucle). Town = la ville ; d'autres lieux viendront avec les zones (plage…).
	Music = {
		Town = "rbxassetid://9047861871", -- « Funky Comedy » (APM, sous licence), 2 min 43 en boucle
	},
	-- Effets
	Sfx = {
		RepPerfect = "rbxassetid://18448089848", -- répétition parfaite (le plus satisfaisant : « ding » + petit gonflement)
		RepGood = "rbxassetid://140323850218372", -- répétition réussie
		RepMiss = "rbxassetid://109359226723492", -- répétition ratée (comique : « pfff », couinement)
		SeriesEnd = "rbxassetid://9045129322", -- fin de série
		HelpDone = "rbxassetid://134810204798705", -- aide réussie (cha-ching du Cash)
		Purchase = "rbxassetid://134810204798705", -- achat à la boutique
		StageUp = "rbxassetid://9042409054", -- transformation : nouveau corps (fanfare courte)
		BossVictory = "rbxassetid://1836860398", -- Mog-off gagné
		BossDefeat = "rbxassetid://190705984", -- Mog-off perdu (trombone triste)
		MentorSay = "rbxassetid://72467819049463", -- le mentor parle (petit « hmm » mystérieux)
	},
	Volume = {
		Music = 0.25,
		Sfx = 0.6,
	},
}
