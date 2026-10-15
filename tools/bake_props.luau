--[[
	Pose les décors 3D (ServerStorage.Props) dans Workspace.MapProps EN MODE ÉDITION, pour voir la ville finale
	dans Studio sans lancer le jeu. À coller dans la barre de commande de Studio après un import de décors ou une
	régénération de la carte (tools/build_map.py). Ensuite : Ctrl+S.
	Workspace.MapProps n'est pas géré par Rojo : une reconnexion ne l'efface pas.
	Le jeu repose les décors au démarrage (PropService) : rien n'est doublé.
]]
-- Copie du module : la barre de commande garde en mémoire l'ancienne version d'un module déjà chargé.
-- La copie est posée à côté de l'original (PropService charge ../PropColliders), puis retirée.
local module = game:GetService("ServerScriptService").Server.Services.PropService
local copy = module:Clone()
copy.Name = "PropServiceBake"
copy.Parent = module.Parent
local PropService = require(copy)
copy:Destroy()
print(`[bake_props] {PropService.PlaceAll()} décors posés dans Workspace.MapProps`)
