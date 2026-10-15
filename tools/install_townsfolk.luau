--[[
	Range les habitants importés depuis Blender (assets/export/npcs/MogLife_Townsfolk.fbx, Accueil > Importer 3D)
	dans ServerStorage.NpcModels : un modèle par personnage (nommé comme son id : Mom, Courier, VendorBarber,
	Mentor…), dont la PrimaryPart est le corps. Npc.Spawn utilise alors ce vrai modèle au lieu de l'avatar provisoire.
	Un modèle déjà présent du même nom est remplacé. À coller dans la barre de commande de Studio, en mode édition.
	Ensuite : Ctrl+S.
]]

local ServerStorage = game:GetService("ServerStorage")

local imported = workspace:FindFirstChild("MogLife_Townsfolk")
if not imported then
	warn("[install_townsfolk] Modèle MogLife_Townsfolk introuvable dans Workspace : importer le FBX d'abord.")
	return
end
local folder = ServerStorage:FindFirstChild("NpcModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "NpcModels"
	folder.Parent = ServerStorage
end

-- Import parfois en centimètres (tout 100 fois trop grand) : détecté et corrigé
local scale = 1
for _, part in imported:GetDescendants() do
	if part:IsA("MeshPart") and part.Size.Magnitude > 500 then
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
		local model = Instance.new("Model")
		model.Name = part.Name
		part.Size *= scale
		part.Anchored = true
		part.CFrame = CFrame.new(0, part.Size.Y / 2, 0)
		part.Parent = model
		model.PrimaryPart = part
		model.Parent = folder
		count += 1
	end
end
imported:Destroy()
print(`[install_townsfolk] {count} habitants rangés dans ServerStorage.NpcModels`)
