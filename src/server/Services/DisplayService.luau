-- Présentoirs des magasins (étape 3) : mannequins habillés au magasin de vêtements, têtes coiffées chez le coiffeur.
-- Ils portent les VRAIS objets de la boutique (mêmes modèles que sur les joueurs, ReplicatedStorage.Style),
-- sur un corps de stade blanc façon mannequin de vitrine.
-- Un présentoir = une pièce invisible taggée "StyleDisplay" (posée au sol, face vers -Z), avec les attributs :
--   Stage : corps porté (Normie, Bro, Chad…)   Items : objets, séparés par des virgules
--   Kind  : "Mannequin" (corps entier sur un socle) ou "Bust" (tête seule sur un pied)
-- Si les modèles ne sont pas importés, le présentoir reste vide.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BodyPieces = require(ReplicatedStorage.Shared.Config.BodyPieces)
local BodySkeleton = require(ReplicatedStorage.Shared.Config.BodySkeleton)
local StyleItems = require(ReplicatedStorage.Shared.Config.StyleItems)
local StylePieces = require(ReplicatedStorage.Shared.Config.StylePieces)

local TAG = "StyleDisplay"
local MANNEQUIN_COLOR = Color3.fromRGB(236, 234, 228)
local STAND_COLOR = Color3.fromRGB(70, 70, 76)

local DisplayService = {}

local function placePiece(template: BasePart, cframe: CFrame, parent: Instance, mannequin: boolean)
	local clone = template:Clone()
	clone.Anchored = true
	clone.CanCollide = false
	clone.CanTouch = false
	clone.CFrame = cframe
	if mannequin and clone:IsA("MeshPart") then
		-- Corps de vitrine : blanc mat, sans visage ni peau
		clone.TextureID = ""
		clone.Color = MANNEQUIN_COLOR
		clone.Material = Enum.Material.SmoothPlastic
	end
	clone.Parent = parent
end

local function stand(name: string, size: Vector3, cframe: CFrame, parent: Instance)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = size
	part.CFrame = cframe * CFrame.Angles(0, 0, math.pi / 2)
	part.Color = STAND_COLOR
	part.Material = Enum.Material.Metal
	part.Anchored = true
	part.CanTouch = false
	part.Parent = parent
end

local function build(anchor: Instance)
	if not anchor:IsA("BasePart") then
		return
	end
	local bodies = ReplicatedStorage:FindFirstChild("Bodies")
	local styles = ReplicatedStorage:FindFirstChild("Style")
	local stage = anchor:GetAttribute("Stage")
	local itemsText = anchor:GetAttribute("Items")
	local kind = anchor:GetAttribute("Kind")
	local skeleton = typeof(stage) == "string" and BodySkeleton[stage]
	if not bodies or not styles or not skeleton or typeof(itemsText) ~= "string" then
		return
	end
	local old = anchor:FindFirstChild("Display")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "Display"
	local base = anchor.CFrame * CFrame.new(0, -anchor.Size.Y / 2, 0)
	local bust = kind == "Bust"

	-- Une tête seule est posée sur son pied : on la descend à hauteur du présentoir
	local lift = Vector3.zero
	if bust then
		local head = skeleton.Head
		lift = Vector3.new(0, -head.Y + 1.1, 0)
		stand("Stand", Vector3.new(0.9, 0.35, 0.35), base * CFrame.new(0, 0.45, 0), model)
	else
		stand("Base", Vector3.new(0.15, 3.2, 3.2), base * CFrame.new(0, 0.075, 0), model)
	end

	local items = string.split(itemsText, ",")
	local hasHair = false
	for _, itemId in items do
		local item = StyleItems[itemId]
		if item and item.category == "Hair" then
			hasHair = true
		end
	end

	-- Le corps (blanc) puis les objets exposés
	for piece, offset in BodyPieces[stage] do
		local part = string.split(piece, "_")[1]
		local skip = (bust and part ~= "Head") or (piece == "Head_Hair" and (hasHair or bust))
		local template = bodies:FindFirstChild(`{stage}_{piece}`)
		if not skip and template and template:IsA("BasePart") then
			placePiece(template, base * CFrame.new(skeleton[part] + offset + lift), model, true)
		end
	end
	for _, itemId in items do
		for part, offset in (StylePieces[stage] and StylePieces[stage][itemId]) or {} do
			local template = styles:FindFirstChild(`{stage}__{itemId}__{part}`)
			if template and template:IsA("BasePart") and (not bust or part == "Head") then
				placePiece(template, base * CFrame.new(skeleton[part] + offset + lift), model, false)
			end
		end
	end
	model.Parent = anchor
end

function DisplayService.Start()
	for _, anchor in CollectionService:GetTagged(TAG) do
		build(anchor)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(build)
end

return DisplayService
