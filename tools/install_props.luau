--[[
	Range les décors importés depuis Blender dans ServerStorage.Props (là où PropService et FurnitureService
	les cherchent). À coller dans la barre de commande de Studio (Affichage > Barre de commande), en mode édition,
	juste après l'import de assets/export/props/MogLife_AllProps.fbx (Accueil > Importer 3D).

	- Prend le modèle importé (nommé « MogLife_AllProps » dans Workspace) et toutes ses MeshParts.
	- Chaque MeshPart garde son nom (Bench, StreetLamp, Furniture_SaggyCouch…), est ancrée et rangée.
	- Un décor déjà présent du même nom est remplacé (pour réimporter après une modification).
	Enregistrer ensuite la place (Ctrl+S) : les modèles vivent dans la place, pas dans les fichiers.
]]

local ServerStorage = game:GetService("ServerStorage")

local imported = workspace:FindFirstChild("MogLife_AllProps")
if not imported then
	warn("[install_props] Modèle « MogLife_AllProps » introuvable dans Workspace : importer le FBX d'abord.")
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
		part.Anchored = true
		part.Parent = folder
		count += 1
	end
end
imported:Destroy()
print(`[install_props] {count} décors rangés dans ServerStorage.Props`)
