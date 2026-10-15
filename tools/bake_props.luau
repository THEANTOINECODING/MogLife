--[[
	Pose les décors 3D (ServerStorage.Props) dans la carte EN MODE ÉDITION, pour voir la ville finale dans Studio
	sans lancer le jeu. À coller dans la barre de commande de Studio après un import de décors ou une
	régénération de la carte (tools/build_map.py). Ensuite : Ctrl+S.
	Le jeu fait la même chose au démarrage (PropService) : si un décor est déjà posé, il ne le double pas.
]]
local PropService = require(game:GetService("ServerScriptService").Server.Services.PropService)
print(`[bake_props] {PropService.PlaceAll()} décors posés`)
