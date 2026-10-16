-- Corps du personnage du joueur, un par stade (design/02_MECANIQUES/PERSONNAGE.md, décisions D28 et D39).
-- Squelette R15 standard aux proportions du stade + « coque » modélisée dans Blender (tools/blender/build_bodies.py) :
-- une pièce par partie du squelette, rangée dans ReplicatedStorage.Bodies sous le nom <stade>_<PartieR15>
-- (+ <stade>_Head_Hair, la coupe de base). Décalages des pièces : BodyPieces.luau (généré).
-- ⚠ Si on change des proportions ici, il faut relever le squelette dans Studio
-- (assets/export/bodies/skeletons.json) puis relancer build_bodies.py, sinon les pièces seront décalées.
-- Un stade absent de cette liste garde l'apparence provisoire (avatar Roblox élargi par le Mog).

export type Body = {
	width: number, -- proportions du squelette R15 (HumanoidDescription)
	height: number,
	depth: number,
	head: number,
}

local Bodies: { [string]: Body } = {
	Normie = { width = 0.5, height = 1.05, depth = 0.6, head = 1.15 }, -- « spaghetti » : très grand et très mince (D55)
	GymRat = { width = 0.9, height = 1.0, depth = 0.9, head = 1.05 },
	Bro = { width = 1.05, height = 1.05, depth = 1.0, head = 1.0 },
	Alpha = { width = 1.2, height = 1.1, depth = 1.1, head = 1.0 },
	Chad = { width = 1.35, height = 1.15, depth = 1.2, head = 0.95 },
	Gigachad = { width = 1.5, height = 1.2, depth = 1.3, head = 0.95 },
	GodMogger = { width = 1.7, height = 1.3, depth = 1.45, head = 0.9 },
}

return Bodies
