-- Corps du personnage du joueur selon son stade : proportions du squelette R15 + coque Blender.
-- Les parties Roblox d'origine deviennent invisibles ; chaque pièce de la coque est soudée à sa partie,
-- donc les animations Roblox standard fonctionnent telles quelles.
-- Si le modèle d'un stade n'est pas encore importé, l'apparence provisoire de StatsService s'applique.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bodies = require(ReplicatedStorage.Shared.Config.Bodies)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)

local SHELL_NAME = "BodyShell"

local DataService

local BodyService = {}

-- Corps prévu pour le stade du joueur, seulement si son modèle est bien présent dans le jeu
function BodyService.BodyFor(player: Player): (Bodies.Body?, Model?)
	local data = DataService.Get(player)
	local stage = data and Stages.List[data.Stage]
	local body = stage and Bodies[stage.id]
	local folder = ReplicatedStorage:FindFirstChild("Bodies")
	local template = body and folder and folder:FindFirstChild(body.model)
	if body and template and template:IsA("Model") then
		return body, template
	end
	return nil, nil
end

local function applyProportions(humanoid: Humanoid, body: Bodies.Body)
	local description = humanoid:GetAppliedDescription()
	description.WidthScale = body.width
	description.HeightScale = body.height
	description.DepthScale = body.depth
	description.HeadScale = body.head
	description.ProportionScale = 0
	description.BodyTypeScale = 0
	-- Parties standard (tailles prévisibles), sans accessoires ni vêtements : la coque les remplace
	description.Head = 0
	description.Torso = 0
	description.LeftArm = 0
	description.RightArm = 0
	description.LeftLeg = 0
	description.RightLeg = 0
	description.Face = 0
	description.Shirt = 0
	description.Pants = 0
	description.GraphicTShirt = 0
	description:SetAccessories({}, true)
	humanoid:ApplyDescription(description)
end

local function hideOriginalBody(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
			child.Transparency = 1
			for _, decal in child:GetChildren() do
				if decal:IsA("Decal") then
					decal.Transparency = 1
				end
			end
		end
	end
end

local function buildShell(character: Model, body: Bodies.Body, template: Model)
	local old = character:FindFirstChild(SHELL_NAME)
	if old then
		old:Destroy()
	end
	local shell = Instance.new("Model")
	shell.Name = SHELL_NAME

	local prefix = body.model .. "_"
	local mains: { [string]: BasePart } = {}
	for _, piece in template:GetDescendants() do
		if piece:IsA("BasePart") then
			local suffix = string.sub(piece.Name, #prefix + 1)
			if not string.find(suffix, "_", 1, true) then
				mains[suffix] = piece
			end
		end
	end

	for _, piece in template:GetDescendants() do
		if not piece:IsA("BasePart") or string.sub(piece.Name, 1, #prefix) ~= prefix then
			continue
		end
		local suffix = string.sub(piece.Name, #prefix + 1)
		local partName = string.split(suffix, "_")[1]
		local main = mains[partName]
		local target = character:FindFirstChild(partName)
		if not main or not target or not target:IsA("BasePart") then
			continue
		end
		-- La pièce principale est centrée sur sa partie ; les détails gardent leur position par rapport à elle
		local offset = main.CFrame:ToObjectSpace(piece.CFrame)
		local clone = piece:Clone()
		clone.Anchored = false
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.Massless = true
		clone.CastShadow = true
		clone.Color = body.colors[suffix] or body.skin
		clone.CFrame = target.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = target
		weld.Part1 = clone
		weld.Parent = clone
		clone.Parent = shell
	end
	shell.Parent = character
end

-- Applique (ou retire) le corps du stade sur le personnage actuel du joueur
function BodyService.Refresh(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end
	local body, template = BodyService.BodyFor(player)
	if not body or not template then
		local old = character:FindFirstChild(SHELL_NAME)
		if old then
			old:Destroy()
		end
		return
	end
	applyProportions(humanoid, body)
	hideOriginalBody(character)
	buildShell(character, body, template)
end

function BodyService.Init(services)
	DataService = services.DataService
end

function BodyService.Start()
	DataService.PlayerLoaded:Connect(function(player)
		player.CharacterAppearanceLoaded:Connect(function()
			BodyService.Refresh(player)
		end)
		if player.Character and player:HasAppearanceLoaded() then
			task.spawn(BodyService.Refresh, player)
		end
	end)
end

return BodyService
