-- Corps du personnage du joueur, un par stade (voir design/05_ART_SON.md, décision D28).
-- Squelette R15 standard aux proportions du stade + « coque » modélisée dans Blender
-- (modèle ReplicatedStorage.Bodies.<model>, pièces nommées <model>_<PartieR15>[_<Détail>]).
-- Un stade absent de cette liste garde l'apparence provisoire (avatar Roblox élargi par le Mog).

export type Body = {
	model: string,
	width: number, -- proportions du squelette R15 (HumanoidDescription)
	height: number,
	depth: number,
	head: number,
	-- Couleur de chaque pièce (le nom sans le préfixe du modèle), le reste prend `skin`
	colors: { [string]: Color3 },
	skin: Color3,
}

local SKIN = Color3.fromRGB(238, 189, 153)
local SHIRT = Color3.fromRGB(140, 145, 153)

local Bodies: { [string]: Body } = {
	Normie = {
		model = "Normie",
		width = 0.5,
		height = 1,
		depth = 0.6,
		head = 1.22,
		skin = SKIN,
		colors = {
			UpperTorso = SHIRT,
			LeftUpperArm_Sleeve = SHIRT,
			RightUpperArm_Sleeve = SHIRT,
			LowerTorso = Color3.fromRGB(38, 77, 191),
			Head_Eyes = Color3.fromRGB(242, 242, 242),
			Head_Pupils = Color3.fromRGB(8, 8, 10),
			Head_Face = Color3.fromRGB(46, 26, 15),
			LeftFoot = Color3.fromRGB(242, 242, 242),
			RightFoot = Color3.fromRGB(242, 242, 242),
			LeftFoot_Sole = Color3.fromRGB(217, 31, 31),
			RightFoot_Sole = Color3.fromRGB(217, 31, 31),
		},
	},
}

return Bodies
