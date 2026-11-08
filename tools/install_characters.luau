--[[
	Range les personnages importés depuis Blender (assets/export/characters/MogLife_Characters.fbx,
	ou MogLife_Wardrobe.fbx pour ne réimporter que le style ; Accueil > Importer 3D) :
	corps des stades -> ReplicatedStorage.Bodies (<stade>_<Partie>),
	objets de style -> ReplicatedStorage.Style (<stade>__<objet>__<Partie>). Une pièce déjà présente du même
	nom est remplacée (pour réimporter après une modification).
	À coller dans la barre de commande de Studio, en mode édition. Ensuite : Ctrl+S.
	Les dossiers Bodies et Style ne sont pas gérés par Rojo : une reconnexion ne les efface pas.
	La version D71 vérifie les 3 318 pièces de style et la palette avant de remplacer les anciens modèles.
	La version D119 range chaque texture dans une SurfaceAppearance en mode Overlay (teinte de la peau, des yeux...).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local imported = workspace:FindFirstChild("MogLife_Wardrobe") or workspace:FindFirstChild("MogLife_Characters")
if not imported then
	warn("[install_characters] Modèle MogLife_Wardrobe ou MogLife_Characters introuvable dans Workspace.")
	return
end

-- La nouvelle palette contient aussi les couleurs des 20 ensembles. Si Studio perd toutes les textures
-- pendant l'import, ne remplaçons pas les anciens habits texturés par des modèles gris.
local styleTexture = ""
local styleAppearance: SurfaceAppearance? = nil
local styleCount = 0
for _, part in imported:GetDescendants() do
	if part:IsA("MeshPart") and string.find(part.Name, "__", 1, true) then
		styleCount += 1
		if part.TextureID ~= "" then
			styleTexture = part.TextureID
		end
		styleAppearance = styleAppearance or part:FindFirstChildOfClass("SurfaceAppearance")
	end
end
if styleCount ~= 4466 then
	warn(`[install_characters] Import incomplet : {styleCount} pièces de style sur 4466. Rien n'a été remplacé.`)
	return
end
if styleCount > 0 and styleTexture == "" and not styleAppearance then
	warn(
		"[install_characters] Texture des habits absente : réimporter le FBX avec MogLife_Style.png. Rien n'a été remplacé."
	)
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
		if target == "Style" and part.TextureID == "" and not part:FindFirstChildOfClass("SurfaceAppearance") then
			if styleTexture ~= "" then
				part.TextureID = styleTexture
			elseif styleAppearance then
				styleAppearance:Clone().Parent = part
			end
		end
		local destination = folder(target)
		local old = destination:FindFirstChild(part.Name)
		if old then
			old:Destroy()
		end
		-- D119 : Roblox affiche une TextureID opaque, le voile de l'atlas cachait la couleur choisie (peau noire et
		-- blanche). La texture passe dans une SurfaceAppearance en Overlay : la couleur de la pièce se voit dessous.
		-- Seule la barre de commande peut créer cette texture (un script de jeu n'en a pas le droit).
		if part.TextureID ~= "" and not part:FindFirstChildOfClass("SurfaceAppearance") then
			local appearance = Instance.new("SurfaceAppearance")
			appearance.AlphaMode = Enum.AlphaMode.Overlay
			appearance.ColorMapContent = Content.fromUri(part.TextureID)
			appearance.Parent = part
			part.TextureID = ""
		end
		part.Size *= scale
		part.Anchored = true
		part.CanCollide = false
		part.Parent = destination
		counts[target] += 1
		if (counts.Bodies + counts.Style) % 100 == 0 then
			task.wait()
		end
	end
end
imported:Destroy()
print(`[install_characters] {counts.Bodies} pièces de corps et {counts.Style} pièces de style rangées`)
