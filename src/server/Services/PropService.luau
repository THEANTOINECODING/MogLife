-- Décors 3D (modélisés dans Blender, importés dans ServerStorage.Props) : chaque emplacement de la carte
-- (tag "PropSlot", attribut Prop = nom du modèle) reçoit une copie du modèle, posée sur son repère.
-- Attributs optionnels d'un emplacement :
--   PropHeight  : hauteur voulue (le modèle est agrandi ou réduit uniformément)
--   PropCollide : false = on passe à travers (stations, tapis, décors au ras du sol)
--   PropAlign   : "Back" = le dos du modèle touche le repère (fenêtres, enseignes contre un mur)
-- Une station d'exercice (BasePart) peut aussi être un emplacement : le modèle se pose sur la dalle.
--
-- Les copies vont dans Workspace.MapProps, un dossier que Rojo ne gère pas (la carte, elle, vient des fichiers :
-- Rojo efface tout ce qu'on ajoute à l'intérieur). Dans Studio, tools/bake_props.luau les pose en mode édition
-- pour voir la ville finale ; au démarrage, le serveur les repose de toute façon (la carte a pu changer).
-- Si une carte est régénérée avec les blocs de secours (« Fallback »), ils sont retirés quand le modèle existe.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local SLOT_TAG = "PropSlot"
local ANCHOR_NAME = "PropAnchor"
local FALLBACK_NAME = "Fallback"
local FOLDER_NAME = "MapProps"

local visuals: { [Instance]: BasePart } = {}

local PropService = {}

local function getFolder(): Folder
	local folder = workspace:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = workspace
	end
	return folder :: Folder
end

-- Modèle importé portant ce nom (une MeshPart), ou nil
function PropService.GetTemplate(name: string): BasePart?
	local folder = ServerStorage:FindFirstChild("Props")
	local template = folder and folder:FindFirstChild(name, true)
	if template and template:IsA("BasePart") then
		return template
	end
	return nil
end

-- Copie du modèle posée sur `base` (au sol, devant vers -Z du repère), ou nil si le modèle n'existe pas.
-- La copie n'a pas de parent : à l'appelant de la ranger.
function PropService.Place(name: string, base: CFrame, options: { [string]: any }?): BasePart?
	local template = PropService.GetTemplate(name)
	if not template then
		return nil
	end
	local opts = options or {}
	local clone = template:Clone()
	clone.Anchored = true
	local height = opts.height
	if typeof(height) == "number" and height > 0 and clone.Size.Y > 0 then
		clone.Size *= height / clone.Size.Y
	end
	clone.CanCollide = opts.collide ~= false
	clone.CanTouch = false
	local offsetZ = if opts.align == "Back" then -clone.Size.Z / 2 else 0
	local offsetY = if opts.centered then 0 else clone.Size.Y / 2
	clone.CFrame = base * CFrame.new(0, offsetY, offsetZ)
	return clone
end

-- Retire les blocs provisoires d'un emplacement qui a son modèle 3D
local function removeFallback(slot: Instance)
	if slot:IsA("BasePart") then
		for _, child in slot:GetChildren() do
			if child:IsA("BasePart") then
				child:Destroy()
			end
		end
	else
		local fallback = slot:FindFirstChild(FALLBACK_NAME)
		if fallback then
			fallback:Destroy()
		end
	end
end

local function setup(slot: Instance)
	local name = slot:GetAttribute("Prop")
	if typeof(name) ~= "string" then
		return
	end
	local old = visuals[slot]
	if old then
		old:Destroy()
		visuals[slot] = nil
	end

	local base: CFrame
	if slot:IsA("BasePart") then
		base = slot.CFrame * CFrame.new(0, slot.Size.Y / 2, 0)
	else
		local anchor = slot:FindFirstChild(ANCHOR_NAME)
		if not anchor or not anchor:IsA("BasePart") then
			return
		end
		base = anchor.CFrame
	end

	local visual = PropService.Place(name, base, {
		height = slot:GetAttribute("PropHeight"),
		collide = slot:GetAttribute("PropCollide"),
		align = slot:GetAttribute("PropAlign"),
	})
	if not visual then
		return
	end
	removeFallback(slot)
	visual.Name = name
	visual.Parent = getFolder()
	visuals[slot] = visual
end

-- Pose (ou repose) les décors 3D de tous les emplacements. Renvoie le nombre de décors posés.
function PropService.PlaceAll(): number
	local existing = workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
	table.clear(visuals)
	local count = 0
	for _, slot in CollectionService:GetTagged(SLOT_TAG) do
		setup(slot)
		if visuals[slot] then
			count += 1
		end
	end
	return count
end

function PropService.Start()
	PropService.PlaceAll()
	CollectionService:GetInstanceAddedSignal(SLOT_TAG):Connect(setup)
end

return PropService
