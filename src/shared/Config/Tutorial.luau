-- Tutoriel des 5 premières minutes (design/01_BOUCLES.md), guidé par le mentor (D29) : contextuel, quittable,
-- rejouable (en le demandant au mentor). Chaque étape attend un événement du jeu ; la cible est montrée par un
-- trait lumineux. Textes : Tutorial.<id>.Goal (objectif court), Tutorial.<id>.Say (réplique du mentor).
-- Étape TryLook : le design prévoit un premier achat, mais la première aide ne rapporte que 5 Cash et le moins cher
-- des objets en coûte 25 ; on fait donc essayer un look (essayage gratuit). ❓ Prix d'un objet de départ.

export type Target = {
	tag: string, -- tag CollectionService de la cible
	attribute: string, -- attribut qui la désigne
	value: string,
	own: boolean?, -- dans sa propre maison
}

export type Step = {
	id: string,
	event: string, -- événement envoyé par les services (TutorialService.OnEvent)
	arg: string?, -- paramètre attendu de l'événement (nil : n'importe lequel)
	target: Target,
}

local Tutorial: { Steps: { Step } } = {
	Steps = {
		{
			id = "Train",
			event = "SeriesCompleted",
			arg = "Curl",
			target = { tag = "Station", attribute = "ExerciseId", value = "Curl", own = true },
		},
		{
			id = "HelpMom",
			event = "HelpCompleted",
			arg = "OpenJar",
			target = { tag = "HelperSpot", attribute = "HelpId", value = "OpenJar", own = true },
		},
		{
			id = "TryLook",
			event = "ShopOpened",
			target = { tag = "VendorSpot", attribute = "Store", value = "Barber" },
		},
		{
			id = "MogKevin",
			event = "BossBeaten",
			arg = "Kevin",
			target = { tag = "BossSpot", attribute = "BossId", value = "Kevin" },
		},
	},
}

return Tutorial
