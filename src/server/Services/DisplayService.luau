-- Présentoirs des magasins (étape 3) : mannequins habillés au magasin de vêtements, têtes coiffées chez le coiffeur.
-- Ils portent les VRAIS objets de la boutique (mêmes modèles que sur les joueurs, module Outfit),
-- sur un corps de stade blanc façon mannequin de vitrine.
-- Un présentoir = une pièce invisible taggée "StyleDisplay" (posée au sol, face vers -Z), avec les attributs :
--   Stage : corps porté (Normie, Bro, Chad…)   Items : objets, séparés par des virgules
--   Kind  : "Mannequin" (corps entier sur un socle) ou "Bust" (tête seule sur un pied)
-- Si les modèles ne sont pas importés, le présentoir reste vide.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Outfit = require(ReplicatedStorage.Shared.Outfit)

local TAG = "StyleDisplay"
local STAND_COLOR = Color3.fromRGB(70, 70, 76)
local BUST_HEIGHT = 1.1 -- centre de la tête au-dessus du présentoir

local DisplayService = {}

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
	local stage = anchor:GetAttribute("Stage")
	local items = anchor:GetAttribute("Items")
	if typeof(stage) ~= "string" or typeof(items) ~= "string" then
		return
	end
	local bust = anchor:GetAttribute("Kind") == "Bust"
	local outfit = Outfit.Build(stage, string.split(items, ","), { mannequin = true, bust = bust })
	if not outfit then
		return
	end
	local old = anchor:FindFirstChild("Display")
	if old then
		old:Destroy()
	end
	outfit.Name = "Display"
	local base = anchor.CFrame * CFrame.new(0, -anchor.Size.Y / 2, 0)
	if bust then
		-- Une tête seule est posée sur son pied : on la descend à hauteur du présentoir
		local head = Outfit.HeadCenter(stage) :: Vector3
		outfit:PivotTo(base * CFrame.new(0, BUST_HEIGHT - head.Y, 0))
		stand("Stand", Vector3.new(0.9, 0.35, 0.35), base * CFrame.new(0, 0.45, 0), outfit)
	else
		outfit:PivotTo(base)
		stand("Base", Vector3.new(0.15, 3.2, 3.2), base * CFrame.new(0, 0.075, 0), outfit)
	end
	outfit.Parent = anchor
end

function DisplayService.Start()
	for _, anchor in CollectionService:GetTagged(TAG) do
		build(anchor)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(build)
end

return DisplayService
