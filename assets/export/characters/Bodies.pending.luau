-- Corps du personnage du joueur, un par stade (design/02_MECANIQUES/PERSONNAGE.md, décisions D28 et D39).
-- Squelette R15 standard aux proportions du stade + « coque » modélisée dans Blender (tools/blender/build_bodies.py) :
-- une pièce par partie du squelette, rangée dans ReplicatedStorage.Bodies sous le nom <stade>_<PartieR15>
-- (+ <stade>_Head_Hair, la coupe de base). Décalages des pièces : BodyPieces.luau (généré).
-- ⚠ Si on change des proportions ici, il faut recalculer le squelette (tools/derive_skeleton.py) ou le relever dans
-- Studio (assets/export/bodies/skeletons.json) puis relancer build_bodies.py, sinon les pièces seront décalées.
-- Un stade absent de cette liste garde l'apparence provisoire (avatar Roblox élargi par le Mog).

export type Body = {
	width: number, -- proportions du squelette R15 (HumanoidDescription)
	height: number,
	depth: number,
	head: number,
}

local Bodies: { [string]: Body } = {
	Normie = { width = 0.35, height = 1.1, depth = 0.5, head = 1.15 }, -- « spaghetti » : très grand, maigre à l'extrême (D55, D116)
	GymRat = { width = 0.9, height = 1.0, depth = 0.9, head = 1.05 },
	Bro = { width = 1.05, height = 1.05, depth = 1.0, head = 1.0 },
	Alpha = { width = 1.2, height = 1.1, depth = 1.1, head = 1.0 },
	Chad = { width = 1.35, height = 1.15, depth = 1.2, head = 0.95 },
	Gigachad = { width = 1.5, height = 1.2, depth = 1.3, head = 0.95 },
	GodMogger = { width = 2.05, height = 1.55, depth = 1.7, head = 0.85 }, -- démesuré mais passe les portes (8,2 x 5 studs, D116)

	-- Corps féminins (D55, refaits le 17/10) : épaules plus étroites (largeur x0,85), un peu moins profonds et moins
	-- grands que les masculins du même stade, même tête. Squelettes relevés dans Studio comme les autres.
	NormieF = { width = 0.3, height = 1.07, depth = 0.46, head = 1.15 },
	GymRatF = { width = 0.77, height = 0.97, depth = 0.83, head = 1.05 },
	BroF = { width = 0.89, height = 1.02, depth = 0.92, head = 1.0 },
	AlphaF = { width = 1.02, height = 1.07, depth = 1.01, head = 1.0 },
	ChadF = { width = 1.15, height = 1.12, depth = 1.1, head = 0.95 },
	GigachadF = { width = 1.28, height = 1.16, depth = 1.2, head = 0.95 },
	GodMoggerF = { width = 1.75, height = 1.5, depth = 1.6, head = 0.85 },
}

return Bodies
