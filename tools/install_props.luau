--[[
	Range les décors importés depuis Blender dans ServerStorage.Props (là où PropService et FurnitureService
	les cherchent). À coller dans la barre de commande de Studio (Affichage > Barre de commande), en mode édition,
	juste après l'import de assets/export/props/MogLife_AllProps.fbx, MogLife_Buildings.fbx, Props_Colosseum.fbx ou Props_Colosseum_Portal.fbx
	(Accueil > Importer 3D).

	- Prend le modèle importé (« props », « MogLife_AllProps » ou « MogLife_Buildings » dans Workspace) et ses MeshParts.
	- Selon les réglages, l'importateur lit parfois le FBX en centimètres (tout 100 fois trop grand) : détecté et corrigé.
	- Chaque MeshPart garde son nom (Bench, StreetLamp, Furniture_SaggyCouch…), est ancrée et rangée.
	- Un décor déjà présent du même nom est remplacé (pour réimporter après une modification).
	- Murs des bâtiments (*_Walls) : leur collision n'est pas celle du mesh (Roblox rebouche les portes), PropService
	  pose des blocs invisibles exacts (tools/gen_colliders.py). Façades (*_Trim) : sans collision.
	- Texture : tous les décors partagent la même palette (MogProps_Palette.png, déjà sur Roblox). L'importateur ne
	  la remet pas toujours (import du 18/10 : bâtiments tout gris) ; une pièce importée sans texture la reçoit.
	Enregistrer ensuite la place (Ctrl+S) : les modèles vivent dans la place, pas dans les fichiers.
]]

local ServerStorage = game:GetService("ServerStorage")

local PALETTE = "rbxassetid://123907474681522" -- assets/export/props/MogProps_Palette.png
-- Le Colisée du Pump (D89) et son portail (D105) ont leurs propres couleurs (grès, marbre, velums) : palette à part
local COLOSSEUM_PALETTE = "rbxassetid://121502714741030" -- assets/export/props/Colosseum_Palette.png

local imported = workspace:FindFirstChild("Props_Colosseum")
	or workspace:FindFirstChild("Props_Colosseum_Portal")
	or workspace:FindFirstChild("props")
	or workspace:FindFirstChild("MogLife_GymStations")
	or workspace:FindFirstChild("MogLife_AllProps")
	or workspace:FindFirstChild("MogLife_Buildings")
if not imported then
	warn("[install_props] Modèle importé introuvable dans Workspace : importer le FBX d'abord.")
	return
end

local folder = ServerStorage:FindFirstChild("Props")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Props"
	folder.Parent = ServerStorage
end

-- Aucun décor ne dépasse quelques centaines de studs : au-delà, l'import est en centimètres
local scale = 1
for _, part in imported:GetDescendants() do
	if part:IsA("MeshPart") and part.Size.Magnitude > 2000 then
		scale = 1 / 100
		break
	end
end

local count = 0
for _, part in imported:GetDescendants() do
	if part:IsA("MeshPart") then
		local old = folder:FindFirstChild(part.Name)
		if old then
			old:Destroy()
		end
		part.Size *= scale
		part.Anchored = true
		if imported.Name == "Props_Colosseum" or imported.Name == "Props_Colosseum_Portal" then
			part.TextureID = COLOSSEUM_PALETTE
		elseif part.TextureID == "" then
			part.TextureID = PALETTE
		end
		part.CFrame = CFrame.new(0, part.Size.Y / 2, 0)
		part.Parent = folder
		count += 1
	end
end
imported:Destroy()
print(`[install_props] {count} décors rangés dans ServerStorage.Props`)
