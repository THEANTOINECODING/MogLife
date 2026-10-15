--[[
	Range les décors importés depuis Blender dans ServerStorage.Props (là où PropService et FurnitureService
	les cherchent). À coller dans la barre de commande de Studio (Affichage > Barre de commande), en mode édition,
	juste après l'import de assets/export/props/MogLife_AllProps.fbx (Accueil > Importer 3D).

	- Prend le modèle importé (nommé « props » ou « MogLife_AllProps » dans Workspace) et toutes ses MeshParts.
	- L'importateur lit le FBX en centimètres : tout arrive 100 fois trop grand, on divise donc la taille par 100.
	- Chaque MeshPart garde son nom (Bench, StreetLamp, Furniture_SaggyCouch…), est ancrée et rangée.
	- Un décor déjà présent du même nom est remplacé (pour réimporter après une modification).
	- Murs des bâtiments (*_Walls) : leur collision n'est pas celle du mesh (Roblox rebouche les portes), PropService
	  pose des blocs invisibles exacts (tools/gen_colliders.py). Façades (*_Trim) : sans collision.
	Enregistrer ensuite la place (Ctrl+S) : les modèles vivent dans la place, pas dans les fichiers.
]]

local ServerStorage = game:GetService("ServerStorage")

local IMPORT_SCALE = 1 / 100

local imported = workspace:FindFirstChild("props") or workspace:FindFirstChild("MogLife_AllProps")
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

local count = 0
for _, part in imported:GetDescendants() do
	if part:IsA("MeshPart") then
		local old = folder:FindFirstChild(part.Name)
		if old then
			old:Destroy()
		end
		part.Size *= IMPORT_SCALE
		part.Anchored = true
		part.CFrame = CFrame.new(0, part.Size.Y / 2, 0)
		part.Parent = folder
		count += 1
	end
end
imported:Destroy()
print(`[install_props] {count} décors rangés dans ServerStorage.Props`)
