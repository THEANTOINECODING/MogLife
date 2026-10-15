-- Décors 3D (modélisés dans Blender, importés dans ServerStorage.Props) : chaque emplacement de la carte
-- (tag "PropSlot", attribut Prop = nom du modèle) reçoit une copie du modèle, posée sur son repère, et les
-- blocs provisoires (enfant « Fallback ») sont retirés. Sans modèle importé, les blocs restent : rien ne casse.
-- Attributs optionnels d'un emplacement :
--   PropHeight  : hauteur voulue (le modèle est agrandi ou réduit uniformément)
--   PropCollide : false = on passe à travers (stations, tapis, décors au ras du sol)
--   PropAlign   : "Back" = le dos du modèle touche le repère (fenêtres, enseignes contre un mur)
-- Une station d'exercice (BasePart) peut aussi être un emplacement : le modèle se pose sur la dalle et
-- remplace ses accessoires en blocs.
-- Les décors peuvent aussi être posés dans Studio en mode édition (tools/bake_props.luau) pour voir la ville
-- finale ; au démarrage, le serveur les repose de toute façon.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local SLOT_TAG = "PropSlot"
local ANCHOR_NAME = "PropAnchor"
local FALLBACK_NAME = "Fallback"
local VISUAL_NAME = "PropVisual"

local PropService = {}

-- Modèle importé portant ce nom (une MeshPart), ou nil
function PropService.GetTemplate(name: string): BasePart?
	local folder = ServerStorage:FindFirstChild("Props")
	local template = folder and folder:FindFirstChild(name, true)
	if template and template:IsA("BasePart") then
		return template
	end
	return nil
end

-- Copie du modèle posée sur `base` (au sol, devant vers -Z du repère), ou nil si le modèle n'existe pas
function PropService.Place(name: string, base: CFrame, options: { [string]: any }?): BasePart?
	local template = PropService.GetTemplate(name)
	if not template then
		return nil
	end
	local opts = options or {}
	local clone = template:Clone()
	clone.Name = VISUAL_NAME
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
			if child:IsA("BasePart") and child.Name ~= VISUAL_NAME then
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
	-- Déjà posé (dans Studio par tools/bake_props.luau) : on le repose, au cas où l'emplacement a bougé
	local existing = slot:FindFirstChild(VISUAL_NAME)
	if existing then
		existing:Destroy()
	end

	local base: CFrame
	if slot:IsA("BasePart") then
		-- Station : le modèle se pose sur la dalle
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
	visual.Parent = slot
end

-- Pose les décors 3D dans tous les emplacements (appelé au démarrage du serveur, et dans Studio en mode édition
-- par tools/bake_props.luau pour voir la ville finale sans lancer le jeu)
function PropService.PlaceAll(): number
	local count = 0
	for _, slot in CollectionService:GetTagged(SLOT_TAG) do
		setup(slot)
		if slot:FindFirstChild(VISUAL_NAME) then
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
