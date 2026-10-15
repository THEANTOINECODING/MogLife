--[[
	Range d'un coup TOUT ce qui vient d'être importé depuis Blender (Accueil > Importer 3D), quel que soit le fichier :
	- MogLife_Characters  : corps des stades -> ReplicatedStorage.Bodies, objets de style -> ReplicatedStorage.Style
	- MogLife_Townsfolk   : habitants, vendeurs, mentor -> ServerStorage.NpcModels (un modèle par personnage)
	- MogLife_Buildings, MogLife_GymStations, MogLife_AllProps, props : décors -> ServerStorage.Props
	Une pièce déjà présente du même nom est remplacée. À coller dans la barre de commande de Studio, en mode édition,
	après le ou les imports. Ensuite : poser les décors (tools/bake_props.luau) si des décors ont changé, puis Ctrl+S.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local function folder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing :: Folder
	end
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

-- Import parfois en centimètres (tout 100 fois trop grand) : détecté et corrigé
local function importScale(model: Instance): number
	for _, part in model:GetDescendants() do
		if part:IsA("MeshPart") and part.Size.Magnitude > 500 then
			return 1 / 100
		end
	end
	return 1
end

local function store(part: MeshPart, destination: Instance, scale: number)
	local old = destination:FindFirstChild(part.Name)
	if old then
		old:Destroy()
	end
	part.Size *= scale
	part.Anchored = true
	part.CFrame = CFrame.new(0, part.Size.Y / 2, 0)
	part.Parent = destination
end

local report = {}

local characters = workspace:FindFirstChild("MogLife_Characters")
if characters then
	local scale, bodies, styles = importScale(characters), 0, 0
	for _, part in characters:GetDescendants() do
		if part:IsA("MeshPart") then
			part.CanCollide = false
			if string.find(part.Name, "__", 1, true) then
				store(part, folder(ReplicatedStorage, "Style"), scale)
				styles += 1
			else
				store(part, folder(ReplicatedStorage, "Bodies"), scale)
				bodies += 1
			end
		end
	end
	characters:Destroy()
	table.insert(report, `{bodies} pièces de corps, {styles} pièces de style`)
end

local townsfolk = workspace:FindFirstChild("MogLife_Townsfolk")
if townsfolk then
	local scale, count = importScale(townsfolk), 0
	local models = folder(ServerStorage, "NpcModels")
	for _, part in townsfolk:GetDescendants() do
		if part:IsA("MeshPart") then
			local old = models:FindFirstChild(part.Name)
			if old then
				old:Destroy()
			end
			local model = Instance.new("Model")
			model.Name = part.Name
			store(part, model, scale)
			model.PrimaryPart = part
			model.Parent = models
			count += 1
		end
	end
	townsfolk:Destroy()
	table.insert(report, `{count} habitants`)
end

for _, name in { "MogLife_Buildings", "MogLife_GymStations", "MogLife_AllProps", "props" } do
	local props = workspace:FindFirstChild(name)
	if props then
		local scale, count = importScale(props), 0
		for _, part in props:GetDescendants() do
			if part:IsA("MeshPart") then
				store(part, folder(ServerStorage, "Props"), scale)
				count += 1
			end
		end
		props:Destroy()
		table.insert(report, `{count} décors ({name})`)
	end
end

if #report == 0 then
	warn("[install_all] Rien à ranger : importer d'abord un FBX (Accueil > Importer 3D).")
else
	print(`[install_all] Rangé : {table.concat(report, ", ")}. Penser à Ctrl+S.`)
end
