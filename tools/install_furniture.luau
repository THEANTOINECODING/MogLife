--[[
	Meubles v3 (D133) : range les meubles importés depuis assets/export/props/Props_Furniture.fbx dans
	ServerStorage.Props. À coller dans la barre de commande de Studio (mode édition), juste après l'import
	(Accueil > Importer 3D), ou à lancer par Claude via le MCP.

	- Chaque meuble arrive en plusieurs MeshParts nommées Furniture_<Id>__<Matière>_<rrggbb> (ou __Tex).
	- Le script crée pour chaque meuble une pièce principale invisible Furniture_<Id> (la boîte englobante : c'est
	  elle que PropService pose au sol, contre le mur, et qui fait la collision), et y range les MeshParts comme
	  morceaux (attribut AccentOffset, voir src/shared/PropAccents.luau) avec leur vraie matière Roblox et leur couleur.
	- __Tex : la palette partagée des décors (motifs léopard, damier, coucher de soleil).
	- Un meuble déjà présent est remplacé (ancienne version v2 comprise).
	Enregistrer ensuite la place (Ctrl+S) : les modèles vivent dans la place, pas dans les fichiers.
]]

local ServerStorage = game:GetService("ServerStorage")

local PALETTE = "rbxassetid://123907474681522" -- assets/export/props/MogProps_Palette.png
local GLASS_TRANSPARENCY = 0.45

local imported = workspace:FindFirstChild("Props_Furniture")
if not imported then
	warn("[install_furniture] Modèle « Props_Furniture » introuvable dans Workspace : importer le FBX d'abord.")
	return
end

local folder = ServerStorage:FindFirstChild("Props")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Props"
	folder.Parent = ServerStorage
end

-- Aucun meuble ne dépasse quelques dizaines de studs : au-delà, l'import est en centimètres
local scale = 1
for _, part in imported:GetDescendants() do
	if part:IsA("MeshPart") and part.Size.Magnitude > 500 then
		scale = 1 / 100
		break
	end
end

local groups: { [string]: { MeshPart } } = {}
for _, part in imported:GetDescendants() do
	if part:IsA("MeshPart") then
		local base, suffix = string.match(part.Name, "^(Furniture_%w+)__(.+)$")
		if base and suffix then
			part:SetAttribute("Look", suffix)
			groups[base] = groups[base] or {}
			table.insert(groups[base], part)
		end
	end
end

local function hexColor(hex: string): Color3
	return Color3.fromRGB(
		tonumber(string.sub(hex, 1, 2), 16) or 255,
		tonumber(string.sub(hex, 3, 4), 16) or 255,
		tonumber(string.sub(hex, 5, 6), 16) or 255
	)
end

local function applyLook(part: MeshPart)
	local suffix = part:GetAttribute("Look") :: string
	if suffix == "Tex" then
		part.TextureID = PALETTE
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.new(1, 1, 1)
		return
	end
	local materialName, hex = string.match(suffix, "^(%a+)_(%x%x%x%x%x%x)$")
	local ok, material = pcall(function()
		return (Enum.Material :: any)[materialName]
	end)
	part.TextureID = ""
	part.Material = if ok and material then material else Enum.Material.SmoothPlastic
	part.Color = hexColor(hex or "ffffff")
	if part.Material == Enum.Material.Glass then
		part.Transparency = GLASS_TRANSPARENCY
	end
	if part.Material == Enum.Material.Neon or part.Material == Enum.Material.Glass then
		part.CastShadow = false
	end
end

local count, pieces = 0, 0
for base, parts in groups do
	-- Boîte englobante du meuble (repère de l'import, sans rotation)
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = -minV
	for _, part in parts do
		part.Size *= scale
		part.Position *= scale
		local half = part.Size / 2
		minV = minV:Min(part.Position - half)
		maxV = maxV:Max(part.Position + half)
	end
	local center = (minV + maxV) / 2

	local old = folder:FindFirstChild(base, true)
	while old do
		old:Destroy()
		old = folder:FindFirstChild(base, true)
	end
	local root = Instance.new("Part")
	root.Name = base
	root.Anchored = true
	root.Transparency = 1
	root.CastShadow = false
	root.CanTouch = false
	root.Size = maxV - minV
	root.CFrame = CFrame.new(center)
	for _, part in parts do
		applyLook(part)
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part:SetAttribute("AccentOffset", root.CFrame:ToObjectSpace(part.CFrame))
		part.Parent = root
		pieces += 1
	end
	-- Rangé debout sur l'origine ; les morceaux suivent
	root.CFrame = CFrame.new(0, root.Size.Y / 2, 0)
	for _, part in parts do
		part.CFrame = root.CFrame * (part:GetAttribute("AccentOffset") :: CFrame)
	end
	root.Parent = folder
	count += 1
end
imported:Destroy()
print(`[install_furniture] {count} meubles ({pieces} pièces) rangés dans ServerStorage.Props`)
