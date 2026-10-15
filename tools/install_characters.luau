--[[
	Range les personnages importés depuis Blender (assets/export/characters/MogLife_Characters.fbx,
	Accueil > Importer 3D) : corps des stades -> ReplicatedStorage.Bodies (<stade>_<Partie>),
	objets de style -> ReplicatedStorage.Style (<stade>__<objet>__<Partie>). Une pièce déjà présente du même
	nom est remplacée (pour réimporter après une modification).
	À coller dans la barre de commande de Studio, en mode édition. Ensuite : Ctrl+S.
	Les dossiers Bodies et Style ne sont pas gérés par Rojo : une reconnexion ne les efface pas.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local imported = workspace:FindFirstChild("MogLife_Characters")
if not imported then
	warn("[install_characters] Modèle MogLife_Characters introuvable dans Workspace : importer le FBX d'abord.")
	return
end

local function folder(name: string): Folder
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing then
		return existing :: Folder
	end
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = ReplicatedStorage
	return created
end

-- Import parfois en centimètres (tout 100 fois trop grand) : détecté et corrigé
local scale = 1
for _, part in imported:GetDescendants() do
	if part:IsA("MeshPart") and part.Size.Magnitude > 500 then
		scale = 1 / 100
		break
	end
end

local counts = { Bodies = 0, Style = 0 }
for _, part in imported:GetDescendants() do
	if part:IsA("MeshPart") then
		local target = if string.find(part.Name, "__", 1, true) then "Style" else "Bodies"
		local destination = folder(target)
		local old = destination:FindFirstChild(part.Name)
		if old then
			old:Destroy()
		end
		part.Size *= scale
		part.Anchored = true
		part.CanCollide = false
		part.Parent = destination
		counts[target] += 1
	end
end
imported:Destroy()
print(`[install_characters] {counts.Bodies} pièces de corps et {counts.Style} pièces de style rangées`)
