--[[
	Range les corps importés depuis Blender (assets/export/bodies/MogLife_Bodies.fbx, Accueil > Importer 3D)
	dans ReplicatedStorage.Bodies, où BodyService les cherche (pièces <stade>_<PartieR15>).
	À coller dans la barre de commande de Studio, en mode édition. Ensuite : Ctrl+S.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local imported = workspace:FindFirstChild("MogLife_Bodies")
if not imported then
	warn("[install_bodies] Modèle MogLife_Bodies introuvable dans Workspace : importer le FBX d'abord.")
	return
end
local folder = ReplicatedStorage:FindFirstChild("Bodies")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Bodies"
	folder.Parent = ReplicatedStorage
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
		part.Size *= scale
		part.Anchored = true
		part.CanCollide = false
		part.Parent = folder
		count += 1
	end
end
imported:Destroy()
print(`[install_bodies] {count} pièces de corps rangées dans ReplicatedStorage.Bodies`)
